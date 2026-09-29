# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

A Claude Code **plugin marketplace**, not an application. There is no build step, no test suite and
no linter; the deliverable is markdown consumed by Claude Code's skill and command loaders, plus
the shell scripts `utils`' hooks run. Outside `plugins/utils/hooks/` and
`plugins/utils/scripts/` there is no executable code at all.

It carries three independent plugins, and the split matters when deciding where something goes:

| Plugin | Holds | Registers hooks? |
| --- | --- | --- |
| `prototype-conventions` | Rules to follow on topic match — conventions and guidelines for building *prototypes and proof-of-concept projects*, not for production use | No, and must not |
| `documentation-and-planning` | Rules to follow on topic match — the portable layer of *documentation and planning* conventions: markdown, the three tenses of documentation, proposals, plans of action, the glossary | No, and must not |
| `utils` | General-purpose tooling — commands, agents, and skills that describe an *action* to take — plus general conventions that are not specific to prototypes (`api-design`, `mysql`) | Yes — the two auto-summary-commit hooks |

A rule for how a prototype or proof of concept is built belongs in `prototype-conventions`; one that
states how a document is written, where it belongs, or how work is proposed and planned belongs in
`documentation-and-planning`. A convention that holds whatever the project — production included —
and fits neither of those belongs in `utils`, as `api-design` and `mysql` do, alongside the skills
that do something, such as the one that runs at the end of every turn. That distinction is why
`auto-summary-commit` is not a conventions skill despite being about commits, and why `api-design`
and `mysql` left `prototype-conventions`: nothing in them is specific to prototypes, and a
production project should be able to use them without installing a plugin that says it is not for
production.

## Commands

```
claude plugin validate plugins/prototype-conventions --strict
claude plugin validate plugins/documentation-and-planning --strict
claude plugin validate plugins/utils --strict
/plugin marketplace add tedslittlerobot/stefs-claude-plugins   # consumers; hosted on GitHub
/plugin marketplace add ~/Developer/claude/stefs-claude-plugins # this clone, to work on the plugins
/plugin install prototype-conventions@stefs-plugins
/plugin install documentation-and-planning@stefs-plugins
/plugin install utils@stefs-plugins
/plugin marketplace update stefs-plugins                        # pull the latest commit
/reload-plugins                                                 # after changing anything but a SKILL.md
```

Skills are model-invoked, so the way to verify a skill change is to check that the frontmatter
`description` still contains the vocabulary that should trigger it, and that any `reference/*.md`
file the change adds is named explicitly from its `SKILL.md`.

### Bump the plugin version with every change to it

**Any change to a plugin's contents bumps that plugin's `version` in
`plugins/<name>/.claude-plugin/plugin.json`, in the same commit** — a new skill, an edited
`SKILL.md`, a new or changed `reference/*.md`, a hook script, a command. Both plugins are
versioned independently; bump the one that changed.

The version is not decoration, it is the install cache key. An installed plugin is copied to
`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`, and `/plugin marketplace update`
pulls the repository but will not re-copy into a version directory it already has. Adding the
`plan-of-action` skill without a bump produced exactly that: the marketplace clone held all ten
skills at the right commit, `~/.claude/plugins/cache/stefs-plugins/arc-conventions/0.1.0/` still
held the nine from three days earlier, and the new skill was invisible in Claude with nothing
wrong with it and nothing to see in `git log`. Pushing and updating again cannot fix it; only a
new version number or deleting the stale cache directory can.

`marketplace.json` has a `version` of its own, for the marketplace rather than the plugins. It
does not key the cache and does not need bumping for a skill change — but the per-plugin
`description` in that file is what the plugin browser shows, so a change that dates it (a skill
count, a list of what the plugin covers) is corrected there in the same commit.

## Architecture

Three nested levels, each with its own manifest:

```
.claude-plugin/marketplace.json     # marketplace "stefs-plugins", pluginRoot ./plugins
plugins/prototype-conventions/
  .claude-plugin/plugin.json        # plugin "prototype-conventions"
  skills/<skill-name>/
    SKILL.md                        # YAML frontmatter (name, description) + the always-loaded rules
    reference/*.md                  # detail, loaded only when SKILL.md points at it by filename
plugins/documentation-and-planning/
  .claude-plugin/plugin.json        # plugin "documentation-and-planning"
  skills/<skill-name>/              # same shape: SKILL.md + reference/*.md
plugins/utils/
  .claude-plugin/plugin.json        # plugin "utils"
  commands/<name>.md                # slash commands, /utils:<name>
  skills/<skill-name>/SKILL.md
  agents/<name>.md                  # subagents
  hooks/hooks.json                  # event registration; scripts alongside
  scripts/                          # helpers invoked by hooks and commands
```

