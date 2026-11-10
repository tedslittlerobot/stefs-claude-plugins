# Shared Libraries

**The default is that a Lambda's code lives inside that Lambda.** A helper is copied rather than
shared, because every Lambda is independently deployable and a shared dependency is a way for one
deployment to break another. **That default is not negotiable for incidental code** — two Lambdas
having similar helpers is not a reason to extract one.

What *is* allowed is a small number of **explicitly registered** shared libraries, each in
`lib/go/<library-name>/` at the repository root.

## The Register

**"Explicitly registered" is the entire mechanism**: a library exists because it is listed in the
project's own conventions file, not because someone spotted duplication. **Nothing may import from
`lib/go/` unless it appears in that register.**

The register is a table in `conventions/golang.md` (or the project's equivalent) with one row per
library: its path, its purpose, and its status. Adding a library means adding the row in the same
change.

## This Is Not a Hole in "No Shared Code Between Services"

The part of that rule which matters survives intact: **the services share no runtime resources, and
neither reaches into the other's code or data at runtime.**

A shared library is **source**, compiled separately into each Lambda's own `bootstrap` binary. After
`go build` there is no shared artefact, no shared version in production, and nothing one service can
do to another's deployed code — **a Lambda that is never rebuilt goes on running exactly the bytes
it was deployed with.**

What a shared library must therefore **never** hold:

- **Anything service-specific.** If it names a table, a queue, an endpoint, a pool or a bucket
  belonging to one service, it belongs in that service
- **Anything creating a runtime dependency between services** — a client to a shared resource, or
  code assuming both services are deployed at the same version
- **Business logic.** A library is *mechanism*; the rules that use it stay in the Lambda that owns
  them

A well-shaped library is constructed with the caller's vocabulary passed *in* (a namespace, bare
type names) so it carries none of its own.

## Layout

```
lib/go/<library-name>/
  go.mod                  # module <library-name> — the bare directory name, as Lambdas do
  README.md               # required — see the `documentation` skill
  <name>.go               # a struct with methods gets its own file
  models.go               # plain structs with no methods
  interfaces.go           # interfaces grouped together
  <name>_test.go          # tests beside the file they test
```

The file-organisation rules are exactly the Lambda ones, and so is the module path: `module bouncer`,
imported as `bouncer`, mirroring how a Lambda declares `module api-get-users`. **There is no version
tag and no module proxy** — the path is not resolvable and is not meant to be.

## Naming

A single lowercase word, and — the part that is easy to get wrong — it **must not collide with a
well-known public Go package**, even one the repository will never use.

A worked example, which the snippets below also use: a library wrapping an authorisation-decision
service was named `bouncer` precisely for this reason. The obvious name, `authz`, is already a
published Go library for Google Cloud authorization, and a reader meeting `import "authz"` would
have to work out which of the two they were looking at. **Check the name against the public
ecosystem before committing to it.**

## Consuming One

Each consuming Lambda adds a `require` and a `replace` to its own `go.mod`:

```
require bouncer v0.0.0

replace bouncer => ../../../../lib/go/bouncer
```

The number of `..` segments is however many levels the Lambda directory sits below the repository
root. `v0.0.0` is a placeholder that is never resolved, because `replace` short-circuits it.

The repository's `go.work` (see `build-and-deploy.md`) also `use`s the library, which is what the
editor and the repository-wide sweeps go by. The `replace` stays regardless: it is what lets the
Lambda build on its own with `GOWORK=off`, which is how CI builds every artifact.

## Keeping Consumers Rebuilt

**A change to a shared library is a change to every Lambda that imports it**, and each of those
must be rebuilt and redeployed. If anything decides which Lambdas to rebuild by looking at which
directories changed, the library's consumers are exactly the ones it misses: the deployed
`bootstrap` keeps running the old library while the source says otherwise, and nothing reports it.

The CI build closes this by not deciding at all. **It rebuilds every Lambda on every change**, and
because the build is reproducible an unchanged Lambda produces the same artifact and is not updated
— see `build-and-deploy.md`. A pipeline that does build selectively must treat any change under
`lib/go/<library-name>/` as a change to every module whose `go.mod` requires it.

**Diverged from `prototype-conventions`:** there, `terraform-aws-modules/lambda/aws` builds each
Lambda at plan time and decides whether to rebuild by hashing files matched relative to the Lambda's
own directory — which a library outside it never matches. The prototype skill closes that with a
`hash_extra` digest of the library's files on every consuming Lambda's module, an entry whose
absence fails silently. With the build moved to CI there is no plan-time hash to feed, and no entry
to forget.

## Testing

A library owns its own tests, run from its own directory (`go test ./...` in
`lib/go/<library-name>/`).

**Any repository-wide test, coverage, lint or `govulncheck` sweep must include `lib/go/*`**
alongside the `lambdas/` trees: a library no Lambda exercises yet is still code that has to compile
and pass. Looping over the modules `go.work` lists covers both.
