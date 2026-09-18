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

## Lifecycle

A proposal is a **living document while its design is under discussion**, and is edited in place as
decisions land — an outstanding question becomes a recorded decision rather than being deleted. The
record of how the design moved is part of the value.

Once a proposal is built:

- the description of what now exists belongs in `architecture/`
- the operational side belongs in `instructions/`
- **the proposal itself stays where it is**, as the record of why the design is the shape it is. It
  is not deleted and not moved
- **its status line is updated** to say it has been implemented, and to point at the documentation
  that now describes the real thing

That last step is the one that gets missed, and missing it is exactly how a proposal comes to be
mistaken for a description of production.
