# Research: Integration coordination for parallel coding agents

Scope of this document: does the problem OpenMerge targets exist at measurable
scale, has anyone already solved it, and what would make this product wrong.

Every figure below was retrieved and checked during this research pass. Where a
claim in the founding brief could not be confirmed, it is marked as such rather
than repeated.

## Problem Evidence

### Concurrent agent work is the normal case, not the edge case

The strongest available measurement of concurrency itself comes from
**arXiv:2607.04697v2**, *AI Agent Pull Requests on GitHub: Frequency, Structure,
and Merge Conflict Rates* (Xu, Subramanian, Karthik; 6 July 2026), over the
AIDev-pop dataset of **33,596 PRs across 2,807 repositories**:

- **40.2%** of repositories contain agent-authored PR pairs with exact temporal
  overlap ("co-active" pairs).
- Those pairs account for **79.4%** of all agent-generated PRs.
- Widening to a one-week window: **53.4%** of repositories and **95.0%** of PRs.

So agent work is overwhelmingly concurrent with other agent work. The 79.4%
figure is the load-bearing one: an integration problem that touches four fifths
of agent output is not a niche.

### Combining that work breaks textually about a quarter of the time

**arXiv:2604.03551**, *AgenticFlict: A Large-Scale Dataset of Merge Conflicts in
AI Coding Agent Pull Requests on GitHub* (Ogenrwot, Businge; v1 4 April 2026,
v2 12 May 2026), ran deterministic merge simulation over agent PRs:

- **142,000+** agentic PRs collected from **59,000+** repositories.
- **107,000+** successfully processed through merge simulation.
- **29,000+** PRs exhibited merge conflicts — a conflict rate of **27.67%**.
- **336,000+** fine-grained conflict regions extracted.

The paper reports variation between agents, "particularly between Copilot and
OpenAI Codex," suggesting conflict likelihood depends on the underlying system.

arXiv:2607.04697v2 measured the same thing on actual three-way merges of **747
unique co-active pairs** and found the split that matters more:

- **19.8%** textual conflict for intra-agent pairs (same agent both sides).
- **41.7%** for cross-agent pairs.

### But most concurrency today is single-vendor

The same paper reports that only **0.5%** of co-active pairs involved different
agents (~4.3% of repositories, 122 of 2,807). This cuts against the founding
brief's framing. The cross-agent case has roughly double the conflict rate but
is currently rare. **Agent-agnostic architecture is still correct — it is a
portability and lock-in argument, not a "users run mixed fleets today"
argument.** Positioning that leads with heterogeneous fleets would be selling
against the data.

### Concurrent edits correlate with defects, independently of agents

**arXiv:2101.06542**, *ConE: A Concurrent Edit Detection Tool for Large Scale
Software Development* (Maddila, Nagappan, Bird, Gousios, van Deursen; ACM TOSEM,
September 2021) studied half a year of changes across six Microsoft repositories
each receiving 1,000+ PRs per month, and found "files concurrently edited in
different pull requests are more likely to introduce bugs."

