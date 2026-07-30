# Product: OpenMerge

Every claim about user behaviour below is tagged. `[E]` traces to a row in
`research.md`'s evidence ledger. `[A]` is an assumption we have not yet earned.
The distinction is the point: this document commits to a position without
pretending the demand is proven.

## Positioning

**OpenMerge verifies that in-progress coding-agent changes still work together,
before review and before CI.**

Shorter, for the top of the page:

> Your agents pass alone. OpenMerge makes sure they pass together.

The thing being sold is not merging, and not conflict detection. It is the
interval between "the agents finished" and "someone finds out the combination is
broken" — and shrinking that interval to zero while the responsible agent still
has the context to fix it.

### Present tense, not future tense

The temptation is to pitch heterogeneous agent fleets. The data says not to.
Only **0.5%** of temporally overlapping agent PR pairs involve two different
agents `[E]`. What is actually happening is one developer or one team running
several sessions of the *same* agent at once.

That is the pitch, and it loses nothing:

```
Claude Code session A   → rewrites the login system
Claude Code session B   → adds an admin page
Claude Code session C   → changes the database schema
```

Three sessions of one agent break each other exactly as thoroughly as three
different vendors would. Same worktrees, same shared code, same clean merge,
same broken build.

So the three timeframes are distinct and must not be collapsed:

| | Claim |
| --- | --- |
| **Demand today** | Multiple concurrent sessions of the same agent in one repository `[E]` |
| **Architecture** | Vendor-neutral, so no single agent's hook API can strand the product `[A]` |
| **Future market** | Mixed-vendor sessions, currently 0.5% of pairs `[E]` |

Marketing speaks only to the first row. The second is an engineering decision
that costs us something now and buys optionality later; it is not a customer
benefit and must never be sold as one.

## Target User

**Role.** A developer or small team who has already adopted parallel agents and
has discovered that integration throughput, not code generation, is now the
bottleneck.

**Situation.** Concretely:

- Runs **2–10 concurrent agent sessions**, each in its own Git worktree or branch.
- One repository, with substantial shared code between the areas the agents touch.
- The repository has deterministic checks worth running: a compiler, a type
  checker, a test suite, schema validators. A TypeScript monorepo, a Cargo
  workspace, or a large Python repository.
- **Full CI takes minutes, not seconds.** This is load-bearing: if CI is
  instant, the interval OpenMerge sells does not exist.
- Re-integrating finished agent work is already a recurring, annoying task —
  serially, by hand, after the fact.

**Today's workaround.** Let each agent finish, open the PRs, wait for CI or for
main to break, then re-engage whichever agent is at fault — which means that
agent re-reads the repository, rebuilds context it already had an hour ago, and
fixes something it could have fixed instantly `[A]`.

**Why they will listen.** The concurrency is real and measured: **40.2%** of
repositories contain temporally overlapping agent PRs, and those overlapping
pairs account for **79.4%** of all agent-authored PRs `[E]`. Textual conflict
alone hits **19.8%** of same-agent overlapping pairs `[E]`. Whatever the rate of
the harder failures turns out to be, this population is not hypothetical.

## Who Will Not Use This

Naming these is not modesty. Each one is a prospect we should disqualify fast
rather than convert badly.

- **Runs one agent at a time.** No combinations exist. Nothing to verify.
- **Small repository.** Full CI is cheap enough that speculative combination
  verification saves nothing worth installing a daemon for.
- **Genuinely independent tasks.** Separate services, separate packages, no
  shared types or schema. Correctly, OpenMerge would stay silent forever — which
  means it should never have been installed.
- **Sub-ten-second CI.** The interval this product sells does not exist. Push
  and find out.
- **One shared workspace, already coordinated upstream.** If agents write through
  a mediator that rejects stale writes, divergence is prevented rather than
  verified, and there is no combination to build. **This is the substitute most
  likely to eliminate the product rather than compete with it** — STORM reports
  beating git-worktree baselines with exactly this design `[E]`.
- **No tests, no types, no schema.** Deterministic evidence is the entire
  product. With nothing to run, all that remains is a model's opinion, which we
  have committed never to block on.
- **Rarely hits integration problems.** Believing this without measuring is
  common; being right about it is also common. Either way, not a user yet.

OpenMerge is not "every developer needs this." It is, precisely:

> For developers already running parallel agents who have found that integration
> cannot keep up with generation.

## The Must-Have Moment

It is 4:40pm. Three sessions have been running for about an hour.

Session A was told to clean up the session model. Forty minutes ago it renamed
`Session.userId` to `Session.subject` — a good change, the one you asked for, and
it updated all fourteen call sites it could see inside `packages/auth`. It has
since moved on to writing tests, which pass. Its worktree is green.