`metadata.pluginRoot` is `./plugins`, so another plugin means creating `plugins/<name>/` and
appending an entry to `marketplace.json`. **Conventions plugins are scoped by subject.**
`prototype-conventions` carries the rules for building prototypes and proofs of concept and nothing
else, and `documentation-and-planning` the rules for documents and planning; a set of conventions
with a different subject — a different audience, a different reason to be followed — becomes its own
plugin rather than more skills in an existing one. Folding them together would mean a project that
wants one scope loads the other's descriptions into every session, competing for trigger match
against skills it will never want. The name says the scope: `prototype-conventions` uses a
`-conventions` suffix, `documentation-and-planning` names its subject directly, and either form is
fine for a new one so long as the scope is legible from the name. A new skill or command needs no
registration beyond its file. Reference bundled files from hooks with `${CLAUDE_PLUGIN_ROOT}`, never
a relative or absolute path — the plugin is copied to a versioned cache directory on install.

### The two-layer model

This is the organising idea behind every skill in `prototype-conventions` and
`documentation-and-planning`, and the reason those plugins exist. `api-design` and `mysql`, the
conventions skills in `utils`, follow it too.

| Layer | Lives in | Contains |
| --- | --- | --- |
| **Portable** | the skills here | The rule and its reasoning, with no reference to any one project's services, paths or vocabulary |
| **Project** | `conventions/<topic>.md` in each consuming repository | Scope, chosen values, registered exceptions, registers, worked examples |

**The project file wins where the two differ.** A skill that leaks a project's paths, service names
or chosen values has broken the split — those lines belong in the consuming repository's
`conventions/` file instead. The `conventions` skill documents the arrangement in full, including
what belongs in a project file versus in `architecture/`, `glossary/`, `instructions/`,
`proposals/` or `requirements/`.

The five `prototype-conventions` skills divide as: four per-stack (`frontend`, `infrastructure`,
`lambdas-go`, `lambdas-node`) and one per-document-kind (`product-requirements`). The conventions
skills in `utils` are `api-design` and `mysql`, neither tied to prototypes. The four
`documentation-and-planning` skills are one meta-skill (`conventions`), `documentation` (which also
carries the markdown rules every document follows, such as the table of contents), `plan-of-action`
and `glossary`.

`api-design` was briefly its own `api-conventions` plugin, on the reading that rules independent of
any stack were a different scope. It was merged back before it shipped: API design is architecture,
and the split between conventions plugins is by subject, not by stack. `documentation`,
`plan-of-action` and `glossary` went the other way at `arc-conventions` 0.12.0: rules about writing
documents and planning work are a different subject from how software is built, and a project can
want them without any of the stack skills. `conventions` followed at 0.13.0: recording a project's
rules is itself a document-writing subject, and the meta-skill serves both plugins equally.
`product-requirements` stayed, as the per-document-kind skill closest to the software it specifies.
When the plugin was renamed `prototype-conventions` at 0.14.0 and given its prototype-only scope at
0.15.0, `mysql` moved to `utils`, since its rules are general rather than prototype-specific, and
`api-design` followed at 0.16.0 for the same reason. `plan-of-action` is the one that also carries a
procedure — implementing the plan, stage by stage — and it lives beside `documentation` rather than
in `utils` because the document and its execution are the same subject, and both are meaningless
without the `proposals/` layout the `documentation` skill defines.

Skills cross-reference each other by name in a `## Related` section rather than duplicating rules —
`lambdas-node` defers to `lambdas-go` for the shared trigger-naming rules, and both defer to
`conventions` for precedence. Cross-plugin references work the same way, and are common:
`api-design`, in `utils`, names the `documentation` skill for the OpenAPI file, and every
conventions skill, whichever plugin it is in, defers to `conventions` for precedence. A skill that
may be installed without the plugin it names says so — "where installed" — so a missing reference
reads as optional rather than broken. `auto-summary-commit` names the `conventions` skill for a
project's commit-message style, and falls back to reading the style off `git log` when it is not
installed.

