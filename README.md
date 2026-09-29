# Stef's Claude Plugins

A [Claude Code](https://code.claude.com/docs) plugin marketplace hosting three plugins:
conventions for building **prototypes and proof-of-concept projects**, the portable layer of our
documentation and planning conventions, and a collection of general-purpose utilities and
conventions.

| Plugin | Covers | Changes a session on its own? |
| --- | --- | --- |
| [`prototype-conventions`](plugins/prototype-conventions) | Conventions and guidelines for building **prototypes and proof-of-concept projects — not for production use**. Five model-invoked skills: frontends, infrastructure, Lambdas and product requirements | No — no hooks, no executable code |
| [`documentation-and-planning`](plugins/documentation-and-planning) | Four model-invoked skills carrying the **documentation and planning** conventions: how a project records its own conventions, the markdown rules every document follows, the three tenses of documentation, proposals, plans of action, and the glossary | No — no hooks, no executable code |
| [`utils`](plugins/utils) | General-purpose commands, skills and agents, including the default-on `auto-summary-commit` workflow, and general conventions not specific to prototypes (`api-design`, `mysql`) | **Yes** — installing it turns commit-per-prompt on. See [The commit hooks](#the-commit-hooks) |

## Install

```
/plugin marketplace add tedslittlerobot/stefs-claude-plugins
/plugin install prototype-conventions@stefs-plugins
/plugin install documentation-and-planning@stefs-plugins
/plugin install utils@stefs-plugins
```

Or from the CLI:

```bash
claude plugin marketplace add tedslittlerobot/stefs-claude-plugins
claude plugin install prototype-conventions@stefs-plugins
claude plugin install documentation-and-planning@stefs-plugins
claude plugin install utils@stefs-plugins
```

The three plugins are independent — install any of them on its own. The two conventions plugins name
each other's skills in their Related sections, and work best installed together. Verify `utils` with
`/utils:hello`.

Updating the marketplace —

```
/plugin marketplace update stefs-plugins
```

— pulls the latest commit, so every project that has a plugin installed picks up a convention
change without any per-project edit.

To work on the plugins themselves, add this checkout by path instead and the same commands apply
against your working tree:

```bash
claude plugin marketplace add ~/Developer/claude/stefs-claude-plugins
```

## The conventions plugins

`prototype-conventions` and `documentation-and-planning` share one model. Conventions come in two
layers, and keeping them apart is what makes any of this reusable:

| Layer | Lives in | Contains |
| --- | --- | --- |
| **Portable** | the skills in this repository | The rule and its reasoning, stated without reference to any one project's services, paths or vocabulary |
| **Project** | `conventions/<topic>.md` in each repository | What that project's rules are *on top of* this: the paths the rules apply to, its chosen values, its registered exceptions, and its worked examples |

**The project file wins where the two differ** — that is the whole point of having the layer. A
project conventions file opens by naming the skill that carries its general layer, then records only
what is genuinely specific to that repository.

The `conventions` skill, in `documentation-and-planning`, documents this arrangement in full,
including what belongs in a project file versus in architecture documentation, a glossary entry, an
instruction or a proposal.

Every skill in both plugins is model-invoked — its `description` decides when it loads, so the
body stays out of context until the work actually calls for it. Nothing here fires on its own:
neither plugin adds hooks, and neither changes anything about a session in which no skill matches.

### `prototype-conventions`

For prototypes and proof-of-concept projects only — **not for production use**. The rules are
chosen for how quickly a prototype can be built and understood, not for what a production system
needs.

| Skill | Covers |
| --- | --- |
| `frontend` | SPA frontends: AlpineJS + Tailwind v4 + Pinecone Router with no build step, layout, routing, runtime config, S3 deployment, design idiom, accessibility |
| `infrastructure` | Terraform and AWS: tfvars and workspaces, recorded outputs, naming and tagging, S3/CloudFront hosting, Route 53/SES, Cognito, WAF |
| `lambdas-go` | Go Lambdas: trigger-based naming, module layout, package naming, logging, shared libraries, testing |
| `lambdas-node` | Node.js Lambdas: when Node is justified at all, ESM, factory-function DI, `node --test`, packaging |
| `product-requirements` | Requirements and user stories: sections, Gherkin, acceptance criteria, test-coverage notes, risk assessment |

### `documentation-and-planning`

| Skill | Covers |
| --- | --- |
| `conventions` | How a project records its own conventions: the `conventions/` directory, what belongs there versus elsewhere, precedence, and how to write a rule so the reasoning survives |
| `documentation` | The markdown rules every document follows (an up-to-date table of contents, root-relative paths, recording the reasoning), the three tenses of documentation, API docs, READMEs, proposals, diagrams |
| `plan-of-action` | The staged implementation plan a settled proposal becomes: stage naming, where the boundaries and checkpoints go, and implementing it one stage at a time |
| `glossary` | The project-level glossary: one file per term, the entry template, the index, and linking rather than restating |

## The `utils` plugin

| Kind    | Name                  | Covers                                                                                                                                                           |
| ------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Command | `/utils:hello`        | A smoke test — reports what the plugin currently provides                                                                                                        |
| Skill   | `auto-summary-commit` | The default commit workflow: after any prompt that changed files, stage them and commit onto the current branch straight away — recording the prompt and the summary in the commit body |
| Skill   | `api-design`          | HTTP/JSON APIs, designed for the human calling them first: principles, `kebab-case` URLs and the `data`/`error` envelope, `snake_case` naming and data types, methods and status codes, list endpoints (`q` search, `filter[...]`, `sort[]`, page-based pagination), errors and `400` versus `422`, versioning by resource suffix, auth and rate limiting |
| Skill   | `mysql`               | General MySQL/Aurora schema and query conventions: snake_case naming, UUIDv7 keys, timestamps, adding columns, SQL formatting |

`api-design` and `mysql` are the conventions skills in `utils`. They follow the same two-layer
model as the conventions plugins — a project's own values go in its `conventions/api.md` or
`conventions/sql.md` — and they live here rather than in `prototype-conventions` because nothing in
them is specific to prototypes.

### The commit hooks

`auto-summary-commit` is the one skill that changes what happens when you *don't* ask for anything.
The plugin ships a pair of hooks that drive it:

- **`UserPromptSubmit`** fingerprints every dirty path in the working tree before the turn runs.
- **`Stop`** fingerprints it again. If this turn changed anything, it feeds the model the
  instruction to run the skill, with the list of paths *this turn* changed, and the conversation
  continues so it can act on it.

`UserPromptSubmit` also records the prompt itself, so the commit body can quote what was asked
rather than a reconstruction of it. Then the skill does the rest: stage exactly those paths, and
commit onto the current branch with a body of `## Prompt` and `## Summary`.

It commits straight away on the great majority of turns, so every prompt leaves its prompt and
outcome in `git log` — a history, an audit trail, and a rollback point. Caveats, assumptions and
follow-up questions in the summary go into the commit body rather than holding it up. It stops to
ask only when something is majorly wrong with the change, or when an open question decides whether
the work is the right work at all. When it does ask, the options are **Commit it**, **Not yet, still
working**, **I'll commit it myself**, and **Stop asking this session** — only the last switches
anything off, and the middle two record the paths so the eventual commit still covers them.

The baseline is the point. Asking only "is the tree dirty" fires on work that was already
uncommitted when the session started, re-asks every turn once you have declined, and lets
`git add -A` sweep your in-flight edits into a commit that claims to describe only the model's
work. Fingerprints are content hashes, not status codes, so a file you had already modified before
the turn and the model modified during it is still attributed correctly.

Neither hook commits anything itself, and `Stop` raises a given tree state only once, so ending a
turn with the work uncommitted is always possible — declining leaves the tree unchanged, so the
question is not put again. They stay silent when the turn changed nothing, when only gitignored
files changed, outside a git repository, and during a rebase, merge, cherry-pick or bisect.

To switch it off:

| Scope        | How                                                                             |
| ------------ | --------------------------------------------------------------------------------- |
| This session | Pick "Stop asking this session" when it asks, or say so in a prompt              |
| Always       | Set `AUTO_SUMMARY_COMMIT=off` in the environment                                |
| Entirely     | Don't install `utils`, or remove `plugins/utils/hooks/` from your fork |

Installing `prototype-conventions` or `documentation-and-planning` alone changes nothing about a
session until a skill matches.

## Repository layout

```
.
├── .claude-plugin/
│   └── marketplace.json            # marketplace "stefs-plugins" — lists the plugins below
└── plugins/
    ├── prototype-conventions/      # conventions for prototypes and proofs of concept
    │   ├── .claude-plugin/plugin.json
    │   └── skills/<skill-name>/
    │       ├── SKILL.md            # frontmatter + the core rules
    │       └── reference/*.md      # detail, loaded only when SKILL.md points at it
    ├── documentation-and-planning/ # the documentation and planning skills, same shape
    │   ├── .claude-plugin/plugin.json
    │   └── skills/<skill-name>/
    └── utils/                      # general-purpose utilities
        ├── .claude-plugin/plugin.json
        ├── commands/               # slash commands
        ├── skills/                 # skills (<name>/SKILL.md)
        ├── agents/                 # subagents
        ├── hooks/
        │   ├── hooks.json          # the two hooks that drive auto-summary-commit
        │   └── auto-summary-commit.sh  # their script
        └── scripts/                # helper scripts
```

`metadata.pluginRoot` is `./plugins`, so another plugin means creating `plugins/<name>/` and
appending an entry to `marketplace.json`. A new skill or command needs no registration beyond its
file.

## Adding to a skill

- **`SKILL.md` holds the frontmatter and the rules a reader needs every time.** Only the
  frontmatter `description` is always in context, so it must carry the *trigger vocabulary* — the
  words and file types that should cause the skill to load — rather than a summary. A vague
  description means the skill never fires and the convention silently isn't followed
- **`reference/*.md` holds the detail**, and `SKILL.md` must point at it explicitly by filename.
  Splitting one skill into per-topic reference files is cheaper than splitting it into several
  skills, since every skill's description competes for trigger match
- **Keep conventions skills portable** — in `prototype-conventions` and `documentation-and-planning`
  alike. No service names, no repository paths, no project-specific values. Those belong in the
  consuming project's `conventions/` file. Where a concrete example genuinely teaches the rule
  better than an abstraction would, frame it as an example
- **Record the reasoning, and prefer the failure that motivated the rule.** A bare rule gets
  deleted the first time it is inconvenient; a rule with its reason attached gets followed, or gets
  changed deliberately
- **Correct in place and say it was corrected** when a rule turns out to be wrong — what it used to
  say, and why the old version failed. That is usually why the new one is shaped as it is

## Validate

```bash
claude plugin validate plugins/prototype-conventions --strict
claude plugin validate plugins/documentation-and-planning --strict
claude plugin validate plugins/utils --strict
```

## History

This repository replaces two separate marketplaces, each of which carried one of these plugins:
[`claude-arc-conventions`](https://github.com/tedslittlerobot/claude-arc-conventions) and
[`claude-utils`](https://github.com/tedslittlerobot/claude-utils). Their install commands
(`conventions@arc-conventions`, `claude-utils@claude-utils`) are superseded by the ones above.

Both plugins were renamed in the move. `claude-utils` became `utils` — the `claude-` prefix said
nothing once the plugin no longer had to carry its own marketplace's name — and its command
namespace moved with it, so `/claude-utils:hello` is now `/utils:hello`. `conventions` became
`arc-conventions`, narrowing the name to the scope it actually covers: software and project
*architecture*. Conventions with a different focus and a different set of rules are expected later,
and they get their own plugin rather than being folded into this one, so a project can install one
scope without the other. Skill names are unchanged, so a project `conventions/` file that names a
skill keeps working as it is.

The first such split came at `arc-conventions` 0.12.0: `documentation`, `plan-of-action` and
`glossary` moved out into `documentation-and-planning`. They are rules about writing documents and
planning work rather than about how software is built, and a project can want them without any of
the stack-specific skills. Their skill names are unchanged, but **a project that had
`arc-conventions` installed must also install `documentation-and-planning`** to keep them —
updating the marketplace alone drops them from the session.

`conventions` followed at `arc-conventions` 0.13.0. It is the meta-skill for recording a project's
rules — a document-writing subject — and it serves both plugins equally, so it sits with the other
rules about documents; as before, a project needs `documentation-and-planning` installed to keep
it. `product-requirements` stays in `arc-conventions`.

`arc-conventions` itself was then renamed `prototype-conventions`, at 0.14.0, with its skill names
unchanged. The old name is no longer in the marketplace, so a project that had it installed
uninstalls it and installs the new one:

```
/plugin uninstall arc-conventions@stefs-plugins
/plugin install prototype-conventions@stefs-plugins
```

At `prototype-conventions` 0.15.0 the plugin took its current scope — prototypes and proofs of
concept, not production — and `mysql` moved to `utils` (0.4.0), since its rules hold for any
project. A project that wants `mysql` needs `utils` installed. `api-design` followed at
`prototype-conventions` 0.16.0 (`utils` 0.5.0), for the same reason.

## License

MIT — see [LICENSE](LICENSE).
