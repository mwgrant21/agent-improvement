---
loop: daily-triage
level: 1
paused: false
attempt_cap: 3
budget: soft
last_run: 2026-08-22
runs_since_retro: 5
constrained_scopes: []
---
## State Ownership
<!-- Retrofitted 2026-08-22 adopting the loop-design "state ownership ledger"
     convention (loops/README.md, stolen from lidge-jun/opencodex during
     evaluate-repo). This file was 134 lines at retrofit time; the rows below
     are the honest current growth pattern, not aspirational caps. -->
| Category | Location | Cap / rotation policy |
|---|---|---|
| runs.jsonl | loops/daily-triage/runs.jsonl | Unbounded, append-only by design - source of truth for retrospectives. No cap; rotate via log-archivist if reads become slow. |
| Adjustment ledger | STATE.md body | Unbounded rows, one per proposed refinement; landed rows never deleted (re-checked each retrospective per R1). Rotate older LANDED rows to a dated archive via log-archivist if STATE.md exceeds ~50KB. |
| Human Decisions | STATE.md body | Unbounded append-only; retired decisions kept (not deleted) so a future run doesn't misread absence as loss. Same log-archivist rotation trigger as the Adjustment ledger. |
| Watch List | STATE.md body | Bounded by active repo/branch count (~20 currently); an item is pruned to "Resolved since last run" once it closes, so this section self-bounds in practice. |
| High Priority | STATE.md body | Small by construction - an item here is actively awaiting a human decision; moves to Human Decisions or Resolved once decided. |
| Recent Noise / Untriaged noise | STATE.md body | Small, cleared as items get `[FP]`-marked or decided; self-bounding. |
| Resolved since last run | STATE.md body | Pruned every run per existing step-2 convention; prior entries live in git history, not here. |
| constrained_scopes | STATE.md frontmatter | Empty by default; human-added/removed only (Intervention ladder step 2) - naturally small. |

## Constrained Scopes
<!-- Human-added/removed only (loops/README.md, Intervention ladder step 2).
     Each entry: {scope, reason, since, reconsider}. Empty currently -->
(none currently)

**Retrospective completed 2026-08-17** (runs 11-20). `runs_since_retro` now 5 (runs 21-25). Run 24 was a deliberate, human-requested SECOND run on 2026-08-21, taken specifically to exercise the `record-behind-by-alongside-ahead-by` change applied earlier the same day. **Run 25 (2026-08-22) is the first run in this window FROM home-matt** (hostname TITAN) rather than work-it - the machine-tag freeze/verify directionality flipped correctly with no LOOP.md change needed.

## High Priority (waiting on human)
- **NEW (run 25, 2026-08-22): 2 of `TokenMonitorV2`'s 3 tracked non-default branches disappeared from GitHub since run 24 with NO recorded Human Decision authorizing it - unlike `reskin-phases-3-4`, whose closure IS documented (see Resolved, 2026-08-21).**
  - `reskin-phase-5` - was `20a/32b`, sitting exactly at the >20-commit escalation boundary, with 20 commits of unique unmerged work. Gone from GitHub. The local home-matt clone's stale remote-tracking ref still remembers its tip (`f05342ef24a785de7b1bdad02aeaa37a561b3ea1`) as of this run, which may allow recovery via `git fetch` before that ref is pruned - but this loop is read-only and will not run that itself.
  - `chore/postinstall-install-electron` - was `1a/27b`, lower risk (1 commit, likely absorbed given `M=27`), also gone with no recorded decision.
  - [action: confirm whether this was an authorized cleanup (like the 2026-08-21 fleet branch cleanup) that simply wasn't logged, or verify `reskin-phase-5`'s 20 commits landed somewhere before the local stale ref is pruned]
- ~~Two adjustments were sitting undecided...~~ **RESOLVED same day (2026-08-21): both `clarify-repo-discovery-depth-definition` and `freeze-unchanged-runs-when-not-verified` were decided and APPLIED via the loop-design skill - see the Adjustment ledger and Human Decisions section.** Carried here only as a standing note that this item existed and closed the same day it was raised, not as an open action.

