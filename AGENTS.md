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
openspec instructions <artifact> --change <change-name>   # what this artifact must contain
openspec validate <change-name>            # delta-spec structural check
```

Do not skip ahead. `product` without `research` is invention; `tasks` without
`benchmark` produces work nobody can evaluate.

Artifact-level rules live in `openspec/config.yaml` under `rules:`. They are
requirements, not suggestions. They reach you through
`openspec instructions <artifact> --json` as the `rules` field — apply them as
constraints, never copy them into the artifact file.

### One artifact per step — enforced by configuration

The installed workflows are deliberately restricted:

| Available | Deliberately absent |
| --- | --- |
| `/opsx:new`, `/opsx:continue`, `/opsx:apply`, `/opsx:verify`, `/opsx:update`, `/opsx:sync`, `/opsx:archive`, `/opsx:explore` | `/opsx:propose`, `/opsx:ff`, `/opsx:bulk-archive`, `/opsx:onboard` |

`/opsx:propose` generates every artifact in one pass and `/opsx:ff` fast-forwards
the chain. For this project both are failure modes, not shortcuts: a single-pass
run produces a `research.md` full of plausible citations nobody checked, and
every downstream artifact then inherits fiction. Use `/opsx:new` to scaffold,
then `/opsx:continue` once per artifact, reviewing each before unlocking the
next.

If those commands are missing, the machine-level profile was reset. Restore with:

```bash
openspec config set profile custom
openspec config set workflows '["explore","new","continue","apply","update","sync","archive","verify"]'
openspec update
```

### Two OpenSpec behaviors to know

**`openspec validate` needs delta specs.** A change that has artifacts but no
`specs/<capability>/spec.md` yet fails with "Change must have at least one
delta". That is expected, not a broken setup. Use `openspec status --change` for
progress while a change is still in the artifact phase.

**`/opsx:verify` looks for `design.md`.** Its coherence dimension checks
implementation against a `design` artifact, which this schema does not have. Map
that step onto `architecture.md` and `adrs.md` instead — an ADR violation is a
CRITICAL coherence finding here, not a skipped check.

**Changes with no spec-level behavior use `skip_specs`.** Workspace scaffolding,
tooling, and docs changes have nothing observable to specify. Do not invent
requirements to unblock the artifact graph — declare it in the change's
`.openspec.yaml`:

```yaml
schema: openmerge-product
skip_specs: true
```

`openspec status` then renders the specs stage as explicitly skipped and `tasks`
no longer waits on it. Requires openspec >= 1.7.0.

Per-operation guidance for `apply` and `archive` lives in `openspec/config.yaml`
under `operations:`, and the workflows load it at execution time. Read it with
`openspec instructions apply --change <name> --json` or
`openspec instructions archive --change <name> --json`.

### Editing specs while other changes are active

OpenSpec applies `## MODIFIED Requirements` by replacing the whole requirement
block at archive time. There is a guard: archive aborts if the live spec contains
a scenario your MODIFIED block omits ("Refresh the change spec before archiving
to avoid dropping scenarios"), so you cannot silently delete a sibling change's
scenario.

The guard compares scenario **names and counts only**. It does not compare
scenario bodies or the requirement description. So if another change already
archived an edit to the *body* of a scenario you also carry, your block
overwrites it without warning. Before archiving a change with MODIFIED
requirements, re-read the live `openspec/specs/<capability>/spec.md` and rebase
your delta onto it.

This is worth internalising rather than merely obeying: it is the exact class of
failure OpenMerge exists to catch — two independently valid changes, a clean
merge, and a silently wrong result.

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
