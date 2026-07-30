# Architecture: OpenMerge

Realises the six capability specs. Decisions here are binding on implementation;
the ones that must not be quietly reversed are promoted to `adrs.md`.

## Architectural Goals

1. **Never mutate observed state.** No write to any user branch, index, working
   tree, ref, or stash, under any code path, including failure paths.
2. **Every verdict reproducible offline.** A finding must be re-derivable from
   persisted content without the daemon running.
3. **Deterministic evidence decides; generated text only explains.**
4. **Silence is cheap, noise is fatal.** The system does nothing visible until it
   has provable cause.
5. **Generic before specific.** A repository with `make test` and nothing else
   must work before any language adapter exists.
6. **Vendor-neutral core.** No core component may know that Claude Code, Codex, or
   Copilot exist.
7. **Local-first.** No network dependency for any core function.
8. **Survive an unclean kill.** `SIGKILL` at any instant must lose no finding.

## Non-Goals

- Merging code differently, or resolving conflicts.
- Detecting all semantic conflicts.
- Owning, creating, or destroying worktrees.
- Replacing CI, review, merge queues, or build systems.
- Running agents, or mediating their writes.
- Cross-repository coordination in this change.
- Guaranteeing that an agent runtime honours a gate verdict.

## System Context

```
┌──────────────────────────────────────────────────────────────┐
│  Agents (untrusted)  Claude Code │ Codex │ Copilot │ other    │
└───────────┬──────────────────────────────────┬───────────────┘
            │ lifecycle hooks (thin)           │ writes files
            ▼                                  ▼
     ┌──────────────┐                  ┌───────────────────┐
     │ omrg (CLI)   │◀── unix socket ──│  omrg daemon      │
     │ user-facing  │      IPC         │  one per repo     │
     └──────────────┘                  └─────┬─────────────┘
                                             │
        ┌────────────────────────────────────┼──────────────────┐
        ▼                ▼                   ▼                  ▼
  ┌──────────┐    ┌────────────┐     ┌────────────┐    ┌─────────────┐
  │ Snapshot │    │   Graph    │     │  Planner   │    │  Executor   │
  │  engine  │    │            │     │            │    │ (sandboxed) │
  └────┬─────┘    └─────┬──────┘     └─────┬──────┘    └──────┬──────┘
       │                │                  │                  │
       │          ┌─────▼──────────────────▼─────┐             │
       │          │        Adapters              │             │
       │          │ generic │ typescript │ rust  │             │
       │          └──────────────────────────────┘             │
       ▼                                                       ▼
  ┌──────────────────────────────────────────────────────────────┐
  │  Store: append-only events · SQLite projections · CAS objects │
  └──────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────▼────────────┐
                    │ Git repository (read)  │
                    │ never written           │
                    └────────────────────────┘
```

### Component Map

| Component | Owns | Must not |
| --- | --- | --- |
| `openmerge-cli` | argument parsing, terminal rendering, exit codes | contain verification logic |
| `openmerge-daemon` | scheduling, session registry, event bus, ownership | parse language sources |
| `openmerge-protocol` | envelope, IPC, versioning | depend on any other component |
| `openmerge-git` | Git plumbing, worktree discovery | know about agents or adapters |
| `openmerge-snapshot` | dirty capture, synthetic trees, snapshot identity | run checks |
| `openmerge-store` | events, projections, content-addressed objects | interpret findings |
| `openmerge-graph` | impact graph, incremental update | contain language logic |
| `openmerge-planner` | combination selection, risk scoring, check plans | execute anything |
| `openmerge-executor` | isolation, resource limits, process trees | decide what to run |
| `openmerge-evidence` | classification, attribution, reproduction bundles | run checks or select combinations |
| `openmerge-policy` | trust modes, gate configuration | be bypassable by an adapter |
| `openmerge-adapter-*` | language and contract knowledge | write to the store or publish findings |
| `openmerge-agent-*` | translating one vendor's hook events | contain judgement of any kind |

### Forbidden Dependencies

These are compile-time constraints, enforced by CI, not conventions.

- `openmerge-{core,snapshot,graph,planner,executor,evidence,store,policy}` **MUST
  NOT** depend on any `openmerge-adapter-*` or `openmerge-agent-*` crate.
  Dependencies point inward only; adapters are injected as trait objects.
- No crate except `openmerge-executor` **MAY** spawn a process that runs
  repository content.
- No crate except `openmerge-git` and `openmerge-snapshot` **MAY** invoke Git.
- `openmerge-adapter-*` **MUST NOT** depend on `openmerge-store`. Adapters return
  values; they never persist.
