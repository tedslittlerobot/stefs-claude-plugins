# Build and Deploy

## One Artifact, Built Once, by CI

**CI builds every Lambda's artifact, and CI deploys it.** Nothing is compiled or installed on the
machine running `terraform apply`, and Terraform does not deploy code at all. It creates the
function, and CI puts the code in it — see the `infrastructure` skill's `lambda-deployment.md`.

**Diverged from `prototype-conventions`:** there, `terraform-aws-modules/lambda/aws` runs
`go build` (or `npm install`) at plan time on whoever's machine runs Terraform. For one developer on
a prototype that is the least machinery possible. In production it means the deployed bytes depend
on that machine's Go or npm version and on the module proxy or registry being reachable at deploy
time, and nothing records which bytes went out. It is also why a shared library's consumers can
go unrebuilt — see `shared-libraries.md`.

## The Build

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
  go build -trimpath -buildvcs=false -ldflags="-s -w" -tags lambda.norpc -o build/bootstrap .
```

| Part | Why |
| --- | --- |
| `CGO_ENABLED=0` | A static binary, with no dependency on the C library in the runtime image |
| `GOARCH=arm64` | Graviton: about 20% less per GB-second than `x86_64`. The function's `architectures` must say `arm64` to match |
| `-trimpath` | Removes the build machine's paths, so the same source gives the same bytes anywhere |
| `-buildvcs=false` | Leaves the commit out of the binary. With it in, every commit changes every binary, and an unchanged Lambda could never produce an unchanged artifact. Provenance comes from the build manifest instead |
| `-ldflags="-s -w"` | Strips the symbol table and DWARF debug data — a smaller artifact, a faster cold start. Panic stack traces keep their function names |
| `-tags lambda.norpc` | Leaves out `aws-lambda-go`'s RPC mode, which only the retired `go1.x` runtime used |

Build each Lambda with **`GOWORK=off`**, so it compiles against exactly the versions in its own
`go.mod` — see "The Workspace" below for why that matters.

## The Artifact

- **Zip deterministically**, so identical binaries give an identical zip. Zip stores each file's
  modification time, so fix it first:

  ```bash
  TZ=UTC touch -t 198001010000 build/bootstrap
  (cd build && TZ=UTC zip -X -q bootstrap.zip bootstrap)
  ```

- **Upload it content-addressed**: `s3://<artifact bucket>/<lambda-name>/<sha256 of the zip>.zip`
- **CI records a manifest**, as its provenance record for each build: Lambda, key, commit, and the
  zip's SHA-256 in **base64**, the form Lambda reports as a function's `CodeSha256`. The deploy step
  compares that hash with the function's to decide whether to upload, and records the version it
  published

Together these make **rebuilding every Lambda on every change free at deploy time**: an unchanged
Lambda produces the same bytes, the same hash and no upload. That matters because it means there is
no change detection to get wrong. Working out which Lambdas a change affects is exactly how a shared
library's consumers used to go undeployed.

> **Corrected at 0.6.0.** This said to have Terraform point the function at the content-addressed
> key (`create_package = false`, `s3_existing_package`), so that a new key made the next apply
> update the code. That made every code release a plan and an apply in every environment, and a
> rollback a revert run through the same pipeline. CI now deploys the code itself, behind an alias
> that a rollback moves back.

## The Workspace

The repository root holds a committed **`go.work`** that `use`s every Lambda module and every
shared library:

```bash
go work init
go work use -r .        # every directory under the root that holds a go.mod
```

It is for three things:

- **The editor.** `gopls` understands a multi-module repository through the workspace, and without
  one treats each Lambda as an island
- **The list of modules.** `go list -m -f '{{.Dir}}'` in workspace mode prints every module, which
  is what CI loops over to build, test, vet and scan each one — so a new Lambda cannot be missed by
  a sweep
- **Keeping shared dependencies aligned.** `go work sync` writes the workspace's chosen version of
  each dependency back into every module's `go.mod`, so a security bump to the AWS SDK lands in
  every Lambda in one change instead of one at a time

It is **not** what CI builds with. In workspace mode Go picks one version of each dependency for the
whole workspace, which can be newer than a given Lambda's own `go.mod` says. Building with
`GOWORK=off` makes the artifact match the `go.mod` committed beside it. After a `go work sync` the
two agree anyway; `GOWORK=off` is what guarantees it.

Each consuming Lambda keeps its `replace` directive for a shared library (see
`shared-libraries.md`), which is what lets it build on its own with the workspace off.

## Dependency Hygiene

- **`govulncheck ./...` runs in CI for every module** and fails the build on a finding. It reports
  only vulnerabilities in code the module actually calls, so its findings are worth acting on
- **Dependency updates are automated** — Renovate or Dependabot, configured to cover every module
  and, as far as the tool allows, to **group** an update to one dependency across all of them into
  a single change (Renovate does this natively), followed by `go work sync`
- **A fix to a copied helper is a fix to every copy.** The default is to copy rather than share (see
  `shared-libraries.md`), so a bug or security fix found in one Lambda's helper is searched for
  across every Lambda and fixed everywhere in the same change. A helper that keeps needing that
  treatment is the signal to register it as a shared library
