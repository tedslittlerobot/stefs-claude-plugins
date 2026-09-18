---
name: documentation
description: How to write the project's markdown documents and which context each belongs in — architecture/ for what IS built, instructions/ for what a human does, proposals/ for what could be built, plus API overview documents, Lambda and shared-library READMEs, and the Mingrammer/MermaidJS diagram conventions. Use when writing or editing any markdown document, deciding where a document belongs, adding a README or api.md, writing a proposal, or creating an architecture or ER diagram.
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

## References

Load the reference file for the specific document type being written:

- **`reference/api-docs.md`** — OpenAPI (OAS 3.1) files, and the structure of an
  `architecture/<service>/api.md` overview document
- **`reference/readmes.md`** — the required four-section format for a Lambda `README.md` and for a
  shared-library `README.md`
- **`reference/proposals.md`** — the layout, required content and lifecycle of a proposal
- **`reference/diagrams.md`** — Mingrammer Diagrams for architecture/infrastructure/flow diagrams,
  MermaidJS `erDiagram` for data models, and the shared PNG naming pattern

## Related

- `conventions` skill — what belongs in `conventions/` rather than in a document here
- `glossary` skill — where a term's meaning is recorded
- `lambdas-go` / `lambdas-node` skills — the `schema.md` that accompanies every Lambda `README.md`
- `product-requirements` skill — `requirements/`, which is governed separately
