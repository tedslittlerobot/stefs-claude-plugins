# engineering-conventions

**Engineering conventions for projects built to run in production.** Three model-invoked skills:
Terraform and AWS infrastructure, and Go and Node.js AWS Lambdas.

This is the production counterpart to [`prototype-conventions`](../prototype-conventions), whose
rules are chosen for how quickly a prototype can be built and thrown away. The skills here started
as copies of that plugin's `lambdas-go`, `lambdas-node` and `infrastructure` at
`prototype-conventions` 0.19.0, and diverged where a prototype's choices do not survive production
— the Lambda skills at 0.2.0, `infrastructure` at 0.5.0.

### Lambdas

| Area | `prototype-conventions` | Here |
| --- | --- | --- |
| Logging | Plain-text `[module:file:function:step]` lines at one level | Structured JSON (`log/slog`, Powertools Logger) with shared key names, levels, request and trace IDs |
| Failure handling | Not covered | `context.Context` and deadlines, idempotency, partial batch responses, dead-letter queues and on-failure destinations, timeouts |
| Observability | Logs only | Plus OpenTelemetry metrics over OTLP to CloudWatch for CloudWatch Omni, OpenTelemetry tracing, and the alarms every Lambda needs |
| Build and deploy | Terraform builds at plan time on the operator's machine | CI builds reproducible `arm64` artifacts once and deploys them itself, behind a `live` alias; Node bundled with esbuild |
| Dependencies | One module per Lambda | Plus a committed `go.work`, `govulncheck` and `npm audit` in CI, grouped automated updates |
| Testing | Unit tests only | Plus integration tests against a real MySQL and smoke tests against a deployed environment |
| Manual-invocation Lambdas | `ninja-` | `invoke-`, invocable by a restricted operations role only |
| `url-` and `aurora-` Lambdas | Allowed | Discouraged; allowed with a recorded justification |
| Timeouts | Not covered | An estimate of the work plus a buffer, never below 30 seconds; a caller's shorter limit is respected by the code |

### Infrastructure

| Area | `prototype-conventions` | Here |
| --- | --- | --- |
| Applying | A person runs `apply` from their own machine | Only CI applies — a saved plan, reviewed on the pull request, with approval for production |
| State | A local file; a CLI workspace per deployment | A shared remote backend, one state per root per environment — GitLab-managed state for a repository on GitLab, otherwise HCP Terraform (in Local execution mode), S3 or another |
| Credentials | `saml2aws` and `.aws-credentials.bash` | OIDC roles in CI — a read-only plan role and an apply role per environment; local credentials are a project value |
| Checks | None | `fmt`, `validate`, `tflint`, a misconfiguration scanner, a multi-platform provider lock file, a scheduled drift check |
| Resource names | The environment only where a service is deployed twice in one account | Always `<prefix>-<environment>-<name>`, since environments may share an account; IAM scoped by that prefix |
| Tags | Project | `Project`, `Environment`, `Owner`, `Repository` |
| Lambda timeouts | 30 seconds for every Lambda | An estimate plus at least half again, with a 30-second floor and the estimate in a comment |
| Lambda code | Built and deployed by `terraform apply` | Deployed by CI after the apply: a placeholder package Terraform ignores, `publish-version`, a `live` alias every trigger invokes, rollback by moving the alias |
| Lambda configuration | Packaging only | JSON logging, retention, tracing, `arm64`, failure destinations, scoped permissions, `invoke-` auditing, alarms |
| Recorded outputs | Committed `.tfoutputs/*.yaml` after every apply | Dropped — outputs are read on demand |
| Stateful resources | Disposable | `prevent_destroy`, deletion protection, AWS Backup, KMS rotation |
| Aurora | A fixed, non-secret password and a public endpoint | Secrets Manager-managed password, private subnets, encryption, Multi-AZ; the `rds-aurora` module |
| Frontend hosting | Terraform uploads every file; no build step | Terraform builds the hosting only; CI uploads hashed assets and invalidates; security headers, TLS 1.2, access logs |
| SES | DKIM and MAIL FROM | Plus DMARC, bounce and complaint handling, leaving the sandbox |
| Cognito and WAF | The apply-time traps and the WAF baseline | Deletion protection, MFA, a custom Hosted UI domain; managed WAF rules counted before they block, pinned versions, log retention |

### The `/api` route prefix

**Corrected at 0.5.0.** 0.2.0 removed the rule that every API route sits under `/api` from the
Lambda skills, on the reading that it existed only for the prototype's CloudFront hosting and was a
production infrastructure concern. It is now a rule of this plugin's `infrastructure` skill, and
holds **even for an API on its own hostname**: a route then has the same path whichever
distribution serves it. With that, the Lambda skills' wording is the prototype's again, and no
longer a divergence.

Everything else — the rest of the trigger-naming table and the `/api` prefix, module and package
layout, file organisation, `schema.md` and the README contract, and in `infrastructure` the file
organisation, module preferences, SPA fallback, delegated zones and the Cognito and WAF traps — is
still the same in both, and each divergence is marked in the skill where it happens.

Where both plugins are installed, a prototype or proof of concept follows the
`prototype-conventions` skill and any other project follows this one. Each skill's opening note
says so, because the plugin description is not in context when a skill loads.

The plugin follows the same two-layer model as the other conventions plugins: the portable rule
lives here, and a project's own values, exceptions and registers live in its `conventions/` files.
How those files work is the `conventions` skill, in
[`documentation-and-planning`](../documentation-and-planning).

See the [repository README](../../README.md) for installation, the full skill list, and how to add
to a skill.

## Skills

| Skill | Load it when |
| --- | --- |
| `infrastructure` | Writing or editing `.tf` files, setting up a Terraform pipeline or state backend, naming or tagging AWS resources, choosing a Lambda timeout, adding infrastructure for a feature, or debugging an apply-time AWS error |
| `lambdas-go` | Writing, reviewing or testing Go Lambda code, or creating a Lambda directory |
| `lambdas-node` | Writing a Node Lambda, or deciding whether a Lambda may be Node at all |

Each skill's `SKILL.md` names the `reference/` files it depends on; those load only when the skill
points at them.

## Hooks

None. Installing this plugin changes nothing about a session until a skill's description matches
the work.
