# Lambda Functions — the Terraform Side

The `lambdas-go` and `lambdas-node` skills say what a Lambda's code does about logging, failures,
metrics and alarms. Most of those rules only hold if the function is configured to match, and that
configuration is here. The timeout rule is in `SKILL.md`.

## The Function

Every function, through `terraform-aws-modules/lambda/aws` (the module's input names in the first
column):

| Input | Value | Why |
| --- | --- | --- |
| `function_name` | `${var.project_prefix}-${var.environment}-<directory name>` | The directory name is the Lambda's identity in logs and metrics; the prefix and environment make it unique — see "Resource Naming" in `SKILL.md` |
| `create_package`, `local_existing_package`, `ignore_source_code_hash`, `publish` | `false`, the committed placeholder zip, `true`, `false` | CI deploys the code, and Terraform never touches it after creation — see `lambda-deployment.md` |
| `architectures` | `["arm64"]` | The artifact is built for it, and a mismatch fails at the first invocation, not at deploy |
| `logging_log_format`, `logging_application_log_level`, `logging_system_log_level` | `"JSON"`, `"INFO"`, `"WARN"` — the module's default format is `"Text"` | The code logs JSON with levels; Lambda then filters by level itself and sets `AWS_LAMBDA_LOG_LEVEL` for the code to read |
| `cloudwatch_logs_retention_in_days` | Set, always — a project value | The module's default is unset, and a log group with no retention keeps everything forever, billed monthly |
| `tracing_mode` | `"Active"` | What the OpenTelemetry instrumentation joins its spans to |
| `environment_variables` | Configuration only — names, ARNs, the environment, `NODE_OPTIONS` | **Never a secret.** Environment variables are readable by anyone who can read the function's configuration. A secret's ARN goes in an environment variable; the secret goes in Secrets Manager and is read at init |

**Prefer an on-failure destination to `dead_letter_config`** for an asynchronous Lambda. The
`lambdas-go` skill allows either, but a destination's record carries the error and the invocation's
details alongside the original event, where a dead-letter queue carries only the event.

## Failure Configuration

The `lambdas-go` skill's `failure-handling.md` says what the code does when it fails. The
configuration that makes that behaviour reach somewhere:

| Invoked by | Configure |
| --- | --- |
| An asynchronous source (SNS, EventBridge, S3, `aws lambda invoke --invocation-type Event`) On the `live` alias (the alias module's `create_async_event_config = true`): a `destination_on_failure` (usually an SQS queue), and `maximum_retry_attempts` and `maximum_event_age_in_seconds` set explicitly |
| SQS | The **source queue's** `redrive_policy` to a dead-letter queue, with a `maxReceiveCount`; `function_response_types = ["ReportBatchItemFailures"]` on the event source mapping |
| A stream (DynamoDB, Kinesis, Kafka, DocumentDB) | On the event source mapping: `function_response_types = ["ReportBatchItemFailures"]`, `bisect_batch_on_function_error = true`, `maximum_retry_attempts` and `maximum_record_age_in_seconds` set, and a `destination_config.on_failure` |

- **Event source mappings and async configuration belong to the `live` alias**, not the function,
  because the alias is what every trigger invokes — see `lambda-deployment.md`
- **An SQS source queue's `visibility_timeout_seconds` is derived from the function's timeout**, not
  typed in: `visibility_timeout_seconds = 6 * local.<lambda>_timeout`. AWS recommends at least six
  times, and two numbers maintained separately drift apart
- **Every failure queue and dead-letter queue has an alarm** (below) and a retention period long
  enough to investigate — the maximum, 14 days, unless the project records otherwise

## Permissions

- **One role per function**, from the module, with only the actions and resources that function
  uses — the module's `attach_policy_statements` with resource ARNs, never `*` on a data store
- **Scope every statement to this environment's resources by name**, which the naming rule makes
  possible: `arn:aws:sqs:<region>:<account>:${var.project_prefix}-${var.environment}-*`. Where
  environments share an account, this is the only thing stopping staging code from writing to a
  production queue
- **A function that exports metrics gets `cloudwatch:PutMetricData`** — that is the permission the
  OTLP metrics endpoint checks (see the `lambdas-go` skill's `metrics.md`)

### `invoke-` Lambdas

A manually invoked Lambda is an administrative action, and the `lambdas-go` skill requires that only
an operations role may invoke one and that every invocation is auditable:

- Grant `lambda:InvokeFunction` on `...:function:${var.project_prefix}-${var.environment}-invoke-*`
  to the operations role, and to nothing else. The operator invokes the alias,
  `<function name>:live`, which the trailing `*` covers
- **Record the invocations with CloudTrail data events.** Lambda invocations are data events, which
  a trail does not record by default. An `advanced_event_selector` on the trail selecting
  `eventCategory = Data`, `resources.type = AWS::Lambda::Function`, and `resources.ARN` starting
  with that same `invoke-` prefix records exactly these, and not every invocation in the account —
  which would be billed per event

## Alarms

**A Lambda is not deployed without its alarms.** The `lambdas-go` skill's `observability.md` lists
which ones each kind of Lambda needs. They are `aws_cloudwatch_metric_alarm` resources in the same
spec-named `.tf` file as the function, so a function and its alarms are reviewed, deployed and
deleted together.

- **Every alarm action goes to an SNS topic that reaches a person** — paging or a ticket queue, a
  project value. An alarm with no action is a graph
- Set `treat_missing_data` deliberately. An `Errors` alarm treats missing data as `notBreaching` —
  no invocations is not an error. An alarm on a queue's age or depth does too. An alarm that is
  meant to catch a scheduled Lambda not running at all needs `breaching`
- **A dead-letter or on-failure queue alarms on its first message** —
  `ApproximateNumberOfMessagesVisible` above zero
