# prototype-conventions

**Conventions and guidelines for building prototypes and proof-of-concept projects — not for
production use.** Six model-invoked skills: API design, the frontend, infrastructure and Lambda
stack a prototype is built on, and the product requirements it is built against.

These rules are chosen for how quickly a prototype can be built, understood and thrown away or
rebuilt, not for what a production system needs — scale, resilience, security review, operational
support. A project that is going to production should not take them as its standards without
reviewing each one for that purpose.

The name is a scope, not decoration. The plugin was called `arc-conventions` until 0.14.0, when it
carried the portable *architecture* conventions. General conventions that are not specific to
prototypes live elsewhere: the `mysql` skill is in [`utils`](../utils).
Conventions with a different focus get their own plugin rather than being folded in here, so a
project can install one scope without the other. How a project records its own conventions (the
`conventions` skill), and the rules for documents — markdown, the three tenses of documentation,
proposals, plans of action and the glossary — are in the sibling
[`documentation-and-planning`](../documentation-and-planning) plugin.

See the [repository README](../../README.md) for the two-layer model this sits in, installation, the
full skill list, and how to add to a skill.

## Skills

| Skill | Load it when |
| --- | --- |
| `api-design` | Designing, building or reviewing an HTTP/JSON API: an endpoint, a request or response payload, a list endpoint's filters, sort or pagination, an error response, a status code, or a breaking change |
| `frontend` | Writing frontend HTML/CSS/JS, adding a route, working with Alpine or Tailwind |
| `infrastructure` | Writing `.tf` files, naming AWS resources, debugging an apply-time AWS error |
| `lambdas-go` | Writing, reviewing or testing Go Lambda code, or creating a Lambda directory |
| `lambdas-node` | Writing a Node Lambda, or deciding whether a Lambda may be Node at all |
| `product-requirements` | Writing a requirement or user story, or updating test-coverage notes |

Each skill's `SKILL.md` names the `reference/` files it depends on; those load only when the skill
points at them.

`api-design` is the one skill not tied to a stack. Its rules hold whatever serves the API: paths
of `/api`, service prefixes, then collections, resources and verbs, with CRUD left to the HTTP
methods; `snake_case` keys and `kebab-case` paths; arrays as repeated `name[]` query parameters,
never comma-separated strings; `filter[...]` and `q` on list endpoints, with page-based pagination
by default; `/me/` for the current user's own resources; nested objects for related resources;
`422` for validation failures; gzipped responses; and a `-v2` resource suffix instead of a version
prefix. A project's chosen values and exceptions go in its `conventions/api.md`.

## Hooks

None. Installing this plugin changes nothing about a session until a skill's description matches
the work.