## The auto-summary-commit hooks

`plugins/utils/hooks/` is the only executable code here. One script,
`auto-summary-commit.sh`, runs in two modes registered by `hooks.json`:

| Event | Mode | Does |
| --- | --- | --- |
| `UserPromptSubmit` | `pre` | Writes a fingerprint of every dirty path to `$TMPDIR/claude-auto-summary-commit-<session>.pre`. Must print nothing — this event's stdout becomes model context |
| `Stop` | `stop` | Fingerprints again, diffs against the baseline, and emits `hookSpecificOutput.additionalContext` naming this session's uncommitted paths |

Session state lives in `$TMPDIR/claude-auto-summary-commit-<session id>.*` — `.pre` (baseline),
`.nudged` (last-raised fingerprint), `.deferred` (carried-forward paths), `.prompt` (the turn's
prompts, verbatim, for the commit body), `.turnopen` (a turn is in progress) and `.off` (the
switch).

These properties are load-bearing, and a change that breaks any of them will loop, wedge a session
or produce a mis-attributed commit:

- **It feeds back via `hookSpecificOutput.additionalContext`, not top-level `decision: "block"`.**
  The Stop schema names the former "Feedback for the model; the conversation continues so the
  model can act on it". `decision`/`reason` is the legacy field: it works, but Claude Code routes
  it through the blocking-error path, so the user sees every nudge rendered as
  `Stop hook error: ...`
- **It raises any given tree state at most once**, recorded in `<session>.nudged`, and bails on
  `stop_hook_active`. Feeding the same state back repeatedly means the turn can never end —
  including when the user has just declined and the tree is *meant* to stay dirty. The fingerprint
  guard is the durable one: `stop_hook_active` only covers the immediate continuation
- **Fingerprints are content hashes, not status codes.** A file already modified before the turn
  and modified again during it keeps the same ` M` code throughout; comparing codes would file it
  under "not this turn's work" and drop it from the commit
- **Deferred work is carried forward, but never interrupts on its own.** A "not yet" writes its
  paths to `<session>.deferred`; later turns fold those back in so the eventual commit covers all
  of it, and entries drop out once they stop being dirty. A turn that changed nothing stays silent
  even with deferrals outstanding — otherwise a single "not yet" would nag for the rest of the
  session