- No core crate **MAY** depend on any component that consumes model output.
- `openmerge-protocol` **MUST** be a leaf: it depends on nothing in the workspace.

## Trust Boundaries

Four boundaries. Everything crossing inward is untrusted.

| # | Boundary | Untrusted input | Enforced by |
| --- | --- | --- | --- |
| 1 | Repository content → analysis | file contents, paths, filenames, branch names, symlinks, submodule refs | path canonicalisation, no shell interpolation, size limits |
| 2 | Repository content → configuration | `.openmerge/config.yaml`, check commands, adapter selection arriving on a branch | branch-supplied config is not trusted for execution until approved |
| 3 | Combined tree → execution | agent-generated code, dependency install scripts, build scripts, test code | sandboxed executor, network denied, no inherited credentials |
| 4 | Agent runtime → daemon | hook payloads, session identifiers, paths | schema validation, repository-scope check, no privilege from being a hook |

**The dangerous one is boundary 3.** OpenMerge exists to build and run
combinations of code written by autonomous agents. That is arbitrary code
execution as a core feature. Design consequence: **the executor's default is
container isolation with no network and no inherited credentials, and host
execution requires explicit opt-in per repository.**

**Boundary 2 is the subtle one.** A check command is configuration, and
configuration can arrive on a branch an agent wrote. A branch that can define
`checks[].command` and have it executed on the host is a remote code execution
path. Therefore: check definitions are read from the configuration at the
**observed worktree's base**, and a change to a check definition inside an
agent's snapshot does not take effect for that snapshot's verification.

## Process Model

### Single Binary

**Decision: exactly one distributed executable, `omrg`.** The daemon is a mode of
the same binary, reached through an internal subcommand:

```
omrg daemon --repo <git-common-dir>
```

`daemon` is hidden from the top-level help. Mode selection is by subcommand only
— **never by `argv[0]` inspection**, which is fragile under symlinks, shells that
rewrite argv, and process supervisors.

No second `openmerged` executable is published. Consequences: the CLI and the
daemon can never disagree about version; Homebrew, Cargo, and release signing
maintain one artifact; upgrade cannot leave a stale daemon binary behind; a user
has one name to learn.

`openmerged` survives only as prose for "the daemon mode of `omrg`". It is not an
installable name.

### Repository-Scoped Daemon

**Decision: one daemon per Git repository, not one per user account and not one
per worktree.** Linked worktrees of the same repository share a daemon — this is
the whole point, since coordination between worktrees is the product.

Identity comes from the common Git directory, never from the current path:

```
git rev-parse --path-format=absolute --git-common-dir
```

A global daemon was rejected: it would need to hold state for repositories the
user is not working in, its crash would take down every repository at once, and
its resource ceiling could not be reasoned about. A per-worktree daemon was
rejected outright: each worktree would observe only itself, which is the absence
of the product.

### Runtime Paths

Two locations with two different owners.

```
<git-common-dir>/openmerge/          # runtime state — ours, never committed
├── daemon.lock                      # ownership, held for the daemon's lifetime
├── daemon.sock                      # IPC endpoint (named pipe on Windows)
├── daemon.pid
├── state.db                         # SQLite, WAL
├── objects/                         # content-addressed evidence, logs, trees
├── findings/
├── reproductions/
├── agent-feedback/                  # the durable channel the gate writes
└── logs/

<worktree>/.openmerge/               # project configuration — the user's
└── config.yaml
```

Runtime state lives in the common directory because it is shared across
worktrees; putting it in each worktree's `.openmerge/` would let two worktrees
each start a daemon and coordinate nothing. Configuration lives in the worktree
because it is versioned with the code.

`.openmerge/` in a worktree is gitignored for state but `config.yaml` is intended
to be committed.

### CLI-to-Daemon IPC

Unix domain socket, named pipe on Windows. Filesystem permissions restrict it to
the owning user; there is no network listener.

Every connection begins with a handshake:

```json
{
  "protocol_version": 1,
  "client_version": "0.1.0",
  "repository_id": "repo_...",
  "command": "handshake"
}
```

**Decision: on version incompatibility the CLI does not kill the daemon.** It
reports the mismatch, names both versions, and tells the user how to restart.
Automatically terminating a process that may be mid-execution on someone else's
behalf is not a client's decision to make.

- `omrg watch --restart` is the only path that stops a running daemon.
- `omrg status` still works against an incompatible or absent daemon by reading
  `state.db` and `findings/` directly, and reports `freshness: stale` with the
  reason in `degraded_reasons`.
- `omrg check` and `omrg gate` require a compatible daemon; `gate` exits 3
  (`inconclusive_or_degraded`) rather than 0 when it cannot obtain one.

