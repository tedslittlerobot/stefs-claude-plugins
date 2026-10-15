# Decisions and Assumption Tests

A proposal records two kinds of working material in files of their own rather than in
`proposal.md`: **decisions**, under `decisions/`, and **assumption tests**, under `tests/`. Each
gets an ID and a file of its own that opens with a **status box**. Each directory also has a
**summary file**, `decisions/decisions.md` or `tests/tests.md`, with one row per file. `proposal.md`
links the summary files and gives counts, but it never repeats the lists. The layout, and why it is
laid out this way, is in `reference/proposals.md`. This file covers the IDs, the status boxes, the
summary files and what each file contains.

```
proposals/<proposal-slug>/
  proposal.md
  decisions/
    decisions.md                          # the summary: every decision, its status
    D1-one-row-per-invitation.md
    D2-a-separate-invitations-service.md
    D3-tokens-carry-the-study.md
    D4-how-long-an-invitation-lasts.md
  tests/
    tests.md                              # the summary: every test, its status
    T1-cognito-tokens-fit-in-a-cookie.md
    T1-measure-token-size.sh
    T2-ses-sandbox-accepts-plus-addresses.md
```

## IDs

- **`D<n>` for a decision, `T<n>` for an assumption test**, each starting at 1 and counting up
  separately within the proposal — `D1`, `D2`, `D3`; `T1`, `T2`. No zero-padding: these are
  identifiers, not a sequence to be listed in order
- **The filename is the ID, a hyphen and a few words of kebab-case description** —
  `D3-tokens-carry-the-study.md`, `T1-cognito-tokens-fit-in-a-cookie.md`. **The file never moves
  and never changes name**, whatever happens to its status, so every link to it holds for the
  life of the proposal
- **An ID is never reused or renumbered**, including when a decision is rejected or a test turns
  out to be pointless. `proposal.md`, other decisions, plan stages and commit messages all cite
  these IDs, and renumbering one silently repoints every citation at the wrong thing. The next ID
  is one more than the highest in the directory
- **Cite them by ID in prose, linked on first use in a section** — "see [D3](...)". Inside the
  proposal the bare ID is unambiguous; from outside it, qualify it with the proposal's name

## The summary files

`decisions/decisions.md` and `tests/tests.md` work the same way, and the `plan-of-action` skill's
`plan-of-action/plan.md` follows the same pattern for stages:

- **One table with one row per file, in ID order.** A new row goes at the bottom, and a row never
  moves when its status changes. The columns are the ID (linked to the file), a one-line summary,
  and the status. A reader scanning the table sees where everything stands without opening a file
- **A counts line above the table**: how many there are and how they split by status, saying how
  many outstanding decisions block work. This is the line `proposal.md` copies
- **The file's status box is the source of truth.** The summary row and the counts are copies of
  it, so they are updated **in the same change as the status box**, along with the counts in
  `proposal.md`. If they ever disagree, the file wins and the summary is corrected
- **The summary is a status line, not the argument.** Keep it to a phrase that a reader can follow
  the design from, and leave the reasoning to the file

### What `proposal.md` carries instead

**`proposal.md` does not repeat the lists.** It links each summary file and gives the counts, and
it names by ID only what a reader of the proposal must act on, which is a decision that blocks
work:

```markdown
## Decisions and Tests

**Decisions:** four — one outstanding, which blocks work ([D4](./decisions/D4-how-long-an-invitation-lasts.md));
two resolved; one rejected. See [`decisions/decisions.md`](./decisions/decisions.md).

**Assumption tests:** two — one confirmed, one planned. See [`tests/tests.md`](./tests/tests.md).
```

A design section that rests on a decision or a test still names its ID inline, linked, so the
dependency is visible where it matters. That is a reference, not a list, and it is what lets
`proposal.md` stay short without hiding what the design depends on.

**Corrected:** `proposal.md` used to carry every decision and test as a one-line summary, grouped
by state. That put a second copy of each list in the file every reader opens first, so the list
grew with the proposal, which is exactly the clutter the separate files were meant to remove.

## Decisions

### The states

