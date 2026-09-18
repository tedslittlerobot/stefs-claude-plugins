# Requirement Format

## Dependencies

- Lists other User Requirements this one depends on — requirements that must already be satisfied
  for this one to make sense (a "user views their study dashboard" requirement depends on "user logs
  in")
- Reference each as a **link to its requirement file**: `- [User logs in](./user-logs-in.md)`
- **If there are none, the section is still present** and states exactly **No Dependencies**. An
  absent section and "nothing depends on this" are different facts

## Risk Assessment (requirement-level)

The aggregate risk assessment for the requirement as a whole, distinct from the Light Risk
Assessment carried by each User Story. Four subsections:

1. **Score** — three ratings, each an integer 1–9:
   - **Risk Severity** — how bad the outcome is if the risk materialises (1 = low, 9 = highest)
   - **Risk Likelihood** — how likely it is to materialise (1 = virtually impossible, 9 = almost
     certain)
   - **Risk Detectability** — how hard it is to detect if it materialises (**1 = would likely go
     unnoticed, 9 = easy to detect**). Note the inverted direction: a low score here is the bad one
2. **Assessment** — a summary rolling up all risks flagged across this requirement's User Stories'
   Light Risk Assessments. **Name the categories that carried no risk**, so the reader can tell the
   difference between "considered and clear" and "not considered"
3. **Mitigations** — mitigations already in place, whether through how the Stories and Acceptance
   Criteria are written or through what has already been implemented. **Cite the AC** that carries
   each one
4. **Treatment Plan** — suggested actions to further mitigate the risk. May be "None" if existing
   mitigations are considered sufficient

## User Stories

Each User Story is a subsection (`### <n>. <story title>`) containing, in order:

1. **Title**
2. **Story**
3. **Acceptance Criteria** — at least one
4. **Light Risk Assessment**
5. **Caveats**

### Story

```gherkin
As a <user type>,
I want to <perform an action>
So that <a result is achieved>
```

- **Must be end-user / human focused** — never phrased in terms of internal systems or components
- **Terse**: each line no longer than 200 characters, ideally under 100

### Acceptance Criteria

- Each has a **title and a number** — `##### AC1: Successful login`
- Written in **Gherkin** (`Given` / `When` / `Then`), describing a specific action and effect
- **At least one is required: the happy path** — the golden path that fulfils the story's goal
- Alternate success states may each form an additional AC
- Error/failure states may each form an additional AC
- **Keep criteria terse.** Prefer one general AC covering a class of failure ("input validation
  fails") over one per possible validation error. Only break out a single validation case when it is
  particularly complex or risky

#### Test Coverage

**Each Acceptance Criterion is immediately followed by a Test Coverage note** stating how much of it
— and which specific parts, if not all — is exercised by automated/unit tests, **naming the covering
tests**:

```
**Test Coverage**: Fully covered — `reset-password/handler_test.go::TestResetPassword_Success`
```

- If no automated test exercises it, state exactly **Entirely uncovered by unit testing**
- **Keep the note current** as tests are added, removed or renamed
- If any coverage is **incidental** — a test written against another AC that also happens to
  exercise part of this one — **say so, name which AC it comes from, and say how much of this AC it
  accounts for**, rather than implying a dedicated test exists:

```
**Test Coverage**: Partially covered incidentally — AC1's `TestResetPassword_Success` asserts the
complexity check accepts a valid password, but no test asserts the rejection path for an invalid
one; the rejection behaviour itself is entirely uncovered by unit testing
```

### Light Risk Assessment

- Assessed at the **User Story** level (not the requirement level)
- **One subsection (`##### <category>`) per category, in order, covering every category even when it
  carries no risk**
- **If a category has no relevant risk, its subsection body states exactly `No risk identified` and
  nothing else**
- If a category does have a relevant risk, its subsection contains, in order:
  1. **Risk Score** — the same three ratings as the requirement-level assessment, each 1–9
  2. **Risk Summary** — what the risk is and why it applies to *this* User Story
  3. **Risk Mitigation** — what has already been accounted for, via how the Story/ACs are written or
     via what is already implemented
  4. **Risk Recommendation** — what has *not* been accounted for and what could be done about it.
     May state "None" if the existing mitigation is sufficient

#### Default risk categories

This list is **domain-specific** — it comes from clinical/medical software. A project in another
domain records its own list in `conventions/requirements.md`, and that list wins.

- **Patient Safety**
- **Privacy**
- **Product/Service Quality**
- **Data Integrity**
- **Electronic Records** (electronic signatures, authentication, 3rd party systems)
- **Security**
- **Regulatory Compliance (for a Technical Product Medical in the Medical Space — but not a Class 1
  Medical Device)**
- **User Experience Issues**

### Caveats

Known limitations, edge cases deliberately out of scope, or assumptions the User Story depends on.

This is where scope is defended. An assumption written down here is a decision; the same assumption
left unwritten is a defect waiting to be filed.
