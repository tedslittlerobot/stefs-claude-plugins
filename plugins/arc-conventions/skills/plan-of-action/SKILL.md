---
name: plan-of-action
description: Turning a settled proposal into a Plan of Action — a staged implementation plan written for an AI agent to carry out, one plan-<n>-<description>.md file per stage in the proposal's own directory, with a checkpoint between stages and human steps called out explicitly. Use when a proposal's design is settled and it is time to plan the build, when writing a plan of action or splitting one into stages, and when implementing one — executing a proposal, working through the next stage, or asking what to build next from proposals/.
---

# Plan of Action

A **Plan of Action** is the bridge between a proposal and the work. The proposal argues what should
be built and why that shape; the plan says what to do about it. It lives in the proposal's own
directory, and it is **written for an AI agent to implement** — a sequence of instructions, not an
argument.

The proposal itself — its layout, status line, rejected options and lifecycle — is governed by the
`documentation` skill. This skill covers only the plan: writing it, staging it, and carrying it
out.

## When it is written

**Once a proposal's design is settled, it is turned into a Plan of Action before any of it is
built.** Writing the plan is a separate act from writing the proposal, and doing it separately is
the point: the proposal is where the design is argued out, and once that argument has landed the
plan can be written without relitigating it.

**The proposal's blocking questions are answered first.** A proposal marks which of its outstanding
questions block work; a plan written over an unanswered one encodes a guess as an instruction, and
an agent implementing it has no way to tell the guess from the decisions. A non-blocking question
can be carried into the stage that needs it, said plainly as a question rather than dressed up as a
step.

## Stages

A Plan of Action may be split into **stages**, one file per stage, alongside `proposal.md`:

```
proposals/<proposal-slug>/
  proposal.md
  plan-1-update-database.md          # a plan of nine stages or fewer: no padding
  plan-2-backfill-existing-rows.md
  plan-01-update-database.md         # a plan of ten to ninety-nine stages: pad to two digits
  plan-10-cut-over-the-reader.md
```

- **`plan-<iteration>-<description>.md`.** The iteration is the stage's position in the sequence;
  the description is a few words at most saying what that stage does
- **Zero-pad only as far as the current plan needs.** Nine stages or fewer take no padding at all,
  ten to ninety-nine pad the single digits to two, and so on. Padding is there so a directory
  listing shows the stages in execution order; padding wider than the plan needs implies stages
  that do not exist
- **Link the stages from `proposal.md`**, in order, so the entry point remains a complete index

**Splitting a plan into stages reduces the risk and the context of implementing it.** A stage is a
unit small enough for the implementing agent to hold at once, and small enough for a mistake to be
caught inside it rather than discovered twenty steps later with everything since built on top.

**Put the boundaries where a checkpoint is worth having.** The second reason to split is to stop
and verify, so a stage that can be tested or inspected on its own is a stage worth splitting out,
and consecutive work with nothing worth checking between it is one stage rather than three. Where
it can be had cheaply, a stage boundary should also leave the repository in a coherent state — one
that builds, deploys and makes sense on its own — so that stopping after any stage is a safe place
to stop.

## What a stage file contains

- **The instructions for that stage, in order** — the files to change, the commands to run, the
  end state to arrive at. Concrete enough to follow without re-deriving the design; where the
  *why* matters, link back to the section of `proposal.md` that argues it rather than restating it
- **Human steps, named as such.** Some work cannot be done by the agent — issuing a credential,
  flipping a console setting, obtaining an approval, anything needing a login the agent does not
  have. Call these out explicitly at the point they are needed
- **The checkpoint, at the end** — the tests to run, the command whose output should have changed,
  the thing to look at in a console. A stage with no way to verify it says so, rather than leaving
  the reader to wonder whether a check was forgotten

## Implementing the plan

**One stage at a time, in order.** Read the stage you are on, plus `proposal.md` for context; do
not read ahead into later stages. Reading ahead spends the context the split exists to save, and
pulls decisions forward into a stage that was deliberately not making them yet.

- **Stop and prompt the human at a human step**, then wait. Do not work around it, and do not
  assume it has been done because the plan says it should be — the whole reason it is in the plan
  is that the agent cannot verify it
- **Clear the stage's checkpoint before starting the next stage.** A failing checkpoint is the end
  of the run, not a note to carry forward; the next stage is written on the assumption that this
  one landed
- **Commit at each stage boundary**, so which stages are done is legible from `git log` rather than
  from memory. A session that resumes a part-built plan finds out where it got to that way
- **When reality contradicts the plan, stop and amend the plan** rather than improvising past it.
  The divergence — the thing the plan assumed that turned out not to hold — is exactly what the
  next reader needs, and a plan that has been quietly diverged from is worse than no plan at all,
  because it still reads as a description of what was done

**When the last stage is done, the proposal's lifecycle takes over**: what now exists is described
in `architecture/`, the operational side in `instructions/`, and the proposal's status line is
updated to say it has been implemented and to point at both. The plan stages stay where they are,
with the proposal. See the `documentation` skill.

## Related

- `documentation` skill — the proposal itself, the three tenses, and where the description of the
  built thing goes afterwards
- `conventions` skill — the project's own `conventions/` file, which wins over anything here
- `product-requirements` skill — `requirements/`, where a user-level feature and its acceptance
  criteria are recorded, as opposed to a plan for building one
