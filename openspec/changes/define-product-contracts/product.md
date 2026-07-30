# Product: OpenMerge

This document records decisions. The evidence behind them lives in
`research.md` and is not restated here. Claims are tagged `[E]` when a
research.md evidence row supports them and `[A]` when they are assumptions we
have not earned.

## What OpenMerge Is

OpenMerge is continuous integration verification for parallel coding sessions.

It observes coding agents working in isolated Git worktrees, creates immutable
snapshots of their in-progress changes, and verifies high-risk combinations
before the work reaches pull-request review or merge queues.

OpenMerge is designed first for developers running multiple concurrent sessions
of the same coding agent. Its agent-agnostic architecture prevents workflow
lock-in and supports future mixed-agent environments, but mixed-agent fleets are
not the primary demand claim.

OpenMerge does not claim to detect every semantic conflict. Blocking findings
require reproducible evidence from Git, compilers, type checkers, schema
validators, or existing tests. It prefers silence over low-confidence warnings.

## Positioning

Formal:

> **OpenMerge verifies high-risk combinations of in-progress coding-agent
> changes before review and CI.**

For the top of the page:

> **Your agents pass alone. OpenMerge makes sure they pass together.**

**Decision: the formal line says "verifies high-risk combinations", not "makes
sure they pass".** The promise line is marketing and may be aspirational; the
formal line is a contract and must be true. Two things constrain it.

First, we verify a *selected* subset of combinations, not all of them. Claiming
completeness would be false and would forfeit the precision the product depends
on.

Second, the completion hook cannot be relied on to hold an agent — blocking hooks
can be overridden after repeated blocks and hook timeouts can fail open `[E]`.
**So the reliable product boundary is persisted findings plus machine-readable
feedback on disk, never "guaranteed blocking".** Any promise phrased as *stops
the agent* would be a promise we cannot keep. `omrg gate` is a strong default,
not a guarantee.

## Core Problem

```
A alone         pass
B alone         pass
git merge       clean
A + B           fail
```

Nothing in a developer's existing toolchain reports that fourth line while it
still matters. Git sees no conflict. Each branch's own checks are green. CI never
built the combination because neither change has been submitted.

## Core Job

> Surface reproducible integration failures between in-progress changes while the
> responsible agent still has context.

Two words carry the weight. **Reproducible**, because a finding the user cannot
re-run offline is not evidence and must not block anything. **Still has context**,
because the same fix costs a fraction as much before the agent's working state is
gone.

## Market Entry, Architecture, Expansion

Three separate claims that must never be collapsed into one pitch:

| | Decision |
| --- | --- |
| **Market entry** | Multiple concurrent sessions of the *same* coding agent, in one repository `[E]` |
| **Architecture principle** | Agent-agnostic, to prevent workflow lock-in `[A]` |
| **Future expansion** | Mixed-agent workflows `[E]` |

**Decision: marketing speaks only to the first row.** Cross-vendor concurrency is
a small fraction of overlapping agent work today `[E]`, so leading with
heterogeneous fleets would be selling against the data. Three sessions of one
agent break each other exactly as thoroughly as three vendors would — same
worktrees, same shared code, same clean merge, same broken build.

**Decision: agent-agnostic architecture is an engineering cost we accept for
optionality, and is never presented as a user benefit.** It buys portability
against a vendor changing its hook API. That is a reason for us to build it, not
a reason for anyone to adopt it.

## Target User

Developers and teams running **2–10 concurrent coding-agent sessions** in a
single repository, each in its own Git worktree or branch.

Qualifying conditions, all of which must hold:

- Substantial shared code between the areas the sessions touch. Without shared
  surface there are no interesting combinations.
- Deterministic checks worth running: compiler, type checker, test suite, schema
  validators. A TypeScript monorepo, a Cargo workspace, a large Python
  repository.
- **Full CI takes minutes, not seconds.** The interval OpenMerge sells is the
  interval before CI would have told them. If CI is instant, there is no
  interval.
- Re-integrating finished agent work is already a recurring manual task.

**The condition that actually predicts adoption** is none of the above. It is:

> Agent output has outpaced the human capacity to review and integrate it.

That is the trigger. Users who have not yet felt it will not install a daemon to
prevent a problem they have not had `[A]`.

## Who Will Not Use This

Disqualify these fast rather than convert them badly.

- **One agent at a time.** No combinations exist.
- **Small repository.** Full CI is cheap enough that verifying combinations early
  saves nothing worth a daemon.
- **Genuinely independent tasks.** No shared types or schema. OpenMerge would
  correctly stay silent forever, which means it should never have been installed.
- **Sub-ten-second CI.** Push and find out is faster than anything we offer.
- **A single shared workspace already coordinated at write time.** If agents write
  through a mediator that rejects stale writes, divergence is prevented rather
  than verified and there is no combination to build. **This is the profile most
  likely to eliminate the product rather than compete with it** `[E]`.
