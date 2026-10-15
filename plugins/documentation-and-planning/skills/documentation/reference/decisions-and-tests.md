# Decisions and Assumption Tests

A proposal records two kinds of working material in files of their own rather than in
`proposal.md`: **decisions**, under `decisions/`, and **assumption tests**, under `tests/`. Each
gets an ID, each is summarised in one line in `proposal.md`, and each file carries the full
argument or evidence. The layout and the reason for it are in `reference/proposals.md`; this file
is the IDs, the lifecycle and the contents.

```
proposals/<proposal-slug>/
  proposal.md
  decisions/
    outstanding/D4-how-long-an-invitation-lasts.md
    resolved/D1-one-row-per-invitation.md
    resolved/D3-tokens-carry-the-study.md
    rejected/D2-a-separate-invitations-service.md
  tests/
    T1-cognito-tokens-fit-in-a-cookie.md
    T1-measure-token-size.sh
    T2-ses-sandbox-accepts-plus-addresses.md
```

## IDs

- **`D<n>` for a decision, `T<n>` for an assumption test**, each starting at 1 and counting up
  separately within the proposal — `D1`, `D2`, `D3`; `T1`, `T2`. No zero-padding: these are
  identifiers, not a sequence to be listed in order
- **The filename is the ID, a hyphen and a few words of kebab-case description** —
  `D3-tokens-carry-the-study.md`, `T1-cognito-tokens-fit-in-a-cookie.md`. The file keeps its name
  for life; a decision changing state moves directory, not name
- **An ID is never reused or renumbered**, including when a decision is rejected or a test turns
  out to be pointless. `proposal.md`, other decisions, plan stages and commit messages all cite
  these IDs, and renumbering one silently repoints every citation at the wrong thing. The next ID
  is one more than the highest that exists across all three `decisions/` subdirectories, or in
  `tests/`
- **Cite them by ID in prose, linked on first use in a section** — "see [D3](...)". Inside the
  proposal the bare ID is unambiguous; from outside it, qualify it with the proposal's name

## Decisions

### The three states

| Directory | Means |
| --- | --- |
| `decisions/outstanding/` | Not yet made. Every decision starts here |
| `decisions/resolved/` | Made: the proposal now holds an answer to it, and the file says what the answer is and why |
| `decisions/rejected/` | Will not be made as framed: the change it put forward was declined outright, it was ruled out of scope, another decision made it moot, or it was framed wrongly and replaced by a better-framed one |

**The test for resolved versus rejected is whether the proposal now holds an answer.** A decision
asking "which queue?" answered with "none — poll the table instead" is *resolved*: there is an
answer, it is just not one of the options first listed. A decision asking "should invitations move
to their own service?" that the user declines is *rejected*: the proposal goes on without the
change. A decision that turns out to be the wrong question is rejected, naming the decision that
replaced it.

**A decision moves with `git mv`, in the same change that updates its status line and its summary
line in `proposal.md`.** Moving the file breaks every link to its old path, so find them —
`grep -rn 'D4-' proposals/<proposal-slug>/` — and fix them in that same change. Prose that cites
the bare ID is unaffected, which is part of why the ID is in the filename.

**A reversed decision is a new decision.** Once `D3` is resolved, changing the answer is `D9`, in
`outstanding/`, saying which decision it would reverse and why; when it resolves, `D3`'s status
line is updated to say it was superseded by `D9`, and `D3` stays in `resolved/`. The original
argument and the reason it stopped holding are both part of the record, and editing `D3`'s answer
in place would lose the first.

**Plan of Action stages link only to resolved decisions**, because a plan is not written until the
proposal's blocking decisions are made (see the `plan-of-action` skill). Those links do not move:
a resolved decision stays in `resolved/`, even when superseded.

### What a decision file contains

```markdown
> **Status: Outstanding — blocks work.** Needed before the Plan of Action can be written.

**Contents**

- [D4: How long an invitation lasts](#d4-how-long-an-invitation-lasts)
  - [Context](#context)
  - [Options](#options)
  - [Recommendation](#recommendation)

# D4: How long an invitation lasts

## Context
```

- **A status line first**, then the contents (the `documentation` skill's "Table of Contents"
  rule), then the title. The status line is one of:
  - `**Status: Outstanding — blocks work.**` or `**Status: Outstanding — does not block work.**`,
    saying what it blocks or why it can wait. **Every outstanding decision says which.** The
    `plan-of-action` skill will not write a plan over a blocking one, and an undifferentiated list
    stalls the whole proposal on its least important item
  - `**Status: Resolved** — <the answer, in one line>.`, plus `Superseded by D9.` if it later is
  - `**Status: Rejected** — <why, in one line>.`, naming the replacement decision if there is one
- **The title is `D<n>: <the decision>`**, phrased as the question or the choice being made
- **Context** — what needs deciding, why now, and which parts of the proposal rest on it, linked.
  Any test it waits on, named by ID
