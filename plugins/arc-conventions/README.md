# arc-conventions

The portable layer of software and project **architecture** conventions, as seven model-invoked
skills — API design, engineering and infrastructure rules that hold across projects.

The `arc-` prefix is a scope, not decoration: these are the architecture conventions specifically.
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
| `mysql` | Writing DDL, migrations, `ALTER TABLE`, or repository queries |
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
