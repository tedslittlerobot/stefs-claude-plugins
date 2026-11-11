---
name: lambdas-node
description: Node.js AWS Lambda conventions for production — when Node is justified over Go, ESM/.mjs modules, the nodejs runtime on arm64 and index.handler entry point, bundling with esbuild and npm ci in CI, factory-function dependency injection, structured JSON logging with Powertools for AWS Lambda Logger and log levels, idempotency, partial batch failures (batchItemFailures), dead-letter queues, getRemainingTimeInMillis and abortSignal, OpenTelemetry (OTel) metrics over OTLP to CloudWatch and CloudWatch Omni with a SigV4-signing exporter and forceFlush per invocation, tracing and alarms, npm audit, node --test with co-located .test.mjs files and integration tests, and the same trigger-based directory naming as Go Lambdas (api-, api-socket-, alb-, url-, sqs-, sns-, dynamo-, kinesis-, kafka-, s3-, bus-, pipe-, schedule-, cognito-, secrets-, invoke- and the rest). Use when writing, editing, reviewing, testing, building or deploying a Node.js Lambda, or deciding whether a Lambda may be written in Node at all.
---

# Node.js Lambda Conventions

> **Engineering conventions, for projects built to run in production.** This skill is part of the
> `engineering-conventions` plugin. A prototype or proof of concept that also has the
> `prototype-conventions` plugin installed follows that plugin's `lambdas-node` skill instead —
> its rules are chosen for speed of building, and it says so.

Applies to every Node.js Lambda function in the repository.

Go is the default for Lambdas (see the `lambdas-go` skill). **A Node.js Lambda is a registered
exception, not a free choice** — but where it is justified, it is a first-class Lambda held to
equivalent standards, not a scratch script.

## When Node Is Justified

The bar is that **an official vendor library exists for Node and not for Go, and reimplementing it
in Go would be the wrong kind of original work** — security-sensitive, cryptographic, or protocol
code whose bugs surface intermittently in production rather than as a failing test.

The worked example: Cognito's Custom Email Sender trigger encrypts the code it hands the Lambda
using the AWS Encryption SDK message format (KMS keyring, HKDF key derivation, an embedded
signature). AWS publishes official AWS Encryption SDK clients for Java, Python, JavaScript/Node.js,
.NET and C — **there is no official Go implementation.** Hand-rolling that decryption in Go was
judged too high-risk for a security-sensitive path (password reset and sign-up codes) against using
AWS's own `@aws-crypto/client-node`.

What does **not** clear the bar: familiarity, a nicer npm package for something Go can already do,
or wanting to reuse frontend code. "There is a convenient library" is not the same as "there is no
viable Go path".

**Every Node Lambda is recorded as a deliberate exception in the project's own conventions, with its
reason** — otherwise the next reader takes it as precedent. See the `conventions` skill on
registered exceptions.

## Runtime & Packaging

- **Runtime**: a current `nodejs<N>.x` Lambda runtime, pinned in Terraform, architecture **`arm64`**
  — the same choice and reason as a Go Lambda's (see `lambdas-go`). A dependency with native code
  needs a `linux-arm64` build, and is a reason to look hard at whether it is needed at all
- **Handler**: `index.handler` — the exported handler in the bundled `index.mjs`
- **ESM, not CommonJS.** `package.json` sets `"type": "module"`; source files are `.mjs`. No
  `require`, no transpiler
- **`package.json` is `"private": true`** with an explicit `main`, and pins its dependencies
- **`.gitignore` ignores `node_modules/` and `build/`**
- **CI bundles the Lambda with esbuild into one file**, and that file is the artifact:

```bash
npm ci
npx esbuild index.mjs --bundle --platform=node --target=node<N> --format=esm \
  --sourcemap --outfile=build/index.mjs \
  --banner:js="import { createRequire } from 'module'; const require = createRequire(import.meta.url);"
```

