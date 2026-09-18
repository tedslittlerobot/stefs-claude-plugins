# Worked Example

A complete requirement file. The nesting of heading levels is the part most easily got wrong, so
copy the shape from here rather than reconstructing it.

Note in particular:

- **Dependencies** states `No Dependencies` explicitly rather than being omitted
- The requirement-level **Assessment** names the categories that carried *no* risk, so a reader can
  tell "considered and clear" from "not considered"
- **Mitigations** cite the AC that carries them
- **AC2 and AC3** show a partial and an incidental Test Coverage note — the two honest shapes that
  are easy to fudge into "covered"
- Every risk category appears for the story, and the ones with nothing to say state exactly
  `No risk identified`

---


```markdown
# User resets a forgotten password

## Dependencies

No Dependencies

## Risk Assessment

### Score

- Risk Severity: 6
- Risk Likelihood: 3
- Risk Detectability: 4

### Assessment

Account takeover via a leaked or guessable reset code is the primary risk (Electronic Records,
Privacy, Security). No Patient Safety, Data Integrity, Regulatory Compliance, or User Experience
risks were identified across this requirement's User Stories.

### Mitigations

- Reset codes are single-use and expire after 15 minutes (enforced in AC2 of Story 1)
- Codes are delivered only to the verified email address already on file, never to a
  user-supplied address

### Treatment Plan

- Add rate limiting on reset code submission attempts to reduce brute-force risk

## User Stories

### 1. Reset a forgotten password via emailed code

#### Story

As a registered platform user,
I want to reset my password when I've forgotten it
So that I can regain access to my account without contacting support

#### Acceptance Criteria

##### AC1: Successful password reset (happy path)

Given a user has requested a password reset and received a valid reset code
When they submit the code along with a new password meeting complexity requirements
Then their password is updated and they can log in with the new password

**Test Coverage**: Fully covered — `reset-password/handler_test.go::TestResetPassword_Success`

##### AC2: Reset code expired or invalid

Given a user submits a reset code
When the code is expired, already used, or does not match
Then the reset is rejected and the user is told to request a new code

**Test Coverage**: Partially covered — the expired/already-used cases are covered by
`reset-password/handler_test.go::TestResetPassword_ExpiredCode` and
`TestResetPassword_AlreadyUsedCode`; the non-matching-code case is entirely uncovered by unit
testing

##### AC3: New password must meet complexity requirements

Given a user submits a valid, unexpired reset code
When the new password does not meet complexity requirements
Then the reset is rejected and the user is shown the complexity rules

**Test Coverage**: Partially covered incidentally — AC1's `TestResetPassword_Success` asserts the
complexity check accepts a valid password, but no test asserts the rejection path for an invalid
one; the rejection behaviour itself is entirely uncovered by unit testing

#### Light Risk Assessment

##### Patient Safety

No risk identified

##### Privacy

**Risk Score**: Risk Severity 5, Risk Likelihood 3, Risk Detectability 4

**Risk Summary**: The reset code, if sent to the wrong address, would expose account access to
someone other than the account holder.

**Risk Mitigation**: The code is only ever sent to the verified email address already on file
(AC1) — there is no path for a user-supplied address to receive it.

**Risk Recommendation**: None — existing mitigation is considered sufficient.

##### Product/Service Quality

No risk identified

##### Data Integrity

No risk identified

##### Electronic Records

**Risk Score**: Risk Severity 5, Risk Likelihood 3, Risk Detectability 4

**Risk Summary**: The reset code functions as a short-lived authentication credential; if it did
not expire or could be reused, it would undermine the integrity of the authentication event.

**Risk Mitigation**: Codes are single-use and expire after 15 minutes (AC2).

**Risk Recommendation**: None — existing mitigation is considered sufficient.

##### Security

**Risk Score**: Risk Severity 6, Risk Likelihood 3, Risk Detectability 4

**Risk Summary**: A leaked or guessable reset code would allow account takeover.

**Risk Mitigation**: Codes are single-use, expire after 15 minutes, and are only sent to the
verified email on file (AC1, AC2).

**Risk Recommendation**: Add rate limiting on reset code submission attempts to reduce
brute-force/guessing risk.

##### Regulatory Compliance (for a Technical Product Medical in the Medical Space - but not a Class 1 Medical Device)

No risk identified

##### User Experience Issues

No risk identified

#### Caveats

Assumes the user still has access to the email address on their account; account recovery when
that email is also lost is out of scope for this requirement.
```
