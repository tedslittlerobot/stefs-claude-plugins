# Utils

General-purpose utility commands, skills and agents for Claude Code, and general conventions that
hold beyond prototypes.

## What's in it

| Kind    | Name                  | Loads when                                                     |
| ------- | --------------------- | -------------------------------------------------------------- |
| Command | `/utils:hello`        | You run it — a smoke test that reports what the plugin provides |
| Skill   | `auto-summary-commit` | Any prompt has just changed git-tracked files — it runs by default, last |
| Skill   | `api-design`          | Designing, building or reviewing an HTTP/JSON API: an endpoint, a request or response payload, a list endpoint's filters, sort or pagination, an error response, a status code, or a breaking change |
| Skill   | `mysql`               | Writing DDL, migrations, `ALTER TABLE`, or repository queries against MySQL or Aurora MySQL |

`api-design` and `mysql` are conventions skills rather than actions: general rules, with a project's
own values in its `conventions/api.md` or `conventions/sql.md` on top, as the `conventions` skill
describes. They are here rather than in `prototype-conventions` because nothing in them is specific
to prototypes.

`api-design`'s rules hold whatever serves the API: paths of `/api`, service prefixes, then
collections, resources and verbs, with CRUD left to the HTTP methods; `snake_case` keys and
`kebab-case` paths; arrays as repeated `name[]` query parameters, never comma-separated strings;
`filter[...]` and `q` on list endpoints, with page-based pagination by default; `/me/` for the
current user's own resources; nested objects for related resources; `422` for validation failures;
gzipped responses; and a `-v2` resource suffix instead of a version prefix. A project's chosen
values and exceptions go in its `conventions/api.md`.

### The commit hooks

`hooks/hooks.json` registers two hooks, both running `hooks/auto-summary-commit.sh`:

| Event              | Mode   | Does                                                                                                                       |
| ------------------ | ------ | -------------------------------------------------------------------------------------------------------------------------- |
| `UserPromptSubmit` | `pre`  | Fingerprints the dirty paths in the working tree, and records the prompt; prints nothing                                     |
| `Stop`             | `stop` | Fingerprints again; if this turn changed anything, feeds back an instruction to run the `auto-summary-commit` skill on exactly those paths |

Neither commits anything itself — staging, the summary and the commit are the skill's job. See
the [repository README](../../README.md#the-commit-hooks) for what silences them.

## Layout

| Directory   | Holds                                                        |
| ----------- | ------------------------------------------------------------ |
| `commands/` | Flat `.md` slash commands, e.g. `/utils:hello`                |
| `skills/`   | Named skills, one directory each containing a `SKILL.md`      |
| `agents/`   | Subagent definitions as `.md` files with YAML frontmatter     |
| `hooks/`    | `hooks.json` event configuration                             |
| `scripts/`  | Shell/Python/Node helpers invoked by hooks and commands       |

Reference bundled files from hooks and MCP configs with `${CLAUDE_PLUGIN_ROOT}`,
never a relative or absolute path — the plugin is copied to a versioned cache
directory on install.

## Adding a command

Create `commands/<name>.md` with frontmatter:

```markdown
---
name: my-command
description: One line describing when to use it.
---

Instructions for Claude...
```

It becomes available as `/utils:my-command`.

## Adding a skill

Create `skills/<name>/SKILL.md` with `name` and `description` frontmatter. The
description is what Claude matches against when deciding to load the skill, so
make it say *when* to use it, not just what it does.

## Local development

```bash
claude plugin validate plugins/utils --strict   # from the repository root
/reload-plugins   # inside a Claude Code session, after changing anything but a SKILL.md
```
