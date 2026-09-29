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

## The Rebuild Trap

**A shared library sits outside the Lambda's `source_path`, so editing it will not trigger a
rebuild.** This is the most important consequence of allowing shared code at all, and **it fails
silently**: the deployed `bootstrap` keeps running the old library while the source says otherwise,
and nothing in a `terraform plan` says so.

The cause: `terraform-aws-modules/lambda/aws` hashes the files matched by `patterns` at **plan**
time — before `commands` runs `go build` — and those patterns resolve **relative to the Lambda's own
directory.** Files under `lib/go/` match nothing.

So every Lambda consuming a library must bring that library's files into its rebuild hash. **The way
to do that is `hash_extra`, not a second `source_path` entry.**

### Why not a second `source_path` entry

The second-entry approach is the obvious one, and was what this convention originally prescribed. It
does close the hash gap — but **it is not hash-only.** For a `source_path` entry with a `path` and
no `commands`, the module does both `step("zip", …)` and `hash(…)`, so the matched files are
**packaged as well as hashed**: every consuming Lambda's zip ends up carrying the library's sources
**and its `_test.go` files** alongside the binary.

`hash_extra` feeds the same content hash and **packages nothing**, so it is the mechanism that
actually does what is wanted.

### The mechanism

Compute the library's digest once in a `locals` block and hand it to each consumer:

```hcl
locals {
  bouncer_source_dir = "${path.module}/../../../lib/go/bouncer"

  # filesha256 per file rather than a hash of concatenated contents, so a change
  # that moved bytes between two files still moves the digest; sorted, so the
  # digest is stable across plans.
  bouncer_source_hash = sha256(join("", [
    for file in sort(tolist(fileset(local.bouncer_source_dir, "**/*.{go,mod,sum}"))) :
    filesha256("${local.bouncer_source_dir}/${file}")
  ]))
}
```

```hcl
module "api_get_users_lambda" {
  # ...
  source_path = [
    {
      path     = "${path.module}/../lambdas/api-get-users"
      commands = ["GOOS=linux GOARCH=amd64 go build -o build/bootstrap .", ":zip build/bootstrap"]
      patterns = ["!.*", ".*\\.go", "go\\.(mod|sum)"]
    }
  ]

  # Brings the library's sources into the rebuild hash. NOT optional, and its
  # absence fails silently.
  hash_extra = local.bouncer_source_hash
}
```

### Verified, not assumed

Confirmed on the first library actually built, by driving the module's own `package.py` directly:

| Check | Result |
| --- | --- |
| Editing the library with `hash_extra` set | Artifact hash **moves** ✓ |
| Editing the library with neither mechanism | Artifact hash **does not move** — the trap is real ✓ |
| Zip contents with `hash_extra` | `bootstrap` only ✓ |
| Zip contents with a second `source_path` entry | `bootstrap` **plus ten library files**, `_test.go` included ✗ |

**Every consuming Lambda must have the `hash_extra` entry**, or editing the library silently fails
to redeploy that Lambda. This is worth checking explicitly whenever a Lambda gains its first import
of a library.

## Testing

A library owns its own tests, run from its own directory (`go test ./...` in
`lib/go/<library-name>/`).

**Any repository-wide test, coverage or lint sweep must include `lib/go/*`** alongside the
`lambdas/` trees: a library no Lambda exercises yet is still code that has to compile and pass.