| Status | Means |
| --- | --- |
| **Outstanding** | Not yet made. Every decision starts here, and says whether it blocks work |
| **Resolved** | Made: the proposal now holds an answer to it, and the file says what the answer is and why |
| **Rejected** | Will not be made as framed: the change it put forward was declined outright, it was ruled out of scope, another decision made it moot, or it was framed wrongly and replaced by a better-framed one |

**The test for resolved versus rejected is whether the proposal now holds an answer.** A decision
asking "which queue?" answered with "none — poll the table instead" is *resolved*: there is an
answer, it is just not one of the options first listed. A decision asking "should invitations move
to their own service?" that the user declines is *rejected*: the proposal goes on without the
change. A decision that turns out to be the wrong question is rejected, naming the decision that
replaced it.

**A status change is an edit, not a move.** It updates the decision's status box, its row in
`decisions/decisions.md`, and the counts in `proposal.md`, all in one change.

**Corrected:** decisions used to live in `decisions/outstanding/`, `decisions/resolved/` and
`decisions/rejected/`, and moved between them with `git mv` as their status changed. That made the
directory listing show the status, but every move broke every link to the file: from
`proposal.md`, from plan stages, from other decisions and from tests. Each status change then
needed a search through the proposal for the old path. `decisions/decisions.md` shows the status
just as clearly, and a file that never moves never breaks a link.

**A reversed decision is a new decision.** Once `D3` is resolved, changing the answer is a new
decision, `D9`, which starts outstanding and says which decision it would reverse and why. When
`D9` resolves, `D3`'s status box records that it was superseded by `D9`. The original argument and
the reason it stopped holding are both part of the record, and editing `D3`'s answer in place
would lose the first.

### The status box

**Every decision file opens with a status box**, one blockquote before anything else. It holds the
status and whatever goes with it, and is followed by the contents (the `documentation` skill's
"Table of Contents" rule) and then the title. These are the parts, in this order, each appearing
once it applies:

| Part | Holds |
| --- | --- |
| **Status** | `Outstanding — blocks work.`, `Outstanding — does not block work.`, `Resolved.` or `Rejected.` |
| **Blocks** | For an outstanding decision: what it blocks, or why it can wait. **Every outstanding decision says which.** The `plan-of-action` skill will not write a plan over a blocking one |
| **Waits on** | The tests or other decisions it cannot be made without, linked |
| **Answer** or **Reason** | Once resolved, the answer in one line. Once rejected, why in one line, naming the replacement decision if there is one |
| **Decided** | Who made the call and when, and whether it went against the recommendation |
| **Superseded** | By which later decision, once one reverses it |

```markdown
> **Status: Outstanding — blocks work.**
>
> **Blocks:** the Plan of Action. Stage 1's table definition needs an expiry column or none.
>
> **Waits on:** [T2](../tests/T2-ses-sandbox-accepts-plus-addresses.md), for whether a reissue
> can go to the same address.
```

```markdown
> **Status: Resolved.**
>
> **Answer:** the study travels in the ID token's claims, not in a lookup at every request.
>
> **Decided** by the user, 2026-10-14, as recommended. Rests on
> [T1](../tests/T1-cognito-tokens-fit-in-a-cookie.md).
```

### What a decision file contains

- **The title is `D<n>: <the decision>`**, phrased as the question or the choice being made
- **Context** — what needs deciding, why now, and which parts of the proposal rest on it, linked
- **Options** — each with what it costs, what it conflicts with and what it rules out later. The
  obvious option is always listed, even when it is not the one recommended; why it was not taken is
  usually the most valuable line in the file
- **Recommendation** — the writer's own, said as such, having weighed each input as
  `reference/proposals.md` requires. A recommendation is not a decision; it stays outstanding until
  the user makes the call
- **Resolution** or **Rejection**, added when the status changes — the answer or the reason, and
  **the argument that settled it**. If the user chose against the recommendation, the objection
  stays recorded beside the choice, so a later reader sees the risk was known and accepted rather
  than missed

### `decisions/decisions.md`

The summary column phrases an outstanding decision as its question and a settled one as its
answer:

