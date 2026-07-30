## Purpose

Defines how a repository becomes observable by OpenMerge: what is detected, what
is written, what happens when nothing verifiable can be found, and the guarantee
that initialising never disturbs work already in progress.

## ADDED Requirements

### Requirement: Initialization detects the repository and the checks available to verify it

Initialization SHALL detect the repository, the worktrees currently associated
with it, the package and workspace layout, the language toolchains present, the
schema and contract sources present, and which supported coding agents are
installed. It SHALL report what it detected and what it configured.

#### Scenario: A supported repository is initialized

- **WHEN** initialization runs in a Git repository with a recognised workspace
  layout and at least one deterministic check available
- **THEN** it reports each detected item and each configuration file it created
- **AND** the repository is ready to observe without further configuration

#### Scenario: The directory is not a Git repository

- **WHEN** initialization runs where no Git repository can be resolved
- **THEN** it refuses with a usage-or-configuration error
- **AND** it creates no files

#### Scenario: No deterministic checks can be found

- **WHEN** initialization finds no compiler, type checker, test runner, or schema
  validator it can run
- **THEN** initialization still succeeds
- **AND** the repository is configured in an observe-only state
- **AND** the report states that no verification will occur until a check is
  configured

#### Scenario: A coding agent is installed but unsupported

- **WHEN** an installed agent has no available integration
- **THEN** initialization succeeds and names that agent as unintegrated
- **AND** observation falls back to a mechanism that does not depend on that agent

### Requirement: Initialization is idempotent and preserves user configuration

Re-running initialization on an already initialized repository SHALL leave a
correct configuration in place without duplicating or discarding anything. Values
a user has edited SHALL NOT be overwritten silently. State left behind by an
interrupted run SHALL not prevent a later run from completing.

#### Scenario: Initialization is run twice

- **WHEN** initialization runs on a repository that is already initialized and
  unmodified
- **THEN** the resulting configuration is unchanged
- **AND** the report states that the repository was already initialized

#### Scenario: The user has edited the configuration

- **WHEN** initialization runs on a repository whose configuration the user has
  edited
- **THEN** the edited values are preserved
- **AND** any newly detected capability is reported rather than written over the
  user's choices
- **AND** nothing is changed without being reported

#### Scenario: A previous run was interrupted

- **WHEN** initialization runs after an earlier attempt was interrupted partway
- **THEN** it completes successfully
- **AND** the resulting configuration is the same as if the earlier attempt had
  never happened

### Requirement: Initialization never modifies Git or in-progress work

Initialization SHALL NOT modify branches, the index, working tree contents, refs,
or stashes, and SHALL NOT create commits. It SHALL succeed while work is in
progress.

#### Scenario: The repository has uncommitted work

- **WHEN** initialization runs while worktrees contain staged, unstaged, and
  untracked changes
- **THEN** all of that work is left exactly as it was
- **AND** initialization succeeds

#### Scenario: Agents are running during initialization

- **WHEN** initialization runs while agent sessions are actively editing files
- **THEN** no agent's files are modified by initialization
- **AND** sessions already in progress are picked up by observation without being
  interrupted

#### Scenario: Initialization fails partway

- **WHEN** initialization fails after detection but before configuration is
  complete
- **THEN** the repository's Git state is unchanged
- **AND** the failure names what was and was not written

### Requirement: Agent integration is installed explicitly and reversibly

Initialization SHALL report any agent integration it installs, and SHALL provide a
way to remove it that leaves the agent's own configuration as it was. Installing
integration SHALL NOT alter unrelated agent settings.

#### Scenario: Agent integration is installed

- **WHEN** initialization configures a supported agent's integration
- **THEN** the report names the agent and what was added
- **AND** settings unrelated to OpenMerge are unchanged

#### Scenario: Agent integration is removed

- **WHEN** the user removes OpenMerge's agent integration
- **THEN** the agent's configuration returns to a state that does not reference
  OpenMerge
- **AND** the agent continues to work normally

#### Scenario: The agent's configuration is not writable

- **WHEN** an agent's configuration cannot be written
- **THEN** initialization still succeeds for the repository
- **AND** the report names the agent whose integration could not be installed and
  the fallback that applies
