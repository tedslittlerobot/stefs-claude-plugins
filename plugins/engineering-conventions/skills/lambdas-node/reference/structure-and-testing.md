# Structure & Testing

## The Factory-Function Pattern

A Node Lambda has the same two concerns a Go Lambda separates into `main.go` and `handler.go`:
**wiring** and **orchestration**. It separates them with factory functions rather than a struct and
an interface.

### One factory per external dependency

Each thing that talks to the outside world gets a factory that closes over what it needs and returns
a plain async function:

```js
export function makeDecryptCode({ decryptFn, kmsKeyArn }) {
  return async function decryptCode(encryptedCode) {
    if (!encryptedCode) {
      return null
    }
    const keyring = new KmsKeyringNode({ keyIds: [kmsKeyArn] })
    const { plaintext } = await decryptFn(keyring, Buffer.from(encryptedCode, 'base64'))
    return plaintext.toString('utf-8')
  }
}

export function makeSendEmail({ sesClient, fromEmail }) {
  return async function sendEmail({ toAddress, email }) {
    await sesClient.send(new SendEmailCommand({ /* … */ }))
  }
}
```

The returned function's signature is **the seam**: it speaks in the Lambda's own terms
(`encryptedCode`, `{ toAddress, email }`), not the SDK's. That is what lets a test pass a
three-line fake instead of a mocked SDK client.

### One factory for the orchestration

```js
// Everything the handler actually does, independent of how its
// dependencies (decryption, sending) are constructed — this is what unit
// tests exercise directly, with fake decryptCode/sendEmail, rather than
// mocking the AWS SDK or KMS.
export function makeHandler({ decryptCode, sendEmail, frontendUrl, logger }) {
  return async function handler(event, context) {
    logger.addContext(context)
    /* … */
  }
}
```

**A comment at this factory saying what it exists for is worth writing.** The pattern is
unremarkable to anyone who has seen it and puzzling to anyone who has not.

### Module top level is the wiring

Everything above the exports is the equivalent of Go's `main.go` — and holds the same restriction:
**environment variables, client construction, and factory calls only.** No logic.

```js
export const handler = makeHandler({ decryptCode, sendEmail, frontendUrl: process.env.FRONTEND_URL, logger })
```

Because this runs at **module load**, it happens once per container rather than per invocation —
which is what you want for SDK clients, and which is also why a missing environment variable
surfaces as an init failure rather than a per-request error.

## Splitting Files

**One file per subject, named for the subject** — the flattened form of a Go Lambda's sub-packages:

| File | Holds |
| --- | --- |
| `index.mjs` | The factories, the handler orchestration, and the wiring |
| `logger.mjs` | The Powertools `Logger`, constructed once with the Lambda's `serviceName` |
| `telemetry.mjs` | The OpenTelemetry meter provider and its SigV4-signing OTLP exporter — see below |
| `<topic>.mjs` | One subject's logic — email template building, validation, a parsing helper |

A pure function belongs in its own file as soon as it has more than one case worth testing.
Template building is the usual first candidate: it is where the branching lives, and it needs no
dependencies at all, so its tests are the cheapest in the Lambda.

**Do not create directories** unless a Lambda genuinely outgrows a flat layout. If it has, that is
worth noticing — a Node Lambda large enough to need packages may not still clear the bar for being
Node at all.

## Testing

Node's built-in runner, no framework:

```js
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { Logger } from '@aws-lambda-powertools/logger'
import { makeHandler } from './index.mjs'

const context = { awsRequestId: 'test-request', getRemainingTimeInMillis: () => 5000 }

test('sends an email for a sign-up trigger', async () => {
  const sent = []
  const handler = makeHandler({
    decryptCode: async () => '123456',
    sendEmail: async (args) => { sent.push(args) },
    frontendUrl: 'https://example.test',
    logger: new Logger({ logLevel: 'SILENT' }),
  })

  await handler({ triggerSource: 'CustomEmailSender_SignUp', userName: 'u', request: { userAttributes: { sub: 's', email: 'a@b.test' } } }, context)

  assert.equal(sent.length, 1)
  assert.equal(sent[0].toAddress, 'a@b.test')
})
```

- **Fakes are plain functions**, usually one line, often collecting their arguments into an array so
  the test can assert on what the orchestration *decided* rather than on what a mock recorded
- **Never mock the AWS SDK and never hit AWS in a unit test.** The factories exist so that neither
  is necessary
- **Assert what is not logged.** Pass a fake logger that records its calls, run the path that
  handles the decrypted code, and assert the code appears in none of them
- **Cover the paths that return early.** A handler that skips sending when an attribute is absent
  needs a test asserting **nothing** was sent — that branch is invisible in production
- **Table-driven tests** for anything with more than one case (every trigger source, every template
  variant): an array of cases and a loop of `test(...)` calls, so adding a case is one line

```bash
npm test                     # all tests, from the Lambda's own directory
node --test index.test.mjs   # one file
```