## Retrospective outcome (2026-08-06, runs 1-10)
- Refinements 1-6 APPROVED and applied to LOOP.md via the loop-design skill: loop-derived noise counting (1), revised spend/cache thresholds (2), discovered scan roots + source-unavailable reporting (3), machine-tagged hygiene items (4), stale-only uncommitted-changes reporting (5), and a verified commit/push of the loop's own state as step 5 (6).
- Refinements 7 (branch staleness by commits-ahead rather than tip date) and 8 (cache PR/issue results for quiet repos) were HELD, then approved and applied the same day - see the ledger.
- L2 promotion HELD at the user's decision despite the gate being literally met. Re-evaluated by the 2026-08-17 retrospective: NOT MET (see below).
- Refinement 9 APPROVED and applied the same day: the retrospective now reconciles the Adjustment ledger (below) as its FIRST step, per-run critiques record a structured `notes.adjustment` entry, and an adjustment proposed `attempt_cap` (3) times without landing escalates instead of being re-proposed.

## Retrospective outcome (2026-08-17, runs 11-20)
- **Step R1 (ledger reconciliation)**: all 12 rows marked LANDED were re-verified by grepping the CURRENT `LOOP.md` text (not by trusting the ledger table) - all 12 confirmed present, none regressed. Ledger fully cleared the same day across 6 human decisions.
- **Step R2/R3**: all outstanding items decided - 4 applied, 1 held, 1 declined. See Adjustment ledger and Human Decisions.
- **L2 promotion gate, explicitly re-evaluated**: NOT MET, and for the first time a real (not silent-zero) measurement. `false_positives` non-zero on 3 of runs 11-20 (=3, above the <=2 gate) and 2 unresolved escalations open at the time against a gate requirement of 0. Recommendation: do not propose promotion.

