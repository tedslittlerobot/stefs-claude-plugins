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
- **`log.Fatalf` paths** (a missing required environment variable) are tested by **re-running the
  test binary as a subprocess** and asserting a non-zero exit

## Coverage

`go test -cover ./...` reports per package.

- **Sub-packages should sit at or near 100%** — they take their dependencies as interfaces, so every
  branch is reachable from a test
- **The root `package main` sits lower by design.** `main()` itself is wiring that ends in
  `lambda.Start`; typically only a DSN builder and `handle` are meaningfully testable there
