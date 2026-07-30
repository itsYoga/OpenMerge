# OpenMerge

**Keep parallel coding agents continuously integratable.**

Each agent succeeds on its own. That is not the same as the product working
after all of them are combined.

OpenMerge watches the agents that are working *right now*, understands what each
one intends to change, builds throwaway combined versions of their in-progress
work, runs verifiable checks against those combinations, and hands reproducible
failure evidence back to the agent that caused the problem — before a human
starts reviewing anything.

```
intent → change → impact → combination → verification → repair → safe integration
```

> **Status: pre-implementation.** This repository currently contains the
> spec-driven workflow that the product is being designed through. There is no
> installable binary yet.

## What it is not

| Mistaken for | Difference |
| --- | --- |
| Worktree manager | OpenMerge does not create or own your worktrees; it observes them. |
| Merge queue | Merge queues act on finished PRs. OpenMerge acts while agents are still working. |
| Git conflict detector | Textual conflicts are the easy case. The interesting failures merge cleanly. |
| AI code reviewer | Blocking verdicts come from compilers, schemas, and tests — not from a model's opinion. |
| CI dashboard | CI reports what happened. OpenMerge decides which combinations are worth running at all. |
| Coding agent | It coordinates agents; it does not write your features. |
| Semantic merge algorithm | It does not merge code differently; it verifies that a normal merge still works. |

It is the coordination layer *between* those tools.

## Standing constraints

These are not aspirations. They are the rules the design is held to:

- **Deterministic evidence before probabilistic interpretation.** A model may
  explain a failure or suggest a fix; it may never be the sole basis for a
  blocking finding.
- **Never mutate user state.** No writes to your branches, index, worktree,
  refs, or stashes. Ever.
- **Local-first.** Source code does not leave the machine unless you explicitly
  configure remote execution. Nothing requires an account.
- **Agent-agnostic.** Core components must not depend on any single agent vendor.
- **Generic before specific.** Plain command checks work before any
  language-specific adapter exists.
- **Everything reproduces.** Every verdict traces to an immutable,
  content-addressed snapshot and a command you can re-run offline.
- **Quiet by default.** When nothing is actually wrong, you hear nothing.
- **Sandboxed by default.** OpenMerge executes agent-generated code; the safe
  posture is the default and the fast one is opt-in.

## Command surface

Deliberately small. Five commands you use daily:

```
omrg init      # detect repository, worktrees, build system, agents; write config
omrg watch     # start the daemon and follow active agents
omrg status    # active agents, changes, findings
omrg check     # verify integration scenarios now
omrg gate      # can this agent safely finish?
```

Secondary:

```
omrg explain <finding>
omrg reproduce <finding>
omrg plan
omrg doctor
omrg config
```

Inside an AI assistant, the same capabilities live under `/omrg:*` —
`/omrg:status`, `/omrg:check`, `/omrg:explain`, `/omrg:resolve`, `/omrg:gate`,
`/omrg:plan`. This pairs with a spec workflow such as OpenSpec's `/opsx:*`:
`opsx` decides *what to build*, `omrg` decides *whether the parallel changes can
safely coexist*.

## Naming

| Layer | Name |
| --- | --- |
| Product | OpenMerge |
| Terminal binary | `omrg` — the only published executable |
| Daemon | `omrg daemon`, a hidden subcommand of the same binary |
| Runtime state | `<git-common-dir>/openmerge/` |
| Project config | `.openmerge/config.yaml` |
| Rust crates | `openmerge-*` |
| AI command namespace | `/omrg:*` |
| Agent protocol | OpenMerge Agent Protocol |
| GitHub check | OpenMerge Gate |
| Benchmark | OpenMerge Bench |
| Hosted service | OpenMerge Cloud |

Only the command you type every day is abbreviated. Internal names stay spelled
out. There is one binary, so the CLI and the daemon can never disagree about
version and release signing has a single artifact.

## How this repository is developed

OpenMerge is built through OpenSpec using a custom, evidence-first workflow
schema at `openspec/schemas/openmerge-product/`. Every change moves through ten
artifacts before implementation begins:

```
research → product → specs → architecture → threat-model
        → benchmark → adrs → rollout → tasks → verification
```

Two properties matter more than the artifact count:

- `research` demands primary sources and an explicit evidence ledger that
  separates verified facts from assumptions.
- `verification` is authored as a contract (every row `pending`) and completed as
  a record (every `pass` cites a command and its real outcome).

Artifacts are created **one per step** via `/opsx:new` then `/opsx:continue`, each
reviewed before the next unlocks. The one-shot `/opsx:propose` and `/opsx:ff`
workflows are deliberately not installed — a single pass over ten artifacts
produces citations nobody verified, and everything downstream inherits them.

Inspect the workflow:

```bash
openspec schema validate openmerge-product
openspec status --change define-product-contracts
openspec instructions research --change define-product-contracts
```

## Roadmap

Changes are sequenced so that nothing blocking is built before its evidence is
reproducible:

| # | Change | Delivers |
| --- | --- | --- |
| 001 | `define-product-contracts` | Positioning, non-users, CLI vocabulary, finding taxonomy, protocol versioning. No code. |
| 002 | `establish-rust-workspace` | Cargo workspace, crate boundaries, error model, tracing, config, CI. |
| 003 | `build-immutable-snapshot-engine` | Worktree discovery, committed and dirty snapshots, synthetic commits, proof of zero user-state mutation. |
| 004 | `build-local-daemon` | Single-instance daemon, IPC, event log, crash recovery, stale-run cancellation. |
| 005 | `build-repository-change-graph` | Generic file and package graph, TypeScript adapter, incremental updates. |
| 006 | `build-integration-scenario-planner` | Candidate selection, risk scoring, connected components, N-way batching. |
| 007 | `build-isolated-execution-engine` | Host and container executors, no-network mode, quotas, process-tree cleanup. |
| 008 | `build-evidence-and-attribution` | Baseline comparison, failure classification, stable finding ids, reproduction bundles. |
| 009 | `integrate-coding-agent-hooks` | Canonical agent protocol, vendor adapters, filesystem fallback, completion gate. |
| 010 | `integrate-openspec-intent` | Change discovery, scope drift, missing verification, spec collision. |
| 011 | `build-local-control-plane-ui` | `init`, `doctor`, `watch`, `status`, `explain`, `reproduce`, `plan`, local web UI. |
| 012 | `build-github-integration-gate` | GitHub App, check runs, annotations, rerun, remote workers. |
| 013 | `support-cross-repository-changes` | Multi-repo snapshots, provider/consumer contracts, coordinated merge plans. |
| 014 | `harden-release-one` | Platform coverage, state migration, fuzzing, security review, signed releases. |

## The measurement that matters

OpenMerge Bench collects scenarios where every one of these holds
simultaneously: the base passes, each change passes alone, the textual merge is
clean, and the combination fails. The headline metric is not stars or downloads
— it is **how many real integration failures were prevented before the user
would otherwise have found them**.

## License

Apache-2.0. See [LICENSE](LICENSE).

The CLI, daemon, snapshot engine, graph core, local execution, agent protocol,
local UI, adapters, benchmark, and plugin SDK are open source. Findings that are
valuable locally will not be moved behind a paywall.
