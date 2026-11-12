# Deploying Lambda Code

## CI Owns the Code, Terraform Owns the Function

**Terraform creates every Lambda function and owns its configuration**: runtime, architecture,
memory, timeout, environment variables, role, logging, failure destinations, triggers and alarms.
**CI owns the code.** After the environment's apply, it puts the CI-built artifact into each
function, publishes a version, and moves the function's **`live` alias** to that version. **Every
trigger invokes the alias**, never the function itself.

- **A code-only change needs no apply.** Its plan is empty, so the release is the deploy step
  alone, and it takes seconds per function rather than a plan and an apply per environment
- **Rolling back is moving the alias back**, one call, with no revert, plan or apply in the way
- **A version is an immutable snapshot of the function's code and its configuration together**, so
  what the alias points at is exactly what was tested in the environment before it, settings
  included. A configuration change Terraform applies reaches traffic only when CI publishes the
  next version, which the pipeline does straight after the apply, so a change that needs new code
  and a new setting together (a new environment variable, say) still goes live as one version
- **Gradual rollout becomes possible** — see "Canaries" below

**Diverged from `prototype-conventions`:** there, `terraform-aws-modules/lambda/aws` builds the
code at plan time and `terraform apply` deploys it, so code and infrastructure are one release.
`engineering-conventions` moved the build into CI at 0.2.0 but kept Terraform deploying the code,
by pointing each function at the artifact's content-addressed S3 key. That made every code release a
full plan and apply in every environment, and a rollback a revert run through the same pipeline. It
changed at 0.6.0 to this split.

## The Terraform Side

The function is created from a **placeholder package** and Terraform is told not to track its code.
The alias is created once and then left to CI:

```hcl
module "sqs_orders_created" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.13.0"

  function_name = "${var.project_prefix}-${var.environment}-sqs-orders-created"
  # … runtime, architectures, timeout, logging and the rest — see lambda-functions.md

  create_package          = false
  local_existing_package  = "${path.module}/lambda-placeholder.zip"
  ignore_source_code_hash = true # CI deploys the code; Terraform never touches it after creation
  publish                 = false
}

module "sqs_orders_created_live" {
  source  = "terraform-aws-modules/lambda/aws//modules/alias"
  version = "8.13.0"

  name             = "live"
  function_name    = module.sqs_orders_created.lambda_function_name
  function_version = "$LATEST" # only until CI's first deploy publishes version 1
  refresh_alias    = false     # CI moves the alias; Terraform only creates it

  create_version_allowed_triggers   = false
  create_version_async_event_config = false

  event_source_mapping = { … } # triggers belong here, on the alias
  allowed_triggers     = { … }
}
```

**Why Terraform leaves CI's code alone:** the AWS provider never reads a function's `filename`,
`s3_key` or `s3_object_version` back from AWS, and `ignore_source_code_hash = true` gives it no hash
to compare. So Terraform sees no difference however many times CI changes the code. This is the
module's documented route for "infrastructure and code deployments [managed] separately". Its README
also suggests forking the module to add `ignore_changes` for `s3_key`; that is needed only when the
configured key changes, and here it never does.

- **The placeholder's path never changes, and is relative** — `${path.module}/…`, never
  `abspath()`. A changed `filename` is a code change to the provider, and an absolute path differs
  between CI and a laptop. Either one makes the next apply upload the placeholder over the
  deployed code. The alias still points at a published version, so traffic is unaffected and the
  next deploy step puts the code back. It is still a surprise worth not having
- **One placeholder zip, committed beside the Terraform, serves every function.** It holds no
  working handler, so any invocation before the first deploy fails loudly rather than doing
  something
- **`publish = false`.** Only CI publishes versions, so every version is a release
- **`refresh_alias = false`** makes the alias module ignore `function_version` after creation. It
  still manages the alias's other settings
- **The `create_version_*` switches are off** because the alias starts at `$LATEST`. The module
  would otherwise grant the trigger permissions and async configuration to the unqualified function
  as well as the alias

### Triggers target the alias

A trigger that names the function rather than the alias invokes `$LATEST`. That is the code CI
last uploaded, with whatever configuration Terraform last applied, neither of them published, and
it can't be rolled back by the alias. So:

