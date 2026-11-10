# State and the Pipeline

## State in HCP Terraform

**Every root's state lives in HCP Terraform** (formerly Terraform Cloud), in **one HCP Terraform
workspace per root per environment** — `<service>-<environment>`, or
`<service>-<environment>-<deployment>` for a service deployed more than once in an environment
(see `variables-and-environments.md`). The workspaces for a repository sit in one HCP Terraform
project, named in the project's `conventions/terraform.md`.

**The workspaces run in Local execution mode** — set as that HCP Terraform project's default
execution mode, so a new workspace inherits it. HCP Terraform then stores the state, locks it while
a run holds it, and keeps every version; the plan and the apply themselves run in CI:

- **The plan that is applied is the plan that was shown** — a saved plan file, applied by the same
  job that produced it (see "The Pipeline")
- **CI's own AWS credentials are used**, through OIDC — no AWS credentials are stored in HCP
  Terraform
- **The committed `.tfvars` files are the only source of variables.** HCP Terraform does not
  evaluate workspace variables or variable sets in Local mode, so **never set a variable in the HCP
  Terraform UI** — it would be silently ignored
- HCP Terraform's remote runners make no promise about which tools they carry, so nothing that
  depends on a toolchain could run there anyway

```hcl
terraform {
  required_version = ">= 1.10"

  cloud {
    organization = "<organisation>"
    workspaces {
      project = "<HCP Terraform project>"
      tags    = { service = "<service>" }
    }
  }
}
```

- **`tags` is a map.** The list form (`tags = ["service:orders"]`) is the legacy one, for Terraform
  before 1.10
- The tags match every environment's workspace for this root, and **`TF_WORKSPACE` chooses one** —
  the wrapper script sets it from the environment argument. HCP Terraform **never creates a
  workspace from `TF_WORKSPACE`**: a typo fails rather than producing an empty state that plans to
  create everything
- **A new environment's workspace is created deliberately**, with `terraform workspace new
  <service>-<environment>` from the root, which tags it to match. Check its execution mode is Local
  before its first plan
- **State is sensitive.** It holds every attribute of every resource, which can include generated
  passwords and keys. Only CI's token writes it; read access is limited to the people who need it;
  anything that only needs outputs gets the workspace's "Read outputs only" permission

**Diverged from `prototype-conventions`:** there, state is a local file on whoever runs Terraform,
and a CLI workspace per deployment is seeded by copying files into `terraform.tfstate.d/`. Local
state has no lock, no history and no backup, and the only copy of production's state cannot live on
one person's laptop.

## The Pipeline

**On a pull request**, for every root:

1. `terraform fmt -check -recursive`
2. `terraform init -lockfile=readonly`, then `terraform validate`
3. **`tflint`**, with the AWS ruleset — invalid instance types, deprecated arguments, unused
   declarations
4. **A misconfiguration scanner** — Checkov or `trivy config`. A finding is fixed, or suppressed
   **inline, on the resource, with the reason** in the suppression comment; never suppressed
   wholesale in the scanner's configuration
5. **`terraform plan` for each environment**, with the read-only plan role, posted to the pull
   request for review

**On merge**, for each environment in the project's promotion order (`dev`, then `stg`, then
`prod`, say):

6. `terraform plan -out=tfplan`, then `terraform apply tfplan` — **the saved plan, never a fresh
   `apply`**, which would plan again and apply whatever it found
7. **A production apply waits for a manual approval that shows the saved plan** — the pull request's
   plan was a preview, made against state that may have moved since

- **Applies to one workspace never overlap.** HCP Terraform's lock stops a second apply touching the
  state, but CI should also queue the jobs (a concurrency group per workspace), so the second waits
  instead of failing on the lock
- **Terraform refuses a saved plan whose state has changed since it was made.** That is the
  protection working — plan again
- **Nobody applies outside the pipeline**, Claude included. An emergency change made by hand is
  recorded, and written into the configuration (or reverted by the next apply) the same day

## Credentials

| Job | AWS role | Can |
| --- | --- | --- |
| Pull request plan, drift check, a developer's local plan | **Plan role**, per environment | Read the account; change nothing |
| Apply on merge | **Apply role**, per environment | Change the environment's resources |

- **The apply role's trust policy names the repository and the protected branch** (or the CI
  environment) in its OIDC subject condition, so a pull request from a branch cannot assume it —
  however its workflow file has been edited
- **CI's HCP Terraform token** is a team token scoped to the project's workspaces, stored as a CI
  secret

## The Provider Lock File

**`.terraform.lock.hcl` is committed, with checksums for every platform that runs Terraform**:

```bash
terraform providers lock -platform=linux_amd64 -platform=darwin_arm64
```

A plain `terraform init` records checksums only for the platform it ran on, so a lock file made on
a Mac can fail verification on a Linux CI runner, or be silently extended by it. CI runs `init`
with `-lockfile=readonly`, so a missing or mismatched checksum fails the pull request instead of
being written. Update the lock file in the same change as a provider version bump.

## Drift

**A scheduled CI job plans every workspace** — daily, or as the project records — with the plan
role and `terraform plan -detailed-exitcode`. Exit code `2` means the real infrastructure no longer
matches the configuration, and it opens a ticket. Drift is someone's console change or a resource
changed by AWS, and the next apply would otherwise undo it with nobody expecting it.
