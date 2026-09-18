---
name: infrastructure
description: Terraform and AWS conventions — never running apply, per-environment tfvars and workspaces, recorded outputs, file organisation, default_tags, project_prefix resource naming, terraform-aws-modules preferences, Lambda timeouts, and references for S3/CloudFront frontend hosting, Route 53/SES, Cognito and WAF. Use when writing or editing .tf files, running terraform plan or validate, naming AWS resources, adding infrastructure for a new feature, or debugging an apply-time AWS error.
---

# Terraform & AWS Conventions

Applies to every Terraform root in the repository. Each service has its own `terraform/` directory
and is **applied independently** — there are no shared runtime resources between services, and
anything one service needs from another is passed in as a variable or read from SSM, never
hardcoded.

## Ground Rules

- **Tool**: [Terraform](https://www.terraform.io/); **Provider**: AWS
- **NEVER run `terraform apply`.** That is a manual command for the user to run. `terraform plan`,
  `terraform validate` and `terraform init` are safe
- Use [terraform-aws-modules](https://registry.terraform.io/namespaces/terraform-aws-modules)
  wherever possible instead of hand-rolled `resource` blocks
- **Pin every module version explicitly** (`version = "5.1.0"`) — reproducible plans matter more
  than automatic upgrades

## AWS Credentials

- Before running any Terraform command, check for a `.aws-credentials.bash` file in the project root
- If it exists, `source` it first to load credentials into the shell environment
- The file is populated by `saml2aws` and exports short-lived credentials
  (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`)
- Credentials expire after a few hours. **If a Terraform command fails with an auth error, ask the
  user to re-run `saml2aws login`** rather than trying to work around it
- The file is gitignored and must never be committed

## Module Preferences

| Resource | Use |
| --- | --- |
| Lambda + its IAM | [`terraform-aws-modules/lambda/aws`](https://registry.terraform.io/modules/terraform-aws-modules/lambda/aws) |
| HTTP/WebSocket API Gateway | [`terraform-aws-modules/apigateway-v2/aws`](https://registry.terraform.io/modules/terraform-aws-modules/apigateway-v2/aws) |
| S3 bucket | [`terraform-aws-modules/s3-bucket/aws`](https://registry.terraform.io/modules/terraform-aws-modules/s3-bucket/aws) |
| CloudFront | [`terraform-aws-modules/cloudfront/aws`](https://registry.terraform.io/modules/terraform-aws-modules/cloudfront/aws) |
| ACM certificate | [`terraform-aws-modules/acm/aws`](https://registry.terraform.io/modules/terraform-aws-modules/acm/aws) |
| Cognito User Pool | `lgallard/cognito-user-pool/aws` — see `reference/cognito.md` |
| **SES** | the AWS provider directly (`aws_ses_domain_identity`, `aws_ses_email_template`, …) — no community module needed |
| **Aurora** | the AWS provider directly (`aws_rds_cluster`, `aws_rds_cluster_instance`). `terraform-aws-modules/rds-aurora/aws`'s current major version dropped its plain-string `master_password` input in favour of a write-only argument, which adds ephemeral-variable wiring not worth it for a fixed, non-secret master password |

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

- Every AWS provider block must include a `default_tags` block setting the project tag — the value
  is recorded in the project's `conventions/terraform.md`
- This tags every resource automatically without per-resource entries; individual resource `tags`
  blocks are **additive** and merge with the defaults

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

- Every Terraform root declares a **`project_prefix`** variable in `variables.tf`
- **Every named resource the service creates** — S3 buckets, Lambda function names, Cognito User
  Pool names, or anything else with a name or identifier that must be unique or human-readable —
  **is prefixed with `${var.project_prefix}-`.** This applies to future resources, not just
  existing ones
- The reason is that some AWS resource names (S3 buckets in particular) must be **globally unique
  across all of AWS**, not merely within the account — a plain service name collides easily
- `project_prefix` has a default but is expected to be overridden per-environment via `.tfvars`

### Carrying the environment in the prefix

A service that may be stood up **more than once in a single AWS account** (a `prod` pool alongside
an `int` one) needs `${var.project_prefix}-${var.environment}-<resource name>`, because
`project_prefix` alone leaves no way to tell two such deployments apart in the console.

Where a service does that, **cap `var.environment` at four characters.** It is prepended to names
with hard limits — 63 for an S3 bucket and a Cognito Hosted UI domain prefix, 64 for a Lambda
function name and the IAM role derived from it — and the longest generated name in the root has to
stay inside them **with room left for the Lambda module's own `-logs`/`-vpc` policy suffixes.**

A service deployed once per account keeps the plain `${var.project_prefix}-` form.

### Variables a root does not use

**A Terraform root that declares no resources needing a variable the shared root-level tfvars file
sets must still declare that variable, with a `null` default**, or the file is rejected — the
wrapper script passes the root-level file to every service.

## Lambda Functions

- **Every Lambda gets `timeout = 30` by default.** Thirty seconds is the platform floor, not a
  per-function judgement call: these Lambdas talk to Aurora over its public endpoint, to Cognito, to
  SES and to SQS — sometimes several in one invocation — and a cold start on a custom runtime plus a
  fresh MySQL connection can eat several seconds before any real work starts. A tighter timeout buys
  nothing (a hung AWS call still burns the whole budget) and turns a slow-but-successful request
  into a 502 for the caller
- **A Lambda may only exceed 30s when something about its work explicitly calls for it** — a batch
  or migration job, a fan-out that must finish in one invocation, an intentional long poll. When it
  does, **say so in a comment directly above the `timeout` line**, naming what needs the extra time,
  so the deviation is reviewable rather than accidental
- **Never go below 30s.** A shorter timeout is not a safety feature; guard runaway work in the
  function's own logic, not by starving it of wall-clock
- API Gateway HTTP APIs cap integration responses at 29–30s regardless, so for API-backed Lambdas
  the 30s timeout simply matches the ceiling the caller already sees

**Packaging a Lambda that consumes a shared library needs `hash_extra`, not a second `source_path`
entry** — and getting this wrong fails silently. See the `lambdas-go` skill's shared-libraries
reference for the mechanism and the verification.

## References

- **`reference/variables-and-environments.md`** — per-environment `.tfvars`, several deployments in
  one environment (workspaces), and the recorded `.tfoutputs/` convention
- **`reference/frontend-hosting.md`** — S3 + OAC + CloudFront + ACM, cache behaviours, the SPA
  fallback rewrite (and the `custom_error_response` trap), and the API origin
- **`reference/dns-and-ses.md`** — delegated hosted zones, SES domain verification, DKIM, custom
  MAIL FROM
- **`reference/cognito.md`** — the User Pool module, Custom Email Sender triggers, and the several
  apply-time-only validation traps
- **`reference/waf.md`** — Web ACL scope and placement, rate-based rules, and logging

## Related

- `lambdas-go` / `lambdas-node` skills — what the Lambdas being deployed look like
- `frontend` skill — what is being uploaded to the S3 origin
- `conventions` skill — where this project's chosen values (tag, prefix defaults, aliases) live
