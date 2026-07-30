## Purpose

Defines what a finding is: how a verification outcome is classified, what evidence
a finding must carry before it is allowed to block anything, and which
classifications have the power to block at all. This is the vocabulary every other
capability reports in, so it is fixed here once rather than reinvented per adapter.

## ADDED Requirements

### Requirement: Findings are classified on two independent axes

A finding SHALL carry a `classification` describing the outcome and an
`evidence_kind` describing where the evidence came from. Classification is a
closed set; evidence sources are open.

`classification` MUST be exactly one of:

- `pass`
- `textual_conflict`
- `baseline_failure`
- `integration_failure`
- `inconclusive`
- `execution_error`

`evidence_kind` MUST be one of `git`, `build`, `test`, `schema`, `contract`,
`resource`, or `custom`.

A finding MAY additionally carry an `adapter` naming the analyser that produced
it and an `adapter_code` giving that analyser's specific outcome. Adding an
adapter, an `adapter_code`, or an `evidence_kind` SHALL NOT require adding a
`classification`.

#### Scenario: A type error appearing only in a combination

- **WHEN** two changes each pass their own checks, merge without textual conflict,
  and the combined tree fails a type check
- **THEN** the finding reports `classification: integration_failure`,
  `evidence_kind: build`, `adapter: typescript`, and an `adapter_code` identifying
  the specific outcome

#### Scenario: A schema adapter reports migration ordering

- **WHEN** a schema adapter determines that two changes' migrations cannot be
  applied in the proposed order
- **THEN** the finding reports `classification: integration_failure` and
  `evidence_kind: schema` with the adapter's own `adapter_code`
- **AND** no new `classification` value is introduced to accommodate it

#### Scenario: A consumer encounters an adapter it does not know

- **WHEN** a consumer receives a finding whose `adapter_code` it does not
  recognise
- **THEN** the consumer can still determine severity and blocking status from
  `classification` alone

#### Scenario: A finding declares a classification outside the closed set

- **WHEN** a component emits a finding whose `classification` is not one of the
  six defined values
- **THEN** the finding is rejected rather than passed through
- **AND** the rejection is reported as an `execution_error`, not as a defect in
  the user's code

### Requirement: A blocking finding requires deterministic, reproducible evidence

A finding SHALL be treated as blocking only when all of the following hold:

- `classification` is `integration_failure`
- every member snapshot's baseline result is `pass`
- the combined result is a failure
- the failure is reproducible from the recorded snapshots and command
- the evidence is persisted and retrievable after the process that produced it
  has exited

If any condition is unmet, the finding MAY still be recorded and reported, but it
SHALL NOT block.

#### Scenario: All conditions are satisfied

- **WHEN** each member passed alone, the merge was clean, the combination failed,
  the failure reproduces, and the evidence is persisted
- **THEN** the finding is blocking
- **AND** it carries the exact command, its exit status, and the diagnostics
  needed to reproduce it without the daemon running

#### Scenario: The failure does not reproduce

- **WHEN** a combined failure cannot be reproduced from the recorded snapshots
  and command
- **THEN** the finding is not blocking
- **AND** it is reported as `inconclusive` with a reason of `unstable_result`

#### Scenario: Evidence cannot be persisted

- **WHEN** a combined failure is observed but its evidence cannot be written to
  durable storage
- **THEN** the finding is not blocking
- **AND** the inability to persist is reported as an `execution_error` naming the
  storage failure

### Requirement: Non-integration classifications have restricted authority

Each classification other than `integration_failure` SHALL have fixed, limited
powers, so that no classification can be used to smuggle an unprovable warning
into a blocking position.

- `textual_conflict` MAY block the affected combination. It SHALL be presented as
  a merge result, not as a verification verdict.
- `baseline_failure` SHALL be attributed to the single owning session and SHALL
  NOT be presented as a failure between sessions.
- `inconclusive` SHALL NEVER block.
- `execution_error` SHALL NEVER be presented as a defect in the user's code.

#### Scenario: Two changes cannot be merged textually

- **WHEN** a combination cannot be constructed because the changes conflict
  textually
- **THEN** the finding is `textual_conflict` with `evidence_kind: git`
- **AND** the combination is blocked
- **AND** the report describes it as a merge conflict, without claiming any
  build, type, or test verdict

#### Scenario: One change is broken on its own

- **WHEN** a change fails its own checks before any combination is attempted
- **THEN** the finding is `baseline_failure` attributed to that change's session
- **AND** it is not reported to any other session
- **AND** no `integration_failure` is created from that combination

#### Scenario: A required tool is missing

- **WHEN** a check cannot run because its tool is absent from the environment
- **THEN** the finding is `execution_error` with the missing tool named
- **AND** the report distinguishes it from a failing check
- **AND** nothing is blocked on the basis of that check

#### Scenario: A result cannot be trusted

- **WHEN** verification cannot reach a trustworthy conclusion for any reason
- **THEN** the finding is `inconclusive` with a machine-readable reason
- **AND** it does not block

### Requirement: Finding identity is stable, and findings close themselves

A finding SHALL have an identifier derived from the problem it describes, so that
re-detecting the same problem yields the same identifier. A finding SHALL be
closed automatically when re-verification no longer reproduces it, and marked
stale when the snapshots it was computed from are no longer current.

#### Scenario: The same problem is detected again

- **WHEN** the same underlying failure is observed in a later verification run
- **THEN** the existing finding is updated rather than a second finding created
- **AND** the user is not notified again for the same unchanged problem

#### Scenario: The responsible change is fixed

- **WHEN** re-verification of the same combination no longer reproduces the
  failure
- **THEN** the finding is closed automatically
- **AND** the closure records which snapshots demonstrated it

#### Scenario: The underlying work moves on

- **WHEN** a member snapshot is superseded before the finding is resolved
- **THEN** the finding is marked stale rather than reported as current
- **AND** a stale finding does not block

### Requirement: Model output may explain a finding but never establish one

Generated explanations, summaries, or suggested fixes MAY be attached to a
finding. They SHALL be distinguishable from recorded evidence, and SHALL NOT
contribute to whether a finding blocks. Recorded evidence SHALL NOT be rewritten
by any generated content.

#### Scenario: An explanation is attached to a blocking finding

- **WHEN** a generated explanation accompanies a finding backed by a failing
  command
- **THEN** the explanation is presented as commentary, clearly separated from the
  command, exit status, and diagnostics
- **AND** removing the explanation does not change the finding's blocking status

#### Scenario: Only a generated judgement is available

- **WHEN** the sole basis for suspecting a problem is generated analysis, with no
  failing deterministic check
- **THEN** no blocking finding is created
- **AND** any report is `inconclusive`
