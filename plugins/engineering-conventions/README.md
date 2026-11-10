# engineering-conventions

**Engineering conventions for projects built to run in production.** Two model-invoked skills, for
Go and Node.js AWS Lambdas.

This is the production counterpart to [`prototype-conventions`](../prototype-conventions), whose
rules are chosen for how quickly a prototype can be built and thrown away. The skills here started
as copies of that plugin's `lambdas-go` and `lambdas-node` at `prototype-conventions` 0.19.0, and
diverged at 0.2.0 where a prototype's choices do not survive production:

| Area | `prototype-conventions` | Here |
| --- | --- | --- |
| Logging | Plain-text `[module:file:function:step]` lines at one level | Structured JSON (`log/slog`, Powertools Logger) with shared key names, levels, request and trace IDs |
| Failure handling | Not covered | `context.Context` and deadlines, idempotency, partial batch responses, dead-letter queues and on-failure destinations, timeouts |
| Observability | Logs only | Plus EMF metrics, OpenTelemetry tracing, and the alarms every Lambda needs |
| Build and deploy | Terraform builds at plan time on the operator's machine | CI builds reproducible `arm64` artifacts once, deployed by content-addressed key; Node bundled with esbuild |
| Dependencies | One module per Lambda | Plus a committed `go.work`, `govulncheck` and `npm audit` in CI, grouped automated updates |
| Testing | Unit tests only | Plus integration tests against a real MySQL and smoke tests against a deployed environment |
| Manual-invocation Lambdas | `ninja-` | `invoke-`, invocable by a restricted operations role only |
| `/api` route prefix | Required, for the prototype's CloudFront hosting | Removed — a production infrastructure concern |
| `url-` and `aurora-` Lambdas | Allowed | Discouraged; allowed with a recorded justification |

Everything else — the rest of the trigger-naming table, module and package layout, file
organisation, `schema.md` and the README contract — is still the same in both, and each divergence
is marked in the skill where it happens.

Where both plugins are installed, a prototype or proof of concept follows the
`prototype-conventions` skill and any other project follows this one. Each skill's opening note says so, because the plugin
description is not in context when a skill loads.

The plugin follows the same two-layer model as the other conventions plugins: the portable rule
lives here, and a project's own values, exceptions and registers live in its `conventions/` files.
How those files work is the `conventions` skill, in
[`documentation-and-planning`](../documentation-and-planning).

See the [repository README](../../README.md) for installation, the full skill list, and how to add
to a skill.

## Skills

| Skill | Load it when |
| --- | --- |
| `lambdas-go` | Writing, reviewing or testing Go Lambda code, or creating a Lambda directory |
| `lambdas-node` | Writing a Node Lambda, or deciding whether a Lambda may be Node at all |

Each skill's `SKILL.md` names the `reference/` files it depends on; those load only when the skill
points at them.

## Hooks

None. Installing this plugin changes nothing about a session until a skill's description matches
the work.