## Adjustment ledger
<!-- Seeded 2026-08-06 from the prose critiques of runs 1-10, which predate the structured notes.adjustment field. Retrospective step R1 reconciles this every 10th run by grepping LOOP.md and scripts/ - never by trusting this table's own text. Landed rows STAY here and get re-checked; a landed row that goes missing is REGRESSED and escalates. -->
| id | first_proposed | times | status |
|---|---|---|---|
| batch-branch-commit-date-lookups | 2026-07-14 | 5 | LANDED 2026-08-03 (branch_tips cache, step 1) |
| fix-spend-summary-date-window | 2026-07-17 | 1 | LANDED 2026-07-22 (scripts/spend-summary.mjs local-day bucketing) |
| record-output-token-baseline | 2026-07-17 | 1 | LANDED 2026-07-18 (step 3 notes) |
| flag-branches-20-commits-ahead | 2026-07-18 | 1 | LANDED 2026-08-06 (step 1, local hygiene - promotes a >20-ahead branch to High Priority) |
| branch-staleness-by-commits-ahead | 2026-07-21 | 1 | LANDED 2026-08-06 (step 1, GitHub - implemented as author-date staleness + `ahead_by` as a separate signal, NOT as the literal "replace date with commits-ahead") |
| verify-loop-own-commit-completed | 2026-07-24 | 1 | LANDED 2026-08-06 (retro refinement 6, step 5) |
| self-confirming-noise-without-fp-mark | 2026-07-24 | 1 | LANDED 2026-08-06 (retro refinement 1, step 2) |
| promote-tokenmonitor-pr1-to-human-decisions | 2026-08-03 | 2 | LANDED 2026-08-06 (Human Decisions section) |
| cache-quiet-repo-pr-issue-results | 2026-08-04 | 1 | LANDED 2026-08-06 (step 1, GitHub - implemented by ELIMINATING the per-repo sweep via one fleet-wide `gh search prs`/`gh search issues` call, NOT by caching a quiet-repo negative) |
| drop-bare-uncommitted-changes-signal | 2026-08-04 | 1 | LANDED 2026-08-06 (retro refinement 5, step 1) |
| machine-tag-watchlist-items | 2026-08-06 | 1 | LANDED 2026-08-06 (retro refinement 4, step 2) |
| exclude-default-branches-from-staleness | 2026-08-06 | 1 | LANDED 2026-08-06 (step 1, GitHub) |
| gate-cache-flag-on-min-volume | 2026-08-07 | 3 | **DECLINED 2026-08-17 (human decision).** Escalated at attempt_cap; 3-of-5 low-volume data points against the hypothesis. Not re-propose-eligible absent new evidence. |
| noise-match-on-finding-identity-not-text | 2026-08-10 | 1 | **LANDED 2026-08-17.** Step 2 now matches on finding identity (repo + branch/path + recommendation, volatile fields like age stripped) instead of literal rendered text. |
| distinguish-broken-probe-from-dead-source | 2026-08-11 | 3 | **LANDED 2026-08-17.** Step 1 distinguishes a dead/absent source from a multi-target source where 100% of targets fail the same way. |
| specify-branch-tips-cache-key-format | 2026-08-11 | 2 | **LANDED 2026-08-17.** Canonicalized on the FULL 40-char SHA; a shorter cached `sha` is a miss. |
| record-behind-by-alongside-ahead-by | 2026-08-21 | 1 | **LANDED 2026-08-21 (human decision, applied via loop-design skill).** Step 1 records `behind_by` from the SAME compare call that already returns `ahead_by` (zero extra API calls), reports the pair as `Na/Mb`, and requires a divergent branch (ahead>0 AND behind>0) to be labelled `divergent, verify against the default branch before proposing a merge`. **First exercised by run 24 (2026-08-21) - see that run's digest: 4 of the fleet's 5 non-default branches turned out to be DIVERGENT, none of which the old `ahead_by`-only format could have distinguished from clean fast-forwardable work.** |
| clarify-repo-discovery-depth-definition | 2026-08-18 | 3 | **LANDED 2026-08-21 (human decision, applied via loop-design skill).** Reached attempt_cap without ever being escalated, because runs 23 and 24 each declined to re-propose it precisely to avoid tripping the cap - a dodge the loop itself flagged as unsustainable. Settled by MEASURING both readings on work-it rather than arguing them: depth-to-`.git` yields 16 repos, depth-to-repo-dir yields 20, and runs 23 and 24 had silently used different ones. LOOP.md step 1 now pins depth to the REPO DIRECTORY (`find <root> -maxdepth 3 -name .git`), names `~/Downloads` as a third scan root (run 24 was already using it undocumented), and classifies a `.git` FILE as a linked worktree attributed to its parent instead of counted separately. |
| freeze-unchanged-runs-when-not-verified | 2026-08-21 | 1 | **LANDED 2026-08-21 (human decision, applied via loop-design skill).** Proposed by run 23 from its own false finding. A run that does not OBSERVE a repo now carries `unchanged_runs` forward frozen with `frozen_not_verified: true` instead of incrementing it, so the 3-run staleness flag can only count runs that actually looked. Evidence: runs 21 and 22 stepped `Aether-OS-livetest` 6 to 7 while recording "not verified this run", and run 23's first live check found 5 dirty paths against 4 cached - a 7-run-stale finding built entirely on observations nobody made. |
| dedupe-same-day-spend-baseline | 2026-08-21 | 1 | **LANDED 2026-08-21 (human decision, applied via loop-design skill).** Proposed by run 24, applied same day. Spend/cache figures identical to the previous run-log line are a RE-READ, not a new sample: now tagged `spend_duplicate_of`, excluded from the trailing-5 median, and any threshold firing on one is labelled `same reading as run <N>`. Surfaced only because the loop ran twice in one day; a once-daily loop could not have exposed it. |
| dirty-count-blind-to-content-churn | 2026-08-13 | 1 | **LANDED 2026-08-17.** Staleness check compares the dirty file PATH SET, not the line count; `dirty_lines` -> `dirty_paths`. |
| expand-home-matt-discovery-root | 2026-08-15 | 1 | **HELD 2026-08-17 (human decision).** Rests on a single home-matt-only observation unverifiable from work-it. Re-propose with home-matt confirmation. |
| validate-jsonl-line-before-append | 2026-08-17 | 1 | **LANDED 2026-08-17.** Round-trip `JSON.parse(JSON.stringify(...))` before appending a run's own line. |
| worktree-hygiene-report | 2026-08-21 | 1 | **LANDED 2026-08-21 (human decision, applied via loop-design skill, same day as proposed).** New step-1 local-repo-hygiene check: for each discovered repo's worktrees, flag any whose branch is already merged or gone as a one-line finding. Report-only - the loop never runs `git worktree remove`. No cache added (worktree counts are small; measured cheap enough to run in full each time per the uncached-path lesson). |
| gitignore-and-auth-drift-check | 2026-08-21 | 1 | **LANDED 2026-08-21 (human decision, applied via loop-design skill, same day as proposed).** Two new step-1 checks: (a) per-repo, flag a `.gitignore` that excludes `.worktrees/` but not `.claude/worktrees/` - the exact drift that produced false test failures in both TokenMonitor and aether-os; (b) a single fleet-wide `gh auth status` check per run (not per repo) - if invalid, one finding naming the shared cause, worded as "likely also blocks git push" since this loop never runs a real push and cannot confirm push would succeed even when auth looks clean. |
| close-expand-home-matt-discovery-root | 2026-08-22 | 1 | **PROPOSED by run 25 - not yet a human decision.** Running from home-matt for the first time, run 25 confirms `~/projects` (12 repos) is ALREADY reached by the existing `~` scan root at the repo-dir depth-3 rule landed 2026-08-21 (`~/projects/<repo>/.git` is exactly 3 levels deep). This suggests the HELD `expand-home-matt-discovery-root` adjustment is moot and needs no LOOP.md change - proposing to CLOSE it rather than re-propose it, pending a human decision to that effect. |

