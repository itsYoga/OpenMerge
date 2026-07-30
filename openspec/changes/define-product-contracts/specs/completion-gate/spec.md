## Purpose

Defines the verdict an agent receives when it tries to declare its work finished:
the fixed exit codes, what each one means, and the boundary between OpenMerge's
authority over its own recorded state and an agent runtime's decision to honour it.

## ADDED Requirements

### Requirement: The gate returns one of five fixed exit codes

The gate SHALL exit with exactly one of the following, and these values SHALL be
part of the compatibility surface:

| Exit | Meaning |
| --- | --- |
| 0 | `clear` — no relevant persisted blocking findings, and the verification results relied upon are still valid |
| 2 | `blocked` — a persisted blocking finding applies to this scope |
| 3 | `inconclusive_or_degraded` — no trustworthy conclusion could be formed |
| 4 | `usage_or_configuration_error` — the request itself was invalid |
| 5 | `internal_error` — the gate failed to perform its own function |

Exit code 1 SHALL NOT be used, so that an unexpected generic failure is never
mistaken for a verdict.

#### Scenario: Nothing is wrong

- **WHEN** the gate is invoked for a scope with no persisted blocking findings and
  with valid verification results
- **THEN** it exits 0 with status `clear`
- **AND** the result names the snapshots the verdict was computed from

#### Scenario: A blocking finding applies

- **WHEN** the gate is invoked for a scope that has a persisted blocking finding
- **THEN** it exits 2 with status `blocked`
- **AND** the result includes each blocking finding's identifier, the failing
  command, and its reproduction instructions

#### Scenario: The conclusion cannot be trusted

- **WHEN** the gate cannot form a trustworthy conclusion
- **THEN** it exits 3 with status `inconclusive_or_degraded`
- **AND** every reason is listed in machine-readable form
- **AND** it does not exit 0

#### Scenario: The request is malformed

- **WHEN** the gate is invoked with an unknown scope, contradictory arguments, or
  invalid configuration
- **THEN** it exits 4
- **AND** no verdict of `clear` or `blocked` is reported

#### Scenario: The gate itself fails

- **WHEN** the gate cannot complete its own work, including being unable to write
  the feedback it is required to write
- **THEN** it exits 5
- **AND** it does not report `clear`

### Requirement: A degraded gate never reports clear

Any condition that prevents the gate from confirming that the relied-upon
verification is valid and current SHALL produce exit 3, never exit 0. This
includes the observation service being unavailable, snapshots being stale, a
required check never having run, and executor failure.

#### Scenario: The observation service is not running

- **WHEN** the gate is invoked while the observation service is unavailable
- **THEN** it exits 3
- **AND** the reason identifies the unavailable service
- **AND** any state read from durable storage is reported as stale

#### Scenario: The work has moved since it was verified

- **WHEN** the scope's current snapshot differs from the one the available results
  were computed from
- **THEN** it exits 3 with a reason of stale verification
- **AND** it does not report the earlier result as current

#### Scenario: A required check never ran

- **WHEN** a check the configuration marks as required has not been executed for
  the current snapshots
- **THEN** it exits 3 naming that check
- **AND** absence of a failure is not treated as a pass

#### Scenario: Execution was impossible

- **WHEN** the environment needed to run checks is unavailable
- **THEN** it exits 3 with the executor failure recorded
- **AND** the condition is not reported as a defect in the user's code

### Requirement: A blocked gate always leaves durable machine-readable feedback

Before reporting `blocked`, the gate SHALL persist machine-readable feedback
describing each blocking finding, its owner, and how to reproduce it, at a
location discoverable without the observation service running. This feedback is
the durable channel; the exit code is not.

#### Scenario: Feedback is written before the verdict is returned

- **WHEN** the gate determines that the scope is blocked
- **THEN** the feedback is persisted before the process exits
- **AND** the feedback is readable by a later process with no service running

#### Scenario: Feedback cannot be written

- **WHEN** the gate determines that the scope is blocked but cannot persist the
  feedback
- **THEN** it exits 5
- **AND** it does not report `clear`

#### Scenario: The gate is never invoked

- **WHEN** an agent finishes without the gate being invoked at all
- **THEN** any blocking findings recorded during observation remain persisted and
  discoverable
- **AND** a later invocation of the gate reports them

### Requirement: The gate is authoritative over recorded state and claims nothing about enforcement

The gate's verdict SHALL be a strict, deterministic function of OpenMerge's
recorded state. Whether an agent runtime honours that verdict is outside
OpenMerge's control, and OpenMerge SHALL NOT represent enforcement as guaranteed.
Neither a verdict nor its persisted feedback SHALL be altered by whether the
runtime acted on it.

#### Scenario: The runtime overrides a block

- **WHEN** an agent runtime ignores or overrides a `blocked` verdict and allows the
  agent to finish
- **THEN** the recorded verdict remains `blocked`
- **AND** the persisted feedback remains discoverable and unchanged
- **AND** the next invocation reports the same verdict for the same state

#### Scenario: The gate invocation times out inside the runtime

- **WHEN** an agent runtime abandons the gate invocation before it returns
- **THEN** any feedback already persisted remains valid
- **AND** the verdict is recomputed on the next invocation rather than assumed

#### Scenario: Documentation describes the gate's power

- **WHEN** the gate's behaviour is documented for users
- **THEN** it states that the verdict is authoritative within OpenMerge's recorded
  state and that enforcement depends on the agent runtime
- **AND** it does not claim that agents can be prevented from finishing

### Requirement: The gate can be disabled, and a disabled gate says so

The gate SHALL be disableable by configuration without uninstalling OpenMerge. A
disabled gate SHALL report that it is disabled rather than reporting `clear`, so
that a suppressed gate is never mistaken for a passing one.

#### Scenario: The gate is disabled by configuration

- **WHEN** the gate is invoked while disabled by configuration
- **THEN** it exits 0 with status `disabled`
- **AND** the status is distinguishable from `clear`
- **AND** any blocking findings that exist are still reported as informational

#### Scenario: A user needs to finish work despite a block

- **WHEN** a user must complete work that the gate reports as blocked
- **THEN** a documented way to proceed exists that does not require uninstalling
  OpenMerge
- **AND** taking it is recorded rather than silent
