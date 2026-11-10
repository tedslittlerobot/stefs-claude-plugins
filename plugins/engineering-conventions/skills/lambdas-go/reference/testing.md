# Testing

- Use Go's built-in **`testing`** package. **No assertion library** — the standard
  `if got != want { t.Errorf(...) }` shape is used throughout
- **Every package carries its own tests**, in `*_test.go` files co-located with the source they
  cover: `input/input_test.go` tests `input/input.go`. A sub-package covered only through the
  handler's tests **reports 0% for itself** and leaves its own edge cases untested, so it does not
  count as covered
- **Table-driven tests wherever a rule has more than one case** — every rejected input, every mapped
  error type — so adding a case is one line

## Mocking AWS

**Mock AWS SDK calls using interfaces, never by hitting real AWS.**

Each Lambda **narrows the SDK client to the handful of calls it actually makes** — `cognito.Client`,
`queue.Client`, `notifications.Invoker` — and the real `*cognitoidentityprovider.Client` /
`*sqs.Client` / `*lambda.Client` satisfies it unchanged.

**Assert that in the package's test:**

```go
var _ Client = (*sqs.Client)(nil)
```

so an SDK signature change fails *there* rather than in `main.go`.

## Testing Repositories

**Test repositories with [`github.com/DATA-DOG/go-sqlmock`](https://github.com/DATA-DOG/go-sqlmock)**
rather than a live database.

Its `QueryMatcherOption` / `QueryMatcherFunc` captures the SQL a repository actually emits, which is
how a query is asserted **not** to select a column — the mechanism for pinning that a
credential-bearing column stays out of a `SELECT`. That is a test worth writing, because the failure
it prevents is a secret leaking into a response body.

## Reaching Awkward Branches

- **A `crypto/rand` failure branch is reachable.** `rand.Reader` is a package variable, so a test can
  swap in a failing reader and assert the error surfaces instead of a weak value being used
- **Exit paths** (a missing required environment variable, logged then `os.Exit(1)`) are tested by
  **re-running the test binary as a subprocess** and asserting a non-zero exit
- **Assert what is not logged.** Point `slog.SetDefault` at a JSON handler writing to a buffer, run
  the path that handles a credential or personal data, and assert it is absent from the output.
  The failure that prevents is a secret in CloudWatch, where it outlives any fix to the code

## Integration Tests

Unit tests prove the logic against fakes; they cannot prove the fakes are right. **sqlmock asserts
the SQL a repository sends, not that MySQL accepts it or that it returns the right rows**, and no
local test sees an IAM permission, an environment variable or the real shape of an event.

**Repository integration tests run against a real MySQL**, started by testcontainers-go's `mysql`
module:

- In `<thing>_repository_integration_test.go` beside the repository, behind a
  **`//go:build integration`** constraint, so `go test ./...` stays fast and Docker-free and
  `go test -tags integration ./...` runs them
- The container runs **the MySQL version production runs** — for Aurora, the MySQL version its
  engine version is compatible with — pinned to an exact image tag
- The schema comes from **the project's own migrations**, applied to the container, never a
  hand-written copy that can drift from them
- go-sqlmock stays, for what it is good at: driver-error branches, and pinning that a
  credential-bearing column is never selected

**Deployed-environment smoke tests** run after every deploy to a non-production environment. Each
Lambda is triggered with the examples in its `schema.md` — invoked directly when it is synchronous
or an `invoke-` Lambda, through its real source (a message on the queue, an object in the bucket)
otherwise — and the test asserts the outcome. That is what catches a missing permission or a
mistyped environment variable before production does. Where they live and how they run is a
project value, recorded in its conventions file.

**Diverged from `prototype-conventions`:** the prototype skill stops at unit tests — interface
fakes for AWS and sqlmock for the database, never a real service. That is the right trade for code
that may be thrown away; for code that will not, it leaves every query and permission first tested
in production.

## Coverage

`go test -cover ./...` reports per package.

- **Sub-packages should sit at or near 100%** — they take their dependencies as interfaces, so every
  branch is reachable from a test
- **The root `package main` sits lower by design.** `main()` itself is wiring that ends in
  `lambda.Start`; typically only a DSN builder and `handle` are meaningfully testable there
