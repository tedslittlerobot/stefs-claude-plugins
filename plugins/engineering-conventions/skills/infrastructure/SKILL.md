---
name: infrastructure
description: Terraform and AWS conventions for production — never running apply (CI applies a reviewed plan), HCP Terraform (Terraform Cloud) state in local execution mode, per-environment tfvars and workspaces, outputs fetched on demand, CI checks (fmt, validate, tflint, Checkov/Trivy, provider lock file, drift), OIDC credentials, file organisation, default_tags (Project, Environment, Owner, Repository), project_prefix and environment resource naming, terraform-aws-modules preferences, Lambda timeouts (estimate plus buffer, 30-second floor), Lambda code deployed by CI (update-function-code, publish-version, a live alias, rollback, CodeDeploy canaries), Lambda configuration, failure destinations, IAM and alarms, prevent_destroy and deletion protection, Aurora with Secrets Manager, KMS rotation, AWS Backup, and references for S3/CloudFront frontend hosting deployed by CI, the /api route prefix, Route 53/SES (DKIM, DMARC, bounces), Cognito and WAF. Use when writing or editing .tf files, running terraform plan or validate, setting up a Terraform CI pipeline or HCP Terraform workspace, naming or tagging AWS resources, adding infrastructure for a new feature, choosing a Lambda timeout, deploying or rolling back Lambda code, protecting a database or user pool, or debugging an apply-time AWS error.
---

# Terraform & AWS Conventions

> **Engineering conventions, for projects built to run in production.** This skill is part of the
> `engineering-conventions` plugin. A prototype or proof of concept that also has the
> `prototype-conventions` plugin installed follows that plugin's `infrastructure` skill instead —
> its rules are chosen for speed of building, and it says so.

Applies to every Terraform root in the repository. Each service has its own `terraform/` directory
and is **applied independently** — there are no shared runtime resources between services, and
anything one service needs from another is passed in as a variable or read from SSM, never
hardcoded.

## Ground Rules

