---
name: documentation
description: How to write the project's markdown documents and which context each belongs in — architecture/ for what IS built, instructions/ for what a human does, proposals/ for what could be built, the table of contents every markdown file must keep up to date, plus API overview documents, Lambda and shared-library READMEs, and the Mingrammer/MermaidJS diagram conventions. Use when writing or editing any markdown document, adding, renaming or removing a heading, adding or updating a table of contents, deciding where a document belongs, adding a README or api.md, writing a proposal or recording a decision in one, evaluating a suggested design, or creating an architecture or ER diagram.
---

# Documentation Conventions

Applies to every markdown document in the repository outside `conventions/`, `glossary/` and
`requirements/` — which have their own skills (`conventions`, `glossary`,
`product-requirements`) — and to documentation embedded in other files.

## The Three Tenses

The single most important distinction. Three directories, told apart by tense:

| Directory | Tense | Answers |
| --- | --- | --- |
| `architecture/` | present | what **is** built |
| `instructions/` | imperative | how a **human** sets up, wires up or tests what is built |
| `proposals/` | future/conditional | what **could** be built, and why that shape |

**Nothing in `proposals/` describes the system as it stands, and it must never be read as a
statement of fact about it.** That is the whole reason the directory is separate: a design under
discussion and a description of production are dangerous to confuse in either direction — someone
implements a proposal believing it is already built, or someone reads a proposal's rejected option
as the current design.

Getting the tense wrong is the commonest documentation fault. Before writing, decide which of the
three questions the document answers, and put it in the matching directory.

**Writing a proposal has two further rules**, set out in full in `reference/proposals.md`:

- **Evaluate each input before recording it as a decision.** A suggestion — the user's, a
  ticket's, or your own — is weighed against the problem, its cost and what it conflicts with; if
  it does not hold up, say so to the user before recording anything
- **Write nothing outside `proposals/<proposal-slug>/` without asking.** Several proposals may be
  written at once by different agents in the same tree, so everything outside the proposal's own
  directory is shared ground. A change the proposal implies elsewhere is recorded in it and raised
  with the user, not made

## Structure

```
architecture/
  overview.md                              # top-level architecture
  <service>/infrastructure.md              # infrastructure, per service
  <service>/api.md                         # the service's HTTP surface — see reference/api-docs.md
  <service>/authorization.md               # the authorisation model, where the service has one
  <service>/data-design-mysql.md           # MySQL data design, per service
  <service>/data-design-dynamo.md          # DynamoDB data design, per service
  <service>/<other>.md                     # other per-service documentation
  <service>/<feature>/overview.md          # documentation of one specific feature
instructions/
  <topic>.md                               # a process a human follows
  setup/<topic>.md                         # first-time setup tasks specifically
proposals/
  <proposal-slug>/proposal.md              # a design not yet built
  <proposal-slug>/plan-<n>-<desc>.md       # its Plan of Action — `plan-of-action` skill
glossary/                                  # governed by the `glossary` skill, not this one
```

- **`instructions/<topic>.md`** is written in the **imperative, addressed to the person at the
  keyboard** — processes, CLI commands and step-by-step sequences for setting something up, wiring
  two services together, or testing by hand. Distinct from `architecture/`, which documents what is
  built rather than how to operate it
- **`instructions/setup/<topic>.md`** is the same thing for first-time setup specifically (sending a
  test email, rotating credentials)
- **`architecture/<service>/authorization.md`** documents the authorisation model where a service
  has one: the policy namespace, the full schema, and tables of every entity type, action, policy
  and resource entity. It is the specification a reader consults instead of reading policy files
  and handler code, and it complements `api.md` — which says *whether* an endpoint is guarded rather
  than what the guard is made of

## General Writing Rules

- **Link a term to its glossary entry on first use in a document's prose**, and never restate a
  definition — see the `glossary` skill
- **Every path is repository-root-relative.** A reader arrives at a document from anywhere; a path
  relative to "here" is ambiguous the moment the document is quoted elsewhere
- **Record the reasoning, not just the outcome.** The shape of the system is legible from the code;
  why it is that shape is legible from nowhere else. This applies hardest to decisions that look
  arbitrary and to constraints imposed from outside (a provider's validation rule, an AWS API
  limit)