Session B, in a different worktree, has been building the admin dashboard from
scratch. It wrote `packages/admin/src/session.ts` half an hour ago against the
session model as it existed when it started: `session.userId`. Its worktree also
builds. Its tests also pass.

Neither agent has touched a file the other touched. `git merge-tree` reports a
clean merge — there is no textual conflict to find, and nothing in your terminal
is red.

You are about to start reviewing. Instead, a line appears:

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

You paste the finding to session B. It is still holding the file it wrote thirty
minutes ago; it does not re-read the repository, does not rebuild its mental
model, does not ask you what the session type looks like now. It changes six
lines. The finding closes itself.

Nothing was pushed. No PR was opened. No CI ran. You never context-switched, and
neither did the agent.

**The counterfactual is what sells it.** Without that line: you review both
branches and approve them, because each is individually correct. You merge A.
You merge B. Main goes red. You read a CI log, work out which of three sessions
caused it, reopen that session — cold, an hour later, context gone — and it
spends real tokens rediscovering what it already knew before fixing six lines.

The moment is not "OpenMerge found a conflict." It is **the first time it catches
something real that would otherwise have surfaced at CI or after merge.** Our
bet is that a few of those a week is enough to make it undeployable-without
`[A]`. That bet is unproven and is stated as such below.

## Primary Workflow

What the user does, in order, and what OpenMerge does behind it.

**1. Once per repository.**

```
omrg init
```

Detects the repository, active worktrees, package manager, build system,
language toolchains, schema sources, and which agents are installed. Writes
`.openmerge/config.yaml` and the agent hook configuration. No further setup.

**2. Once per machine session.**

```
omrg watch
```

The daemon runs. From here the user does nothing unless something is wrong.

**3. Agents work normally.**

Nothing about how the user drives their agents changes. No mediator, no special
workspace, no wrapper command. Agents keep writing files the way they already
do; hooks report what happened. This is the concession that makes adoption
cheap, and it is the opposite of the shared-workspace approach.

Behind that: each meaningful edit produces an immutable content-addressed
snapshot covering staged, unstaged, and untracked files. Untracked files are why
this step is unavoidable rather than an optimisation — `git merge-tree` does not
consider them `[E]`, so half-finished agent work cannot be evaluated without
building a synthetic commit first.

**4. Nothing happens, loudly.**

When the combinations are fine, the user sees nothing at all. Silence is the
product working. ConE shipped with deliberately reduced coverage specifically to
avoid false alarms, and reported over 70% of its notifications rated useful with
over 90% of interviewed users intending to keep it `[E]`. We inherit that
trade: fewer, truer findings.

**5. Something breaks.**

A finding appears with the failing command, the file and line, the baseline
status of each side, the merge result, and the owning session. The user hands it
to that agent, or the agent's own `/omrg:check` picks it up.

**6. The agent fixes it and the finding closes itself.**

Re-verification is automatic. Fixed findings close. Stale ones are marked stale
rather than repeated.

**7. Before an agent declares itself done.**

```
omrg gate
```

Reports whether unresolved integration failures remain. **This is best-effort by
construction, not by choice.** Copilot's runtime overrides a blocking stop hook
after eight consecutive blocks, and its hook timeouts fail open `[E]`. So the
durable channel is machine-readable feedback written to disk, which survives a
gate that was overridden, timed out, or never installed. A gate that can be
outlasted is still worth having; a gate that is the *only* mechanism is a design
error.

**8. Handing over to humans.**

```
omrg plan
```

An integration order that has actually been verified, rather than one guessed
from dependency declarations.

## Product Boundaries

| Mistaken for | The difference |
| --- | --- |
| **Git conflict detector** (Clash) | Clash answers "will these worktrees conflict textually?" using read-only `git merge-tree`, and states outright that it does not evaluate semantic or type-level compatibility `[E]`. OpenMerge answers the question that starts *after* Clash returns clean: the merge succeeded, does the result build, typecheck, migrate, and pass tests? Clean-merge detection is table stakes here, never the differentiator. |
| **Merge queue** (Aviator, Graphite, GitHub) | A pull request must be labelled to enter Aviator's queue before it is included in a speculative combination; evaluating never-submitted branches is not a documented capability `[E]`. Merge queues own the window from "submitted" to "on main". OpenMerge owns the window from "agent started typing" to "submitted", which nothing currently occupies. |
| **Worktree manager** (Worktrunk) | Worktrunk creates, switches, and removes worktrees. OpenMerge never creates or owns a worktree — it observes the ones that exist. These compose; competing here would be self-inflicted. |
| **CI / CI dashboard** | CI reports what happened to work that was submitted. OpenMerge decides which unsubmitted combinations are worth building at all, and runs a selected subset of the same checks earlier. It does not replace CI; it front-runs it. |
| **AI code reviewer** | Reviewers produce opinions about code. OpenMerge produces exit codes, compiler diagnostics, and reproduction commands. A model may explain a finding or propose a fix; it may never be the sole reason something is blocked. |
| **Semantic merge algorithm** | OpenMerge does not merge code differently. It performs an ordinary merge and then verifies the result. The best published test-generation approach to semantic conflicts detects **9 of 28** `[E]`; claiming to find all semantic conflicts would be false and would forfeit the precision that makes the tool tolerable. |
| **Coding agent** | It coordinates agents. It does not write features. |
| **Shared-state agent runtime** (STORM, CoAgent) | Genuinely the opposing design, and the one that could make this product unnecessary. They prevent divergence at write time inside one workspace; OpenMerge permits divergence and verifies combinations. The trade is explicit: they require agents to write through a mediator, we require nothing of the agent beyond a hook. Whether that trade is worth it is unresolved `[A]`. |