### Integration tests

Integration tests sit in `*.integration.test.mjs` beside the file they exercise, and skip unless
`INTEGRATION` is set, so `npm test` stays fast and needs no network:

```js
test('reads the user back from the database', { skip: !process.env.INTEGRATION }, async () => {
  /* … against a real database or a deployed non-production environment … */
})
```

What they must cover — a real database for queries, the deployed environment for permissions and
event shapes — is set out in the `lambdas-go` skill's testing reference, and applies unchanged.

## Dependencies

- **Pin dependencies** and commit `package-lock.json` — CI's `npm ci` installs exactly what it
  says, and fails if `package.json` has moved on without it
- **`esbuild` is a pinned `devDependency`**: it builds the bundle and never ships in it
- **`npm audit --omit=dev --audit-level=high` runs in CI** and fails the build on a finding, and
  dependency updates are automated — Renovate or Dependabot, the same as a Go Lambda's
- Prefer the **official vendor SDK** over a wrapper. The reason this Lambda is Node at all is
  usually that the official library only exists here
- **Every added dependency is a new reason this Lambda cannot be Go.** Keep the list short enough
  that the exception stays justifiable. Powertools and the OpenTelemetry and signing packages below
  are the exception to the exception: they are the platform's logging and metrics standard, so they
  say nothing about why the Lambda is Node

## Metrics: `telemetry.mjs`

The rules are the `lambdas-go` skill's metrics reference; this is the Node code. Neither the
OpenTelemetry JavaScript exporters nor the ADOT Node package (as of 0.13.0) can sign an OTLP
*metrics* request with SigV4 — ADOT signs traces and logs only — so the exporter is ours, and small:

```js
import { randomUUID } from 'node:crypto'
import { MeterProvider, PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics'
import { resourceFromAttributes } from '@opentelemetry/resources'
import { ProtobufMetricsSerializer } from '@opentelemetry/otlp-transformer'
import { ExportResultCode } from '@opentelemetry/core'
import { SignatureV4 } from '@smithy/signature-v4'
import { Sha256 } from '@aws-crypto/sha256-js'
import { defaultProvider } from '@aws-sdk/credential-provider-node'

// An OTLP/HTTP metric exporter that signs each request with SigV4 for the
// "monitoring" service, which CloudWatch's OTLP metrics endpoint requires.
export function makeMetricExporter({ region, endpoint = `https://monitoring.${region}.amazonaws.com/v1/metrics`, credentials = defaultProvider(), fetchFn = fetch }) {
  const url = new URL(endpoint)
  const signer = new SignatureV4({ credentials, region, service: 'monitoring', sha256: Sha256 })

  async function send(resourceMetrics) {
    const body = ProtobufMetricsSerializer.serializeRequest(resourceMetrics)
    const { headers } = await signer.sign({
      method: 'POST',
      protocol: url.protocol,
      hostname: url.hostname,
      port: url.port ? Number(url.port) : undefined,
      path: url.pathname,
      headers: { host: url.host, 'content-type': 'application/x-protobuf' },
      body,
    })
    delete headers.host // fetch sets it, from the same URL
    const response = await fetchFn(url, { method: 'POST', headers, body })
    if (!response.ok) {
      throw new Error(`OTLP metrics export failed: ${response.status} ${await response.text()}`)
    }
  }

  return {
    export(resourceMetrics, resultCallback) {
      send(resourceMetrics).then(
        () => resultCallback({ code: ExportResultCode.SUCCESS }),
        (error) => resultCallback({ code: ExportResultCode.FAILED, error }),
      )
    },
    forceFlush: async () => {},
    shutdown: async () => {},
  }
}

export function makeMeterProvider({ exporter, service, namespace, environment }) {
  return new MeterProvider({
    resource: resourceFromAttributes({
      'service.name': service,
      'service.namespace': namespace,
      'service.instance.id': randomUUID(),
      'deployment.environment.name': environment,
    }),
    // Flushed by the handler at the end of every invocation; the timer is a backstop.
    readers: [new PeriodicExportingMetricReader({ exporter, exportIntervalMillis: 3_600_000 })],
  })
}
```

- **The exporter is a factory like everything else**, so a test passes a local `endpoint`, fixed
  `credentials` and its own `fetchFn`, and asserts the request is signed for the `monitoring`
  service
- **`@opentelemetry/otlp-transformer` is a 0.x package** — its API is not yet declared stable. Pin
  it exactly, and treat an upgrade as a change that re-runs the signing test
- In the wiring, the meter provider and the Lambda's instruments are built once at module load and
  passed to `makeHandler`; the handler flushes in a `finally`:

```js
return async function handler(event, context) {
  logger.addContext(context)
  try {
    /* … */
  } finally {
    await meterProvider.forceFlush().catch((error) =>
      logger.warn('metrics flush failed', { step: 'index.mjs:handler:flush-metrics', error }))
  }
}
```