### Lifecycle and Recovery

```
omrg watch
  → resolve git-common-dir
  → try acquire daemon.lock
      acquired      → become daemon supervisor, spawn `omrg daemon`
      already held  → connect to daemon.sock
  → handshake
      compatible    → stream state, render watch UI
      incompatible  → report, suggest --restart, exit 4
  → connection refused but lock held (stale lock from SIGKILL)
      → verify holder liveness, reclaim lock, spawn daemon, report recovery
```

Lock staleness is decided by holder liveness, not by timestamp. A lock file whose
recorded process is gone is reclaimable; a lock whose process is alive is never
stolen.

## Repository Identity and Runtime Paths

**Decision: local runtime identity is the absolute common Git directory.**
A persisted `repository_id` is an opaque identifier stored in `state.db` on first
initialization and never derived from a path, so that moving a repository does not
invalidate its history.

- Worktree paths are **not** identity. A worktree may move or be removed.
- Two clones of the same upstream are **different** local repositories by default.
  Sharing state between them is a cross-repository concern, deferred.
- `repository_id` accompanies every snapshot reference in the protocol.
  `snapshot_id` is unique within a repository only.

## Core Domain Model

```rust
struct Repository {
    id: RepositoryId,          // opaque, persisted
    common_dir: PathBuf,       // local runtime identity
    default_branch: String,
    object_format: ObjectFormat, // sha1 | sha256
}

struct Worktree {
    id: WorktreeId,
    path: PathBuf,             // mutable, not identity
    head: ObjectId,
    base_branch: Option<String>,
}

struct AgentSession {
    id: SessionId,
    agent_kind: AgentKind,     // opaque to core; adapters map onto it
    worktree_id: WorktreeId,
    change_id: Option<ChangeId>, // intent, when available
    state: SessionState,
}

struct Snapshot {
    id: SnapshotId,            // content address, see below
    repository_id: RepositoryId,
    worktree_id: WorktreeId,   // provenance, NOT part of identity
    base_commit: ObjectId,
    tree_oid: ObjectId,
    synthetic_commit: ObjectId, // for Git merge only
    changed_artifacts: Vec<ArtifactChange>,
}

struct IntegrationScenario {
    id: ScenarioId,
    members: Vec<SnapshotId>,
    merge_order: MergeOrder,   // Canonical | Ordered(Vec<SnapshotId>)
    reason: SelectionReason,   // why this combination was chosen
    check_plan: CheckPlanId,
}

struct CheckPlan {
    id: CheckPlanId,
    checks: Vec<PlannedCheck>,
    adapter_versions: BTreeMap<AdapterId, Version>,
    executor_profile: ExecutorProfileId,
}

struct Evidence {
    check_id: CheckId,
    command: Vec<String>,      // argv, never a shell string
    exit_code: i32,
    diagnostics: Vec<Diagnostic>,
    log_object: ObjectId,      // content-addressed, truncated with marker
}

struct Finding {
    id: FindingId,             // stable, derived from the problem
    classification: Classification,
    evidence_kind: EvidenceKind,
    adapter: Option<AdapterId>,
    adapter_code: Option<String>,
    members: Vec<SnapshotId>,
    baselines: BTreeMap<SnapshotId, BaselineResult>,
    owner_session: Option<SessionId>,
    evidence: Vec<Evidence>,
    reproduction: ReproductionRecipe,
    status: FindingStatus,     // open | closed | stale
}

struct GateVerdict {
    scope: Scope,
    status: GateStatus,        // clear | blocked | inconclusive_or_degraded | disabled
    snapshot_ids: Vec<SnapshotId>,
    blocking: Vec<FindingId>,
    degraded_reasons: Vec<DegradedReason>,
}
```

## Snapshot Identity and Materialization

The load-bearing section: everything downstream is keyed on getting this right.

### Three Distinct Concepts

**Decision: `tree_oid`, `synthetic_commit_oid`, and `snapshot_id` are three
different things and must never be conflated.**

| Concept | What it is | Public? |
| --- | --- | --- |
| `tree_oid` | Git tree of the materialized content | internal |
| `synthetic_commit_oid` | commit wrapping that tree, so Git can do ancestry-aware merges | internal |
| `snapshot_id` | OpenMerge's versioned content address | **yes, in the protocol** |

### Dirty Worktree Capture

`git merge-tree` operates on commits and ignores untracked files. Agent work in
progress is precisely untracked-and-uncommitted. So capture happens first:

```
HEAD tree
  + staged modifications
  + unstaged modifications to tracked files
  + untracked files (respecting ignore rules)
  + deletions
  + renames
  + mode bits (executable)
  + symlinks as symlinks
  + submodule commit references (gitlinks, not contents)
        ↓
  isolated temporary index   ← GIT_INDEX_FILE points here, never the real index
        ↓
  git write-tree             → tree_oid
        ↓
  git commit-tree            → synthetic_commit_oid, parent = base_commit
```

The temporary index is created in `<git-common-dir>/openmerge/` and removed after
use. **The real index is never opened for writing.** No `git add`, no `git stash`,
no `git checkout`, no ref update, at any point, including error paths.

Objects written by `write-tree` and `commit-tree` land in the repository's object
database and are unreachable from any ref. They are therefore garbage-collectable
by the user's own `git gc`, which is acceptable: a collected snapshot invalidates
its cached results, which is a cache miss, not corruption. `omrg gc` prunes our
own references to objects that no longer exist.

### Snapshot ID

**Decision: `snapshot_id` is a versioned hash of a canonical payload, not a Git
OID.**

```
snapshot_id = "snap_v1_b3_" || blake3(canonical_payload)
```

```json
{
  "version": 1,
  "git_object_format": "sha1",
  "base_commit_oid": "abc123...",
  "tree_oid": "def456..."
}
```

Canonicalisation: sorted keys, no insignificant whitespace, UTF-8, lowercase hex.

**Why not the synthetic commit OID.** A commit OID absorbs author, committer,
timestamp, and message. Two snapshots with byte-identical content would get
different commit OIDs across runs, destroying the cache and making results
irreproducible. The synthetic commit exists only so Git can compute merge bases.

**Why the base commit is included.** Identical final trees on different ancestry
have different integration semantics: different merge bases, different rename
detection, different three-way results against the same peer. So:

```
tree_oid equal  ≠  integration identity equal
```

**Deliberately excluded from the hash:** worktree path, agent vendor, session id,
OpenSpec change id, timestamps, configuration hash, check definitions, adapter
versions, operating system. None of them are properties of the snapshot's content,
and including any of them would fragment the cache for no semantic gain.

`git_object_format` is included because a `sha1` and a `sha256` repository can
produce colliding-looking OID strings of different meaning.

**Protocol promise, deliberately weak:** `snapshot_id` is an opaque,
deterministic identifier for a repository-scoped snapshot consisting of a base
commit and a materialized tree. The hash function and payload are **not** part of
the contract and may change under a `snap_v2_` prefix without a protocol version
bump. Consumers must treat it as an opaque string, compare only for equality, and
always carry the accompanying `repository_id`.

### Analysis Cache Key

Distinct from snapshot identity, because a result depends on more than content:

```
analysis_key = hash(
    snapshot_id
  + sorted(peer_snapshot_ids)
  + check_plan_hash
  + adapter_versions
  + executor_profile
)
```

An adapter upgrade or a changed check plan therefore invalidates results without
invalidating snapshots. This separation is why upgrading OpenMerge does not
re-snapshot the world.

### Immutability

A snapshot is immutable once created. Content change produces a **new** snapshot:

```
snap_1 → snap_2 → snap_3
```

`snap_1` is never repointed at a new tree. Findings and scenarios reference
specific snapshot ids, so history stays interpretable and a finding can always
name the exact content it was computed from.

### Scenario Identity

```
scenario_id = hash(
    member_snapshot_ids  (canonically sorted when order is irrelevant,
                          preserved when merge order affects the result)
  + merge_order
  + check_plan_hash
  + executor_profile
)
```

Merge order matters whenever a member's changes interact with ordering — schema
migrations being the obvious case. When it matters, `merge_order` is
`Ordered(..)` and members are not sorted. When it does not, canonical sorting
prevents verifying `A+B` and `B+A` as two scenarios.

## Event Model and Persistent State

**Decision: daemon memory is not the source of truth.**

```
append-only event log      ← the authority
        ↓ fold
SQLite projections         ← queryable state, rebuildable
        +
content-addressed objects  ← evidence, logs, trees
```

Events:

```
session.started · session.intent_attached · worktree.discovered
filesystem.changed · snapshot.created · graph.updated
scenario.planned · check.started · check.completed
finding.created · finding.updated · finding.resolved · finding.staled
gate.requested · gate.answered · plan.created
```

### Crash Recovery

| State | Durable? | On restart |
| --- | --- | --- |
| Event log | yes, fsynced before acknowledgement | replayed |
| SQLite projections | yes, WAL | rebuilt from events if inconsistent |
| Evidence, logs | yes, content-addressed, written before the event referencing them | verified by hash |
| In-flight executions | no | abandoned; rescheduled if inputs still current |
| Graph | no | rebuilt incrementally, cached |