- **No tests, no types, no schema.** Deterministic evidence is the whole product.
  With nothing to run, only a model's opinion remains, and we have committed
  never to block on that.
- **Rarely hits integration problems.** Sometimes true. Either way, not a user
  yet.

OpenMerge is not for every developer. It is for developers whose integration
speed has stopped keeping up with their generation speed.

## The Must-Have Moment

It is 4:40pm. Three sessions have been running for about an hour.

Session A was told to clean up the session model. Forty minutes ago it renamed
`Session.userId` to `Session.subject` — the change you asked for — and updated all
fourteen call sites it could see inside `packages/auth`. It has since moved on to
writing tests, which pass. Its worktree is green.

Session B, in a different worktree, has been building the admin dashboard. It
wrote `packages/admin/src/session.ts` half an hour ago against the session model
as it existed when it started: `session.userId`. Its worktree also builds. Its
tests also pass.

Neither session touched a file the other touched. The merge is clean. Nothing in
your terminal is red.

You are about to start reviewing. Instead:

```
CG-4821  Integration build failure

  auth-refactor        renamed Session.userId → Session.subject
  admin-dashboard      still reads Session.userId

  Baselines:  auth-refactor pass · admin-dashboard pass
  Merge:      clean
  Combined:   fail

  pnpm exec tsc -b
  packages/admin/src/session.ts:42
  TS2339: Property 'userId' does not exist on type 'Session'

  Owner: admin-dashboard
  Reproduce: omrg reproduce CG-4821
```

You hand it to session B. It is still holding the file it wrote thirty minutes
ago — it does not re-read the repository, does not rebuild its model of the
session type, does not ask you what changed. It edits six lines. The finding
closes itself.

Nothing was pushed. No PR was opened. No CI ran.

**The counterfactual is what sells it.** Without that finding: you review both
branches and approve both, because each is individually correct. You merge A. You
merge B. Main goes red. You read a CI log, work out which of three sessions
caused it, reopen that session cold an hour later, and it spends real tokens
rediscovering what it already knew before editing six lines.

The moment is the first time OpenMerge catches something real that would otherwise
have surfaced at CI or after merge. Our bet is that a few of those per week make
it undeployable-without `[A]`.

## Primary Workflow

**Once per repository.** `omrg init` — detects the repository, worktrees, package
manager, build system, toolchains, schema sources, and installed agents; writes
config and agent hook configuration.

**Once per machine session.** `omrg watch` — the daemon runs. From here the user
does nothing unless something is wrong.

**Agents work normally.** Nothing about how the user drives their agents changes:
no mediator, no special workspace, no wrapper command. **Decision: we require
nothing of the agent beyond a hook.** This is the concession that makes adoption
cheap and is deliberately the opposite of the shared-workspace approach.

Behind it, each meaningful edit produces an immutable content-addressed snapshot
covering staged, unstaged, and untracked files. **Decision: the snapshot engine is
a prerequisite, not an optimisation** — three-way merge plumbing ignores untracked
files `[E]`, so half-finished agent work cannot be evaluated at all without
building a synthetic commit first. This is the capability boundary against
textual-conflict tools.

**Nothing happens, loudly.** When combinations are fine the user sees nothing.
Silence is the product working.

**Something breaks.** A finding appears with the failing command, file and line,
the baseline status of each side, the merge result, and the owning session.

**The agent fixes it and the finding closes itself.** Re-verification is
automatic. Fixed findings close; stale ones are marked stale rather than repeated.

**Before an agent declares itself done.** `omrg gate` reports whether unresolved
integration failures remain. Best-effort by construction, with on-disk
machine-readable feedback as the durable channel.

**Handing over to humans.** `omrg plan` proposes an integration order that has
been verified rather than inferred from dependency declarations.

## Product Boundaries

