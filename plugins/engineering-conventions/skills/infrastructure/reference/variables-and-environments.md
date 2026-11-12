# Variables, Environments & Outputs

## Per-Environment tfvars

Variable values are supplied per-environment via **named `.tfvars` files**, not a single untracked
override file. A wrapper script (`scripts/tf` or equivalent) implements this, and **CI and a
developer run the same script**, so a local plan sees exactly the variables CI's does:

- Every Terraform command takes a required **`<environment>`** argument (`dev`, `prod`, …) selecting
  which `.tfvars` files to merge in, checking **both** of these locations and including whichever
  exist:
  1. **Project root**: `tfvars/<environment>.tfvars` at the top level of the repository
  2. **Terraform directory**: `tfvars/<environment>.tfvars` inside the root being planned
- If both exist, pass **both** `-var-file` arguments. The Terraform-directory-level file takes
  precedence for overlapping variables (Terraform is last-wins on duplicate keys)
- **The script selects the environment's state** before every command — `TF_WORKSPACE` for HCP
  Terraform, the state's address or key at `init` for GitLab or S3; see `state-and-pipeline.md`
- **These files are committed**, and are the only source of variable values — never a variable set
  in the backend's own UI, which HCP Terraform, for one, ignores in Local execution mode. They are
  named, shared environment configuration — region, prefix, environment, and so on — not secrets. **Never put
  actual secrets in a `tfvars/*.tfvars` file**; use AWS Secrets Manager (see
  `stateful-resources.md`)
- **Never remove a `tfvars/` directory or any file inside one** when tidying up or cleaning after
  testing. These are committed environment configuration, not scratch output
  - **Exception**: a file named `*.local.tfvars` is understood to be throwaway, for testing or
    sample purposes. Those are gitignored, may be created freely, and may be deleted at will

## Environments and Accounts

**Several environments may share an AWS account.** Every resource name and every resource's tags
carry the environment (see "Resource Naming" and "Default Tags" in `SKILL.md`), which is what keeps
them apart. Which environments share which account is a project value, recorded in its
`conventions/terraform.md`.

Where they share one, the separation is only as good as the IAM policies: every statement scoped to
its own environment's name prefix (see `lambda-functions.md`), and plan and apply roles per
environment (see `state-and-pipeline.md`). A role that can touch `*` in a shared account can touch
production.

## Several Deployments in One Environment

A service can be deployed more than once into the *same* environment — three deployments in one
environment, say. Such a service names **one tfvars file per deployment** inside its own Terraform
root, `tfvars/<environment>-<deployment>.tfvars`, and the wrapper script then runs the Terraform
command **once per file, in alphabetical order**, instead of the single
`tfvars/<environment>.tfvars` run.

The `<environment>` argument still names the **environment**, never one deployment, and the
repository-root `tfvars/<environment>.tfvars` is merged underneath each deployment file as usual.
`*.local.tfvars` files are excluded from the fan-out, so a throwaway scratch file never joins an
`apply` that deploys everything.

Two things must be true of the per-deployment files:

- **Each sets its own `project_prefix`.** The deployments share a Terraform root and an environment,
  so they build resource names from the same expressions; without distinct prefixes they name the
  same S3 bucket, Web ACL and Origin Access Control. An S3 bucket name is globally unique across all
  of AWS, so this is an outright collision rather than a cosmetic clash
- **Each gets its own state**, `<service>-<environment>-<deployment>` (see `state-and-pipeline.md`).
  Deployments sharing a state would share one record of what exists — and a plan for one would
  propose **destroying whatever the other last created**

The script selects the state before **every** command, including `output` — the state is what
decides which deployment's outputs are read.

## Outputs, Fetched on Demand

**Outputs are read from state when they are needed, never recorded in the repository:**

```bash
terraform output -raw <name>
```

through the wrapper script, which selects the environment's state. A CI job that only needs an
output — the frontend deploy needs the bucket name and distribution ID — runs with the least access
to the state its backend offers, not write access to it (see "State Is Sensitive" in
`state-and-pipeline.md`).

- **Anything one service needs from another is passed in as a variable or read from SSM**, never
  read from another root's outputs at plan time — the roots are applied independently, in no fixed
  order
- **An output that must not be printed is declared `sensitive = true`**, so plan and apply logs in
  CI show `(sensitive value)` in its place. `terraform output -raw` still prints it, deliberately

**Diverged from `prototype-conventions`:** there, every `apply` writes each deployment's outputs to
a committed `.tfoutputs/<service>.yaml`, so the last-applied endpoints and IDs can be read in the
tree. Once CI applies, that file would have to be committed back to the repository by the pipeline,
on every apply, and could still be stale the moment anything else changed the state. Reading the
output on demand is never stale.