**Guarantee: a finding that was reported to a user is never lost to an unclean
shutdown.** Ordering: evidence object is written and fsynced, then the
`finding.created` event is appended and fsynced, then the finding becomes
visible. A crash between steps leaves an unreferenced object, which `omrg gc`
reclaims — never a finding referencing evidence that does not exist.

If the event log itself is unreadable, the daemon reports degraded with the
affected range named and **does not** report an absence of findings.

## Repository Graph

Three layers, in strictly decreasing trust:

1. **Deterministic, no language knowledge** — Git diffs, workspace manifests,
   lockfiles, project references, migration directories, route and env
   declarations, CI configuration.
2. **Syntactic** — incremental parse trees for symbol-level edges.
3. **Toolchain** — compiler, type checker, or build-system queries. Authoritative
   but expensive; consulted for verification, not for graph maintenance.

Node kinds: repository, package, file, symbol, endpoint, table, column, migration,
environment variable, route, feature flag, CI resource, test, requirement, change.
Edge kinds: contains, imports, exports, calls, implements, provides, consumes,
reads, writes, migrates, verifies, declared_by, depends_on.

**Generated analysis never contributes graph edges.** The graph is an input to
selection, selection determines what gets executed, and execution determines
verdicts. An inferred edge would make a verdict depend on inference.

## Adapter Architecture

```rust
trait RepositoryAdapter {
    fn id(&self) -> AdapterId;
    fn version(&self) -> Version;
    fn maturity(&self) -> Maturity;   // Stable | FirstClass | Experimental

    fn detect(&self, repository: &Repository) -> DetectionResult;

    fn build_graph(&self, snapshot: &Snapshot) -> Result<AdapterGraph>;

    fn plan_checks(
        &self,
        scenario: &IntegrationScenario,
        graph: &CombinedGraph,
    ) -> Result<Vec<PlannedCheck>>;

    fn parse_evidence(&self, result: &CheckResult) -> Result<Vec<Evidence>>;
}
```

Adapters are pure: they receive snapshots and graphs, return values. They cannot
write to the store, publish findings, spawn processes, or reach the network.

### Levels

**Level 0 — generic command.** Works everywhere, understands nothing:

```yaml
checks:
  - id: build
    command: make build
  - id: test
    command: make test
```

**Level 1 — workspace graph.** Package boundaries, dependency graph, affected
targets.

**Level 2 — contract-aware.** Public type changes, project references, generated
clients, API and schema relations.

### First Adapters

| Adapter | Level | Maturity |
| --- | --- | --- |
| `generic-command` | 0 | stable |
| `typescript` | 2 | **first-class** |
| `rust-workspace` | 1 | experimental / dogfood |

**Decision: TypeScript is the first complete first-class adapter, even though
OpenMerge is written in Rust.** Implementation language must not choose the ideal
customer profile. A typical TypeScript monorepo holds frontend, backend, shared
packages, exported types, API contracts, database schema, and generated clients in
one dependency graph — the densest available environment for clean-merge
integration failures.

TypeScript scope: pnpm/npm/yarn workspaces, package dependency graph, `tsconfig`
project references, import/export edges, public type surface changes,
`package.json` exports, generated clients, OpenAPI/GraphQL/Prisma relations,
affected typecheck and test selection.

`rust-workspace` deliberately stops at Level 1 — `cargo metadata`, workspace
members, crate dependency graph, changed crates, affected reverse dependencies,
`cargo check -p`, `cargo test -p`, `cargo clippy -p`. Enough to dogfood OpenMerge
on itself; **not** a claim of complete Rust integration analysis. Public API
breaks, feature unification, and build-script effects are acknowledged gaps.

### Adapter Versioning and Failure

Adapter version participates in `analysis_key`, so an adapter upgrade invalidates
cached results without touching snapshots.

**Adapter failure never becomes a code defect.** An adapter that panics, times
out, or cannot handle a repository yields `execution_error` or `inconclusive` —
**never** `integration_failure`. Adapters run in-process for now, so a panic is
caught at the boundary and converted; out-of-process adapters are a deferred
decision.

## Scenario Planning

Exhaustive combination is impossible: 20 sessions is 190 pairs and 1,140 triples.

Filters, in increasing cost:

1. **Path** — same package, shared configuration, root manifests, schema or
   generated-code directories.
2. **Dependency** — one change modifies a package another imports.
3. **Contract** — one provides an interface another consumes.
4. **Intent** — declared dependencies between changes, when intent is available.

