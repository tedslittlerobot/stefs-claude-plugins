# Stef's Claude Plugins

A [Claude Code](https://code.claude.com/docs) plugin marketplace hosting two plugins: the
**portable layer** of our engineering and documentation conventions, and a collection of
general-purpose utilities.

| Plugin | Covers | Changes a session on its own? |
| --- | --- | --- |
| [`conventions`](plugins/conventions) | Nine model-invoked skills carrying rules that apply across projects: frontends, infrastructure, Lambdas, MySQL, documentation, glossary, product requirements, and how a project records its own conventions | No — no hooks, no executable code |
| [`utils`](plugins/utils) | General-purpose commands, skills and agents, including the default-on `auto-summary-commit` workflow | **Yes** — installing it turns commit-per-prompt on. See [The commit hooks](#the-commit-hooks) |

## Install

```
/plugin marketplace add tedslittlerobot/stefs-claude-plugins
/plugin install conventions@stefs-plugins
/plugin install utils@stefs-plugins
```

Or from the CLI:

```bash
claude plugin marketplace add tedslittlerobot/stefs-claude-plugins
claude plugin install conventions@stefs-plugins
claude plugin install utils@stefs-plugins
```

The two plugins are independent — install either on its own. Verify `utils` with
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

## The `conventions` plugin

Conventions come in two layers, and keeping them apart is what makes any of this reusable:

| Layer | Lives in | Contains |
| --- | --- | --- |
| **Portable** | the skills in this repository | The rule and its reasoning, stated without reference to any one project's services, paths or vocabulary |
| **Project** | `conventions/<topic>.md` in each repository | What that project's rules are *on top of* this: the paths the rules apply to, its chosen values, its registered exceptions, and its worked examples |

**The project file wins where the two differ** — that is the whole point of having the layer. A
project conventions file opens by naming the skill that carries its general layer, then records only
what is genuinely specific to that repository.

The `conventions` skill documents this arrangement in full, including what belongs in a project file
versus in architecture documentation, a glossary entry, an instruction or a proposal.

Each of the nine skills is model-invoked — its `description` decides when it loads, so the body
stays out of context until the work actually calls for it. Nothing here fires on its own: the
plugin adds no hooks and changes nothing about a session in which no skill matches.

| Skill | Covers |
| --- | --- |
| `conventions` | How a project records its own conventions: the `conventions/` directory, what belongs there versus elsewhere, precedence, and how to write a rule so the reasoning survives |
| `frontend` | SPA frontends: AlpineJS + Tailwind v4 + Pinecone Router with no build step, layout, routing, runtime config, S3 deployment, design idiom, accessibility |
| `infrastructure` | Terraform and AWS: tfvars and workspaces, recorded outputs, naming and tagging, S3/CloudFront hosting, Route 53/SES, Cognito, WAF |
| `lambdas-go` | Go Lambdas: trigger-based naming, module layout, package naming, logging, shared libraries, testing |
| `lambdas-node` | Node.js Lambdas: when Node is justified at all, ESM, factory-function DI, `node --test`, packaging |
| `mysql` | MySQL/Aurora schema and query conventions |
| `documentation` | The three tenses of documentation, API docs, READMEs, proposals, diagrams |
| `glossary` | The project-level glossary: one file per term, the entry template, the index, and linking rather than restating |
| `product-requirements` | Requirements and user stories: sections, Gherkin, acceptance criteria, test-coverage notes, risk assessment |

## The `utils` plugin

| Kind    | Name                  | Covers                                                                                                                                                           |
| ------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Command | `/utils:hello`        | A smoke test — reports what the plugin currently provides                                                                                                        |
| Skill   | `auto-summary-commit` | The default commit workflow: after any prompt that changed files, stage them, show the summary, and commit onto the current branch once reviewed — recording the prompt and the summary in the commit body |

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

It only stops to ask when the summary has something in it worth answering — a choice offered, a
trade-off flagged, an assumption stated, work left out. A turn that just reports what changed
commits straight away; the summary is on screen either way, so a question there would review
nothing. When it does ask, the options are **Commit it**, **Not yet, still working**, **I'll
commit it myself**, and **Stop asking this session** — only the last switches anything off, and
the middle two record the paths so the eventual commit still covers them.

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

Installing `conventions` alone changes nothing about a session until a skill matches.

## Repository layout

```
.
├── .claude-plugin/
│   └── marketplace.json            # marketplace "stefs-plugins" — lists the plugins below
└── plugins/
    ├── conventions/                # the portable conventions skills
    │   ├── .claude-plugin/plugin.json
    │   └── skills/<skill-name>/
    │       ├── SKILL.md            # frontmatter + the core rules
    │       └── reference/*.md      # detail, loaded only when SKILL.md points at it
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

`metadata.pluginRoot` is `./plugins`, so a third plugin means creating `plugins/<name>/` and
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
- **Keep conventions skills portable.** No service names, no repository paths, no project-specific
  values. Those belong in the consuming project's `conventions/` file. Where a concrete example
  genuinely teaches the rule better than an abstraction would, frame it as an example
- **Record the reasoning, and prefer the failure that motivated the rule.** A bare rule gets
  deleted the first time it is inconvenient; a rule with its reason attached gets followed, or gets
  changed deliberately
- **Correct in place and say it was corrected** when a rule turns out to be wrong — what it used to
  say, and why the old version failed. That is usually why the new one is shaped as it is

## Validate

```bash
claude plugin validate plugins/conventions --strict
claude plugin validate plugins/utils --strict
```

## History

This repository replaces two separate marketplaces, each of which carried one of these plugins:
[`claude-arc-conventions`](https://github.com/tedslittlerobot/claude-arc-conventions) and
[`claude-utils`](https://github.com/tedslittlerobot/claude-utils). Their install commands
(`conventions@arc-conventions`, `claude-utils@claude-utils`) are superseded by the ones above.

The `claude-utils` plugin was renamed `utils` in the move — the `claude-` prefix said nothing once
the plugin no longer had to carry its own marketplace's name. Its command namespace moved with it,
so `/claude-utils:hello` is now `/utils:hello`.

## License

MIT — see [LICENSE](LICENSE).