- **The hook never decides whether to ask the user.** It says "run the skill" and lists the
  paths; whether that ends in a straight commit (the default) or a four-option question (only
  when something is majorly wrong or an open question blocks the prompt's purpose) is the skill's
  call. Putting that decision in the hook would mean encoding a judgement about prose in bash
- **The message stays short, and never restates the skill.** Whatever the hook emits is printed
  to the user verbatim as `Stop hook feedback: ...`, and a long one is truncated mid-sentence in
  the terminal. It carries only what the skill cannot work out for itself — the path list and the
  state-file paths — and leaves the procedure to `SKILL.md`. An earlier version inlined step 3's
  four options and drifted out of sync with the skill twice before this rule existed
- **Only the first prompt of a turn moves the baseline**, gated on `.turnopen`. A message sent
  mid-turn fires `UserPromptSubmit` again; re-snapshotting there folds the work already done into
  the baseline and drops it from the commit. `.turnopen` is cleared at the top of `stop` mode,
  before any early exit, because every path through it ends the turn
- **A missing baseline means silence, not a guess.** Without the `pre` file there is no way to tell
  the turn's work from what was already there, and a commit that claims to be the turn's work and
  is not costs more than a missed commit
- **It depends on nothing but `git` and shell builtins.** `jq` is used when present, hand-rolled
  JSON escaping covers its absence, and the set comparison is bash string matching rather than
  `sort`/`comm` — macOS ships bash 3.2, so no associative arrays either. A hook that fails on a
  thin `PATH` fails at the end of every single turn

Test it by piping payloads in, `pre` first and then `stop`, against a scratch repo:

```bash
echo '{"session_id":"t","cwd":"'$REPO'"}' | bash plugins/utils/hooks/auto-summary-commit.sh pre
echo '{"session_id":"t","stop_hook_active":false,"cwd":"'$REPO'"}' | bash plugins/utils/hooks/auto-summary-commit.sh stop
```

A prompt is captured only when `jq` is present — the fallback parser cannot survive the newlines
and quoting in real prompt text, and a mangled prompt in a commit body is worse than no prompt at
all, so `pre` writes nothing rather than something wrong.

These must all produce no output at all: a turn that changed nothing, a turn that only touched
gitignored files, a turn that edited a file and reverted it, a tree dirtied before the baseline was
taken, a missing baseline, a missing `session_id`, a non-git directory, mid-rebase,
`stop_hook_active: true`, and a second `stop` over an unchanged tree. A turn that edited a file
which was *already* dirty must be caught. Every emission must be a single valid JSON object on
stdout with nothing on stderr — anything on stderr is reported to the user as a hook error.

## Writing Skills

The rules in the README's "Adding to a skill" section are binding here:

- **The `description` is a trigger, not a summary.** It is the only part always in context, so it
  must carry the words, file types and questions that should cause the skill to load. A vague
  description means the skill never fires and the convention is silently not followed
- **Prefer a new `reference/*.md` over a new skill.** Every skill's description competes for
  trigger match, so splitting a topic into reference files is cheaper than splitting it into
  skills. A reference file that no `SKILL.md` names by filename is dead weight
- **Record the reasoning, preferring the concrete failure that motivated the rule** over an
  abstract justification. A bare rule gets deleted the first time it is inconvenient
- **Correct in place and say it was corrected** — what the rule used to say and why the old version
  failed. Never silently rewrite; code written under the old rule was written in good faith, and
  the old failure is usually why the new rule is shaped as it is
- Prose wraps at 100 columns; tables and code blocks run long

Every `prototype-conventions` `SKILL.md` also **opens**, straight after its `#` title, with the same
prototype-only note: check the project is a prototype or proof of concept, ask when nothing says,
and for a project that is not one, offer to add `"prototype-conventions@stefs-plugins": false` under
`enabledPlugins` in its `.claude/settings.json`. The note is identical in all five, so a change to
it is made to all five at once; a new skill in that plugin copies it verbatim, and its frontmatter
`description` ends "Prototype and proof-of-concept projects only — not for production." The plugin
description is not in context when a skill fires, so the warning cannot live only there.

Every `prototype-conventions` and `documentation-and-planning` `SKILL.md` closes with the same two
sections, and a new skill should keep the shape: a `## References` section listing each
`reference/*.md` with a one-line note on what it holds (skills with no `reference/` directory omit
it), then `## Related` naming the sibling skills that carry adjacent rules. `lambdas-node` is the
one skill with a reference file but no `## References` section — it names the file inline instead.

## History

This repository replaces two separate marketplaces, one per plugin:
[`claude-arc-conventions`](https://github.com/tedslittlerobot/claude-arc-conventions) (marketplace
`arc-conventions`) and [`claude-utils`](https://github.com/tedslittlerobot/claude-utils)
(marketplace `claude-utils`). Both are superseded by `stefs-plugins`; the old install commands no
longer describe how these plugins are distributed.

Both plugins were renamed at the same time. `claude-utils` became `utils`, taking its command
namespace with it: `/claude-utils:<name>` is now `/utils:<name>`. `conventions` became
`arc-conventions`, narrowing the name to the architecture scope it actually covers so that a
later conventions plugin with a different focus has a name available to it. Skill names were left
alone in both renames — a project `conventions/` file names skills, not plugins, and renaming the
`conventions` skill would have broken every one of those files for no gain.

`arc-conventions` was renamed again, to `prototype-conventions`, at 0.14.0 — after
`documentation`, `plan-of-action`, `glossary` and `conventions` had moved out to
`documentation-and-planning` (at 0.12.0 and 0.13.0, the version numbers `arc-conventions` carried
then). Skill names were again left alone. A plugin rename is a new plugin as far as an installation
is concerned: the old name drops out of the marketplace, and a consumer uninstalls
`arc-conventions` and installs `prototype-conventions@stefs-plugins`.

Anything still referring to the old plugin names or command namespace is stale, with the exception
of the paragraphs above and the version-cache example under "Bump the plugin version", which
records the cache path as it was.

## Other Agent Configs

An OpenAI Codex config exists at `~/.codex/`. To import its user-level MCP servers, slash commands,
subagents, skills or instructions into Claude Code, reply `/import` to scan and list what's
importable, then `/import --yes=<digest>` to apply it.