- **Tool**: [Terraform](https://www.terraform.io/); **Provider**: AWS; **State**: HCP Terraform
  (formerly Terraform Cloud) — see `reference/state-and-pipeline.md`
- **NEVER run `terraform apply`.** Applies happen only in CI, from a plan that was reviewed —
  see `reference/state-and-pipeline.md`. `terraform init`, `validate`, `fmt` and `plan` are safe,
  and `plan` runs locally with read-only credentials
- **Never deploy or roll back Lambda code by hand either** — no `update-function-code`,
  `publish-version` or `update-alias`. CI deploys code after the apply (see
  `reference/lambda-deployment.md`), and a rollback is a person's decision
- Use [terraform-aws-modules](https://registry.terraform.io/namespaces/terraform-aws-modules)
  wherever possible instead of hand-rolled `resource` blocks
- **Pin every module version explicitly** (`version = "5.1.0"`) — reproducible plans matter more
  than automatic upgrades. **Pin Terraform and the providers too**: a `required_version` and a
  `required_providers` version constraint in every root, and a committed `.terraform.lock.hcl`

**Diverged from `prototype-conventions`:** there, `apply` is a manual command a person runs from
their own machine, against state on that machine. In production that means nothing records which
plan was applied, two people can apply at once, and the deployed state depends on whose laptop it
was. The rule that Claude never applies is unchanged — now nobody applies outside CI.

## AWS Credentials

- **CI authenticates to AWS through OIDC federation** — the CI provider's identity token, exchanged
  for a role per environment. **No long-lived access keys exist** for Terraform to use
- **Locally, credentials are read-only.** A developer, and Claude, plan with a role that can read
  the account and the state but change nothing
- **How a person gets local credentials is a project value**, recorded in its
  `conventions/terraform.md` — a credentials file a SAML tool writes, an IAM Identity Center
  profile, or similar. Follow it before running any Terraform command, and never commit a file it
  produces
- Credentials expire after a few hours. **If a Terraform command fails with an auth error, ask the
  user to log in again** rather than trying to work around it

**Diverged from `prototype-conventions`:** there, this section names a specific tool and file
(`saml2aws`, `.aws-credentials.bash`). How an organisation signs people in to AWS is its own
choice, not a portable rule, so it moved to the project's conventions file.

## Module Preferences

| Resource | Use |
| --- | --- |
| Lambda + its IAM | [`terraform-aws-modules/lambda/aws`](https://registry.terraform.io/modules/terraform-aws-modules/lambda/aws) — configured per `reference/lambda-functions.md` |
| HTTP/WebSocket API Gateway | [`terraform-aws-modules/apigateway-v2/aws`](https://registry.terraform.io/modules/terraform-aws-modules/apigateway-v2/aws) |
| S3 bucket | [`terraform-aws-modules/s3-bucket/aws`](https://registry.terraform.io/modules/terraform-aws-modules/s3-bucket/aws) |
| CloudFront | [`terraform-aws-modules/cloudfront/aws`](https://registry.terraform.io/modules/terraform-aws-modules/cloudfront/aws) |
| ACM certificate | [`terraform-aws-modules/acm/aws`](https://registry.terraform.io/modules/terraform-aws-modules/acm/aws) |
| Cognito User Pool | `lgallard/cognito-user-pool/aws` — see `reference/cognito.md` |
| **SES** | the AWS provider directly (`aws_ses_domain_identity`, `aws_sesv2_configuration_set`, …) — no community module needed |
| **Aurora** | [`terraform-aws-modules/rds-aurora/aws`](https://registry.terraform.io/modules/terraform-aws-modules/rds-aurora/aws), with its default `manage_master_user_password = true` — see `reference/stateful-resources.md` |

**Diverged from `prototype-conventions`:** there, Aurora uses the provider directly, because the
module's current major version (v10) dropped its plain-string `master_password` input for a
write-only one, and the prototype wanted a fixed, non-secret password. Production wants the password
managed by RDS in Secrets Manager — which is the module's default — so the reason to avoid it is
gone.

## File Organisation

- **`main.tf` contains only** the `terraform` block, `provider` blocks, and truly global data sources
  (`data "aws_caller_identity" "current"`, `data "aws_region" "current"`)
- **All spec-driven infrastructure goes in a `.tf` file named after the spec** — resources for a
  `study-registration` spec belong in `study-registration.tf`. This is what makes infrastructure
  traceable back to the spec that introduced it, and it keeps `main.tf` readable
- `variables.tf` and `outputs.tf` remain shared files for the root
- Note that Terraform accepts an `output` block in **any** file in the root, so an output may
  legitimately live in a spec-named file rather than `outputs.tf`

## Default Tags

Every AWS provider block has a `default_tags` block carrying these four tags, so every resource gets
them without a per-resource entry; a resource's own `tags` block is **additive** and merges with
them:

| Tag | Value |
| --- | --- |
| `Project` | The project's name — a project value, in its `conventions/terraform.md` |
| `Environment` | `var.environment` |
| `Owner` | The team that answers for it — a project value |
| `Repository` | The repository's URL — where the configuration that made the resource lives |

- **The same four keys, spelled the same way, in every root** — a tag is only useful to billing,
  IAM conditions and the console if every resource uses the same key for the same thing
- **Activate them as cost-allocation tags** in the account that pays the bill, or Cost Explorer
  cannot group by them
- A tag key or value is never a secret, and never personal data — tags are visible to anyone who can
  list the resource

**Diverged from `prototype-conventions`:** there, `default_tags` sets only the project tag. With
several environments able to share an account, a resource that does not say which environment it
belongs to, who owns it and where it is defined cannot be safely changed, costed or cleaned up.

**`default_tags` has no per-resource opt-out.** It applies to every taggable resource under a given
provider configuration, with no way to exclude one `resource` block (confirmed against the AWS
provider's own resource-tagging documentation). For the small number of resources that **adopt**
pre-existing, account-wide shared infrastructure rather than creating something the service owns —
`aws_default_vpc` / `aws_default_subnet`, say — stamping project tags on them would be misleading.
Declare a second, aliased `provider "aws" { alias = "shared" }` with **no** `default_tags` block
(same region, otherwise identical) and set `provider = aws.shared` on those specific resources. A
resource's own `tags` argument still applies normally on the aliased provider; only the
provider-level defaults are skipped.

## Resource Naming

**Every named resource the service creates is named
`${var.project_prefix}-${var.environment}-<resource name>`** — S3 buckets, Lambda function names,
queues, Cognito User Pool names, log groups, anything with a name or identifier that must be unique
or human-readable. This applies to future resources, not just existing ones.

- Every Terraform root declares **`project_prefix`** and **`environment`** variables in
  `variables.tf`. `project_prefix` has a default and is overridden per environment in `.tfvars`
- **Some AWS names are globally unique across all of AWS** — S3 buckets in particular — so a plain
  service name collides easily; the prefix is what prevents it
- **The environment is in every name because environments may share an account.** Without it, two
  environments in one account collide outright on any name that must be unique, and are
  indistinguishable in the console on every other
- **It is also what IAM policies scope by.** Every policy statement names its resources by
  `${var.project_prefix}-${var.environment}-*` (see `reference/lambda-functions.md`). Where
  environments share an account, that prefix is the boundary between staging code and production
  data — so a resource named without it is outside the boundary

**Cap `var.environment` at four characters**, and enforce it in the variable:

```hcl
variable "environment" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9]{1,4}$", var.environment))
    error_message = "environment must be 1-4 lowercase letters or digits (prod, stg, dev)."
  }
}
```

It is prepended to names with hard limits — 63 for an S3 bucket and a Cognito Hosted UI domain
prefix, 64 for a Lambda function name and the IAM role derived from it — and the longest generated
name in the root has to stay inside them **with room left for the Lambda module's own
`-logs`/`-vpc` policy suffixes.**

**Diverged from `prototype-conventions`:** there, a resource carries the environment only when a
service is deployed more than once in one account, and is otherwise `${var.project_prefix}-<name>`.
That makes adding a second environment to an account a rename of every resource — a replacement,
for anything stateful.

### Variables a root does not use

**A Terraform root that declares no resources needing a variable the shared root-level tfvars file
sets must still declare that variable, with a `null` default**, or the file is rejected — the
wrapper script passes the root-level file to every service.

## Lambda Functions

**Every Lambda's timeout is an estimate of its work plus a buffer, and never less than 30
seconds.**

1. **Estimate the slowest realistic invocation**, not the typical one: a cold start (runtime init,
   configuration, SDK clients, a database connection), plus each call to another service at its
   slow-day latency, times the number of calls, plus the work itself — per record times batch size
   for a batch
2. **Add at least half again** on top of the estimate, and round up
3. **Take 30 seconds if the result is smaller**
4. **Write the estimate in a comment directly above the `timeout`**, so the number can be checked
   and revisited rather than guessed at again:

   ```hcl
   # ~6s: cold start 3s, two Cognito calls and an SES send at 1s each. x1.5 = 9s; 30s floor.
   timeout = 30
   ```

**Thirty seconds is the floor because a timeout that is too tight fails work that was going to
succeed.** A cold start on a custom runtime plus a fresh MySQL connection can take several seconds
before any real work starts, and a hung AWS call burns the whole budget whatever it is. Cutting a
slow success short is worse than letting it finish: a synchronous caller gets a 5xx for work that
may have happened, and an asynchronous source retries it — a duplicate. Guard runaway work in the
function's own logic, not by starving it of wall-clock.

- **The buffer is not padding to remove later.** Durations grow with data, and a tight timeout is
  found by an outage. Revisit the estimate against the function's real `Duration` — its alarm
  (`reference/lambda-functions.md`) fires as it approaches the timeout
- **An API-backed Lambda cannot usefully exceed 30 seconds** — API Gateway HTTP APIs give up at
  30 regardless. One whose estimate and buffer come to more is the wrong design: it accepts the
  request, hands the work to a queue, and returns `202`
- **A caller that gives up sooner** — Cognito waits five seconds for a trigger — is respected by the
  code bounding its own work, not by a shorter timeout; see the `lambdas-go` skill's
  `failure-handling.md`
- **An SQS source queue's visibility timeout is derived from the timeout** — see
  `reference/lambda-functions.md`

**Diverged from `prototype-conventions`:** there, every Lambda gets exactly 30 seconds, and exceeds
it only with a comment naming why. The floor is kept; the flat value is not. A production timeout is
also the bound on a hung dependency and on what it costs, and on the visibility timeout of every
queue in front of the function, so it has to say something about the work.

**CI owns a Lambda's code, and Terraform owns everything else about it.** Terraform creates the
function from a placeholder package, ignores its code from then on, and creates a `live` alias that
every trigger invokes. After each environment's apply, CI uploads the CI-built artifact, publishes a
version and moves the alias to it, so a code-only change ships without an apply and a rollback is
one alias move. The module settings, the deploy step, rollbacks and canaries are in
`reference/lambda-deployment.md`. How the artifact is built is in the `lambdas-go` skill's
`build-and-deploy.md`. Everything else about a function's configuration (logging, tracing, failure
destinations, permissions and alarms) is in `reference/lambda-functions.md`.

## References

- **`reference/state-and-pipeline.md`** — HCP Terraform workspaces in local execution mode, the CI
  pipeline (checks, plan on the pull request, apply on merge), OIDC roles, the provider lock file,
  drift detection
- **`reference/variables-and-environments.md`** — per-environment `.tfvars`, several deployments in
  one environment, and reading outputs on demand
- **`reference/lambda-deployment.md`** — CI deploying Lambda code: the placeholder package,
  `ignore_source_code_hash`, the `live` alias and triggers on it, the deploy step
  (`update-function-code`, `publish-version`, `update-alias`), rollbacks and CodeDeploy canaries
- **`reference/lambda-functions.md`** — the Terraform side of a Lambda: configuration, failure
  destinations, permissions, `invoke-` auditing and alarms
- **`reference/stateful-resources.md`** — `prevent_destroy` and deletion protection, Aurora with
  Secrets Manager in private subnets, secrets, KMS rotation, AWS Backup
- **`reference/frontend-hosting.md`** — S3 + OAC + CloudFront + ACM, content deployed by CI,
  security headers and logging, the SPA fallback rewrite (and the `custom_error_response` trap),
  and the `/api` route prefix
- **`reference/dns-and-ses.md`** — delegated hosted zones, SES domain verification, DKIM, custom
  MAIL FROM, DMARC, bounces and complaints, the SES sandbox
- **`reference/cognito.md`** — the User Pool module, production settings, Custom Email Sender
  triggers, and the several apply-time-only validation traps
- **`reference/waf.md`** — Web ACL scope and placement, managed rules in counting mode first,
  rate-based rules, and logging

## Related

- `lambdas-go` / `lambdas-node` skills — what the Lambdas being deployed look like, how their
  artifacts are built, and which alarms each needs
- `conventions` skill, in `documentation-and-planning` where installed — where this project's chosen
  values (tag values, prefix defaults, credentials, retention periods) live
- `api-design` skill, in `utils` where installed — the routes that sit under the `/api` prefix