- **Name the failure.** When a document exists because something went wrong, describe what went
  wrong concretely. A reader who recognises the symptom finds the document; a reader given only the
  abstract rule does not
- **Say what a thing deliberately is not.** Boundaries are what readers get wrong
- **Correct in place, and say it was corrected.** When a document is superseded by new
  understanding, say what it used to claim and why that was wrong, rather than silently rewriting

## Table of Contents

**Every markdown document keeps an up-to-date table of contents** listing its headings, each
linked to the heading it names. That is every document, not just the long ones: architecture
documentation, `api.md` overviews, Lambda `schema.md` files, READMEs, instructions, proposals and
Plan of Action stage files — and the files whose format another skill defines (conventions files,
glossary entries, requirements), which follow this rule as well as their own template.

Documents are read out of order: someone arrives from a link wanting one section, and an agent
opening a file reads its top first. The contents tell both what the document covers and where,
without reading it. A hosting platform's generated outline does not help in an editor, a terminal
or a raw-file read, which is where most of these documents are read.

### Where it goes

**Before the document's first heading.** The only things that may come above it are:

- a **pre-amble or introduction** — a paragraph or two of opening content that is not under a
  heading
- in a **proposal or Plan of Action stage file**, the **status box** — the status line or status
  header blockquote that must open those files — with the contents straight after it

So a document reads status box (where it has one), then any introduction, then the contents, then
its first heading. Because the contents sit above the first heading, they have **no heading of
their own** — a `## Contents` heading would itself be the first heading. Mark them with a bold
`**Contents**` line instead.

### What it lists

- **Every H1, always.** A document's title is in its own contents
- **Every major section.** Below H1, which levels are listed is a decision for each document: a
  short document lists every heading, a long one may leave out small subsections that would bury the
  sections a reader is looking for. The test is whether a reader scanning the contents would find
  the part they came for
- **If in doubt, list all H1 and H2 headings**
- Nest the list to match the heading levels, and give each entry the heading's text exactly

```markdown
> **Status: Proposal** — not yet built. Supersedes nothing.

**Contents**

- [Study Invitations](#study-invitations)
  - [Problem](#problem)
  - [Design](#design)
  - [Rejected Options](#rejected-options)
  - [Outstanding Questions](#outstanding-questions)

# Study Invitations

## Problem
```

### Keeping it up to date

- **Update the contents in the same change that adds, renames, moves or removes a heading.** A
  renamed heading changes its anchor, so the old link silently stops working — it still looks
  right, and only fails when someone clicks it
- **Links use the GitHub heading-anchor slug**: the heading lowercased, punctuation other than
  hyphens removed, spaces turned into hyphens — `## Rejected Options` is `#rejected-options`,
  `### GET /api/me/profile` is `#get-apimeprofile`. A heading repeated in one document gets `-1`,
  `-2` and so on after the first
- Before finishing an edit, check both directions: every link in the contents points at a heading
  that exists, and every heading the document chose to list is in the contents

## References

Load the reference file for the specific document type being written:

- **`reference/api-docs.md`** — OpenAPI (OAS 3.1) files, and the structure of an
  `architecture/<service>/api.md` overview document
- **`reference/readmes.md`** — the required four-section format for a Lambda `README.md` and for a
  shared-library `README.md`
- **`reference/proposals.md`** — the layout, required content and lifecycle of a proposal, and the
  rules for writing one: evaluating inputs, and staying inside its directory
- **`reference/diagrams.md`** — Mingrammer Diagrams for architecture/infrastructure/flow diagrams,
  MermaidJS `erDiagram` for data models, and the shared PNG naming pattern

## Related

- `conventions` skill — what belongs in `conventions/` rather than in a document here
- `api-design` skill — how the API an OAS file and `api.md` describe should itself be shaped:
  URLs, payloads, list endpoints, errors and status codes
- `plan-of-action` skill — the staged plan a settled proposal becomes, and how it is implemented
- `glossary` skill — where a term's meaning is recorded
- `lambdas-go` / `lambdas-node` skills — the `schema.md` that accompanies every Lambda `README.md`
- `product-requirements` skill — `requirements/`, which is governed separately