Risk score inputs: path overlap, dependency distance, contract relation, shared
resource, declared relation, historical failure rate for the pair, recency.
**Generated analysis contributes nothing to the score.** Weights are configurable
and reported; the formula is explicitly *not* part of the protocol.

Combination breadth, in priority order:

1. Pairs involving the session that just changed — the hot path.
2. Connected components of the risk graph, as batches.
3. Before a gate: the session under gate against all active peers it relates to.
4. Before a merge plan: ordered prefixes of the proposed order.
5. When idle: wider combinations, lowest priority, always pre-emptible.

Higher-order failures (`A+B` pass, `A+C` pass, `B+C` pass, `A+B+C` fails) are
reachable through steps 2 and 5. Power-set enumeration is never attempted, and
the limitation is stated to users rather than hidden.

### Cancellation

**Decision: a superseded run may finish, but must not publish.**

```
snapshot supersedes an in-flight run
  → cancellation requested (cooperative, then process-tree kill on timeout)
  → any completed result is stored under its analysis_key as cache/history
  → freshness re-checked immediately before publication
  → stale results are never published as current findings
```

Freshness is re-checked at publication time, not at scheduling time, because the
gap between them is exactly where a stale finding would slip through.

## Execution Architecture

```rust
trait Executor {
    fn prepare(&self, scenario: &IntegrationScenario) -> Result<Environment>;
    fn run(&self, check: &PlannedCheck, env: &Environment) -> Result<CheckResult>;
    fn cleanup(&self, env: Environment) -> Result<()>;
}
```

Planning and execution are separate: the planner never knows where a check runs,
the executor never decides what to run.

| Profile | Default | Isolation |
| --- | --- | --- |
| `container` | **yes** | network denied, no host credentials, read-only dependency cache, isolated writable filesystem, CPU/memory/disk quotas, wall-clock timeout, process-tree kill |
| `host` | no — explicit opt-in per repository | none; only for repositories the user declares trusted |
| `existing-environment` | no | detected devcontainer/compose/Nix definition |
| `remote` | no | out of scope for this change |

**Decision: hook processes never execute builds.** A hook emits an event or reads
a persisted verdict, and returns. All execution happens in the daemon's executor.
This is what keeps hooks thin, and it is also what keeps a compromised hook from
being an execution vector.

Commands are always `argv` vectors. No shell interpolation anywhere. Paths,
branch names, and session identifiers are never concatenated into a command
string.

Process-tree termination is mandatory, not best-effort: build tools spawn
children that outlive a killed parent, and a leaked test server holding a port
would corrupt later runs.

## Evidence Classification

Classification is mechanical, from observed facts only:

```
merge failed textually                         → textual_conflict     (git)
any member failed alone                        → baseline_failure     (member's kind)
all members passed, combination failed         → integration_failure  (failing check's kind)
tool missing / timeout / executor failure      → execution_error
result not reproducible                        → inconclusive (unstable_result)
otherwise                                      → pass
```

Blocking requires all five conditions from `finding-model`. Attribution: the
owning session is the one whose snapshot, when removed from the combination,
makes the failure disappear — determined by re-verification, not by heuristic,
and left unattributed when it cannot be determined that way.

Reproduction bundles record the member snapshot ids, merge order, resolved
`argv`, executor profile, adapter versions, and environment allowlist — enough
for `omrg reproduce <id>` to work offline. Logs are content-addressed and
truncated with an explicit marker; evidence is never rewritten, by any component.

## Finding Publication and Freshness

```
finding produced
  → freshness re-check against current snapshots
      stale    → record, mark stale, do not notify
      current  → dedupe by finding id
                   existing open   → update, do not re-notify
                   existing closed → reopen, notify
                   new             → notify once
  → write agent-feedback for the owning session
```

Notification is once per finding per state transition. A finding that stays open
and unchanged never notifies again — the single most important behaviour for
surviving daily use.

## Agent Integration

One canonical internal event vocabulary; per-vendor adapters translate onto it and
contain no judgement:

```
session.start · session.end · tool.completed(paths)
file.changed(paths) · worktree.created · agent.stopping
```

Vendor asymmetries, all verified in `research.md`, and how they are absorbed:

| Vendor fact | Architectural response |
| --- | --- |
| Copilot overrides a blocking stop hook after 8 consecutive blocks | the gate is best-effort; `agent-feedback/` is the durable channel |
| Copilot hook timeouts fail open | the gate must be fast enough to return, and its absence must not read as `clear` |
| Claude Code exposes `FileChanged` with `watchPaths`, and `WorktreeCreate` | preferred event source where available; the filesystem watcher is the portable fallback |
| Claude Code runs matching hooks in parallel | hooks must be idempotent and independently safe |
| Vendor hook timeout defaults are 600 s / 600 s / 30 s | not a budget. **Our own SLO is what binds us**, below |
| Hooks inherit the agent's full environment, including tokens | the daemon does not trust hook-supplied environment, and the executor never inherits it |

