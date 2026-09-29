# The stage header, worked

Four worked headers, all of the same file — stage 2 of a nine-stage plan — as it moves from written
to deployed. Read them in order: what changes between them is the point, and what does not change
is the part to copy.

The parts and the rules for them are in `SKILL.md`; this file is the shape.

## The standing preamble

These two paragraphs are the same in every stage file of every proposal, and go in the header
before the dependencies. Copy them as they are:

```markdown
> This is an **execution plan written to be carried out by an AI agent**, one step at a time, in
> order. It is not a description of the system — for the design it serves, read
> [`proposal.md`](./proposal.md).
>
> **Where a step diverges from this plan, correct it in place and say so.**
```

## Not started

Nothing has happened yet, so there is no status beyond the state, no build record and no
divergences. The preamble, the dependency and the stage index are all written when the file is:

```markdown
> **Status: Not Started.**
>
> This is an **execution plan written to be carried out by an AI agent**, one step at a time, in
> order. It is not a description of the system — for the design it serves, read
> [`proposal.md`](./proposal.md).
>
> **Where a step diverges from this plan, correct it in place and say so.**
>
> **Depends on [Stage 1](./plan-1-the-study-slug-rule.md)** — `studies.slug`'s `CHECK` and the
> nuke's discovery pattern are both transcriptions of the rule that stage settles.
>
> Stages: [1](./plan-1-the-study-slug-rule.md) · **2 (this)** ·
> [3](./plan-3-the-tmi-context-envelope.md) · [4](./plan-4-every-lambda-learns-its-study.md) ·
> [5](./plan-5-every-service-every-bundle.md) · [6](./plan-6-ugic-one-identifier-one-version.md) ·
> [7](./plan-7-announcing-a-study.md) · [8](./plan-8-terraform-forgets-the-study.md) ·
> [9](./plan-9-documentation.md)
```

A stage that has to run last depends on the lot, and says why that is rather than listing eight
links:

```markdown
> **Depends on every stage before it.** This is the stage that runs once the shape has stopped
> moving, and running it early means writing a description of something that then changes.
```

## In progress

The status names the last step that landed. The build record and the first divergence appear as
soon as there is one of each — the divergence is summarised here and written up in full under the
step it happened in:

```markdown
> **Status: In Progress — Step 1 Done.**
>
> Built in commits `700d457` (suffixes).
>
> **One divergence from this plan, corrected in place and noted where it belongs:**
>
> 1. **Step 1's `terraform plan` check could not be run** — this session has no AWS credentials. The
>    property it was checking was established from the diff instead, which is the stronger form: the
>    only non-comment line changed in `database.tf` is the new local, so no input moved that could
>    move a `DB_NAME`.
>
> This is an **execution plan written to be carried out by an AI agent**, one step at a time, in
> order. It is not a description of the system — for the design it serves, read
> [`proposal.md`](./proposal.md).
>
> **Where a step diverges from this plan, correct it in place and say so.**
>
> **Depends on [Stage 1](./plan-1-the-study-slug-rule.md)** — `studies.slug`'s `CHECK` and the
> nuke's discovery pattern are both transcriptions of the rule that stage settles.
>
> Stages: [1](./plan-1-the-study-slug-rule.md) · **2 (this)** ·
> [3](./plan-3-the-tmi-context-envelope.md) · [4](./plan-4-every-lambda-learns-its-study.md) ·
> [5](./plan-5-every-service-every-bundle.md) · [6](./plan-6-ugic-one-identifier-one-version.md) ·
> [7](./plan-7-announcing-a-study.md) · [8](./plan-8-terraform-forgets-the-study.md) ·
> [9](./plan-9-documentation.md)
```

## Built, not deployed

The repository is finished and the world is not. **This is the state the header exists for**: every
other state can be guessed at from `git log`, and this one cannot. The status says what is
outstanding, and says the ordering constraint on it, because the reader most likely to be misled is
the one who assumes a merged stage is a done stage:

```markdown
> **Status: BUILT, and its checkpoint cleared. NOT YET DEPLOYED** — the human steps at the foot of
> this file are outstanding, and the FIRST of them must happen BEFORE the apply.
>
> Built in commits `700d457` (suffixes), `3eb3034` (the service), `f414fa2` (the module),
> `3620e1b` (the nuke moves) and `8f3e0a8` (the nuke discovers).
>
> **Three divergences from this plan, all corrected in place and all noted where they belong:**
>
> 1. **Step 1's `terraform plan` check could not be run** — this session has no AWS credentials. The
>    property it was checking was established from the diff instead, which is the stronger form: the
>    only non-comment line changed in `database.tf` is the new local, so no input moved that could
>    move a `DB_NAME`.
> 2. **Step 4 needed `moved` blocks that this plan did not mention**, and the omission cost a failed
>    apply that destroyed the nuke's Lambda, role and log group rather than moving them. Written up
>    in Step 4 itself; the blocks are in `terraform/instance.tf`.
> 3. **Step 4's move also inverts an ordering edge, which this plan did not anticipate.** Once the
>    nuke's `aws_lambda_invocation` lives inside `module "instance"`, the root cannot pass
>    `nuke_invocation_id` back into that module — it would be
>    `module.instance.nuke_invocation_id` feeding `module.instance`, a self-reference Terraform
>    rejects. The module makes the edge directly for its own migrations and **exports** the id for
>    the other eight. Verified acyclic by walking all 1874 edges of `terraform graph`; note that
>    `terraform validate` alone does NOT detect a cycle.
>
> This is an **execution plan written to be carried out by an AI agent**, one step at a time, in
> order. It is not a description of the system — for the design it serves, read
> [`proposal.md`](./proposal.md).
>
> **Where a step diverges from this plan, correct it in place and say so.**
>
> **Depends on [Stage 1](./plan-1-the-study-slug-rule.md)** — `studies.slug`'s `CHECK` and the
> nuke's discovery pattern are both transcriptions of the rule that stage settles.
>
> Stages: [1](./plan-1-the-study-slug-rule.md) · **2 (this)** ·
> [3](./plan-3-the-tmi-context-envelope.md) · [4](./plan-4-every-lambda-learns-its-study.md) ·
> [5](./plan-5-every-service-every-bundle.md) · [6](./plan-6-ugic-one-identifier-one-version.md) ·
> [7](./plan-7-announcing-a-study.md) · [8](./plan-8-terraform-forgets-the-study.md) ·
> [9](./plan-9-documentation.md)
```

Note what divergence 2 records: **the cost, not only the correction.** "Needed `moved` blocks" would
have been enough to fix the file; "and the omission cost a failed apply that destroyed the nuke's
Lambda, role and log group" is what stops the same omission in the next plan.

## Complete and deployed

Both halves done. The status says **what was confirmed live** — the actual observation, not "it
worked" — and then, separately, **what was not exercised**, which is the part a reader will
otherwise assume. Once the divergences are written up under their steps and the stage is closed,
the header can point at them rather than carrying them all:

```markdown
> **Status: COMPLETE and DEPLOYED.** Built in commits `a9d490b` (Step 1), `cbff0a1` (Step 2),
> `fb44b1e` (Step 3), `ef6e860` (Step 4) and `fa019ea` (Step 5), one commit per step, plus
> `9431ac2`, which recorded why the live invite could not pass as first written. Applied by hand in
> both roots, uGIC first, and **the live checkpoint was carried out and confirmed**: the
> announcement wrote a `studies` row with a `version_string` and no `study_id`, and — once
> `var.study_slug` pointed the announcement at `head`, the study being invited into —
> `scripts/invite-participant.zsh` produced the uGIC membership row.
>
> **Not exercised live: an SSO launch.** The launch path lost a signed claim and changed its default
> environment in this stage, and both are covered by tests only; nobody has launched a study through
> uGIC since the apply.
>
> Divergences are recorded in place under each step.
>
> This is an **execution plan written to be carried out by an AI agent**, one step at a time, in
> order. It is not a description of the system — for the design it serves, read
> [`proposal.md`](./proposal.md).
>
> **Where a step diverges from this plan, correct it in place and say so.**
>
> **Depends on [Stage 1](./plan-1-the-study-slug-rule.md)** for the slug rule already applied to the
> same migration file. It is otherwise independent of Stages 2 to 5 and could run beside them.
>
> **It carries one decision the proposal did not make**, since answered — see
> *[The third and fourth columns called `study_id`](#the-third-and-fourth-columns-called-study_id)*.
> **The scope is two tables, not one**, which is more than the question originally asked about.
>
> Stages: [1](./plan-1-the-study-slug-rule.md) · **2 (this)** ·
> [3](./plan-3-the-tmi-context-envelope.md) · [4](./plan-4-every-lambda-learns-its-study.md) ·
> [5](./plan-5-every-service-every-bundle.md) · [6](./plan-6-ugic-one-identifier-one-version.md) ·
> [7](./plan-7-announcing-a-study.md) · [8](./plan-8-terraform-forgets-the-study.md) ·
> [9](./plan-9-documentation.md)
```

The last dependency paragraph carries two things that are not dependencies and belong nowhere else:
**a decision the stage had to make that the proposal did not**, linked to the section of this file
that settles it, and **a scope that turned out wider than the question asked**. Both change how the
rest of the plan should be read, so both go where the plan is entered.
