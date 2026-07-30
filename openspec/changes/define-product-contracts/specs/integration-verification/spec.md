## Purpose

Defines how OpenMerge decides which combinations of in-progress changes to verify,
how it separates a change that is broken on its own from a combination that is
broken together, and how results stay tied to the exact work they were computed
from. This is the capability the product exists for.

## ADDED Requirements

### Requirement: Verification scope resolves from context and never silently expands

Verification SHALL determine its scope in this order:

1. If an agent session is identifiable, verify the high-risk combinations
   involving that session.
2. Otherwise, if the working directory is inside a tracked worktree, verify the
   high-risk combinations involving that worktree.
3. Otherwise, refuse and require an explicit scope.

Repository-wide verification SHALL require an explicit request. Scope SHALL be
reported in every result so the user can see what was actually verified.

#### Scenario: A session is identifiable

- **WHEN** verification is requested from within an identifiable agent session
- **THEN** only combinations involving that session's current snapshot are
  verified
- **AND** the reported scope names that session

#### Scenario: No session, but inside a tracked worktree

- **WHEN** verification is requested with no identifiable session, from a
  directory inside a worktree OpenMerge is observing
- **THEN** only combinations involving that worktree's current snapshot are
  verified
- **AND** the reported scope names that worktree

#### Scenario: Context cannot be determined

- **WHEN** verification is requested and neither a session nor a tracked worktree
  can be determined
- **THEN** the request is refused with a configuration-or-usage error
- **AND** the error names the explicit alternatives available
- **AND** no combinations are verified

#### Scenario: Repository-wide verification is requested explicitly

- **WHEN** verification is requested for the whole repository
- **THEN** every high-risk combination among active work is verified
- **AND** the reported scope states that it was repository-wide

#### Scenario: A named session is requested that does not exist

- **WHEN** verification is requested for a session identifier that is not active
- **THEN** the request is refused with a configuration-or-usage error naming the
  unknown identifier
- **AND** the scope is not silently widened to anything else

### Requirement: Baselines are established before any combination is judged

For every combination, each member's own result SHALL be determined before the
combined result is interpreted. A combined failure SHALL NOT be attributed to the
combination unless every member passed alone.

#### Scenario: Every member passes alone and the combination fails

- **WHEN** each member's snapshot passes its own checks, the merge is clean, and
  the combined tree fails
- **THEN** the result is an integration failure attributable to the combination
- **AND** the report includes each member's baseline result alongside the combined
  result

#### Scenario: One member is already broken

- **WHEN** a member's snapshot fails its own checks
- **THEN** the failure is attributed to that member alone
- **AND** the combination is not reported as an integration failure
- **AND** the other members' sessions are not notified about it

#### Scenario: A baseline cannot be established

- **WHEN** a member's own result cannot be determined, because a required check
  did not run, timed out, or its tool is unavailable
- **THEN** no integration failure is produced for combinations containing that
  member
- **AND** the result is reported as inconclusive with the reason recorded

### Requirement: Combinations are constructed without altering user state

Constructing and verifying a combination SHALL NOT modify the user's branches,
index, working trees, refs, or stashes, and SHALL NOT create commits on any branch
the user can see. Verification SHALL be possible while a worktree contains staged,
unstaged, and untracked changes.

#### Scenario: Verification runs against work in progress

- **WHEN** a combination is verified while its members have staged, unstaged, and
  untracked changes
- **THEN** all three categories of change are included in what is verified
- **AND** the user's Git state is byte-for-byte unchanged afterwards

#### Scenario: A combination cannot be constructed

- **WHEN** two members' changes cannot be merged without textual conflict
- **THEN** the combination is reported as a textual conflict
- **AND** no build, type, or test verdict is claimed for it
- **AND** no partial merge is left anywhere the user can observe

#### Scenario: Verification is interrupted

- **WHEN** verification is terminated before completion, whether by the user or by
  failure
- **THEN** the user's Git state is unchanged
- **AND** no temporary state remains that affects later commands

### Requirement: Results are bound to the snapshots that produced them

Every verification result SHALL identify the snapshots it was computed from. A
result whose inputs are no longer current SHALL NOT be presented as current. An
identical set of inputs SHALL NOT be verified twice.

#### Scenario: Work changes while verification is running

- **WHEN** a member's snapshot is superseded while a verification run using it is
  still in flight
- **THEN** that run's results are not published as current findings
- **AND** verification for the new snapshot is scheduled

#### Scenario: The same combination is requested again unchanged

- **WHEN** verification is requested for a set of snapshots that has already been
  verified
- **THEN** the recorded result is returned without re-executing the checks
- **AND** the result identifies the snapshots it came from

#### Scenario: A result is read after its inputs moved on

- **WHEN** a previously recorded result is reported after one of its snapshots has
  been superseded
- **THEN** the result is marked stale
- **AND** it is not counted as a current blocking finding

### Requirement: Combination selection is bounded and explainable

Verification SHALL NOT attempt every possible combination of active work. It SHALL
select combinations by assessed risk, and SHALL be able to state why a given
combination was selected. Selection SHALL NOT depend on generated analysis.

#### Scenario: Many sessions are active at once

- **WHEN** the number of active sessions makes exhaustive combination verification
  impractical
- **THEN** only combinations assessed as high-risk are verified
- **AND** the result states how many combinations were verified and how many were
  skipped

#### Scenario: The user asks why a combination was verified

- **WHEN** a report for a verified combination is inspected
- **THEN** it states the reason the combination was selected, in terms of
  observable relationships between the changes

#### Scenario: Risk cannot be assessed for a change

- **WHEN** the relationships involving a change cannot be determined
- **THEN** the change is treated as potentially related rather than unrelated
- **AND** the reduced confidence in selection is reported alongside the result