- **Options** — each with what it costs, what it conflicts with and what it rules out later. The
  obvious option is always listed, even when it is not the one recommended; why it was not taken is
  usually the most valuable line in the file
- **Recommendation** — the writer's own, said as such, having weighed each input as
  `reference/proposals.md` requires. A recommendation is not a decision; the file stays in
  `outstanding/` until the user makes the call
- **Resolution** or **Rejection**, added when it moves — the answer or the reason, who made the
  call, and **the argument that settled it**. If the user chose against the recommendation, the
  objection stays recorded beside the choice, so a later reader sees the risk was known and
  accepted rather than missed

### The summary in `proposal.md`

`proposal.md` carries every decision as one line, grouped by state, outstanding first. A reader
should be able to follow the design from these lines alone and open a file only to see the
argument:

```markdown
## Decisions

**Outstanding**

- [D4](./decisions/outstanding/D4-how-long-an-invitation-lasts.md) — how long an invitation stays
  valid before it must be reissued. **Blocks work.**
- [D6](./decisions/outstanding/D6-backfill-existing-members.md) — whether existing members get
  invitation rows. Does not block: only stage 4 needs it.

**Resolved**

- [D1](./decisions/resolved/D1-one-row-per-invitation.md) — one row per invitation, not one per
  study, so a reissue keeps the history of the first.
- [D3](./decisions/resolved/D3-tokens-carry-the-study.md) — the study travels in the token's
  claims, not in a lookup at every request. Rests on [T1](./tests/T1-cognito-tokens-fit-in-a-cookie.md).

**Rejected**

- [D2](./decisions/rejected/D2-a-separate-invitations-service.md) — a separate invitations
  service. Rejected: one table and two endpoints do not justify a deploy pipeline of their own.
```

## Assumption Tests

**An assumption test is an experiment run while the proposal is being written**, to confirm or
refute something the design takes for granted — a query against real data, a call to a provider's
API, a measurement, a throwaway script, a spike. It exists because an assumption written into a
proposal becomes an instruction in the Plan of Action, and an agent implementing that plan has no
way to tell it from a fact. Finding out that a token is too large for a cookie costs an afternoon
during the proposal and a redesign halfway through the build.

**Test the assumptions that would change the design if they were wrong**, and that are cheap to
test relative to being wrong. Not every assumption earns one; one that the proposal leans its whole
shape on almost always does.

### What a test file contains

- **A status line first** — `**Status: Planned.**`, `**Status: Confirmed.**`,
  `**Status: Refuted.**` or `**Status: Inconclusive.**`, the last three each followed by the result
  in one line. Then the contents, then the title
- **The title is `T<n>: <the assumption, as a statement>`** — "Cognito ID tokens fit in a 4 KB
  cookie", not "Token size". Stated so that it can be false
- **Why it matters** — the parts of the design and the decisions that rest on it, linked by ID, and
  what would have to change if it were refuted
- **Method** — what was run, where, against what, ready to run again: the exact commands, the
  environment, the data. A test that cannot be repeated cannot be re-checked when the world changes
- **Result** — what was actually observed: the numbers, the output, the error. Not "it worked"
- **Conclusion** — what the result means for the proposal, the change it caused, and **what was not
  tested** — the staging table with a hundred rows that stands in for production's million, the
  sandbox account that stands in for the real one. A reader will otherwise assume the test covered
  more than it did

**A refuted assumption is not a failed test.** It is the most valuable result a test can return,
because it was found before anything was built on it. Keep the file, mark it refuted, and change
the proposal — usually by opening a decision, or reopening one, that names the test.

**Tests do not move between directories as decisions do.** A test's result is a fact about what
was observed, and the status line carries it; the file stays at `tests/T<n>-...md` whatever it
found.

### Supporting files

**Whatever a test needs to run lives in `tests/`, prefixed with its ID** —
`T1-measure-token-size.sh`, `T1-sample-claims.json`, `T1-output.txt`. The prefix keeps a test's files together in the listing
and makes it obvious which test a stray file belongs to, and keeping them in the proposal's
directory is the rule that a proposal writes nothing outside it.

**Running a test does not license changing shared things.** Reading is expected; but a test that
writes to a shared environment, creates cloud resources, costs money or needs credentials the agent
does not have is raised with the user before it is run — or written as a human step, with the
commands ready to paste, as the `plan-of-action` skill describes. A test exists to reduce risk, and
one that leaves resources behind or changes data someone else depends on has added some.

### The summary in `proposal.md`

```markdown
## Assumption Tests

- [T1](./tests/T1-cognito-tokens-fit-in-a-cookie.md) — Cognito ID tokens fit in a 4 KB cookie with
  the study claims added. **Confirmed**: 2.9 KB measured with ten custom attributes. Rests on it:
  [D3](./decisions/resolved/D3-tokens-carry-the-study.md).
- [T2](./tests/T2-ses-sandbox-accepts-plus-addresses.md) — SES in sandbox delivers to `+`-tagged
  addresses. **Planned.**
```
