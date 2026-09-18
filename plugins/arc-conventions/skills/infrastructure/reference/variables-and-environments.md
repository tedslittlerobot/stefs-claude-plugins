# Variables, Environments & Recorded Outputs

## Per-Environment tfvars

Variable values are supplied per-environment via **named `.tfvars` files**, not a single untracked
override file. A wrapper script (`scripts/tf.zsh` or equivalent) implements this:

- Every Terraform command takes a required **`<environment>`** argument (`dev`, `prod`, …) selecting
  which `.tfvars` files to merge in, checking **both** of these locations and including whichever
  exist:
  1. **Project root**: `tfvars/<environment>.tfvars` at the top level of the repository
  2. **Terraform directory**: `tfvars/<environment>.tfvars` inside the root being planned
- If both exist, pass **both** `-var-file` arguments. The Terraform-directory-level file takes
  precedence for overlapping variables (Terraform is last-wins on duplicate keys)
- **These files are committed.** They are named, shared environment configuration — region, prefix,
  and so on — not secrets. **Never put actual secrets in a `tfvars/*.tfvars` file**; use AWS Secrets
  Manager or SSM Parameter Store
- **Never remove a `tfvars/` directory or any file inside one** when tidying up or cleaning after
  testing. These are committed environment configuration, not scratch output
  - **Exception**: a file named `*.local.tfvars` is understood to be throwaway, for testing or
    sample purposes. Those are gitignored, may be created freely, and may be deleted at will

## Several Deployments in One Environment

A service can be deployed more than once into the *same* environment — three deployments in one
account, say. Such a service names **one tfvars file per deployment** inside its own Terraform root,
`tfvars/<environment>-<deployment>.tfvars`, and the wrapper script then runs the Terraform command
**once per file, in alphabetical order**, instead of the single `tfvars/<environment>.tfvars` run.

The `<environment>` argument still names the **account**, never one deployment, and the
repository-root `tfvars/<environment>.tfvars` is merged underneath each deployment file as usual.
`*.local.tfvars` files are excluded from the fan-out, so a throwaway scratch file never joins an
`apply` that deploys everything.

Two things must be true of the per-deployment files:

- **Each sets its own `project_prefix`.** The deployments share a Terraform root, so they build
  resource names from the same expressions; without distinct prefixes they name the same S3 bucket,
  Web ACL and Origin Access Control. An S3 bucket name is globally unique across all of AWS, so
  this is an outright collision rather than a cosmetic clash
- **Each gets its own Terraform workspace**, named after the deployment. One root has one state file
  per workspace, so deployments sharing the `default` workspace would share one state — and a plan
  for one would propose **destroying whatever the other last created**

The script selects the workspace (`terraform workspace select -or-create <deployment>`) before
**every** command, including `output` — the workspace is what decides which deployment's state is
read. A service deployed once per environment stays in `default`, which the script also selects
explicitly so a run can never inherit whichever workspace the directory was left in.

**Adopting workspaces for a root whose resources are already deployed in `default`** means seeding
the new workspace from the existing state, or the first apply fails on resources that exist but are
absent from the (empty) workspace state. With a local backend that is a file copy into
`terraform.tfstate.d/<deployment>/terraform.tfstate`.

## Recorded Outputs (`.tfoutputs/`)

`apply` records each deployment's `terraform output` values as a YAML file in `.tfoutputs/` at the
repository root — `.tfoutputs/<service>.yaml` for a service deployed once per environment,
`.tfoutputs/<service>-<deployment>.yaml` for one deployed several times into the same environment.

Unlike state, **these files are committed**: having the last-applied endpoints, bucket names and
pool IDs readable in the tree beats re-running `terraform output` in three directories. **Nothing
reads them** — no script and no Terraform root. They are a record, not an input, and never a
substitute for state.

- **Only `apply` writes them.** `plan`, `destroy` and `output` leave the directory alone
- **The directory is cleared at the start of every apply** (its `*.yaml` files, keeping any
  `README.md`), and a file is written only once that deployment's apply has succeeded. So the
  directory always describes exactly one run, and **a missing file is meaningful**: that deployment
  failed, or was not part of the invocation
- **Capture happens immediately after each apply, inside the fan-out loop**, because
  `terraform output` reads whichever workspace is currently selected — it cannot be deferred to the
  end of a run that moves between workspaces
- **Outputs declared `sensitive = true` are recorded as `null` with a `# sensitive` marker, never
  their value.** These files are committed and such outputs are live credentials. Read one from
  state with `terraform output -raw <name>` instead, selecting the deployment's workspace first if
  the root has more than one
- **An output that must not appear in a committed file has to be declared `sensitive`** — that
  declaration is the only thing redaction keys off. Redaction reads the `sensitive` flag out of
  `terraform output -json` rather than parsing HCL, so it finds them wherever they are declared,
  including in a spec-named `.tf` file
- A deployment whose apply succeeded but whose outputs could not be read is reported as
  `ok, no outputs` and makes the run **exit non-zero**, so the gap is not discovered later by
  finding a file absent