| Part | Why |
| --- | --- |
| `npm ci` | Installs exactly what `package-lock.json` says, and **fails** if `package.json` disagrees with it — where `npm install` would quietly resolve something new |
| `--bundle` | One file with only the code actually imported: a smaller artifact and a faster cold start than a zipped `node_modules/` |
| The AWS SDK is bundled too | The runtime's built-in SDK version changes underneath a deployed function; a bundled one changes only when the lockfile does |
| `--target=node<N>` | Matches the runtime, so esbuild leaves alone syntax the runtime already supports |
| `--sourcemap` | With `NODE_OPTIONS=--enable-source-maps` on the function, stack traces point at the source file and line, not the bundle |
| The `createRequire` banner | Some dependencies are CommonJS and call `require` at run time; inside an ESM bundle that name does not exist without it |

The zip and the content-addressed upload are **the same as a Go Lambda's** — see the
build-and-deploy reference in the `lambdas-go` skill — and so is the deployment, by CI behind a
`live` alias, in the `infrastructure` skill's `lambda-deployment.md`.

**Diverged from `prototype-conventions`:** the prototype skill has no build step at all —
`terraform-aws-modules/lambda/aws`, given a plain-string `source_path`, runs `npm install` on the
machine running Terraform and zips the folder. That is the least machinery a prototype can have. In
production it ships whatever `npm install` resolved on that machine on that day, with the whole of
`node_modules/` in the zip, and no record of the bytes that went out.

## Directory Naming

**Identical to Go Lambdas** — the trigger must be visible from the directory name alone:

| Trigger | Name |
| --- | --- |
| API Gateway HTTP route | `api-<http-method>-<purpose>` (route under an `/api` prefix) |
| API Gateway WebSocket route | `api-socket-<route>`, dropping the `$` — `api-socket-connect` |
| Application Load Balancer target | `alb-<http-method>-<purpose>` |
| Lambda function URL | `url-<purpose>` — no method. **Discouraged**: needs a recorded justification, see `lambdas-go` |
| SQS queue | `sqs-<sqs-queue-name>` (drop a `.fifo` suffix) |
| SNS, Amazon MQ, DynamoDB stream, Kinesis, MSK/Kafka, DocumentDB change stream | `sns-`, `mq-`, `dynamo-`, `kinesis-`, `kafka-`, `docdb-`, then what the Lambda does |
| S3 lifecycle event | `s3-<what-it-handles>` — the event, or a terse summary of the work; see `lambdas-go` |
| EventBridge bus event | `bus-<what-the-lambda-does>`, not the event name — see `lambdas-go` |
| EventBridge Pipe | `pipe-<what-the-lambda-does>` |
| Schedule (scheduled rule or EventBridge Scheduler) | `schedule-<frequency>-<purpose>` — `schedule-nightly-clear-caches` |
| Cognito User Pool trigger | `cognito-<what-it-handles>` — `cognito-custom-email-sender`; see `lambdas-go` |
| CloudWatch Logs subscription, CloudWatch alarm, SES receipt rule, IoT Core rule | `logs-`, `alarm-`, `email-`, `iot-`, then what the Lambda does |
| Aurora MySQL from SQL, Lambda destination | `aurora-`, `lambda-`, then what the Lambda does. **`aurora-` is discouraged**: needs a recorded justification, see `lambdas-go` |
| Secrets Manager rotation | `secrets-<what-it-rotates>` — `secrets-aurora-credentials` |
| Manual invocation only | `invoke-<purpose>` — invocable by a restricted operations role only; see `lambdas-go` |
| Anything else | the function's purpose |

**Corrected:** the last row used to read "A provider trigger, or anything else", with
`custom-email-sender` — a Cognito trigger — as its example. Cognito triggers now take the
`cognito-` prefix, for the reasons given in `lambdas-go`; an existing unprefixed one is not wrong,
but new ones take the prefix.