Ledger standing (last full reconciliation 2026-08-17, plus same-day-as-proposed landings since): **23 of 26 landed**, 1 declined (`gate-cache-flag-on-min-volume`), 1 held (`expand-home-matt-discovery-root`, new run-25 evidence above suggests closing it), 1 new proposal awaiting decision (`close-expand-home-matt-discovery-root`), 0 escalated at attempt-cap.

Pending since that reconciliation (in `runs.jsonl` `notes.adjustment` / `notes.outstanding_adjustments`, NOT yet ledger rows - R1 will collect them): `clarify-repo-discovery-depth-definition` (first_proposed 2026-08-18, 2x, OUTSTANDING - see High Priority), `freeze-unchanged-runs-when-not-verified` (first_proposed 2026-08-21, 1x, from run 23), `dedupe-same-day-spend-baseline` (first_proposed 2026-08-21, 1x, from run 24), and `close-expand-home-matt-discovery-root` (first_proposed 2026-08-22, 1x, NEW from run 25).

Note for the next retrospective's step R1: two rows deviate from their original proposal text ON PURPOSE, and each row says how - `branch-staleness-by-commits-ahead` became author-date staleness plus a separate `ahead_by` signal, and `cache-quiet-repo-pr-issue-results` became a fleet-wide search that removes the calls rather than a cache of their answers. Both would read as never-landed under a naive text match. Also: when reading `runs.jsonl` in full for R1, line 27 is invalid JSON - use a tolerant per-line parse that logs-and-skips rather than aborting.

## Watch List
- **Fleet PR/issue counts: 0 open PRs, 1 open issue.** Both live-verified (`gh search`, `--limit 100` - PR search now empty, issue search 1 result - nowhere near the limit, not truncated). The empty PR result is the CORRECT reading, per run 24's Resolved note: the fleet has had zero open PRs since `TokenMonitorV2#1` was closed 2026-08-21. [machine: any]
  - `Aether-OS#22` white screen after desktop lock. Still instrumented but NOT fixed, `updatedAt` still 2026-08-12 (now 10 days idle). Deliberately left open. [action: none until it recurs - then grab the dev output and grep `[diag]` BEFORE closing the window] [machine: any]