**Filesystem watching is never removed**, even where hooks are richer: an agent
without hooks, a human editing in an editor, and a script all produce changes
that no hook reports.

### Latency Budgets

Our SLOs, not vendor requirements:

| Stage | Budget |
| --- | --- |
| Hook round-trip, cached answer | < 200 ms |
| Filesystem event → ingested | < 500 ms |
| Snapshot creation | < 2 s |
| Incremental graph update | < 2 s |
| Cached scenario result lookup | < 100 ms |
| Gate answer from persisted state | < 500 ms |
| Daemon idle CPU | < 1% |
| Daemon idle resident memory | < 150 MB |

Verification itself is unbounded — it runs the repository's real checks. The
architecture's job is to run fewer of them, reuse results, and cancel work that
no longer matters.

## OpenSpec Integration

**Decision: intent is an input, never a requirement.** OpenSpec supplies change
intent, declared dependencies, requirements, and scenarios. Every core capability
must function fully without it; a repository with no OpenSpec loses only the
intent-based planning filter and spec-level findings.

The adapter reads change directories and produces a normalised intent manifest:
declared scope, provided and consumed contracts, dependencies between changes, and
requirement identifiers. Cross-repository planning is Beta upstream with
explicitly unstable formats, so that adapter is version-isolated and optional.

## Machine Protocol

`openmerge-protocol` is a leaf crate depending on nothing else in the workspace,
so that no component can ship a response shape the protocol does not define.

```json
{
  "protocol_version": 1,
  "command": "check",
  "status": "blocked",
  "scope": { "kind": "session", "id": "sess_123" },
  "repository_id": "repo_7f2a",
  "snapshot_id": "snap_v1_b3_n7yx",
  "freshness": "current",
  "findings": [],
  "degraded_reasons": [],
  "extensions": {}
}
```

Version 1 fixes the envelope, the classification set, the blocking rule, the gate
exit codes, and freshness semantics. It deliberately does not fix adapter
diagnostic layouts, symbol representations, risk-score formulas, or storage
layout. Those live under `extensions`, keyed by adapter, or outside the contract.

## Security Model

Beyond the trust boundaries above:

- Default deny for network in the executor. No exceptions without explicit
  repository configuration.
- Never mount `~/.ssh`, cloud credential directories, or the agent's token
  environment into an execution environment.
- Dependency caches mount read-only.
- Redact secret-shaped strings from logs and evidence before persisting, and
  bound log size.
- Branch-supplied configuration is not trusted for execution; check definitions
  come from the observed base.
- IPC socket is user-only; no network listener exists.
- Trust modes: `observe-only` (no execution at all), `sandboxed` (default),
  `trusted` (host execution, explicit opt-in), `remote` (deferred).

The full inventory belongs in `threat-model.md`.

## Failure and Degraded Modes

**Principle: every degradation is named in `degraded_reasons` and reduces
confidence explicitly. Nothing is ever simulated.**

| Condition | Behaviour |
| --- | --- |
| Daemon absent | `status` reads persisted state, `freshness: stale`; `gate` exits 3 |
| Protocol mismatch | report both versions, exit 4, never kill the daemon |
| Watcher unavailable | report degraded; do not claim those worktrees are observed |
| Container runtime absent | no silent fallback to host; exit 3 with the reason |
| Check tool missing | `execution_error` naming the tool; nothing blocks on it |
| Adapter panic | caught at the boundary, converted, adapter marked degraded |
| Snapshot capture failure | recorded per worktree; others keep working |
| Store corruption | degraded with the affected range; never reported as "no findings" |
| Disk full | stop accepting new work, keep serving persisted state, say so |

## Performance and Caching

| Cache | Key | Invalidated by | Why correct |
| --- | --- | --- | --- |
| Snapshot | `snapshot_id` | never (content-addressed) | identity is the content plus its base |
| Baseline result | `analysis_key` with empty peers | adapter, plan, or profile change | all inputs are in the key |
| Scenario result | `analysis_key` | any member snapshot, plan, adapter, or profile change | ditto |
| Graph | snapshot + adapter version | incremental invalidation per changed file | rebuild is always possible |
| Merge result | member `tree_oid`s + base commits | never | pure function of Git objects |

