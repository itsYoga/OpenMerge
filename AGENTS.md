# Working on OpenMerge

Read this before changing anything in this repository.

## What this repository is

OpenMerge is a spec-aware integration control plane for parallel coding agents.
It keeps concurrently-working agents continuously integratable: it understands
each agent's intent and scope, builds throwaway combined versions of their
in-progress work, runs verifiable checks against those combinations, and returns
reproducible failure evidence to the agent that caused the problem.

It is **not** a worktree manager, merge queue, Git conflict detector, AI code
reviewer, CI dashboard, coding agent, or semantic merge algorithm. If a change
starts turning it into one of those, stop and say so.

## How work happens here

All non-trivial work goes through OpenSpec with the project's custom schema,
`openmerge-product`. Artifact order:

```
research → product → specs → architecture → threat-model
        → benchmark → adrs → rollout → tasks → verification
```

```bash
openspec status --change <change-name>     # what is done, what is blocked
openspec instructions <artifact>           # what this artifact must contain
openspec validate <change-name>            # structural check
```

Do not skip ahead. `product` without `research` is invention; `tasks` without
`benchmark` produces work nobody can evaluate.

Artifact-level rules live in `openspec/config.yaml` under `rules:`. They are
requirements, not suggestions.

## Naming — settled, do not re-open

| Layer | Name |
| --- | --- |
| Product | OpenMerge |
| Terminal binary | `omrg` |
| Daemon | `openmerged` |
| Config directory | `.openmerge/` |
| Rust crates | `openmerge-*` |
| AI commands | `/omrg:*` |
| Agent protocol | OpenMerge Agent Protocol |
| GitHub check | OpenMerge Gate |
| Benchmark | OpenMerge Bench |

Only the daily command is abbreviated. Internal names stay spelled out —
`crates/openmerge-git/`, not `crates/omrg-git/`.

Do not add `scan`, `analyze`, `verify`, `validate`, `inspect`, or `test` as
sibling CLI verbs. Users cannot tell them apart. The core surface is `init`,
`watch`, `status`, `check`, `gate`; the secondary surface is `explain`,
`reproduce`, `plan`, `doctor`, `config`.

## Invariants

Violating any of these is a bug regardless of what the task asked for:

1. **Never mutate user repository state.** No writes to branches, index,
   worktree, refs, or stashes. Snapshots use isolated temporary indexes.
2. **Blocking findings require deterministic evidence.** Compiler, type checker,
   schema validator, or test. A model may explain or suggest; it may never be the
   sole basis for a block.
3. **Everything reproduces.** A finding a user cannot re-run offline is not
   shippable.
4. **Snapshots are immutable and content-addressed.** Identical content is never
   analysed, built, or tested twice.
5. **Hooks stay thin; the daemon does the expensive work.** Anything on an agent
   hook path has a stated latency budget.
6. **Core stays vendor-neutral.** Core crates must not depend on any agent
   vendor adapter. Adapters translate events; they never hold core judgment.
7. **Sandboxed by default.** OpenMerge executes agent-generated code. Host
   execution is opt-in; container isolation with no network is the default.
8. **Local-first.** Nothing requires cloud, an account, or uploading source.
9. **Generic before specific.** Plain command checks must work before any
   language adapter is written.
10. **Compatibility is a contract** for the agent protocol, the finding schema,
    the config schema, and on-disk state.

## When reporting work

State what you actually ran and what it actually printed. A task is complete when
its `Verify:` command passes, not when the code looks right. If something is
blocked, finish everything else and say plainly what you left and why.