## Value vs Novelty

These are different lists and conflating them is how infrastructure products die
of self-regard.

### Why a user adopts — failures prevented and time saved

- **A real integration failure caught before review**, rather than after CI or
  after merge. The single measurable outcome the product exists for.
- **Agent context that is still warm.** Re-engaging a finished agent means it
  re-reads the repository and rebuilds understanding it already had. Fixing
  in-flight skips that entirely — this is a direct token and latency saving,
  and on long sessions it is the largest one `[A]`.
- **No CI round-trip to learn the combination is broken.** Minutes to hours,
  depending on the pipeline.
- **No human re-dispatch.** Nobody has to work out which of five agents caused
  a failure and go wake it up.
- **No second review pass** of branches that were already approved individually.
- **No rebase-and-retest cycle** after a late-discovered incompatibility.
- **No manual end-of-day integration**, the task that currently absorbs the time
  the agents were supposed to save.

### Why this is technically interesting — sold to nobody

- Immutable content-addressed snapshots of dirty worktrees, including untracked
  files, built through an isolated temporary index that never touches the user's
  index or refs.
- Incremental impact graph spanning files, symbols, packages, contracts, schemas,
  and spec requirements.
- Risk-scored combination selection that avoids the combinatorial explosion of
  verifying every pair, then every triple.
- Deterministic failure attribution from a combination back to the change that
  caused it.
- A vendor-neutral agent protocol over three incompatible hook surfaces.

Every item in this second list is a cost. None of it is a reason to adopt. If a
user ever has to care about any of it, something has gone wrong.

## Progressive Adoption Ladder

Each rung must be independently useful, because most users will stop at 2 or 3
and that has to be a success, not a failed conversion.

1. **Observe.** `omrg init` and `omrg watch`. Findings are recorded, nothing is
   surfaced unless asked. Costs nothing, blocks nothing, proves whether the
   failures exist in *this* repository. **This is also our own measurement
   instrument** — the rung where a user's data can answer the question the
   literature has not.
2. **Warn.** Findings surface as they appear. Still nothing blocked. The rung at
   which ConE's precedent says a tool becomes valued rather than tolerated `[E]`.
3. **Gate completion.** `omrg gate` blocks an agent from declaring itself done
   with unresolved integration failures — best-effort, with on-disk feedback as
   the durable path. The first rung that costs the user something, and therefore
   the first that can be rejected. Must be trivially disableable.
4. **Plan integration.** `omrg plan` proposes a verified integration order.
   Advisory only.
5. **Automate integration.** Opt-in, policy-controlled, off by default, and not
   in the first release.

Nothing above rung 3 matters if rung 1 does not find real failures.

## What This Positioning Does Not Yet Prove

Stated plainly, because a product document that hides this is worthless as a
decision record.

| Question | Status |
| --- | --- |
| Do multiple agents work concurrently on the same repository? | **Yes — measured** `[E]` |
| Do agent changes conflict with each other? | **Yes — measured, at the textual level** `[E]` |
| Does clean-merge-but-broken-combination exist? | **Yes — the phenomenon is real** |
| Is it frequent enough to support a standalone product? | **Not proven.** No published rate exists. This is the central assumption `[A]` |
| Will developers accept early, low-false-positive warnings? | **Strong indirect evidence** — ConE, which never blocked anything `[E]` |
| Will developers accept a gate that blocks an agent? | **Not proven** `[A]` |
| Will anyone pay? | **Not tested** |

The falsifiers for each assumption are recorded in `research.md`. The load-bearing
one bears repeating: **if OpenMerge Bench, built from replayed real repository
history, cannot find clean-merge-but-failing combinations at a rate above roughly
1 in 20 co-active pairs, this positioning is wrong and the product should not be
built as specified.**

That measurement, not any argument in this document, decides whether OpenMerge
is a company or a good tool for a small number of people. Both are acceptable
outcomes. Pretending the question is settled is not.