Spearman rank correlation to bug fixes, concurrent versus non-concurrent edits
(paper's Table 2), showing concurrent edits consistently higher:

| Repo | Concurrent edits → bug fixes | Non-concurrent edits → bug fixes |
| --- | --- | --- |
| Repo-1 | 0.298 *** | 0.034 ** |
| Repo-2 | 0.140 *** | 0.057 ** |
| Repo-3 | 0.330 * | 0.120 * |
| Repo-4 | 0.451 *** | −0.461 *** |
| Repo-5 | 0.472 *** | 0.091 *** |
| Repo-6 | 0.196 *** | 0.005 * |

(*** p<0.001, ** p<0.01, * p<0.05)

This predates coding agents entirely, which strengthens rather than weakens it:
the mechanism is concurrency, and agents raise concurrency.

### Textual conflict is the measurable floor, not the whole cost

Every figure above counts **textual** conflicts found by deterministic merge.
The founding brief asserted that the authors explicitly frame these as a
conservative lower bound on coordination cost. **That attribution could not be
confirmed** — neither abstract contains such a statement. The lower-bound
reading is our inference, and it must be labelled as one.

The inference is nevertheless well-supported from the other direction: two
changes that merge cleanly can still fail to build or pass tests together, and
no merge simulation counts those. What is *not* available is a published rate
for clean-merge-but-broken-combination in agent workflows. **That number is the
single most valuable missing measurement for this product, and producing it is
the point of OpenMerge Bench.**

## Prior Art

### ConE (Microsoft) — the demand precedent

Operational deployment on **234 repositories** inside Microsoft: assessed
**26,000 pull requests**, made **775 recommendations** about conflicting
changes, **rated useful in over 70% (554)** of cases. From interviews with **48
users**, "over 90% intend to keep using the service on a daily basis."

**How it decides two PRs overlap** — file-set intersection, verbatim from the
paper:

```
Extent of Overlap = ( |F_r ∩ F_a − F_e| / |F_r| ) * 100
```

where `F_r` = files edited in the reference PR, `F_a` = files edited in a given
active PR, `F_e` = excluded file types. Plus identification of *Rarely
Concurrently Edited Files*. No compilation, no test execution, no type
information.

**The design lesson matters more than the numbers.** Verbatim:

> "A key design consideration is that we want to avoid false alarms. In the
> current state of the practice developers never receive warnings about
> potentially harmful concurrent edits. Based on this we believe it is
> acceptable to miss a few warnings. On the other hand, giving false warnings
> will likely lead to rejection of a tool like ConE."

and:

> "One of the design choices that we had to make was to minimize the false
> alarms by making it more conservative. A side effect of this is our coverage
> (number of pull requests for which we send a notification) will be lower.
> Studies have shown that, in large organizations, tools that generate many
> false alarms are not used and eventually deprecated."

A shipped industrial tool chose precision over recall on purpose, and got >70%
usefulness and >90% retention intent. This is direct support for "quiet by
default" and for treating actionable precision as the primary quality metric.
It is also a warning: any claim of comprehensive semantic-conflict detection
trades away the property that made ConE succeed.

**Boundary:** ConE notifies about file overlap. It never verifies that the
combination works. That gap is the product.

### SAM — the honest ceiling on automated semantic-conflict detection

**arXiv:2310.02395**, *Detecting Semantic Conflicts with Unit Tests* (Da Silva,
Borba, Maciel, Mahmood, Berger, Moisakis, Gomes, Leite; Journal of Systems and
Software, 2024). SAM generates unit tests as partial specifications and uses
them to detect unwanted behaviour changes on merge. Dataset: **more than 80
pairs of changes** integrated into common class elements across **51 merge
scenarios**.

Verbatim result:

> "Our results show that SAM best performs when combining only the tests
> generated by Differential EvoSuite and EvoSuite, and using the proposed
> Testability Transformations (nine detected conflicts out of 28)."

**Nine of 28 — approximately 32% recall in the best configuration.** Note: the
founding brief cited "9 of 29"; the paper says **28**. Corrected here.

**Consequence for OpenMerge: never claim to find all semantic conflicts.** The
best published test-generation approach finds under a third. OpenMerge's claim
must be about the failures that *deterministic* checks catch — compilers, type
checkers, schema validators, existing tests — on combinations that nobody
currently builds at all. That is a different and much more defensible claim than
"semantic conflict detection".

### STORM and CoAgent — a competing paradigm, not just research

**arXiv:2605.20563**, *Multi-agent Collaboration with State Management*
(STORM, STate-ORiented Management), mediates agent interaction with a **shared**
workspace: write-time conflict control rejects a write when the agent's local
view has gone stale and makes it retry with fresh context, plus structured
"intent annotations" left in the code for coordination.

Reported results on Commit0-Lite: **82.5% macro pass rate, 46.2% weighted pass
rate**, and **74.1 on PaperBench** — described as **outperforming git-worktree
baselines**.

**This is the most serious challenge to OpenMerge's premise and must not be
filed under "future competitor".** The two designs are opposed:

| | STORM | OpenMerge |
| --- | --- | --- |
| Workspace | one shared workspace | isolated worktrees |
| Strategy | prevent divergence at write time | permit divergence, verify combinations |
| Touches the agent's write path | yes | no |
| Verdict source | staleness of the local view | compiler / schema / test on the combination |
| Works with agents as shipped | requires mediation | yes, via hooks |

If preventing divergence at write time beats isolate-then-verify, OpenMerge is
solving a problem that better tooling upstream dissolves. The counter-argument
is that write-time mediation requires every agent to write through the mediator,
which is a heavier integration than a hook and does not survive an agent that
edits files directly — but that is an argument, not evidence.

**arXiv:2606.15376**, *CoAgent: Concurrency Control for Multi-Agent Systems*,
frames why classical concurrency control fits LLM agents poorly: a single agent
transaction spans minutes of inference, read sets are broad and opaque, and
writes take effect immediately. Those three properties are exactly why an
integration control plane cannot behave like a database.

## Competitive Landscape

### Direct

**Clash** (`clash-sh/clash`, Rust, MIT) — the closest thing that exists.
Tagline: *"Avoid merge conflicts across git worktrees for parallel AI coding
agents."* Uses `git merge-tree` via `gix` for read-only three-way merges between
all worktree pairs; 100% read-only, never touches working tree, index, or refs.
Commands: `clash check <file>`, `clash status`, `clash watch`, `--json`.
Integrates as a Claude Code **PreToolUse** hook intercepting Write/Edit/MultiEdit.

Explicitly does **not**: resolve conflicts, modify the repository, or **evaluate
semantic or type-level compatibility**.

Two things follow. First, Clash already owns the textual-conflict-between-live-
worktrees niche, and owns it well — OpenMerge should treat clean-merge detection
as table stakes and never market it as the differentiator. Second, and more
awkward: **Clash's command vocabulary is `check` / `status` / `watch`, three of
OpenMerge's five core verbs.** Users who know Clash will assume `omrg check`
means what `clash check` means. The docs must disambiguate on first contact, and
`omrg check` must do something visibly more than report a merge result.

### Adjacent

**Worktrunk** (`max-sixty/worktrunk`, Rust) — worktree lifecycle management for
parallel agents: `wt switch`, `wt list`, `wt merge`, `wt remove`, plus hooks for
local workflow automation. Its own framing is that agents can now "handle longer
tasks without supervision, such that it's possible to manage 5-10+ in parallel"
— the project's motivation, not an independent measurement. Complementary:
Worktrunk creates and owns worktrees, OpenMerge observes them. OpenMerge must
never create or own worktrees, or it competes here for no reason.

**Aviator MergeQueue** — parallel mode builds speculative combinations: the bot
creates a branch combining multiple queued PRs and a Draft PR from it, running
CI on combinations in parallel, and only committing what passes. On failure it
closes subsequent draft PRs, removes the failing PR, and restarts the queue.

The boundary is precise and it is the product's whole reason to exist: **a pull
request must be labelled with the trigger label to enter the queue.** Whether
Aviator can evaluate branches that were never submitted as PRs is **not a
documented capability** — the docs do not address it. So speculative combination
verification is solved for work that is *finished and submitted*, and unaddressed
for work still in progress. OpenMerge lives entirely in the second window.

**GitHub merge queue, Mergify, Graphite** — same structural position as Aviator:
post-PR, pre-main. Same window, same gap.

### Substitutes

These are what users actually do today, and each must be beaten on effort, not
on sophistication:

- **Do nothing; let CI find it after merge.** Free, already installed, and the
  status quo. OpenMerge's entire value is the interval between "agent finishes"
  and "CI on main fails", multiplied by how expensive it is to re-engage an agent
  whose context is gone.
- **Human review before merge.** Catches things no checker will. Slow, and
  scales badly against 5-10 parallel agents.
- **Serialize the agents.** Perfectly effective, and the most likely reason a
  prospect never adopts: they solved concurrency by removing it.
- **Merge to main frequently and keep changes tiny.** Genuinely reduces
  divergence. Reduces, not eliminates.
- **Run one agent with subagents in one workspace.** Concurrency without
  independent branches — moves the problem inside a single vendor's runtime,
  where OpenMerge has no hook to attach to.

### Future competitors and incumbent risk

Ranked by how cheaply each could absorb this:

1. **Coding-agent vendors** (Anthropic, GitHub, OpenAI). They own the hook
   surface OpenMerge depends on, already know every session's intent and diff,
   and Claude Code already ships `WorktreeCreate`, `WorktreeRemove`,
   `FileChanged`, `SubagentStop`, and `TeammateIdle` hook events — the exact
   event vocabulary a coordination layer needs. **This is the highest
   existential risk in this document.** A vendor shipping "check whether your
   parallel sessions still integrate" would be a feature, not a product.
2. **Merge-queue vendors** (Aviator, Mergify, Graphite). Already run speculative
   combinations; extending backwards from "labelled PR" to "in-progress branch"
   is an incremental move for them and a rewrite for nobody.
3. **Build systems** (Nx, Turborepo, Bazel). Already own the affected-target
   graph and remote cache. Adding cross-branch combination verification is
   plausible; they lack the agent-session concept.
4. **Clash**, by adding compile or test verification behind the same interface.
   Lowest engineering distance of anyone. Same language, same hook, same
   read-only posture.
5. **Shared-state runtimes** (STORM/CoAgent lineage). Dissolves the problem
   instead of solving it, if it works at scale.

## Feasibility Evidence

Two mechanisms the product cannot exist without, both confirmed.

### Synthetic combinations without touching user state

`git merge-tree --write-tree`, verbatim from the official documentation:

> "Performs a merge, but does not make any new commits and does not read from or
> write to either the working tree or index."

It performs real three-way content merges with rename detection, directory/file
conflict handling, recursive ancestor consolidation, binary and submodule
handling. Exit 0 = clean, output is the merged tree OID; exit 1 = conflicted,
output adds `<mode> <object> <stage> <filename>` per conflicted file; 2+ = error.

**One documented limitation reshapes the architecture: untracked files are not
considered — only tracked content.** An agent mid-task typically has untracked
new files, which is precisely the state OpenMerge must evaluate. So `merge-tree`
alone is insufficient; a snapshot engine must first build a synthetic commit from
an isolated temporary index (`write-tree` + `commit-tree`) that includes
untracked content, and only then can combinations be merged. This is exactly the
step Clash does not take, and it is where the differentiated capability starts.

### Agent hook surfaces, and where the completion gate actually breaks

All three target agents expose synchronous lifecycle hooks with JSON on stdin.
They are **not** equivalent, and the differences are not cosmetic:

| | Claude Code | Codex | GitHub Copilot |
| --- | --- | --- | --- |
| Config | `.claude/settings.json` | `.codex/hooks.json` or `[hooks]` in `config.toml` | `.github/hooks/*.json` |
| Events | ~30, incl. `WorktreeCreate`, `FileChanged`, `TeammateIdle` | 11 | 14 |
| Default timeout | **600 s** (command hooks) | **600 s** (SessionEnd 1 s, max 3) | **30 s** (`timeoutSec`) |
| Blocking completion | `Stop` / `SubagentStop`, exit 2 or `decision: "block"` | `Stop` / `SubagentStop` via `continue: false` | `agentStop` / `subagentStop`, `decision: "block"` |
| Block ceiling | **none documented** | not documented | **runtime overrides after 8 consecutive blocks** |
| Timeout behaviour | — | — | **fail-open** (even for policy hooks) |
| Concurrency | all matching hooks run in parallel | — | synchronous |

Three consequences, none of which were in the founding brief:

1. **The founding brief's "keep hooks under ~5 seconds" figure is not in any of
   these docs.** The documented defaults are 600 s, 600 s, and 30 s. A thin-hook
   architecture is still right — a 600 s allowance is a ceiling, not a budget,
   and a user watching an agent stall for even two seconds per edit will
   uninstall — but the justification is user experience, not a vendor limit. The
   number must come from our own SLO, stated as ours.
2. **The completion gate cannot assume it can hold an agent.** Copilot's runtime
   overrides a blocking `agentStop` hook after **8 consecutive blocks**, and
   Copilot hook **timeouts fail open**. A gate that only blocks will therefore
   let work through on a slow daemon and after eight refusals. Machine-readable
   feedback written to disk is not a convenience feature — it is the only
   durable channel. Blocking is best-effort.
3. **Claude Code's `FileChanged` + `watchPaths` and `WorktreeCreate` are a
   better event source than filesystem polling**, where available. The
   filesystem watcher remains the portable fallback, not the primary path.

Security guidance is consistent across all three and confirms the threat model:
validate untrusted hook input, quote variables against shell injection, never
log secrets (Copilot names `GITHUB_COPILOT_API_TOKEN` and
`GITHUB_COPILOT_GIT_TOKEN`), restrict network access. Claude Code additionally
documents that **hook processes inherit its full environment including `$HOME`,
`$PATH`, and session tokens**, recommends exec form with `args` over shell form,
and provides `allowManagedHooksOnly` to block untrusted user hooks. Codex has
the same control as `allow_managed_hooks_only` in `requirements.toml`. Settings
files are to be treated as code.

### Spec-level intent as an integration signal

OpenSpec provides structured change intent: requirements, WHEN/THEN scenarios,
and delta specs per capability. Reading it is strictly better than inferring
intent from a branch name.

Two constraints on the adapter, both verified in the OpenSpec source:

- **Cross-repo planning ("Stores") is Beta**, with an explicit warning that
  "command names, flags, file formats, and JSON output may still change shape
  between releases." Any cross-repo adapter must be optional and version-isolated.
- **OpenSpec's own archive path has a narrow parallel-change hazard** worth
  studying as a specimen. Applying `## MODIFIED Requirements` replaces the whole
  requirement block. A guard (`findMissingCurrentScenarios`) aborts the archive
  when the live spec holds a scenario the incoming block omits, so scenarios
  cannot be silently dropped — but it compares scenario **names and counts
  only**. Two changes that both carry a scenario under the same name, where one
  has already landed an edit to that scenario's *body*, merge cleanly and the
  second silently wins.

That last case is the product thesis in miniature, found in the wild, in the
tool being used to build the product: two individually valid changes, a clean
merge, and a silently wrong result that no existing check reports.

## Evidence Ledger

| Claim | Type | Source | Confidence |
| --- | --- | --- | --- |
| 40.2% of repos have co-active agent PR pairs; those pairs are 79.4% of agent PRs | measured-evidence | arXiv:2607.04697v2 abstract | high |
| 53.4% of repos / 95.0% of PRs at a one-week window | measured-evidence | arXiv:2607.04697v2 | high |
| Only 0.5% of co-active pairs are cross-agent | measured-evidence | arXiv:2607.04697v2 | high |
| Textual conflict 19.8% intra-agent vs 41.7% cross-agent, over 747 merged pairs | measured-evidence | arXiv:2607.04697v2 abstract | high |
| 27.67% conflict rate over 107k+ simulated merges of 142k+ agent PRs | measured-evidence | arXiv:2604.03551 abstract | high |
| Concurrently edited files correlate more strongly with bug fixes than non-concurrent, across 6 repos, p<0.05 or better | measured-evidence | arXiv:2101.06542 Table 2 | high |
| ConE: 234 repos, 26,000 PRs, 775 notifications, >70% (554) rated useful | measured-evidence | arXiv:2101.06542 abstract | high |
| ConE: of 48 interviewed users, >90% intend to keep using it daily | measured-evidence | arXiv:2101.06542 abstract | high |
| ConE decides overlap by file-set intersection, with no build or type analysis | verified-fact | arXiv:2101.06542 §4.1.1 EOO formula | high |
| ConE deliberately traded recall for precision to avoid rejection | verified-fact | arXiv:2101.06542 §4 (quoted) | high |
| SAM's best configuration detects 9 of 28 semantic conflicts (~32%) | verified-fact | arXiv:2310.02395 abstract (quoted) | high |
| STORM reports 82.5% macro / 46.2% weighted on Commit0-Lite and 74.1 on PaperBench, beating git-worktree baselines | measured-evidence | arXiv:2605.20563 | medium — figures from search summary, not read in the paper body |
| `git merge-tree --write-tree` never reads or writes the working tree or index | verified-fact | git-scm.com/docs/git-merge-tree (quoted) | high |
| `git merge-tree` does not consider untracked files | verified-fact | git-merge-tree documentation | high |
| Copilot's runtime overrides a blocking `agentStop` hook after 8 consecutive blocks | verified-fact | docs.github.com Copilot hooks reference | high |
| Copilot hook timeouts fail open, including for policy hooks | verified-fact | docs.github.com Copilot hooks reference | high |
| Claude Code command hooks default to a 600 s timeout and run in parallel | verified-fact | code.claude.com/docs/en/hooks | high |
| Codex hooks default to 600 s (SessionEnd 1 s, max 3) | verified-fact | learn.chatgpt.com/docs/hooks | high |
| Claude Code exposes `WorktreeCreate`, `FileChanged`, `TeammateIdle`, `SubagentStop` | verified-fact | code.claude.com/docs/en/hooks | high |
| Clash performs no semantic or type-level compatibility evaluation | verified-fact | clash-sh/clash README | high |
| Aviator requires a trigger label on a PR before speculative combination | verified-fact | docs.aviator.co parallel-mode | high |
| Aviator evaluating never-submitted branches is undocumented | verified-fact (absence of documentation) | docs.aviator.co parallel-mode | medium — absence of documentation is not absence of capability |
| OpenSpec Stores is Beta with unstable formats | verified-fact | OpenSpec `docs/stores-beta/user-guide.md` | high |
| OpenSpec's archive scenario guard compares names and counts only, so scenario-body overwrites pass silently | verified-fact | `src/core/specs-apply.ts` `findMissingCurrentScenarios` | high |
| Published textual-conflict rates are a lower bound on total coordination cost | **inference** | our reading; **no such statement found in either paper** | medium |
| Clean-merge-but-broken-combination is frequent enough to justify a product | **assumption** | none published | low — **falsified if OpenMerge Bench, built from real repository history, cannot find such cases at a rate above roughly 1 in 20 co-active pairs** |
| Users will accept a completion gate that blocks an agent | **assumption** | ConE retention intent is suggestive but ConE never blocked anything | low — **falsified if pilot users disable the gate, or run `--no-gate`, in more than ~20% of sessions** |
| Isolate-then-verify beats prevent-at-write-time | **assumption** | STORM claims the opposite against worktree baselines | low — **falsified if a shared-workspace mediator matches OpenMerge on integration failures prevented without requiring agents to change how they write** |
| Agent-agnostic support is worth its cost now | **assumption** | contradicted in the short term by the 0.5% cross-agent figure | low — **falsified if, after adapters ship, under ~10% of active sessions use a non-primary agent; the remaining argument would be lock-in avoidance, not present demand** |
| "Keep agent hooks under ~5 seconds" is vendor guidance | **retracted** | not present in Claude Code, Codex, or Copilot hook docs | — treat the 200 ms fast-path target as our own SLO, not an external requirement |

## Open Questions

- [ ] What is the real rate of clean-merge-but-failing-combination among
      co-active agent changes? — resolved by building OpenMerge Bench from
      replayed repository history and measuring it. Blocks the central product
      claim; everything else is secondary to this.
- [ ] Does write-time mediation (STORM) dominate isolate-then-verify at scale? —
      resolved by reading arXiv:2605.20563 and arXiv:2606.15376 in full,
      including whether the git-worktree baseline was given any integration
      verification at all, and whether the benchmarks contain multi-change
      integration failures rather than single-task success.
- [ ] Can Aviator or a merge queue be pointed at unsubmitted branches in
      practice? — resolved by testing, not by reading docs. Determines whether
      the "in-progress window" is a moat or a temporary gap.
- [ ] What fraction of integration failures are catchable by deterministic
      checks alone (compiler, type checker, schema validator, existing tests)
      versus requiring new test generation? — resolved on the bench corpus.
      Determines whether the product can honour "no model-only verdicts".
- [ ] What is the actual cost per verified combination on a real monorepo, and
      does incremental check selection keep it inside a laptop's budget? —
      resolved by measurement during the execution-engine change.
- [ ] Is there a published rate for agent PRs that pass their own CI and then
      break main? — searched without success in this pass; **unverified, not
      absent**. Worth one more attempt before OpenMerge Bench assumes it does
      not exist.
- [ ] Is `omrg` free of collision on crates.io, npm, Homebrew, and trademark
      registers, and is `openmerge` available as a package name? — unverified;
      blocks any public launch, blocks nothing before it.

## Sources

- [arXiv:2607.04697v2 — AI Agent Pull Requests on GitHub: Frequency, Structure, and Merge Conflict Rates](https://arxiv.org/abs/2607.04697v2)
- [arXiv:2604.03551 — AgenticFlict: A Large-Scale Dataset of Merge Conflicts in AI Coding Agent Pull Requests on GitHub](https://arxiv.org/abs/2604.03551)
- [arXiv:2101.06542 — ConE: A Concurrent Edit Detection Tool for Large Scale Software Development](https://arxiv.org/abs/2101.06542)
- [arXiv:2310.02395 — Detecting Semantic Conflicts with Unit Tests](https://arxiv.org/abs/2310.02395)
- [arXiv:2605.20563 — Multi-agent Collaboration with State Management (STORM)](https://arxiv.org/abs/2605.20563)
- [arXiv:2606.15376 — CoAgent: Concurrency Control for Multi-Agent Systems](https://arxiv.org/abs/2606.15376)
- [git-merge-tree documentation](https://git-scm.com/docs/git-merge-tree)
- [Clash — clash-sh/clash](https://github.com/clash-sh/clash)
- [Worktrunk — max-sixty/worktrunk](https://github.com/max-sixty/worktrunk)
- [Aviator MergeQueue — Parallel Mode](https://docs.aviator.co/mergequeue/concepts/parallel-mode)
- [Claude Code hooks reference](https://code.claude.com/docs/en/hooks)
- [GitHub Copilot hooks reference](https://docs.github.com/en/copilot/reference/hooks-reference)
- [Codex hooks documentation](https://learn.chatgpt.com/docs/hooks)
