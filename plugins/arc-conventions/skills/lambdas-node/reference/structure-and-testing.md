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
export function makeHandler({ decryptCode, sendEmail, frontendUrl }) {
  return async function handler(event) { /* … */ }
}
```

**A comment at this factory saying what it exists for is worth writing.** The pattern is
unremarkable to anyone who has seen it and puzzling to anyone who has not.

### Module top level is the wiring

Everything above the exports is the equivalent of Go's `main.go` — and holds the same restriction:
**environment variables, client construction, and factory calls only.** No logic.

```js
export const handler = makeHandler({ decryptCode, sendEmail, frontendUrl: process.env.FRONTEND_URL })
```

Because this runs at **module load**, it happens once per container rather than per invocation —
which is what you want for SDK clients, and which is also why a missing environment variable
surfaces as an init failure rather than a per-request error.

## Splitting Files

**One file per subject, named for the subject** — the flattened form of a Go Lambda's sub-packages:

| File | Holds |
| --- | --- |
| `index.mjs` | The factories, the handler orchestration, and the wiring |
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
import { makeHandler } from './index.mjs'

test('sends an email for a sign-up trigger', async () => {
  const sent = []
  const handler = makeHandler({
    decryptCode: async () => '123456',
    sendEmail: async (args) => { sent.push(args) },
    frontendUrl: 'https://example.test',
  })

  await handler({ triggerSource: 'CustomEmailSender_SignUp', userName: 'u', request: { userAttributes: { email: 'a@b.test' } } })

  assert.equal(sent.length, 1)
  assert.equal(sent[0].toAddress, 'a@b.test')
})
```

- **Fakes are plain functions**, usually one line, often collecting their arguments into an array so
  the test can assert on what the orchestration *decided* rather than on what a mock recorded
- **Never mock the AWS SDK and never hit AWS.** The factories exist so that neither is necessary
- **Cover the paths that return early.** A handler that skips sending when an attribute is absent
  needs a test asserting **nothing** was sent — that branch is invisible in production
- **Table-driven tests** for anything with more than one case (every trigger source, every template
  variant): an array of cases and a loop of `test(...)` calls, so adding a case is one line

```bash
npm test                     # all tests, from the Lambda's own directory
node --test index.test.mjs   # one file
```

## Dependencies

- **Pin dependencies** and commit `package-lock.json` — it is what `npm install` at package time
  resolves against
- Prefer the **official vendor SDK** over a wrapper. The reason this Lambda is Node at all is
  usually that the official library only exists here
- **Every added dependency is a new reason this Lambda cannot be Go.** Keep the list short enough
  that the exception stays justifiable
