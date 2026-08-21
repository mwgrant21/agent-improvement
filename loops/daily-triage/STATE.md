---
loop: daily-triage
level: 1
paused: false
attempt_cap: 3
budget: soft
last_run: 2026-08-21
runs_since_retro: 4
constrained_scopes: []
---
## Constrained Scopes
<!-- Human-added/removed only (loops/README.md, Intervention ladder step 2).
     Each entry: {scope, reason, since, reconsider}. Empty currently -->
(none currently)

**Retrospective completed 2026-08-17** (runs 11-20). `runs_since_retro` now 4 (runs 21-24). Run 24 was a deliberate, human-requested SECOND run on 2026-08-21, taken specifically to exercise the `record-behind-by-alongside-ahead-by` change applied earlier the same day.

## High Priority (waiting on human)
- **Two adjustments are sitting undecided, and one of them will force an escalation the next time it is proposed.** `clarify-repo-discovery-depth-definition` (first_proposed 2026-08-18, 2x, OUTSTANDING) was deliberately NOT re-proposed by runs 23 and 24 precisely to avoid tripping `attempt_cap` (3) before a human has had a chance to rule on it - that avoidance is not sustainable and is itself now 3 days old. `freeze-unchanged-runs-when-not-verified` (first_proposed 2026-08-21, 1x, from run 23) is also undecided. [action: decide both, or explicitly HELD-with-reason, before the next retrospective]

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
| dirty-count-blind-to-content-churn | 2026-08-13 | 1 | **LANDED 2026-08-17.** Staleness check compares the dirty file PATH SET, not the line count; `dirty_lines` -> `dirty_paths`. |
| expand-home-matt-discovery-root | 2026-08-15 | 1 | **HELD 2026-08-17 (human decision).** Rests on a single home-matt-only observation unverifiable from work-it. Re-propose with home-matt confirmation. |
| validate-jsonl-line-before-append | 2026-08-17 | 1 | **LANDED 2026-08-17.** Round-trip `JSON.parse(JSON.stringify(...))` before appending a run's own line. |

Ledger standing (last full reconciliation 2026-08-17): **17 of 19 landed**, 1 declined, 1 held, 0 outstanding, 0 escalated. Plus `record-behind-by-alongside-ahead-by`, LANDED 2026-08-21 outside a retrospective: **18 of 20 landed**.

Pending since that reconciliation (in `runs.jsonl` `notes.adjustment` / `notes.outstanding_adjustments`, NOT yet ledger rows - R1 will collect them): `clarify-repo-discovery-depth-definition` (first_proposed 2026-08-18, 2x, OUTSTANDING - see High Priority), `freeze-unchanged-runs-when-not-verified` (first_proposed 2026-08-21, 1x, from run 23), and `dedupe-same-day-spend-baseline` (first_proposed 2026-08-21, 1x, NEW from run 24).

Note for the next retrospective's step R1: two rows deviate from their original proposal text ON PURPOSE, and each row says how - `branch-staleness-by-commits-ahead` became author-date staleness plus a separate `ahead_by` signal, and `cache-quiet-repo-pr-issue-results` became a fleet-wide search that removes the calls rather than a cache of their answers. Both would read as never-landed under a naive text match. Also: when reading `runs.jsonl` in full for R1, line 27 is invalid JSON - use a tolerant per-line parse that logs-and-skips rather than aborting.

## Watch List
- **Fleet PR/issue counts: 1 open PR, 1 open issue.** Both live-verified (`gh search`, `--limit 100`, 1 result each - nowhere near the limit, not truncated). [machine: any]
  - **`TokenMonitorV2#1` "Reskin phases 3-4..." - head branch `reskin-phases-3-4` is now measured `19a/32b`: DIVERGENT, verify against the default branch before proposing a merge.** The PR has been idle 8 days (`updatedAt` 2026-08-13, unchanged) while `main` advanced 32 commits past its merge-base. This is the first run that could say so - prior runs reported it as a bare "19 ahead", which reads as fast-forwardable and is not. [action: rebase/merge `main` into the PR branch and re-review, or close it - do NOT merge as-is] [machine: any]
  - **Sibling branch `reskin-phase-5` is `20a/32b`: DIVERGENT** (author-date 2026-08-13, 8 days). Still exactly at 20, i.e. at the >20-commit escalation boundary and not over it. [action: none, tracking - revisit if it reaches 21+] [machine: any]
  - `Aether-OS#22` white screen after desktop lock. Still instrumented but NOT fixed, unchanged (`updatedAt` 2026-08-12, 9 days). Deliberately left open. [action: none until it recurs - then grab the dev output and grep `[diag]` BEFORE closing the window] [machine: any]
