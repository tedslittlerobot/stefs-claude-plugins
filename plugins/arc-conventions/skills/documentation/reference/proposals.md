# Proposals

A **Proposal** is a design put forward *before* it is built. It is the third kind of document in the
repository, distinguished from the other two by tense:

| Directory | Tense | Answers |
| --- | --- | --- |
| `architecture/` | present | what **is** built |
| `instructions/` | imperative | how a **human** sets up, wires up or tests what is built |
| `proposals/` | future/conditional | what **could** be built, and why that shape |

**Nothing in `proposals/` describes the system as it stands, so it must never be read as a
statement of fact about it.**

## Layout

One directory per proposal, **named for the proposal rather than for the feature it touches**, so
several proposals may address the same service without colliding:

```
proposals/<proposal-slug>/
  proposal.md                       # the proposal itself — always this filename
  plan-<iteration>-<description>.md # Plan of Action stages — see the `plan-of-action` skill
  proposal--<section-slug>.py       # diagram scripts (see reference/diagrams.md)
  proposal--<section-slug>.png      # their rendered output, embedded in proposal.md
  <supplementary>.md                # any number of supporting documents
```

- **`proposal.md` is always the entry point**, whatever the proposal is called. The directory name
  carries the identity; the filename stays predictable so a reader never has to guess
- **Diagrams follow the same conventions as everywhere else** — Mingrammer Diagrams for
  architecture/infrastructure and flow, MermaidJS `erDiagram` for data models, rendered to a PNG and
  embedded. The `<source-filename-without-ext>--<section-slug>` pattern makes them
  `proposal--<section-slug>.png`
- **Supplementary documents** carry material that would swamp the proposal itself — worked examples,
  payload samples, comparisons of rejected options. Name them for their content, keep them in the
  same directory, and **link them from `proposal.md`** so the entry point remains a complete index

## Content

A proposal must open with a **status line** saying plainly that it is a proposal, and what (if
anything) it supersedes. A reader who has landed on it out of context needs to know within one
sentence that they are not reading a description of the system.

Beyond that, a proposal is expected to record its own reasoning, because that is the part which
cannot be recovered later from the code:

- **Rejected options, and why.** The most valuable content in a proposal is usually why the obvious
  approach was *not* taken. What was built is legible from the code; what was ruled out is legible
  from nowhere else
- **Decisions, with the argument that settled them** — including ones later reversed, which is far
  cheaper to record than to re-derive
- **Outstanding questions, grouped by what each needs** rather than by topic: a decision before
  building, a confirmation of an assumption the proposal already makes, or nothing yet because it is
  knowingly deferred. **Say explicitly which of them block work and which do not** — an
  undifferentiated question list stalls the whole proposal on its least important item
- **Impact on what exists today**, naming the files and resources the proposal would change or
  remove

## Writing a Proposal

Two rules govern the act of writing one, as distinct from what the finished document contains.

### Evaluate each input before recording it as a decision

**Everything put forward for the proposal is weighed before it is written down as decided** — a
suggestion from the user, a line lifted from a ticket or a requirements file, an approach carried
over from another document, and the writer's own first idea alike. For each one, ask:

- does it actually solve the problem the proposal states, or a neighbouring one?
- what does it cost — in complexity, in migration, in what it rules out later?
- what does it conflict with — the system as `architecture/` describes it, the project's
  `conventions/`, another decision already recorded in this proposal?
- what is the obvious alternative, and why is this better than it?

**If it holds up, record it with that argument.** If it does not, **say so to the user before
recording anything** — name the concern, and the alternative if there is one. Do not record it as
decided and move on, and do not quietly substitute a different decision; the user makes the call.
If they keep it over the objection, record the decision *and* the objection, so the next reader
sees that the risk was known and accepted rather than missed.

The reason is downstream. A settled proposal is turned into a Plan of Action that is written
*without relitigating the design* (see the `plan-of-action` skill), so a decision that was only
transcribed becomes an instruction that nobody ever examined. And a decision whose only argument is
"it was asked for" fails the content rule above — *decisions, with the argument that settled them*
— because there is no argument to record.

### Write nothing outside the proposal's directory without asking

**While writing a proposal, every file written is inside `proposals/<proposal-slug>/`.** Code,
`architecture/`, `instructions/`, `glossary/`, `conventions/`, `requirements/`, READMEs,
configuration and other proposals are all out of bounds until the user has confirmed the specific
change. Reading them is expected — a proposal cannot be evaluated against a system nobody looked
at — but writing to them is not.

When the proposal implies a change elsewhere, **record it in the proposal and ask**, rather than
making it:

- a change the design would make goes under *Impact on what exists today*
- a new term goes in the proposal's own prose, with its glossary entry listed as a follow-up —
  not added to `glossary/`, which describes vocabulary the system already has
- a stale or wrong document spotted along the way is noted, and raised with the user, not fixed in
  passing

**Several proposals may be in progress at once, written by different agents in the same working
tree.** A proposal's directory belongs to that proposal alone, so writes inside it cannot collide;
everything outside it is shared ground. An edit there can clash with another agent's edit to the
same file, be overwritten by it, or be swept into that agent's commit as if it were its work. The
same applies to committing: **stage the proposal's paths by name**, never `git add -A` or
`git add .`, because the tree holds other agents' unfinished files.

It is also the tense rule applied to writing. A proposal is conditional; editing `architecture/` or
the code to match it makes the present tense describe something that has not been decided, let
alone built.

## The Plan of Action

Once a proposal's design is settled, it is turned into a **Plan of Action** before any of it is
built: a staged implementation plan written for an AI agent to carry out, one
`plan-<iteration>-<description>.md` file per stage in the proposal's own directory, linked in order
from `proposal.md`.

**The `plan-of-action` skill governs it** — the stage naming, where the boundaries go, what a stage
file contains and how one is implemented. This skill covers only the proposal.

## Lifecycle

A proposal is a **living document while its design is under discussion**, and is edited in place as
decisions land — an outstanding question becomes a recorded decision rather than being deleted. The
record of how the design moved is part of the value.

Once a proposal is built:

- the description of what now exists belongs in `architecture/`
- the operational side belongs in `instructions/`
- **the proposal itself stays where it is**, as the record of why the design is the shape it is. It
  is not deleted and not moved. **Its Plan of Action stages stay with it**, as the record of the
  order the work was actually done in
- **its status line is updated** to say it has been implemented, and to point at the documentation
  that now describes the real thing

That last step is the one that gets missed, and missing it is exactly how a proposal comes to be
mistaken for a description of production.
