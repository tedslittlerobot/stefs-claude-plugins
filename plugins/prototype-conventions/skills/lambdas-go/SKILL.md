---
name: lambdas-go
description: Go AWS Lambda conventions — directory naming by trigger (ninja-, api-<method>-, sqs-, bus-, s3-), one Go module per Lambda compiled to a bootstrap binary, the main.go/handler.go root package with everything else in sub-packages, Go package naming, the structured log line format, file organisation, build commands and testing. Use when writing, editing, reviewing or testing Go Lambda code, creating a new Lambda directory, or deciding which package something belongs in.
---

# Go Lambda Conventions

Applies to every Go Lambda function in the repository. A Lambda written in another language is a
**registered exception** recorded in the project's own conventions — see the `lambdas-node` skill
for the Node.js case.

## Language & Runtime

- **Go**, version pinned via [`goenv`](https://github.com/go-nv/goenv) —
  `goenv install <version> && goenv local <version>`
- Lambda runtime **`provided.al2023`** (Amazon Linux 2023 custom runtime for Go)
- Each Lambda compiles to a standalone binary named **`bootstrap`**
- Each Lambda directory needs a `.gitignore` ignoring the `build/` directory, the
  `bootstrap`/`bootstrap.zip` artefacts, **and a file named after the directory itself** — a bare
  `go build` with no `-o` drops a host binary there beside the source, and without that last line it
  is committable. This is not hypothetical: five had been committed before the rule existed

## Directory Naming

Each Lambda lives in its own directory under the service's `lambdas/` folder, named so its **trigger
is visible from the directory name alone**:

| Trigger | Name | Example |
| --- | --- | --- |
| API Gateway route | `api-<http-method>-<purpose>` | `api-get-profile` for `GET /api/me/profile` |
| SQS queue | `sqs-<sqs-queue-name>` | `sqs-new-users` for the `new-users` queue |
| S3 lifecycle event | `s3-<what-it-handles>` | `s3-upload-scan` for `ObjectCreated:*` on the uploads bucket |
| EventBridge bus event | `bus-<what-the-lambda-does>` | `bus-send-welcome-email`, subscribed to `user.registered` |
| Manual invocation only (`aws lambda invoke`, no route or event source) | `ninja-<purpose>` | `ninja-add-user` |
| Anything else | the function's purpose | `register-user`, `validate-token` |

- An API route **must** live under an `/api` prefix — see the `infrastructure` skill's
  frontend-hosting reference for why (one CloudFront path pattern forward-matches every route)
- For a **FIFO** queue, drop the `.fifo`/`fifo` suffix when forming the Lambda name: a
  `new-users.fifo` queue still yields `sqs-new-users`
- A **`bus-` Lambda is named after what it does, not after the event it subscribes to.** The two
  often overlap — `bus-send-welcome-email` does overlap with `user.registered` — but the event is
  not the name. An event bus is fan-out: the whole point is that several Lambdas subscribe to the
  same event, and naming them after the event means the second subscriber has no name left. It also
  makes the interesting question — *what happens when a user registers?* — unanswerable from a
  directory listing, which is exactly what trigger-based naming is for
- The event a `bus-` Lambda subscribes to belongs in its `schema.md` and README invocation section,
  where the full event pattern can be written out; the directory name carries the behaviour
- An **`s3-` Lambda's name after the prefix is terse, and says whatever makes it clearest among its
  siblings** — the lifecycle event alone (`s3-object-created`) when one Lambda handles one event on
  one bucket and nothing else could be meant, or a short summary of what it does (`s3-upload-scan`,
  `s3-thumbnail`) when the bucket, the prefix filter or a sibling Lambda would otherwise be
  ambiguous. Prefer the summary as soon as there is a second `s3-` Lambda in the service: two
  directories named for their events answer *which bucket?* for neither
- The bucket, the event pattern and any key prefix filter belong in the Lambda's `schema.md` and
  README invocation section, where they can be written out in full — the directory name carries the
  trigger kind and the behaviour, the same split as `bus-`
- The `ninja-` prefix exists so an operational/admin utility is identifiable at a glance and never
  mistaken for a user-facing endpoint
- **Corrected:** this rule used to read `sqs-handler-<sqs-queue-name>`. The `handler-` was
  superfluous — every Lambda in the table is a handler, so the word distinguished nothing and only
  pushed the part that *does* carry information, the queue name, further from the front of the
  directory listing. Existing `sqs-handler-` directories are not wrong, and renaming one is a
  separate decision with Terraform and log-prefix consequences; new ones take the short form

## Module & Package Layout

Each Lambda is **its own Go module**, with one `go.mod`/`go.sum` at the Lambda directory's root. The
only code it may import from outside its own directory is an explicitly registered shared library.

**The root `package main` holds only two source files — `main.go` and `handler.go` — plus their
co-located tests.** Everything else lives in a sub-package.

- **`main.go`** is wiring and nothing else: resolve environment variables, construct dependencies,
  instantiate the `Handler`, call `lambda.Start`. No business logic, no validation, no queries
- **`handler.go`** holds a `HandlerInterface` and the `Handler` that satisfies it. `handle`
  sequences sub-packages and maps their errors onto a response — **high-level control flow only**

Read **`reference/module-layout.md`** for the full tree, the `handler.go` contract, the sub-package
table and Go package-naming rules before creating a new Lambda or adding a package.

## Logging

**Log frequently** — at function entry, before and after significant operations (AWS calls, DB
queries, external service calls), and at decision points. Under-logging a Lambda is expensive
because a production trace is often all you get.

Every log line includes the **module**, **file**, **function** and a **unique step identifier**
within that function:

```go
log.Printf("[module:file:function:step] message key=value ...")
log.Printf("[admin-create-user:handler.go:Handle:cognito-create] creating user email=%s", maskedEmail)
log.Printf("[admin-create-user:main.go:main:secrets-retrieved] successfully retrieved DB credentials")
```

Include relevant variables for inspection — request IDs, masked email addresses, resource
identifiers, error messages.

**Never log secrets, passwords, tokens, or unmasked PII.**

## File Organisation

Within **every** package — the root `package main` and each sub-package alike:

- Plain structs with **no** methods group into **`models.go`**
- A struct **with** methods gets its own **`<name>.go`** (a `Study` struct with methods → `study.go`)
- Interfaces group into **`interfaces.go`**
- **Test files always sit beside the file they test** — `input/input_test.go` tests `input/input.go`

The root `package main` is the exception to the first three: it holds only `main.go` and
`handler.go`, so any struct, interface or helper it would otherwise need **belongs in a
sub-package.**

## Frameworks & Libraries

- [`github.com/aws/aws-lambda-go`](https://github.com/aws/aws-lambda-go) — event types, handler
  interface
- [`github.com/aws/aws-sdk-go-v2`](https://github.com/aws/aws-sdk-go-v2) — AWS SDK v2
- [`github.com/DATA-DOG/go-sqlmock`](https://github.com/DATA-DOG/go-sqlmock) — repository tests

## Required Documentation

Every Lambda directory needs **both**:

- **`schema.md`** — the input contract: summary, TypeScript-syntax schema, worked JSON examples. See
  `reference/schema-md.md` for the exact template
- **`README.md`** — the narrative overview, in exactly four sections (Invocation, Purpose,
  Interface, Implementation, the last with a rendered flow diagram). See the `documentation` skill's
  READMEs reference

## Commands

Run from inside a Lambda's own directory:

```bash
GOOS=linux GOARCH=amd64 go build -o build/bootstrap .   # build (deployment artifact)
go test ./...                                            # test
go test -run TestName ./...                              # single test
go test -cover ./...                                     # coverage
go fmt ./...
golangci-lint run
go mod tidy
```

All build output goes into a **`build/` directory** within the Lambda's directory; Terraform zips
`build/bootstrap` for deployment.

**A shared library is never built on its own** — it has no `main` and is compiled into each
consuming Lambda's binary. Only the test, vet, format and tidy commands apply to it.

## References

- **`reference/module-layout.md`** — the module tree, `main.go`/`handler.go` contracts, package
  naming, the sub-package table
- **`reference/shared-libraries.md`** — when shared source is allowed at all, the register, layout,
  naming, consuming one, and **the rebuild trap** (read this before editing any shared library)
- **`reference/testing.md`** — interface-based AWS mocking, `go-sqlmock`, testing `crypto/rand` and
  `log.Fatalf` paths, coverage expectations
- **`reference/schema-md.md`** — the `schema.md` template

## Related

- `lambdas-node` skill — the Node.js sibling, for a Lambda that cannot be Go
- `infrastructure` skill — packaging, timeouts, and the `hash_extra` requirement for shared libraries
- `documentation` skill — the Lambda `README.md` and shared-library `README.md` formats
- `mysql` skill — the schema the `models` package reads and writes
