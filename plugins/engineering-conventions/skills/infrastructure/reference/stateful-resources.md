# Stateful Resources

A **stateful resource** holds something that cannot be rebuilt from the repository: a database, a
table, a bucket of user uploads, a Cognito user pool, a KMS key, a hosted zone, a secret. A bucket
of built frontend files, a Lambda or a queue's configuration is not — CI or Terraform recreates
those exactly.

**Diverged from `prototype-conventions`:** there, nothing is protected from `terraform destroy`, and
a clean teardown is treated as a feature. A prototype's data is disposable; production's is the
product.

## Nothing Stateful Is Destroyed by a Plan

- **Every stateful `resource` block carries `lifecycle { prevent_destroy = true }`.** A plan that
  would destroy or replace it then fails instead of proposing it — including the replacement a
  renamed argument quietly triggers
- **`prevent_destroy` cannot be set on a resource inside a module** — `lifecycle` belongs to the
  `resource` block, and a module's blocks are not ours to edit. For a stateful resource created by a
  module, **turn on the service's own deletion protection**, which AWS enforces whoever asks:

  | Resource | Setting |
  | --- | --- |
  | Aurora cluster | `deletion_protection = true` |
  | DynamoDB table | `deletion_protection_enabled = true` |
  | Cognito user pool | `deletion_protection = "ACTIVE"` |
  | S3 bucket | `force_destroy = false` (the default) — a bucket with objects in it cannot be deleted |
  | KMS key | `deletion_window_in_days = 30` — a deleted key can be recovered within the window |

  Set both where both are possible. They fail at different times — `prevent_destroy` at plan,
  deletion protection at apply — and only the second also stops the console and the CLI
- **A `-/+` (replace) on a stateful resource in a plan stops the review.** It is a delete. Find the
  argument that forces it and change the configuration instead

**A Cognito user pool is the sharpest case.** Deleting one deletes every user in it, and Cognito
cannot export password hashes, so a restored pool means every user resetting their password. There
is no backup to restore from.

## Aurora

**Diverged from `prototype-conventions`:** there, the master password is fixed and non-secret, the
cluster has a public endpoint, and the Lambdas reach it over the internet. Each of those is a
prototype shortcut.

- **The master password is managed by RDS in Secrets Manager** — `manage_master_user_password =
  true`, encrypted with the project's KMS key (`master_user_secret_kms_key_id`). It is never in
  Terraform variables, `.tfvars`, state, or an environment variable, and RDS rotates it
- **A Lambda reads its database credentials from Secrets Manager at init**, from the secret ARN in
  an environment variable, and **reads them again when a connection fails authentication** — a
  rotation changes the password under a warm execution environment
- **Private subnets only**, no public endpoint (`publicly_accessible = false` on every instance),
  with a security group admitting only the Lambdas' security group on the database port
- **A Lambda attached to a VPC loses the internet.** Every AWS API it calls — Secrets Manager, SQS,
  SES, Cognito, and the CloudWatch metrics endpoint — then needs a **VPC interface endpoint** or a
  NAT gateway. List the endpoints with the Lambda's dependencies; a missing one shows up as a
  timeout, not an error
- **Encrypted at rest** with a customer-managed KMS key — `storage_encrypted = true`, `kms_key_id`
- **At least two instances, in different Availability Zones**, so a failover promotes a replica
  instead of waiting for a new instance
- **`backup_retention_period`** set explicitly (a project value, at least 7 days),
  **`skip_final_snapshot = false`** with a `final_snapshot_identifier`, and `deletion_protection`
- **Consider RDS Proxy** where Lambda concurrency can exceed the database's connection limit. Every
  execution environment holds its own connection, and a burst of scale-out is a burst of connections

## Secrets

- **Every secret lives in Secrets Manager** — never in `.tfvars`, a Terraform variable default, an
  output that is not `sensitive`, or a Lambda environment variable
- Terraform creates the secret's container (`aws_secretsmanager_secret`); a value Terraform does not
  generate is put there by a person or a rotation function, not written in configuration, so it
  never reaches state

## KMS Keys

- **`enable_key_rotation = true`** on every customer-managed key. Rotation keeps old key material
  for decryption, so it breaks nothing
- A key's policy names the principals that use it — the service principal (see `cognito.md` for
  Cognito's) and the roles — rather than relying on the account-root statement alone

## Backups

**Every stateful resource that AWS Backup supports is in a backup plan** — an `aws_backup_plan` and
an `aws_backup_selection` that chooses resources **by tag** (`Backup = "<plan name>"`), so a new
table or bucket is covered by tagging it rather than by remembering to edit the plan.

- Retention is a project value, recorded in its conventions file
- Whether backups are also copied to another account or region is a project decision, recorded with
  its reason. A copy in the same account does not survive the account's credentials being misused
- **A backup that has never been restored is a hope.** Restore one into a non-production
  environment on a schedule the project records