| Mistaken for | The difference |
| --- | --- |
| **Git conflict detector** | They answer "will these worktrees conflict textually?" and explicitly do not evaluate semantic or type-level compatibility `[E]`. OpenMerge answers the question that starts after that returns clean: the merge succeeded, does the result build, typecheck, migrate, and pass tests? Clean-merge detection is table stakes here, never the differentiator. |
| **Merge queue** | Merge queues act on submitted, labelled pull requests `[E]`. They own the window from *submitted* to *on main*. OpenMerge owns the window from *agent started editing* to *submitted*, which nothing currently occupies. |
| **Worktree manager** | They create, switch, and remove worktrees. OpenMerge never creates or owns a worktree; it observes the ones that exist. These compose. |
| **CI / CI dashboard** | CI reports what happened to submitted work. OpenMerge decides which unsubmitted combinations are worth building at all, and runs a selected subset of the same checks earlier. It front-runs CI; it does not replace it. |
| **AI code reviewer** | Reviewers produce opinions. OpenMerge produces exit codes, compiler diagnostics, and reproduction commands. A model may explain a finding or propose a fix; it may never be the sole reason something is blocked. |
| **Semantic merge algorithm** | OpenMerge does not merge code differently. It performs an ordinary merge and verifies the result. The best published automated approach to semantic conflicts detects well under half `[E]`; claiming to find all of them would be false and would forfeit the precision that makes the tool tolerable. |
| **Coding agent** | It coordinates agents. It does not write features. |
| **Shared-state agent runtime** | The opposing design, and the one that could make this product unnecessary. They prevent divergence at write time inside one workspace; OpenMerge permits divergence and verifies combinations. The trade is explicit: they require agents to write through a mediator, we require only a hook. Whether that trade is worth it is unresolved `[A]`. |

## Value vs Novelty

### The unit of value

**Decision: the unit of value is not the number of warnings emitted.** A product
measured by warning count optimises toward noise. The unit is what the user did
not have to do:

- one fewer agent re-awakening
- one fewer context reload
- one fewer duplicate review pass
- one fewer full CI cycle
- one fewer human judgement about which branch caused the failure
- one fewer rebase-and-retest cycle
- one fewer manual end-of-day integration

Every one of those is countable, and the largest on long sessions is context
reload — re-engaging a finished agent means paying again for understanding it
already had `[A]`.

This is also the reporting principle: **surface prevented work, never activity.**
"3 combinations verified, 0 findings" is a status line. "47 checks run" is
vanity.

### Why this is technically interesting — sold to nobody

- Immutable content-addressed snapshots of dirty worktrees including untracked
  files, built through an isolated temporary index that never touches the user's
  index or refs.
- Incremental impact graph over files, symbols, packages, contracts, schemas, and
  spec requirements.
- Risk-scored combination selection that avoids verifying every pair and then
  every triple.
- Deterministic attribution from a failing combination back to the change that
  caused it.
- A vendor-neutral agent protocol over incompatible hook surfaces.

Every item here is a cost. None is a reason to adopt. If a user ever has to care
about any of it, something has gone wrong.

## Quality Principle

> **Prefer a missed finding over a blocking warning we cannot prove.**

This is not humility, it is the survival condition. The one industrially deployed
predecessor to this product deliberately reduced its own coverage to suppress
false alarms, and reported both high usefulness ratings and high retention intent
as a result `[E]`. Tools that generate many false alarms get uninstalled.

Consequences, binding on every later artifact:

- A finding that cannot be reproduced offline may not block.
- Ambiguous impact resolves toward silence, not toward a warning.
- Recall is a secondary metric. Actionable precision is primary.
- No blocking finding may rest solely on model output.

## Progressive Adoption Ladder

Each rung must be independently useful, because most users will stop at 2 or 3
and that has to count as success.

1. **Observe.** `omrg init`, `omrg watch`. Findings recorded, nothing surfaced
   unless asked. Costs nothing, blocks nothing, and proves whether these failures
   occur in *this* repository. **This rung is also our measurement instrument** —
   the only place a real user's data can answer the central open question.
2. **Warn.** Findings surface as they appear. Nothing blocked.
3. **Gate completion.** `omrg gate` blocks an agent from declaring itself done
   with unresolved failures — best-effort, with on-disk feedback as the durable
   path. The first rung that costs the user something, so the first that can be
   rejected. Must be trivially disableable.
4. **Plan integration.** `omrg plan` proposes a verified integration order.
   Advisory only.
5. **Automate integration.** Opt-in, policy-controlled, off by default, not in
   the first release.

Nothing above rung 3 matters if rung 1 does not find real failures.

## The Assumption That Can Invalidate This Product

Everything above is conditional on one unmeasured quantity:

> **How often do parallel agent changes merge cleanly, pass individually, and
> still fail in combination?**

No published research measures this `[A]`. The available literature measures
textual conflict, which is a different and easier phenomenon. The failure mode
this product exists for is real — it is demonstrable by construction — but its
*rate* in real parallel agent work is unknown, and rate is what decides whether
this is a product or a curiosity.

**Falsifier, restated from research.md:** if OpenMerge Bench, built from replayed
real repository history, cannot find clean-merge-but-failing combinations at a
rate above roughly 1 in 20 co-active pairs, this positioning is wrong and the
product should not be built as specified.

That measurement — not any argument in this document — decides the outcome.
Producing it is the first priority of the benchmark work, and it is why rung 1 of
the adoption ladder ships before anything that blocks a user.

The honest summary: there is a credible user and credible evidence of need, and
there is no proof yet that the need is large enough to support a standalone
company. Both outcomes are acceptable. Pretending the question is settled is not.