- **`TokenMonitor` `req-4-stryker-ci-gate` is now `1a/53b`: DIVERGENT, jumped from `1a/2b` at run 24** (author-date 2026-08-17 unchanged - branch itself didn't move, but `master` advanced 51 commits past it in the interim, consistent with tonight's heavy commit session on this repo). Still a young/small divergence, not stale. [action: none yet, tracking - the base is moving fast under this branch, worth a rebase before it grows further] [machine: any]
- **`TokenMonitorV2` `reskin-phase-5` and `chore/postinstall-install-electron` are GONE from GitHub - see High Priority, this is not a routine resolution like `reskin-phases-3-4`'s.** [machine: any]
- **`agent-improvement` candidate buffer on home-matt is 357 pending lines (was 277 at last home-matt observation - grew 80 in the interim).** [action: run an `agent-learn` promote pass on home-matt] [machine: home-matt]
- **NEW: `cli-shared-memory` (home-matt) now has an extra worktree at `.claude/worktrees/git-arbiter-plan` (branch `worktree-git-arbiter-plan`).** Not merged into `master`, not `[gone]` - active work, no worktree-hygiene flag warranted. [action: none, informational] [machine: home-matt]
- **NEW: gitignore gap - `aether-os` and `TokenMonitorV2` both have `.gitignore` `.worktrees/` but not `.claude/worktrees/`.** `TokenMonitorV2` actually has a live `.claude/worktrees/` directory on home-matt right now. Same drift class documented in `domains/testing.md` that previously caused false test failures in `TokenMonitor` (already fixed there) and `aether-os`. [action: add `.claude/worktrees/` to both `.gitignore`s] [machine: any - GitHub-side config, not local state]
- **NEW: `TokenMonitorV2` (home-matt clone) now has 1 unpushed commit on `main`** (`a0ea66b` "Add Stryker mutation testing", ahead 1 of `origin/main`) where 0 was recorded at last observation; the previously-dirty `.claude/` path is now clean. [action: none, tracking - push when ready] [machine: home-matt]
- `aether-os` (home-matt, `~/projects/aether-os`) - local branches now down to 2 (`master` + `real-projects-view-stage16`, both tracked, neither `[gone]`), an improvement on the previously-noted 3 stale/`[gone]` branches. Working tree has new dirty paths (`PROGRESS.md`, `PROGRESS.archive-2026-08-21.md`, `PROGRESS.standing-decisions.md`) consistent with a log-archivist compression pass run tonight - treated as a fresh baseline. [action: none, tracking] [machine: home-matt]
- `TarotApp` (home-matt) - 3 unpushed, 8 ahead of `origin/master`, 3 dirty (same 3 paths as before, `unchanged_runs` now 2 of 3). [action: none, tracking - one more identical observation flags it as noise] [machine: home-matt]
- `tarot` (home-matt) - **1 unpushed** on `master` (was recorded as 3 previously - live count this run is 1; treat the new figure as current, no upstream tracking on `master`), 4 dirty (same set, `unchanged_runs` 2 of 3). [action: none, tracking] [machine: home-matt]
- `Miriels-publish` (home-matt) - 1 unpushed, ahead 1, 3 dirty (same set as before, `unchanged_runs` 2 of 3); same 3 paths as `tarot`'s dirty set (shared boilerplate). [action: worth checking whether this is one fix that should land in both repos] [machine: home-matt]
- `About-me` (home-matt) - 1 dirty (`README.md`, `unchanged_runs` 2 of 3). [action: none] [machine: home-matt]
- `nmmtools` (home-matt) - 1 dirty (`testResults.xml`, `unchanged_runs` 2 of 3). Known recurring test-artifact pattern. [action: none, known benign] [machine: home-matt]
- **`cli-shared-memory` (home-matt) - untracked `.claude/`, STILL not committed - 4th consecutive identical observation (`unchanged_runs` now 4).** Human Decision remains "commit it", execution still pending. [action: pending human action on home-matt; do not re-ask for a decision] [machine: home-matt]
- **`code-graph-mcp` (home-matt) - RESOLVED: previously-dirty `package-lock.json` is now clean.** [action: none] [machine: home-matt]
- `TokenMonitor` (home-matt clone) - 1 dirty (`.archex/`, `unchanged_runs` 0->1), checked-out branch is `req-4-stryker-ci-gate` not `master`. [action: none] [machine: home-matt]
- `~/.claude` (dotclaude, home-matt - the loop's own harness config repo, distinct from `~/agent-improvement`) - 5 dirty paths unchanged from cached baseline (`unchanged_runs` 0->1). [action: none, tracking] [machine: home-matt]
- **CONFIRMATION toward closing `expand-home-matt-discovery-root` (HELD 2026-08-17): running from home-matt this run, `~/projects` (12 repos) is reached by the existing `~` scan root at depth-3 - no gap found.** See Adjustment ledger `close-expand-home-matt-discovery-root`. [machine: home-matt]
- `agent-improvement` store (home-matt) - `prototyping-tasks/` and `docs/specs/` etc. are now tracked/committed as of tonight's session (per the task context); store is clean and level with `origin/master`, re-verified this run. [action: none] [machine: home-matt]
- `.agency-agents` and `claude-power-automate` (home-matt) - clean, non-`mwgrant21` remotes, outside fleet PR/issue scope, re-verified this run. [action: none] [machine: home-matt]
- Literal tilde-named directory at `C:\Users\Matt\~\vexjoy-agent` holding a clean clone of `notque/vexjoy-agent`, re-verified this run. [action: none required, worth a rename if unintentional] [machine: home-matt]
- **NOT VERIFIABLE THIS RUN (machine flip - these are work-it-only paths, frozen not incremented):** `Aether-OS-livetest` (5 dirty paths, 101 behind `origin/master`, `unchanged_runs` frozen at 1), `NMMToolkit` (29 dirty paths, `unchanged_runs` frozen at 1), `uw-mail-router` Downloads clone (1 dirty, `unchanged_runs` frozen at 1), `Desktop\cli-shared-memory-agents\claude`/`codex` worktrees, `dept-tools`, `uw-router-teams-tab`, `NMMTools`/`Jira-Autoticketing`/`EFIPartitionRemediation`/`RoundRobin`/`it-claude-marketplace`/`claude-config` local state, and the Desktop stray `.git`. GitHub-side branch/PR/issue data for all of these is still fresh (fleet-wide calls are machine-agnostic); only their LOCAL dirty/unpushed state is unverifiable from home-matt this run. [action: none, resume verification next work-it run] [machine: work-it]

## Recent Noise (ignored this run)
<!-- Mark an item [FP] if it was a false positive. Refinement 1: the loop ALSO counts an item whose FINDING IDENTITY (volatile fields like age stripped) is unchanged across 3 consecutive runs with no human action as noise on its own evidence, without waiting for a mark. -->
- Spend threshold: today's **386,911** output tokens - under the 750,000 absolute floor, so the two-part AND gate cannot fire. No flag.
- Cache threshold: today's **98.8%** - clears both the 0.90 absolute floor and the median-minus-5pp floor (0.911, from a 0.961 five-run median). **No flag** - the 2-run flag streak (runs 23, 24) breaks here on real data, not a suppression.
- `gate-cache-flag-on-min-volume` was DECLINED 2026-08-17 and is deliberately NOT re-proposed; the flag is reported as the protocol currently specifies.

## Untriaged noise
(none currently) - the run-24 cache-threshold streak resolved itself this run (98.8% clears both floors), so the item that was pending a `[FP]`/accept decision is now moot; no decision needed.

## Human Decisions (overrides the loop must respect)
- TokenMonitor PR #1 ("Terminal project folder + repo CLAUDE.md") was the user's own active PR. **MERGED**; override satisfied and retired. Recorded rather than deleted so a future run does not read its absence as the decision having been lost.
- **2026-08-17: adjustment `gate-cache-flag-on-min-volume` DECLINED.** Treat as closed; do not re-propose absent materially new evidence (e.g. a longer run of low-volume days).
- **2026-08-17: adjustment `distinguish-broken-probe-from-dead-source` APPLIED.** User delegated the accept/decline call to the agent.
- **2026-08-17: remaining 5 OUTSTANDING adjustments decided in one pass.** 4 APPLIED (`noise-match-on-finding-identity-not-text`, `specify-branch-tips-cache-key-format`, `dirty-count-blind-to-content-churn`, `validate-jsonl-line-before-append`), 1 HELD (`expand-home-matt-discovery-root` - rests on an unverifiable claim about another machine's filesystem).
- **2026-08-21: `Aether-OS` branch cleanup APPROVED and EXECUTED out-of-band** (L1 boundary intact - the loop reported, a human authorized, a separate session acted). Went from **17 local + 4 remote branches to 1 + 1 (`master` only, both sides) in a single day.** Every deletion was verified merged / `ahead_by 0` with no open PR first; locals used `git branch -d`, never `-D`. **Run 24 confirms the end state live: 1 remote branch (`master`) and 1 local branch, working tree clean, 0 unpushed, 0 `[gone]`.** Three remote branches disappearing at once between runs 23 and 24 is THIS cleanup, not a probe failure - and run 24 correctly did not trip the broken-probe rule on it. A future run must treat ANY new branch there as new work; the baseline is zero.
- **2026-08-21: fleet-wide branch cleanup APPROVED and EXECUTED out-of-band.** 8 local branches deleted across `TokenMonitorV2` and `claude-token-tracker`; `TokenMonitor/chore/electron-43.4.1` deleted from the remote by the human directly. **Run 24 confirms live: `claude-token-tracker` now holds 1 local branch (was 9), `TokenMonitorV2` 4 (was 5), zero `[gone]`-tracking branches anywhere on work-it, zero unpushed commits anywhere on work-it.** This RESOLVES run 23's `claude-token-tracker` "4 `[gone]` of 9" finding. Do not re-raise.
- **2026-08-21: `TokenMonitor` `worktree-packages-core-wiring` ABANDONED.** Merge attempted, investigated, REFUSED as unsafe (it deleted 788 lines master had since extended, and added an absolute `file:` path into another repo's working tree). Local branch `-D`'d by design, remote branch deleted, worktree `.claude/worktrees/packages-core-wiring` removed. **Commit preserved for recovery: `43fde10ab80909e50cf0d6c2768a96d29108ac28`.** Run 24 confirms the branch is absent from the remote listing. This branch is the entire evidentiary basis for `record-behind-by-alongside-ahead-by` (it was `1a/45b`). Do not re-raise.
- **2026-08-21: `EFIPartitionRemediation` `feature/fleet-migration-runbook` MERGED** (fast-forward `e5f1ca7..c77a650`, pushed). **The branch was deliberately NOT deleted** - it is checked out in the live worktree `~/Desktop/EFI-wt-migration`, so deleting it would break that worktree. Run 24 measures it at `0a/0b` (fully absorbed dead weight, author-date 2026-08-06, 15 days - i.e. it WOULD now cross the staleness line and WOULD read as safe-to-delete under the new rules). **It is suppressed by this decision and must not be re-raised as a finding.** Its continued existence and checkout are deliberate.
- **2026-08-21: `cli-shared-memory` (home-matt) untracked `.claude/` - DECISION IS `commit it`. NOT YET DONE.** STOP asking for a decision; carry it as a pending human action tagged `[machine: home-matt]`. Mark Resolved only once a run FROM home-matt observes the path set gone. A work-it run must report it `not verifiable on work-it` and must not infer completion from its own clone being clean.
- **2026-08-21: adjustments `worktree-hygiene-report` and `gitignore-and-auth-drift-check` APPLIED**, outside the normal retrospective cycle, by direct human request during a session evaluating candidate new agents/loop-checks against real project history. Three new step-1 findings added: stale/merged worktree detection, `.gitignore` `.worktrees/`-vs-`.claude/worktrees/` drift, and a once-per-run `gh auth status` check. All three stay within the L1 report-only boundary (no deletion, no push, no auto-fix) and reuse the existing repo-discovery step rather than adding a new one. See Adjustment ledger for full reasoning; ledger now 23 landed / 1 declined / 1 held / 0 outstanding / 0 escalated.

## Resolved since last run
<!-- Pruned each run per step 2. Prior entries remain in git history. -->
- **Cache-threshold flag streak - CLEARED.** Today's 98.8% hit rate clears both floors; the run-24 Untriaged-noise item asking for a `[FP]` decision is now moot.
- **`code-graph-mcp` (home-matt) - dirty `package-lock.json` RESOLVED**, tree now clean.
- **`TokenMonitorV2` (home-matt) - dirty `.claude/` RESOLVED** (tree now clean), but a new unpushed commit appeared - see Watch List.
- **`aether-os` (home-matt) local branch cleanup - the previously-noted 3 stale/`[gone]` branches are down to 1 extra branch (`real-projects-view-stage16`), tracked, not `[gone]`.**
- Test-residue defect in `tests/EFIMigrationState.Tests.ps1` (REPORTED, NOT FIXED, carried forward - not independently verifiable from home-matt, no new evidence this run). [action for a human: strip any pre-existing deny ACE in the test's SETUP]
- `agent-improvement` domain freshness: newest `Added:` across `domains/*.md` is **2026-08-21**, 1 day old - well inside the >7-day threshold.
- `agent-improvement` store: clean and level with `origin/master` at the start of this run (re-verified from home-matt), no out-of-scope untracked files.
- `gh auth status`: OK, logged in as `mwgrant21`, active - no auth-drift finding this run.
- BRANCH PROBE: 0 total failures across 23 repos' branch listings; 7 default-branch author-date lookups plus 1 compare-call refresh spent (all others served from cache), consistent with normal per-run cost now that the `behind_by` schema migration cost from run 24 is behind us.
- SPEND: no flag. CACHE: no flag (see Recent Noise).
