# State and the Pipeline

## Shared State

**Every root's state lives in a shared remote backend**, never on the machine that ran Terraform.
There is **one state per root per environment**, named `<service>-<environment>`, or
`<service>-<environment>-<deployment>` for a service deployed more than once in an environment (see
`variables-and-environments.md`). Which backend is a project value, recorded in its
`conventions/terraform.md`. Whichever it is, it must:

- **Lock the state** while a run holds it, so two runs cannot write it at once
- **Keep every version**, so a state damaged by a bad apply or a botched `state mv` can be restored
- **Be encrypted at rest and access-controlled** — see "State is sensitive" below
- **Be reachable from CI with CI's own credentials**, never a person's token

**Plans and applies run in CI whichever backend stores the state** — see "The Pipeline". The
backend only stores and locks the state.

**Corrected at 0.7.0.** This section used to name HCP Terraform as the only place state could live.
It is one option among several, and on a repository hosted on GitLab it is usually not the best: it
adds a second service with its own accounts, tokens and permissions to keep in step with the
repository's, when GitLab already stores state with the same locking and history.

### Choosing a Backend

| Repository on | Recommended | Why |
| --- | --- | --- |
| GitLab | **GitLab-managed Terraform state** (Terraform state administration) | Nothing else to sign up for; access follows project membership, and CI authenticates with the job token it already has |
| GitHub or elsewhere | **HCP Terraform** (formerly Terraform Cloud), or **an S3 backend** in the project's AWS account | HCP Terraform adds a UI, run history and per-workspace permissions; S3 keeps everything in AWS under the same IAM as the rest |

Other backends that meet the requirements above are fine too — Azure Blob Storage or Google Cloud
Storage for an organisation already there, or a platform such as Spacelift, env0 or Scalr. The
rules in this file are written for the three above; for another, record in the project's
`conventions/terraform.md` how it selects a state, locks it, and grants outputs-only access.

### GitLab-Managed State

The root declares an empty `http` backend, and the wrapper script supplies the state's address at
`init`:

```hcl
terraform {
  required_version = ">= 1.10"

  backend "http" {}
}
```

```bash
# set by the wrapper script, per root and environment; shown with CI's variables
STATE_URL="${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/<service>-<environment>"
export TF_HTTP_ADDRESS="$STATE_URL"
export TF_HTTP_LOCK_ADDRESS="$STATE_URL/lock"
export TF_HTTP_UNLOCK_ADDRESS="$STATE_URL/lock"
export TF_HTTP_LOCK_METHOD=POST
export TF_HTTP_UNLOCK_METHOD=DELETE
export TF_HTTP_USERNAME=gitlab-ci-token
export TF_HTTP_PASSWORD="$CI_JOB_TOKEN"
terraform init -reconfigure -lockfile=readonly
```

- **The state name in the URL selects the state.** The script derives it from the environment
  argument, and runs `init -reconfigure` whenever the environment changes, because the address is
  fixed at `init`
- **GitLab creates a state on its first write**, so a typo in the name produces an empty state that
  plans to create everything. The script builds the name only from the environment argument and
  the root, never from free text, and **a plan for an existing environment that proposes creating
  everything is stopped, not applied**
- **In CI, `CI_JOB_TOKEN` authenticates**, with the permissions of the user who triggered the
  pipeline — nothing is stored. Locally, the script reads the GitLab URL and project ID from the
  project's conventions, and the person's own personal access token (`api` scope) from their
  environment — never from a file in the repository
- **Writing and locking the state needs the Maintainer role; reading it needs Developer.** A plan
  run as a Developer — locally, or on a merge request a Developer opened — passes `-lock=false`
- The states are listed, locked, unlocked and removed under the project's **Operate > Terraform
  states**. Removing a state there is as final as deleting the resources' record — it is never
  done to tidy up

### HCP Terraform

**One HCP Terraform workspace per state**, named as above. The workspaces for a repository sit in
one HCP Terraform project, named in the project's `conventions/terraform.md`.

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
- **CI's HCP Terraform token** is a team token scoped to the project's workspaces, stored as a CI
  secret

### S3

```hcl
terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "<state bucket>"
    region       = "<region>"
    encrypt      = true
    use_lockfile = true
  }
}
```

- **The wrapper script passes `-backend-config="key=<service>/<environment>.tfstate"` at `init`**,
  with `-reconfigure` whenever the environment changes. The key selects the state
- **`use_lockfile = true` locks with a `.tflock` object beside the state.** It needs Terraform
  1.10 or later; the DynamoDB lock table it replaces is deprecated, and a new backend does not use
  one
- **The bucket has versioning on, public access blocked, encryption, and `prevent_destroy`**, and
  is created by a small bootstrap root of its own — a root cannot create the bucket its own state
  lives in. Once the bucket exists, the bootstrap root's state is moved into it with
  `terraform init -migrate-state`
- **Locking writes an object**, so a role that plans with the lock taken needs
  `s3:PutObject` and `s3:DeleteObject` on `<key>.tflock` — and only that — as well as
  `s3:GetObject` on the state. CI's plan and apply roles are its credentials; nothing else is stored

### State Is Sensitive

**State holds every attribute of every resource**, which can include generated passwords and keys.
Only CI's apply credentials write it; read access is limited to the people who need it; anything
that only needs outputs gets the least the backend offers — HCP Terraform's **"Read outputs only"**
workspace permission, `s3:GetObject` on the one state's key, or on GitLab the Developer role.

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

6. `terraform plan -out=tfplan -detailed-exitcode`
7. **Production waits here for a manual approval** showing the saved plan and the Lambdas whose
   code will change. The pull request's plan was a preview, made against state that may have moved
   since
8. `terraform apply tfplan` — **the saved plan, never a fresh `apply`**, which would plan again and
   apply whatever it found. An empty plan (exit code `0`) skips the apply
9. **Deploy the Lambda code** — every merge, whether or not there was an apply: upload each changed
   artifact, publish a version, move the `live` alias. See `lambda-deployment.md`

- **Applies and deploys to one state never overlap.** The backend's lock stops a second apply
  touching the state, but CI should also queue the jobs (a concurrency group per state — a
  `resource_group` on GitLab, a `concurrency` group on GitHub Actions), so the second waits instead
  of failing on the lock
- **Terraform refuses a saved plan whose state has changed since it was made.** That is the
  protection working — plan again
- **Nobody applies or deploys code outside the pipeline**, Claude included. An emergency change
  made by hand is recorded, and written into the configuration (or reverted by the next apply) the
  same day. The one routine exception is a person rolling a Lambda's alias back — see
  `lambda-deployment.md`

## Credentials

| Job | AWS role | Can |
| --- | --- | --- |
| Pull request plan, drift check, a developer's local plan | **Plan role**, per environment | Read the account; change nothing |
| Apply and Lambda code deploy on merge | **Apply role**, per environment | Change the environment's resources |

- **The apply role's trust policy names the repository and the protected branch** (or the CI
  environment) in its OIDC subject condition, so a pull request from a branch cannot assume it —
  however its workflow file has been edited
- **CI's access to the state** depends on the backend — see "Shared State"

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

**A scheduled CI job plans every state** — daily, or as the project records — with the plan
role and `terraform plan -detailed-exitcode`. Exit code `2` means the real infrastructure no longer
matches the configuration, and it opens a ticket. Drift is someone's console change or a resource
changed by AWS, and the next apply would otherwise undo it with nobody expecting it.