**Diverged from `prototype-conventions`:** the manual-invocation prefix was `ninja-` there; see
`lambdas-go` for why it is `invoke-` here, and restricted.

The language a Lambda is written in is **not** part of its directory name. A reader should not have
to care.

## Structure

```
lambdas/<function-name>/
  package.json         # "type": "module", "private": true, pinned deps
  package-lock.json
  .gitignore           # node_modules/, build/
  index.mjs            # factory functions + the exported handler, wired at module load
  logger.mjs           # the Powertools Logger, constructed once
  telemetry.mjs        # the OpenTelemetry meter provider and its signing exporter
  index.test.mjs
  <topic>.mjs          # one file per subject — templates, validation, a client wrapper
  <topic>.test.mjs
  schema.md            # required — the input contract
  README.md            # required — four sections + flow diagram
```

- **One file per subject**, named for the subject. The same principle as a Go Lambda's sub-packages,
  flattened: a Node Lambda small enough to justify the exception rarely needs directories
- **Test files sit beside the file they test** — `templates.test.mjs` tests `templates.mjs`

Read **`reference/structure-and-testing.md`** for the factory-function pattern and the test
approach before writing one.

## Dependency Injection via Factory Functions

**Logic is structured as small factory functions that take their external dependencies as
parameters** — `makeHandler`, `makeDecryptCode`, `makeSendEmail` — so tests exercise real
orchestration logic against fake dependencies rather than mocking the AWS SDK or hitting real AWS.

```js
export function makeHandler({ decryptCode, sendEmail, frontendUrl, logger }) {
  return async function handler(event, context) { /* … */ }
}
```

This is the **direct analogue of a Go Lambda's `Handler` struct holding interface-typed
dependencies**, and it is there for the same reason: the orchestration is the part worth testing,
and it is only testable if the I/O is injected.

**Module top-level is the wiring layer** — the Node equivalent of Go's `main.go`. Read environment
variables, construct the real SDK clients, call the factories, and export the result:

```js
const sesClient = new SESv2Client({})
const decryptCode = makeDecryptCode({ decryptFn: buildDecrypt(...).decrypt, kmsKeyArn: process.env.KMS_KEY_ARN })
const sendEmail   = makeSendEmail({ sesClient, fromEmail: process.env.FROM_EMAIL })

export const handler = makeHandler({ decryptCode, sendEmail, frontendUrl: process.env.FRONTEND_URL, logger })
```

**Export the factories as well as the wired handler**, since the factories are what tests call.

## Logging