**Every cache key contains every input that can change the result.** Where that
cannot be guaranteed — the executor's ambient environment being the honest
example — the profile identifier is part of the key and changing the environment
without changing the profile is a documented way to get a stale answer.

## Cross-Platform Behavior

Linux and macOS are first-class. Windows targets core CLI parity, with the daemon
and container executor following.

Known hazards, all requiring fixtures rather than assumptions: case-insensitive
and case-preserving filesystems, Unicode normalisation differences in filenames,
symlink support and privilege, executable bit absence, path length limits, named
pipes instead of Unix sockets, `SIGKILL`-equivalent process-tree termination,
CRLF and `.gitattributes` filters, sparse checkouts, submodules, and Git LFS
pointers (pointers are content; LFS objects are not fetched).

## Compatibility and Migrations

| Surface | Contract |
| --- | --- |
| Command names, flags, exit codes | breaking change requires a major version |
| Protocol envelope and core semantics | `protocol_version` increment |
| `snapshot_id` construction | prefix change (`snap_v2_`), no protocol bump; treated as cache invalidation |
| `finding_id` derivation | breaking change requires a protocol bump, because users cite them |
| `state.db` schema | forward-only migrations, version recorded, refuse to open a newer version rather than guess |
| Configuration schema | additive; unknown keys warn, never fail |
| Content-addressed objects | append-only, prunable |

A newer `state.db` opened by an older binary must produce an explicit
version-mismatch error, never a partial read.

## Rejected Alternatives

**A separate `openmerged` executable.** Rejected: two artifacts to sign and
distribute, the possibility of a version-skewed pair, and a second name for users
to learn, in exchange for nothing.

**`argv[0]`-based mode dispatch.** Rejected: fragile under symlinks, shells that
rewrite argv, and supervisors; a hidden subcommand is explicit and testable.

**One global daemon per user.** Rejected: holds state for repositories not in use,
one crash affects all repositories, and its resource ceiling cannot be reasoned
about.

**One daemon per worktree.** Rejected outright: each would see only itself, which
eliminates the product.

**`snapshot_id` = synthetic commit OID.** Rejected: absorbs author, committer,
timestamp, and message, so identical content yields different identifiers across
runs, destroying cache reuse and reproducibility.

**`snapshot_id` = `tree_oid` alone.** Rejected: identical trees on different
ancestry have different integration semantics.

**Hashing our own normalised file list instead of using Git's tree.** Rejected:
requires inventing a canonicalisation for modes, symlinks, submodules, and
ordering that Git already defines and that every Git tool already agrees on.

**Committing agent work to real branches to enable merging.** Rejected: violates
the non-mutation invariant, which is the product's licence to operate.

**Host execution by default.** Rejected: OpenMerge executes agent-generated code;
the fast posture cannot also be the default posture.

**Language-server or compiler daemon as the graph source of truth.** Rejected for
graph maintenance: too slow and too stateful for per-edit updates. Retained as an
authoritative verification input.

**Generated analysis contributing graph edges or risk scores.** Rejected: it would
make a blocking verdict depend on inference, transitively.

**Killing an incompatible daemon automatically.** Rejected: it may be mid-execution
for another caller; that is not a client's decision.

**Rust as the first first-class adapter.** Rejected as a market decision, accepted
as a dogfooding one: the implementation language should not select the customer.

## Architectural Risks

1. **Combination selection precision is unproven.** If risk scoring is wrong, the
   product either misses failures or verifies too much and becomes slow. The
   benchmark must measure selection quality separately from detection.
2. **Container executor cost on real monorepos** may exceed what a laptop
   tolerates. Mitigation is check selection and cache reuse; the residual risk is
   that some repositories are simply too large for local verification.
3. **Attribution by re-verification doubles execution** for attributed findings.
   Acceptable for blocking findings, possibly not for all.
4. **Untracked-file capture is the highest-risk correctness surface.** Ignore
   rules, symlinks, submodules, and LFS pointers each have a wrong-by-default
   interpretation. This is where a mutation bug would most plausibly hide.
5. **Adapters in-process** mean a panic is a daemon-wide event until the boundary
   catch is proven by fuzzing.
6. **Vendor hook surfaces will change.** The canonical event vocabulary is the
   hedge; it is unproven against a vendor that removes an event we depend on.

## Decisions Deferred

- Out-of-process adapters and a plugin ABI.
- Remote executor and distributed cache.
- Cross-repository snapshots and coordinated planning.
- Local web UI transport and authentication.
- Automatic merge execution.
- Flaky-result detection mechanism (results are `inconclusive` until it exists).
- Windows container executor.