```markdown
**Contents**

- [Decisions](#decisions)

# Decisions

Four decisions: one outstanding, which blocks work; two resolved; one rejected.

| ID | Decision | Status |
| --- | --- | --- |
| [D1](./D1-one-row-per-invitation.md) | One row per invitation, not one per study, so a reissue keeps the history of the first | Resolved |
| [D2](./D2-a-separate-invitations-service.md) | A separate invitations service | Rejected — one table and two endpoints do not justify a deploy pipeline |
| [D3](./D3-tokens-carry-the-study.md) | The study travels in the ID token's claims | Resolved — rests on [T1](../tests/T1-cognito-tokens-fit-in-a-cookie.md) |
| [D4](./D4-how-long-an-invitation-lasts.md) | How long does an invitation stay valid? | **Outstanding — blocks work** |
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

### The status box

**Every test file opens with a status box**, as a decision file does, followed by the contents
and then the title. These are the parts, in this order, each appearing once it applies:

| Part | Holds |
| --- | --- |
| **Status** | `Planned.`, `Confirmed.`, `Refuted.` or `Inconclusive.` |
| **Result** | Once run, what was observed, in one line with the number or the error in it. Not "it worked" |
| **Ran** | When, where and against what: the date, the environment, the account or the data set |
| **Not tested** | What the run did not cover. Examples: the staging table with a hundred rows standing in for production's million, or the sandbox account standing in for the real one. A reader will otherwise assume the test covered more than it did |
| **Rests on it** | The decisions and design sections that depend on the result, linked |
| **Needs** | For a planned test: anything it is waiting for, such as credentials, a human step or the user's go-ahead |

```markdown
> **Status: Confirmed.**
>
> **Result:** 2.9 KB with ten custom attributes and the study claims added, against a 4 KB limit.
>
> **Ran** 2026-10-13, against the staging user pool, with `T1-measure-token-size.sh`.
>
> **Not tested:** a user in more than three studies. The claim grows with each one.
>
> **Rests on it:** [D3](../decisions/D3-tokens-carry-the-study.md).
```

### What a test file contains

- **The title is `T<n>: <the assumption, as a statement>`** — "Cognito ID tokens fit in a 4 KB
  cookie", not "Token size". Stated so that it can be false
- **Why it matters** — what would have to change if the assumption were refuted
- **Method** — what was run, where, against what, ready to run again: the exact commands, the
  environment, the data. A test that cannot be repeated cannot be re-checked when the world changes
- **Result** — what was actually observed, in full: the numbers, the output, the error
- **Conclusion** — what the result means for the proposal and the change it caused, with the
  detail behind the box's *Not tested* line

**A refuted assumption is not a failed test.** It is the most valuable result a test can return,
because it was found before anything was built on it. Keep the file, mark it refuted, and change
the proposal, usually by opening a decision (or reopening one) that names the test.

### Supporting files

**Whatever a test needs to run lives in `tests/`, prefixed with its ID** —
`T1-measure-token-size.sh`, `T1-sample-claims.json`, `T1-output.txt`. The prefix keeps a test's
files together in the listing and makes it obvious which test a stray file belongs to. Keeping them
in the proposal's directory follows the rule that writing a proposal writes nothing outside it.

**Running a test does not license changing shared things.** Reading is expected; but a test that
writes to a shared environment, creates cloud resources, costs money or needs credentials the agent
does not have is raised with the user before it is run — or written as a human step, with the
commands ready to paste, as the `plan-of-action` skill describes. A test exists to reduce risk, and
one that leaves resources behind or changes data someone else depends on has added some.

### `tests/tests.md`

```markdown
**Contents**

- [Assumption Tests](#assumption-tests)

# Assumption Tests

Two tests: one confirmed, one planned.

| ID | Assumption | Status |
| --- | --- | --- |
| [T1](./T1-cognito-tokens-fit-in-a-cookie.md) | Cognito ID tokens fit in a 4 KB cookie with the study claims added | Confirmed — 2.9 KB measured |
| [T2](./T2-ses-sandbox-accepts-plus-addresses.md) | SES in sandbox delivers to `+`-tagged addresses | Planned — needs SES credentials |
```
