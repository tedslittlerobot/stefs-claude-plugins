---
name: product-requirements
description: Writing user requirements — what counts as a user-level feature versus a system one, one requirement per file grouping related user stories, the required sections (Dependencies, Risk Assessment, User Stories with Gherkin stories and acceptance criteria, Test Coverage notes, Light Risk Assessment, Caveats). Use when writing or editing a requirement or user story, adding acceptance criteria, updating test-coverage notes after adding tests, or doing a risk assessment.
---

# User Requirements

Requirements live in a **`requirements/`** directory at the repository root, one markdown file per
requirement.

## What Counts as a User Requirement

A User Requirement is a **user-level feature** — something a **human** (a platform user, not a
system or another service) directly does or experiences: logging in, viewing a specific page,
resetting a password.

**System-level features are not user requirements and must not be documented here** — creating a
database table, provisioning a queue, an internal refactor. Those belong in `architecture/`.

The test is whether a person could describe it without naming a component. If the description needs
the word "queue" or "table", it is not a user requirement.

## File Layout

- **One requirement per markdown file**, in `requirements/`
- **Filename is a kebab-case slug of the title** — `user-resets-forgotten-password.md`
- **A requirement is a group of related User Stories**, and each User Story is a **section within
  the requirement file**, not a separate file

## Required Sections

Every requirement file contains, in order:

1. **Title** — fewer than 100 characters
2. **Dependencies**
3. **Risk Assessment** — requirement-level
4. **User Stories** — at least one, each with its own Title, Story, Acceptance Criteria, Light Risk
   Assessment and Caveats

The exact format of each is in **`reference/format.md`**. A complete worked example is in
**`reference/example.md`** — read it before writing a first requirement, since the nesting of
sections is easier to copy than to describe.

## The Two Rules That Get Broken

**1. Stories are end-user focused.** The Gherkin `As a … / I want to … / So that …` must never be
phrased in terms of internal systems or components. A story whose actor is a service is a design
note wearing a story's clothes.

**2. Every Acceptance Criterion carries a Test Coverage note, kept current.** Each AC is immediately
followed by a note stating how much of it — and which specific parts, if not all — is exercised by
automated tests, **naming the covering tests**. If nothing covers it, the note says exactly
**Entirely uncovered by unit testing**.

Where coverage is **incidental** — a test written against another AC that also happens to exercise
part of this one — **say so, name which AC it comes from, and say how much of this AC it accounts
for**, rather than implying a dedicated test exists. This is the honesty that makes the notes worth
having: a requirement file that overstates coverage is worse than one with no notes at all.

**Update these notes as tests are added, removed or renamed** — including when the change is to the
tests rather than to the requirement.

## Risk Assessment

Risk is assessed at **two levels**:

- **Requirement-level** (`## Risk Assessment`) — the aggregate: Score, Assessment, Mitigations,
  Treatment Plan
- **Story-level** (`#### Light Risk Assessment`) — per User Story, one subsection per risk category

Both use the same three 1–9 ratings: **Risk Severity**, **Risk Likelihood** and **Risk
Detectability**. Note the direction of the third: **1 = would likely go unnoticed, 9 = easy to
detect** — so, unlike the other two, a *low* score is the worse one. This is easy to get backwards.

**Every risk category is covered for every story, even when it carries no risk** — a category with
nothing to say states exactly **No risk identified** and nothing else. The categories are a
checklist, and a silently omitted one is indistinguishable from one that was never considered.

The **category list itself is domain-specific.** The default set in `reference/format.md` is drawn
from clinical/medical software; a project in another domain records its own list in
`conventions/requirements.md` and that list wins.

## References

- **`reference/format.md`** — the exact format of every section: Dependencies, both Risk
  Assessments, Story, Acceptance Criteria, Test Coverage, Caveats, and the default risk categories
- **`reference/example.md`** — a full worked requirement file

## Related

- `documentation` skill — `architecture/` (where system-level features go), `instructions/` and
  `proposals/`
- `glossary` skill — linking a term on first use rather than defining it in a requirement
- `conventions` skill — where a project records its own risk-category list