- **`TokenMonitorV2` `chore/postinstall-install-electron` is `1a/27b`: DIVERGENT** (author-date 2026-08-19, 2 days - well under the 14-day staleness line, so this is a divergence finding, not a staleness one). Run 23 recorded it as "RESOLVED down to 1 ahead", which implied the work had been absorbed; the `behind_by` half shows the opposite reading is also available - 1 commit is still unmerged and the base has moved 27 past it. [action: verify against `main` before proposing a merge] [machine: any]
- **`TokenMonitor` `req-4-stryker-ci-gate` is `1a/2b`: DIVERGENT** (author-date 2026-08-17, 4 days - not stale). Small divergence, young branch. [action: none yet, tracking] [machine: any]
- **`Aether-OS-livetest` (work-it) - 5 dirty paths, path set IDENTICAL to run 23's live-verified baseline (`unchanged_runs` 1 of the 3 needed).** Separately still **101 behind `origin/master`**, unchanged. [action: no staleness action yet; the clone badly needs a pull] [machine: work-it]
- **`NMMToolkit` (work-it) - 29 dirty paths, path set IDENTICAL to run 23's baseline (`unchanged_runs` 1 of 3).** 0 unpushed, 0 behind. 26 of the 29 are `src/tools/**` scripts plus `build.ps1` and `tools.psd1`. [action: none yet, second consecutive identical observation] [machine: work-it]
- `uw-mail-router` (work-it, `Downloads\uw-mail-router`) - 1 dirty (`sim/simulator.html`), identical to run 23 (`unchanged_runs` 1 of 3), 0 unpushed. [action: none] [machine: work-it]
- **`agent-improvement` candidate buffer on work-it is 14 pending lines** (was 1 at run 23 - grew 13 in one day). [action: run an `agent-learn` promote pass on work-it] [machine: work-it]
- **NEW discovery: `Desktop\cli-shared-memory-agents\claude` and `...\codex` are git WORKTREES of `Desktop\cli-shared-memory`, not independent clones.** Both clean, 0 untracked, 0 unpushed, all three branches (`agent-claude`, `agent-codex`, `master`) at the same SHA `c3f7d45`. Their remote is named `github`, not `origin` - a probe that assumes `origin` reports "no such remote" on them, which is a naming quirk, not a missing remote. Local repo count 16 -> 18 is entirely these two. [action: none, benign] [machine: work-it]
- `aether-os` (home-matt, `~/projects/aether-os`) carries its own 3 stale/`[gone]`-tracking local branches. [action: optional cleanup, not urgent] [machine: home-matt, not verifiable on work-it]
- `TarotApp` (home-matt) - 3 unpushed, 8 ahead of `origin/master`, 3 dirty. [action: none, tracking] [machine: home-matt, not verifiable on work-it]
- `tarot` (home-matt) - 3 unpushed, no upstream tracking, 4 dirty. [action: none, tracking] [machine: home-matt, not verifiable on work-it]
- `Miriels-publish` (home-matt) - 1 unpushed, ahead 1, 3 dirty; same 3 paths as `tarot`'s dirty set (shared boilerplate). [action: worth checking whether this is one fix that should land in both repos] [machine: home-matt, not verifiable on work-it]
- `About-me` (home-matt) - 1 dirty (`README.md`). [action: none] [machine: home-matt, not verifiable on work-it]
- `nmmtools` (home-matt) - 1 dirty (`testResults.xml`). Known recurring test-artifact pattern. [action: none, known benign] [machine: home-matt, not verifiable on work-it]
- **`cli-shared-memory` (home-matt) - untracked `.claude/`. DECISION EXISTS (`commit it`), execution pending on home-matt.** The work-it clone is completely clean and has no `.claude/` at all, re-verified this run - so work-it can never close this. [action: pending human action on home-matt; do not re-ask for a decision] [machine: home-matt, not verifiable on work-it]
- `TokenMonitorV2` (home-matt clone) - 0 unpushed, 1 dirty (`.claude/`). The work-it clone is clean and level with `origin/main`. [action: none] [machine: home-matt, not verifiable on work-it]
- `agent-improvement` store (home-matt) - untracked `prototyping-tasks/` directory, out of scope for this loop's own writes. Absent on work-it. [action: none from this loop] [machine: home-matt, not verifiable on work-it]
- home-matt candidate buffer (277 pending lines at last home-matt observation) is a machine-local gitignored file, not visible from here. [action: home-matt should run a promote pass] [machine: home-matt, not verifiable on work-it]
- `.agency-agents` and `claude-power-automate` (home-matt) - clean, non-`mwgrant21` remotes, outside fleet PR/issue scope. `claude-power-automate` also exists on work-it (`~/claude-power-automate`) and is clean/level there, re-verified this run. [action: none] [machine: home-matt for the first, both for the second]
- Literal tilde-named directory at `C:\Users\Matt\~\vexjoy-agent` holding a clean clone of `notque/vexjoy-agent`. No equivalent on work-it. [action: none required, worth a rename if unintentional] [machine: home-matt, not verifiable on work-it]
- Desktop stray `.git` (`C:\Users\IT\Desktop`, work-it only): known/by-design; skipped, not re-raised. [action: none] [machine: work-it]

