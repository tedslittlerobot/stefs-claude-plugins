# Module & Package Layout

## The Tree

```
lambdas/<function-name>/
  go.mod                      # one module per Lambda; sub-packages import off its module path
  go.sum
  main.go                     # entry point — wiring only
  main_test.go                # only if main.go has anything worth testing
  handler.go                  # top-level control flow
  handler_test.go
  input/                      # request/event structs + validation
    input.go
    input_test.go
  models/                     # database layer: row structs, repositories, their interfaces
    models.go
    interfaces.go
    <thing>_repository.go
    <thing>_repository_test.go
  helpers/                    # small, generic helper functions
    <topic>.go
    <topic>_test.go
  <thing>/                    # a larger collection of helpers focused on one subject
  <feature>/                  # the actual business logic, one package per piece of functionality
```

**"Sub-package" means a sub-package of the Lambda's single Go module, not a nested `go.mod`.** A
nested module would need `replace` directives and its own dependency graph for no benefit. (That
reasoning is about modules *inside* a Lambda — a shared library *outside* one is the case where a
`replace` directive does earn its keep; see `reference/shared-libraries.md`.)

Because sub-packages import off the module path, a Lambda whose `go.mod` declares
`module api-get-profile` imports its own packages as `api-get-profile/input`,
`api-get-profile/models`, and so on.

## `main.go`

Deliberately thin — **wiring, and nothing else.** Its whole job is to:

- resolve the environment variables the Lambda needs
- construct dependencies (MySQL clients, AWS SDK clients, SQS senders, …)
- instantiate the `Handler` with them
- call `lambda.Start` (or the equivalent for the event source) with the handler's `handle` method

**No business logic, no validation, no queries.**

## `handler.go`

Holds a `HandlerInterface` and the `Handler` that satisfies it:

- **`HandlerInterface`** declares, at minimum, a `handle` method whose signature takes the Lambda's
  event type (`events.APIGatewayV2HTTPRequest`, `events.SQSEvent`, …), plus any other handler helper
  methods. **Assert the implementation** with `var _ HandlerInterface = (*Handler)(nil)`
- **`Handler`** is a struct holding the dependencies `main.go` created — repositories, SDK clients —
  **each typed as an interface** so tests can substitute a fake. This is the single decision that
  makes the whole Lambda testable
- **`handle`** controls the Lambda's logic **at a high level only**: parse the event via `input`,
  call into the business-logic packages, and map their results and errors onto a response. Any real
  work is delegated to a sub-package

`handle` and the interface method are **unexported** — nothing outside `package main` ever calls
them, and the Lambda's own tests live in the same package.

## Sub-packages

| Package | Holds |
| --- | --- |
| `input` | Every struct the Lambda's event is parsed into, and all input validation. **No I/O** — parsing and validation only |
| `models` | All database logic: the structs mirroring table rows, the repository types that read and write them, and the repository interfaces the handler depends on |
| `helpers` | Small, self-contained helper functions too generic to belong to any one piece of logic (env lookups, JSON response wrapping, …) |
| `<thing>` | A larger collection of helpers all focused on one subject, **named for that subject alone** — `cognito`, `anchor`, `password`, `names`, `queue`. Never a `_helpers` suffix |
| `<feature>` | The business logic itself — one sensibly named package per piece of functionality, which is where all real work happens |

The **same file-organisation rules apply within every sub-package**: plain structs with no methods
group into `models.go`, a struct with methods gets its own `<name>.go`, interfaces group into
`interfaces.go`. Test files are always co-located with the file they test — never a single
root-level `main_test.go` covering the whole Lambda.

## Package Naming

Package names follow **Go's own conventions**, not the repository's directory-naming habits — a
package name is part of every call site that uses it, so it is chosen for how `pkg.Identifier`
reads:

- **A single lowercase word.** No underscores, no camelCase, no plural unless the package really is
  a collection (`names` is a pool of names; `models` is the project convention). `cognito`, not
  `cognito_helpers`
- **No `_helpers` (or `_utils`, `_lib`) suffix.** A package focused on one subject is named for that
  subject: *holding helpers is what every package does*, so the suffix adds nothing. `helpers`
  itself is the one deliberate exception — the agreed home for small generic functions belonging to
  no subject
- **Don't stutter.** The package name already qualifies the identifier: `cognito.Client`, not
  `cognito.CognitoClient`; `anchor.Components`, not `anchor.AnchorComponents`; `anchor.MaxLength`,
  not `anchor.MaxAnchorLength`
- **Don't collide with a dependency.** A Lambda importing the AWS SDK's own `sqs` package must name
  its own SQS wrapper something else — `queue` — since naming it `sqs` would force an alias at every
  import site
- **Watch for shadowing.** A parameter or variable sharing a package's name hides that package for
  the rest of the function body. Write `func Update(ctx context.Context, client cognito.Client, …)`
  rather than `cognito cognito.Client` — the latter compiles until the body needs the package, then
  fails confusingly

`golangci-lint run` with revive's `var-naming` rule enforces most of this.

## Deployment

Nothing about this layout changes deployment: `go build -o build/bootstrap .` at the Lambda root
compiles the whole tree, and the `patterns` regexes in each Lambda's Terraform `source_path` block
(`".*\\.go"`) match nested paths — so sub-package files are still hashed for rebuild detection and
still packaged.

**Those patterns are relative to the Lambda's own directory**, which is exactly what makes a
*shared* library a different problem. See `reference/shared-libraries.md`.
