# engineering-conventions

**Engineering conventions for projects built to run in production.** Two model-invoked skills, for
Go and Node.js AWS Lambdas.

This is the production counterpart to [`prototype-conventions`](../prototype-conventions), whose
rules are chosen for how quickly a prototype can be built and thrown away. The skills here started
as copies of that plugin's `lambdas-go` and `lambdas-node` at `prototype-conventions` 0.19.0, with
only the prototype-only note replaced. They have **not yet been reviewed for production**, and are
expected to diverge from their prototype originals as that review lands — logging, failure
handling, build and deployment are the likeliest places.

Where both plugins are installed, a prototype or proof of concept follows the `prototype-conventions`
skill and any other project follows this one. Each skill's opening note says so, because the plugin
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
