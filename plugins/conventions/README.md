# conventions

The portable layer of engineering, architecture, and documentation conventions, as nine
model-invoked skills.

See the [repository README](../../README.md) for the two-layer model this sits in, installation, the
full skill list, and how to add to a skill.

## Skills

| Skill | Load it when |
| --- | --- |
| `conventions` | Adding or editing a project conventions file, or project and general rules appear to conflict |
| `frontend` | Writing frontend HTML/CSS/JS, adding a route, working with Alpine or Tailwind |
| `infrastructure` | Writing `.tf` files, naming AWS resources, debugging an apply-time AWS error |
| `lambdas-go` | Writing, reviewing or testing Go Lambda code, or creating a Lambda directory |
| `lambdas-node` | Writing a Node Lambda, or deciding whether a Lambda may be Node at all |
| `mysql` | Writing DDL, migrations, `ALTER TABLE`, or repository queries |
| `documentation` | Writing any markdown document, or deciding where a document belongs |
| `glossary` | Defining a term, or a document is about to explain what a term means |
| `product-requirements` | Writing a requirement or user story, or updating test-coverage notes |

Each skill's `SKILL.md` names the `reference/` files it depends on; those load only when the skill
points at them.

## Hooks

None. Installing this plugin changes nothing about a session until a skill's description matches
the work.
