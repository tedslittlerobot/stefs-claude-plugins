# documentation-and-planning

The portable layer of **documentation and planning** conventions, as four model-invoked skills:
how a project records its own conventions, how its markdown documents are written and where each
belongs, how a design is proposed and then planned and built in stages, and how the terms it all
relies on are defined.

It sits beside [`prototype-conventions`](../prototype-conventions), which carries the architecture
rules, and follows the same two-layer model: the skills carry the portable rules, and a consuming
repository records its own values and exceptions in `conventions/<topic>.md`, which wins where the
two differ. The `conventions` skill documents that model, for both plugins. See the [repository
README](../../README.md) for installation.

## Skills

| Skill | Load it when |
| --- | --- |
| `conventions` | Adding or editing a project conventions file, recording a decision as a rule, or project and general rules appear to conflict |
| `documentation` | Writing or editing any markdown document — including keeping its table of contents current — deciding where a document belongs, writing an `api.md`, README or diagram, or writing a proposal |
| `plan-of-action` | Turning a settled proposal into staged work, or implementing a plan one stage at a time |
| `glossary` | Defining a term, or a document is about to explain what a term means |

The markdown rules every document follows — an up-to-date table of contents before the first
heading, root-relative paths, linking terms to the glossary, recording the reasoning and correcting
in place — are in the `documentation` skill, and apply to documents whose format another skill
defines as well.

Each skill's `SKILL.md` names the `reference/` files it depends on; those load only when the skill
points at them.

## Hooks

None. Installing this plugin changes nothing about a session until a skill's description matches
the work.