**Structured JSON through [Powertools for AWS Lambda](https://docs.powertools.aws.dev/lambda/typescript/)'s
`Logger`** (`@aws-lambda-powertools/logger`) — never bare `console.log`. Its key names are the ones
a Go Lambda's `slog` setup copies, so one Logs Insights query works across every function whatever
its language:

```js
// logger.mjs
import { Logger } from '@aws-lambda-powertools/logger'
export const logger = new Logger({ serviceName: 'cognito-custom-email-sender' })
```

```js
// in the handler — addContext adds function_request_id and the rest from the invocation
logger.addContext(context)
logger.info('handling trigger', { step: 'index.mjs:handler:start', trigger_source: event.triggerSource, user_id: sub })
```

- **The same keys, levels and rules as a Go Lambda** — `service` is the directory name, `step` is
  `<file>:<function>:<step-id>`, the line's own fields are `snake_case`, and the levels mean the
  same things. See the Logging section of `lambdas-go`
- The level comes from the function's application log level (`AWS_LAMBDA_LOG_LEVEL`), which
  Powertools reads; production runs at `INFO`
- **The logger is a dependency like any other** — passed into the factories, so a test hands in
  `new Logger({ logLevel: 'SILENT' })` or a fake that records what was logged
- **Log identifiers, not personal data.** The Cognito `sub`, not the username or email — in many
  pools the username *is* the email. **Never secrets, tokens, decrypted codes or credentials**: log
  that a code was decrypted, never the code
- Powertools is the platform's logging standard, not a reason this Lambda is Node — it does not
  count against the dependency budget in `reference/structure-and-testing.md`

**Diverged from `prototype-conventions`:** the prototype skill logs plain text with
``console.log(`[module:file:function:step] message key=value`)``, at one level. See `lambdas-go` for
why that does not survive production.

## Failure Handling

**Exactly the rules in the `lambdas-go` skill's failure-handling reference** — how each trigger
retries, idempotency, partial batch responses, where failures land, timeouts. They are about the
trigger, not the language. In Node:

- **The deadline is `context.getRemainingTimeInMillis()`.** Pass a signal derived from it to every
  AWS SDK call — `client.send(command, { abortSignal: AbortSignal.timeout(ms) })` — and to `fetch`,
  so a slow call fails while there is still time to report it
- **A partial batch response** is a plain object:
  `return { batchItemFailures: [{ itemIdentifier: record.messageId }] }`

## Observability

**The same as a Go Lambda** — see the `lambdas-go` skill's observability and metrics references.

- **Metrics are OpenTelemetry metrics**, exported over OTLP to CloudWatch for CloudWatch Omni, by a
  small SigV4-signing exporter in `telemetry.mjs` — read `reference/structure-and-testing.md` for
  it.
  The resource attributes, naming, cardinality and temporality rules are `lambdas-go`'s metrics
  reference, unchanged
- **The handler awaits `meterProvider.forceFlush()` in a `finally`** before it returns, catching
  and logging a failure at `WARN` rather than throwing it
- Tracing with OpenTelemetry, and the same alarms

**Corrected at 0.3.0:** this section prescribed Embedded Metric Format through Powertools'
`@aws-lambda-powertools/metrics`. See `lambdas-go`'s metrics reference for why it changed.

## Testing

- **Node's built-in test runner** — `node --test`, wired as `"test": "node --test"` in
  `package.json`. **No external test framework dependency**
- Test files are `*.test.mjs`, **co-located** with the source they test
- **Unit tests** call the **factories** with fake dependencies and assert on real orchestration —
  never mock the AWS SDK, never hit AWS
- **Integration tests** — against a real database, or a deployed non-production environment — sit
  in `*.integration.test.mjs` files and **skip unless `INTEGRATION` is set**, so `npm test` stays
  fast and offline. The rules for what they cover are the `lambdas-go` skill's testing reference
- Tests run against the **source**, not the bundle; the bundle is checked by the
  deployed-environment smoke tests

```bash
npm test                                  # from the Lambda's own directory
node --test index.test.mjs                # a single file
INTEGRATION=1 npm test                    # unit and integration tests
npm audit --omit=dev --audit-level=high   # dependency vulnerabilities — CI fails on a finding
```

**Diverged from `prototype-conventions`:** the prototype skill stops at unit tests. See `lambdas-go`
for why production does not.

## Required Documentation

**The same two files as every Go Lambda** — the language changes nothing about the documentation
contract:

- **`schema.md`** — the input contract: summary, TypeScript-syntax schema, worked JSON examples. See
  the schema-md reference **in the `lambdas-go` skill** — the template is language-agnostic
- **`README.md`** — four sections (Invocation, Purpose, Interface, Implementation with a rendered
  flow diagram). See the `documentation` skill's READMEs reference

## Related

- `lambdas-go` skill — the default, and the source of the naming, logging, failure-handling,
  observability, build and documentation rules this skill shares
- `infrastructure` skill — the Terraform side of a Lambda: its configuration, failure destinations,
  permissions and alarms, the timeout rule, and how CI deploys its code
- `conventions` skill, in `documentation-and-planning` where installed — how a registered exception
  is recorded, and why the reason must travel with it
- `documentation` skill, in `documentation-and-planning` where installed — the Lambda `README.md`
  format
