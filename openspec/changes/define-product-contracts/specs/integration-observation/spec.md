## Purpose

Defines continuous observation of active agent work and the reporting of its
current state: how parallel changes are tracked into immutable snapshots without
interfering with the agents producing them, and how the user reads what OpenMerge
currently knows.

## ADDED Requirements

### Requirement: One observation service owns a repository at a time

At most one observation service SHALL be responsible for a repository. A request to
start observation while a service already owns the repository SHALL attach to the
existing service rather than starting a second. Ownership left behind by a service
that terminated abnormally SHALL be reclaimable without user intervention.

#### Scenario: Observation starts on an unobserved repository

- **WHEN** observation is started for a repository with no service running
- **THEN** a service starts and reports that it is observing
- **AND** it reports the worktrees and sessions it discovered

#### Scenario: Observation is started twice

- **WHEN** observation is started for a repository that already has a running
  service
- **THEN** the request attaches to the existing service
- **AND** no second service is started
- **AND** the report identifies the service already running

#### Scenario: A previous service terminated abnormally

- **WHEN** observation is started for a repository whose ownership record was left
  by a service that is no longer running
- **THEN** ownership is reclaimed and observation starts
- **AND** the recovery is reported rather than silent

### Requirement: Meaningful changes produce immutable, content-addressed snapshots

A change to observed work SHALL produce a snapshot covering staged, unstaged, and
untracked content, together with deletions and renames. A snapshot's identity SHALL
be derived from its content, so that content already snapshotted is never
snapshotted, analysed, or verified again. Snapshots SHALL be immutable once
created.

#### Scenario: An agent edits a file

- **WHEN** an observed worktree's content changes
- **THEN** a snapshot is created covering staged, unstaged, and untracked content
- **AND** the snapshot records which base commit it was taken against

#### Scenario: A change is reverted to previously seen content

- **WHEN** an observed worktree's content returns to a state that was already
  snapshotted
- **THEN** no new snapshot is created
- **AND** the recorded results for that content are reused

#### Scenario: Snapshotting must not disturb the agent

- **WHEN** a snapshot is created while an agent is actively editing
- **THEN** the user's branches, index, working tree contents, refs, and stashes are
  unchanged
- **AND** the agent's own operations are not blocked by snapshot creation

#### Scenario: A worktree cannot be snapshotted

- **WHEN** a worktree's content cannot be captured, for example because it is
  unreadable or is being rewritten concurrently
- **THEN** the failure is recorded against that worktree with its reason
- **AND** other worktrees continue to be observed
- **AND** no partial snapshot is published

### Requirement: Observation survives restart without losing findings

Snapshots, findings, and their evidence SHALL be durable. After an abnormal
termination and restart, previously recorded blocking findings SHALL still be
reported, and state that cannot be recovered SHALL be declared rather than assumed
absent.

#### Scenario: The service is restarted normally

- **WHEN** observation is stopped and started again
- **THEN** previously recorded findings are still reported
- **AND** work that changed while the service was down is snapshotted on startup

#### Scenario: The service terminates abnormally

- **WHEN** the service is terminated without shutting down cleanly
- **THEN** findings and evidence recorded before termination are still readable
- **AND** no finding is silently lost

#### Scenario: Durable state is corrupt

- **WHEN** durable state cannot be read on startup
- **THEN** the condition is reported as degraded with the affected state named
- **AND** unreadable state is not reported as an absence of findings

### Requirement: Degraded observation is declared, never simulated

When OpenMerge cannot observe some or all work, it SHALL say so explicitly. It
SHALL NOT report that it is observing work it is not observing.

#### Scenario: Change notification is unavailable

- **WHEN** the mechanism used to learn about content changes is unavailable
- **THEN** the state is reported as degraded with that mechanism named
- **AND** OpenMerge does not report those worktrees as currently observed

#### Scenario: An agent integration is absent

- **WHEN** an agent provides no usable integration, or its integration is not
  installed
- **THEN** observation falls back to a mechanism that does not depend on it
- **AND** the report states that session attribution for that agent is reduced

#### Scenario: A worktree disappears

- **WHEN** an observed worktree is removed from the repository
- **THEN** it stops being observed
- **AND** findings that referenced it are marked stale rather than reported as
  current

### Requirement: Current state is reportable, and silence is explicit

The current state SHALL be reportable on demand, scoped to the caller's context by
the same resolution rules verification uses. When there is nothing to report, the
report SHALL say so explicitly rather than producing empty output. Reporting SHALL
be possible without the observation service running, from durable state, and SHALL
then declare that state stale.

#### Scenario: There is nothing wrong

- **WHEN** state is reported for a scope with no findings
- **THEN** the report states explicitly that there are no findings
- **AND** it names the scope and the snapshots the conclusion covers

#### Scenario: A blocking finding exists

- **WHEN** state is reported for a scope with a persisted blocking finding
- **THEN** the report includes the finding's identifier, its classification, the
  failing command, and how to reproduce it
- **AND** it identifies which session owns the fix

#### Scenario: The service is unavailable

- **WHEN** state is reported while the observation service is not running
- **THEN** the last durably recorded state is reported
- **AND** it is marked stale
- **AND** the unavailable service is named among the degraded reasons

#### Scenario: Verification has never run for the scope

- **WHEN** state is reported for a scope whose combinations have not been verified
- **THEN** the report distinguishes "not yet verified" from "verified with no
  findings"
- **AND** the absence of findings is not presented as a passing result
