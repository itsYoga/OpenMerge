## Purpose

Defines the versioned envelope that every machine-readable OpenMerge response
shares, so that agents, editors, and CI integrations can consume results without
knowing which adapters produced them, and so that adding adapters never breaks an
existing consumer.

## ADDED Requirements

### Requirement: Every machine-readable response uses the versioned envelope

A machine-readable response SHALL contain `protocol_version`, `command`, `status`,
`scope`, `snapshot_id`, `freshness`, `findings`, and `degraded_reasons`. `scope`
SHALL identify what the response covers by kind and identifier. `findings` and
`degraded_reasons` SHALL be present as empty collections rather than omitted when
there is nothing to report.

#### Scenario: A successful verification is reported

- **WHEN** a machine-readable verification response is produced
- **THEN** it contains all eight envelope fields
- **AND** `scope` names the kind of scope and its identifier
- **AND** `findings` and `degraded_reasons` are present even when empty

#### Scenario: A failing verification is reported

- **WHEN** a verification produces blocking findings
- **THEN** the envelope's `status` reflects the blocked outcome
- **AND** each finding appears in `findings` with its classification and evidence

#### Scenario: A degraded response is reported

- **WHEN** a response cannot be fully computed
- **THEN** `degraded_reasons` is non-empty and machine-readable
- **AND** `status` does not indicate a clear result

### Requirement: The envelope is extensible without a version change

Adapter-specific data SHALL appear only under an `extensions` object keyed by
adapter name. Adding an adapter, an `adapter_code`, an `evidence_kind`, a
`degraded_reasons` value, or a key under `extensions` SHALL NOT change
`protocol_version`. Consumers SHALL be able to ignore unrecognised extension keys
without losing the core semantics of the response.

#### Scenario: An adapter contributes structured detail

- **WHEN** an adapter has structured data beyond the core finding fields
- **THEN** that data appears under `extensions` keyed by the adapter's name
- **AND** none of it appears at the top level of the envelope

#### Scenario: A consumer meets an unknown adapter

- **WHEN** a consumer receives an envelope containing extension keys it does not
  recognise
- **THEN** it can still determine status, scope, freshness, and each finding's
  blocking state
- **AND** the unknown keys are ignorable without error

#### Scenario: A new evidence source is introduced

- **WHEN** a new `evidence_kind` or `adapter_code` is added to the product
- **THEN** `protocol_version` is unchanged
- **AND** existing pinned consumers continue to parse responses

### Requirement: Incompatible protocol versions are refused, never guessed

When a consumer requests a `protocol_version` OpenMerge cannot produce, the
request SHALL be refused with an error naming both the requested and the supported
versions. OpenMerge SHALL NOT emit a best-effort response in a version it does not
implement, and SHALL NOT silently downgrade or upgrade.

#### Scenario: A supported version is requested

- **WHEN** a consumer requests a protocol version OpenMerge implements
- **THEN** the response is emitted in exactly that version

#### Scenario: An unsupported version is requested

- **WHEN** a consumer requests a protocol version OpenMerge does not implement
- **THEN** the request is refused as a usage-or-configuration error
- **AND** the error names the requested version and the versions available
- **AND** no partial or approximated response is emitted

#### Scenario: No version is requested

- **WHEN** a consumer makes a request without specifying a protocol version
- **THEN** the response declares the version it was emitted in
- **AND** the consumer can detect a mismatch from the response itself

### Requirement: Freshness is always declared and never optimistic

Every response SHALL declare the freshness of the state it reports. When freshness
cannot be established, the response SHALL declare the state stale rather than
current.

#### Scenario: State is current

- **WHEN** a response is computed from snapshots that are still current
- **THEN** `freshness` declares the state current

#### Scenario: State is read from storage while the service is unavailable

- **WHEN** a response is assembled from durable storage because the observation
  service is unavailable
- **THEN** the response is still returned
- **AND** `freshness` declares the state stale
- **AND** `degraded_reasons` names the unavailable service

#### Scenario: Freshness cannot be determined

- **WHEN** it cannot be established whether the reported state is current
- **THEN** `freshness` declares the state stale
- **AND** the response is never presented as current

### Requirement: Scoped fields committed in version 1 are limited to stable semantics

Version 1 SHALL fix the envelope fields, the finding classification set, the
blocking rule, the gate exit codes, and the freshness semantics. It SHALL NOT fix
adapter diagnostic field layouts, language-specific symbol representations,
combination selection scoring, or durable storage layout. Those SHALL be free to
change without a protocol version increment, provided the envelope and its core
semantics are unchanged.

#### Scenario: Combination selection changes

- **WHEN** the way combinations are prioritised for verification is changed
- **THEN** `protocol_version` is unchanged
- **AND** existing consumers require no modification

#### Scenario: Durable storage layout changes

- **WHEN** the on-disk layout used to persist snapshots, findings, or evidence
  changes
- **THEN** `protocol_version` is unchanged
- **AND** the machine-readable responses remain identical in shape

#### Scenario: A committed semantic needs to change

- **WHEN** a change would alter the envelope fields, the classification set, the
  blocking rule, the gate exit codes, or freshness semantics
- **THEN** it requires a `protocol_version` increment
- **AND** the previous version's behaviour is documented for consumers still
  pinned to it