- **Event source mappings, `allowed_triggers` and async configuration** (destinations, retries)
  are declared on the alias module, not the function module
- **API Gateway integrations** use the alias's `lambda_alias_invoke_arn`
- **SNS subscriptions, EventBridge targets, Cognito triggers, S3 notifications** use the alias's
  `lambda_alias_arn`
- **Provisioned concurrency**, where a function has it, is set on the alias

### A new function

The alias starts at `$LATEST`, so for the minutes between a new function's apply and its first
deploy step, the alias serves the placeholder. That window is in the same pipeline run and usually
harmless. A new function whose trigger already has traffic waiting, such as a new consumer on an
existing queue, is created in one change and given its trigger in the next, once it has code.

## The Deploy Step

**In each environment's job, straight after the apply**, and on every merge whether or not the
apply had anything to do. For each function:

```bash
fn="${PROJECT_PREFIX}-${ENVIRONMENT}-${lambda}"   # key and sha come from CI's build manifest

if [ "$(aws lambda get-function-configuration --function-name "$fn" \
          --query CodeSha256 --output text)" != "$sha" ]; then
  aws lambda update-function-code --function-name "$fn" \
    --s3-bucket "$ARTIFACT_BUCKET" --s3-key "$key"
fi
aws lambda wait function-updated-v2 --function-name "$fn"

version="$(aws lambda publish-version --function-name "$fn" --code-sha256 "$sha" \
            --query Version --output text)"
aws lambda update-alias --function-name "$fn" --name live --function-version "$version"
```

- **The comparison is on content**, the zip's SHA-256 against the function's `CodeSha256`. Lambda
  reports that hash in base64, not the hex used in the S3 key, so the build manifest records both
  (see the `lambdas-go` skill's `build-and-deploy.md`). An unchanged Lambda uploads nothing, which
  keeps "rebuild everything, deploy what changed" free of any change detection to get wrong
- **It publishes even when the code did not change**, because the apply may have changed the
  configuration, and only a published version carries it to the alias. Lambda publishes nothing
  when neither code nor configuration has changed since the last version
- **`--code-sha256`** makes the publish fail if anything else changed the code since this job
  uploaded it
- **The wait matters.** Lambda refuses a publish while the function's last update is still in
  progress, and both the apply and `update-function-code` leave one in progress
- **CI records the version it moved the alias to** in the deploy's manifest, beside the key and the
  commit. That record is what a rollback reads
- **It runs inside the state's concurrency group** (see `state-and-pipeline.md`), so an apply
  and a deploy to the same environment never overlap

The step needs, on `function:${var.project_prefix}-${var.environment}-*`:
`lambda:GetFunctionConfiguration`, `lambda:GetFunction`, `lambda:UpdateFunctionCode`,
`lambda:PublishVersion` and `lambda:UpdateAlias`, plus `s3:GetObject` on the artifact bucket. The
apply role has these already. A pipeline that deploys code in a job of its own gives that job a
role with these and nothing more.

### Old versions

Published versions accumulate, and their code counts against the region's Lambda storage quota. The
deploy step deletes a function's versions beyond the last ten, never one an alias points to. Ten is
a project value.

## Rolling Back

```bash
aws lambda update-alias --function-name "$fn" --name live --function-version <previous version>
```

The previous version comes from the deploy manifest. It restores that version's **code and
configuration** together. It does **not** restore anything outside the version: the role's
policies, triggers and their permissions, alias settings, reserved concurrency, or the data a newer
version wrote. A rollback across a change to any of those is a forward fix instead.

**A rollback is a stopgap, not a release.** The next merge's deploy step publishes `$LATEST` and
moves the alias forward again. So the rollback is followed the same day by a revert or a fix through
the pipeline.

## Canaries

**Gradual rollout is CodeDeploy's job**, through the module's `modules/deploy` submodule, which
shifts the alias's traffic in steps and rolls back when an alarm fires. It is not done with
hand-set alias weights, because Terraform still manages the alias's `routing_config` and would
remove them at the next apply. Whether a function gets canaries is a project decision. It earns its
keep on a function with enough traffic for an alarm to tell a bad release from a quiet minute.