## Recent Noise (ignored this run)
<!-- Mark an item [FP] if it was a false positive. Refinement 1: the loop ALSO counts an item whose FINDING IDENTITY (volatile fields like age stripped) is unchanged across 3 consecutive runs with no human action as noise on its own evidence, without waiting for a mark. -->
- Spend threshold: today's **2,722** output tokens - far under the 750,000 absolute floor, so the two-part AND gate cannot fire. No flag.
- Cache threshold: today's **80.7% - FLAGGED** (below both the 0.90 absolute floor and the median-minus-5pp floor of 0.911, from a 0.961 five-run median). **These are the IDENTICAL figures run 23 read earlier today** - `spend-summary.mjs` returned byte-identical output (in 8 / out 2722 / cacheRead 337137 / cacheCreate 80809) because the usage log had not advanced between the two same-day runs. This is the same measurement re-read, NOT a second independent data point, and it is the evidence behind this run's adjustment `dedupe-same-day-spend-baseline`. Second consecutive run flagged; a third would make it loop-derived noise.
- `gate-cache-flag-on-min-volume` was DECLINED 2026-08-17 and is deliberately NOT re-proposed; the flag is reported as the protocol currently specifies.

## Untriaged noise
- **Cache-threshold flag - unmarked after 2 runs (23 and 24), asking for a decision.** It has now fired twice in a row on the same low-volume day, once as a genuine reading and once as a duplicate re-read of that same reading. The related `gate-cache-flag-on-min-volume` suppression was already DECLINED, so the question is narrower: is a same-day duplicate reading allowed to count as an independent flag at all? [decision needed: `[FP]` it, or accept the flag as correct-as-specified and let the third consecutive run auto-count it as loop-derived noise]

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

## Resolved since last run
<!-- Pruned each run per step 2. Prior entries remain in git history. -->
- **`Aether-OS` (work-it) `[gone]`-branch finding - CLOSED, live-verified.** 1 local branch, clean tree, 0 unpushed, 0 `[gone]`. Baseline is now zero.
- **`claude-token-tracker` (work-it) "4 `[gone]` of 9" finding - CLOSED, live-verified.** 1 local branch, clean, 0 unpushed.
- **`TokenMonitorV2` (work-it) - CLOSED.** `main` level with `origin/main`, clean, 0 unpushed, 0 `[gone]`; local `worktree-reskin-phases-3-4` gone.
- **`EFIPartitionRemediation` `feature/fleet-migration-runbook` "15d stale, 17 ahead, merge or abandon" - RESOLVED by MERGE.** Now `0a/0b`. The surviving branch + worktree are a standing human decision, not a finding.
- **`TokenMonitor` `worktree-packages-core-wiring` "17d stale, 1 ahead" - RESOLVED by ABANDONMENT.** Absent from the remote this run.
- **`Aether-OS-livetest` stale-WIP flag - stays CLEARED**; the 5-path set from run 23's live verification reproduced exactly, `unchanged_runs` now 1 of 3.
- **Test-residue defect in `tests/EFIMigrationState.Tests.ps1` (REPORTED, NOT FIXED, carried forward).** The ACL failure test applies a `Deny | SetValue` ACE to `HKCU:\Software\EFIMigrationTest\AclTest` and removes it only in a `finally`, so a killed run poisons every later run and surfaces as "Access to the registry key is denied" - reading as a broken environment rather than leftover test state. [action for a human: strip any pre-existing deny ACE in the test's SETUP]
- `agent-improvement` domain freshness: newest `Added:` across `domains/*.md` is **2026-08-21 (today)**, 0 days old - well inside the >7-day threshold.
- `agent-improvement` store: clean and level with `origin/master` at the start of this run, no out-of-scope untracked files on work-it.
- BRANCH PROBE: **0 failures, 28/28 branch listings and 28/28 commit lookups succeeded**, so the broken-probe rule did not fire and was not needed.
- SPEND: no flag. CACHE: **FLAGGED** - see Recent Noise and Untriaged noise.
