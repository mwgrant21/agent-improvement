---
loop: daily-triage
level: 1
paused: false
attempt_cap: 3
budget: soft
last_run: 2026-08-11
runs_since_retro: 4
---
## High Priority (waiting on human)
- **None this run.** No spend flag, no cache flag, no branch at the >20-commits-ahead escalation bar (NMMToolkit `master` is the closest at 9), and every source returned data. Stated explicitly so an empty section reads as "checked and clear", not as "not checked".

## Retrospective outcome (2026-08-06, runs 1-10)
- Refinements 1-6 APPROVED and applied to LOOP.md via the loop-design skill: loop-derived noise counting (1), revised spend/cache thresholds (2), discovered scan roots + source-unavailable reporting (3), machine-tagged hygiene items (4), stale-only uncommitted-changes reporting (5), and a verified commit/push of the loop's own state as step 5 (6).
- Refinements 7 (branch staleness by commits-ahead rather than tip date) and 8 (cache PR/issue results for quiet repos) were HELD, then approved and applied the same day - see the ledger.
- L2 promotion HELD at the user's decision despite the gate being literally met. Re-evaluate only after 10 runs in which `false_positives` is actually being fed by refinement 1. **3 of 10 done** (runs 11-13); run 13 is the first to record a NON-ZERO `false_positives` (1, loop-derived). [action: none until then]
- Refinement 9 APPROVED and applied the same day: the retrospective now reconciles the Adjustment ledger (below) as its FIRST step, per-run critiques record a structured `notes.adjustment` entry, and an adjustment proposed `attempt_cap` (3) times without landing escalates instead of being re-proposed.

## Adjustment ledger
<!-- Seeded 2026-08-06 from the prose critiques of runs 1-10, which predate the structured notes.adjustment field. Retrospective step R1 reconciles this every 10th run by grepping LOOP.md and scripts/ - never by trusting this table's own text. Landed rows STAY here and get re-checked; a landed row that goes missing is REGRESSED and escalates. -->
| id | first_proposed | times | status |
|---|---|---|---|
| batch-branch-commit-date-lookups | 2026-07-14 | 5 | LANDED 2026-08-03 (branch_tips cache, step 1) |
| fix-spend-summary-date-window | 2026-07-17 | 1 | LANDED 2026-07-22 (scripts/spend-summary.mjs local-day bucketing) |
| record-output-token-baseline | 2026-07-17 | 1 | LANDED 2026-07-18 (step 3 notes) |
| flag-branches-20-commits-ahead | 2026-07-18 | 1 | LANDED 2026-08-06 (step 1, local hygiene - promotes a >20-ahead branch to High Priority) |
| branch-staleness-by-commits-ahead | 2026-07-21 | 1 | LANDED 2026-08-06 (step 1, GitHub - held earlier the same day, then applied by explicit decision; implemented as author-date staleness + `ahead_by` as a separate signal, NOT as the literal "replace date with commits-ahead", which would have removed the time dimension entirely) |
| verify-loop-own-commit-completed | 2026-07-24 | 1 | LANDED 2026-08-06 (retro refinement 6, step 5) |
| self-confirming-noise-without-fp-mark | 2026-07-24 | 1 | LANDED 2026-08-06 (retro refinement 1, step 2) |
| promote-tokenmonitor-pr1-to-human-decisions | 2026-08-03 | 2 | LANDED 2026-08-06 (Human Decisions section) |
| cache-quiet-repo-pr-issue-results | 2026-08-04 | 1 | LANDED 2026-08-06 (step 1, GitHub - held earlier the same day, then applied by explicit decision; implemented by ELIMINATING the per-repo sweep via one fleet-wide `gh search prs`/`gh search issues` call, NOT by caching a quiet-repo negative, which would have created a window where a new PR goes unreported) |
| drop-bare-uncommitted-changes-signal | 2026-08-04 | 1 | LANDED 2026-08-06 (retro refinement 5, step 1) |
| machine-tag-watchlist-items | 2026-08-06 | 1 | LANDED 2026-08-06 (retro refinement 4, step 2) |
| exclude-default-branches-from-staleness | 2026-08-06 | 1 | LANDED 2026-08-06 (step 1, GitHub - proposed by run 11's critique and applied same day; implemented literally) |
| gate-cache-flag-on-min-volume | 2026-08-07 | 1 | OUTSTANDING (age 4d, awaiting decision). Run 13 is counter-evidence, not supporting evidence: today was another low-volume day (15,603 output tokens) and the cache flag did NOT fire (95.7% vs a 0.978 median = 2.1pp, inside the 5pp trigger). One low-volume day fired, one did not - the case for a volume gate is now weaker than run 12 argued. Decide on 2 data points or hold for more. |
| noise-match-on-finding-identity-not-text | 2026-08-10 | 1 | OUTSTANDING (proposed by run 13's critique; awaiting decision) |
| distinguish-broken-probe-from-dead-source | 2026-08-11 | 1 | OUTSTANDING (proposed by run 14's critique; awaiting decision) |
| specify-branch-tips-cache-key-format | 2026-08-11 | 1 | OUTSTANDING (proposed by run 14's critique; awaiting decision) |

Ledger standing: **12 of 14 landed**, 0 held, 2 outstanding (ages 3d and 0d). Before the 2026-08-06 retrospective the figure was 4 of 11 across 23 days.

Note for the next retrospective's step R1: two rows deviate from their original proposal text ON PURPOSE, and each row says how. When reconciling, check the file for what was ACTUALLY built, not for the phrase the critique used - `branch-staleness-by-commits-ahead` became author-date staleness plus a separate `ahead_by` signal, and `cache-quiet-repo-pr-issue-results` became a fleet-wide search that removes the calls rather than a cache of their answers. Both would read as never-landed under a naive text match.

## Watch List
- **Fleet is no longer quiet: 2 open PRs and 3 open issues**, up from zero last run. Counts are far below the `--limit 100` used on both searches, so neither result is truncated. [machine: any]
  - `TokenMonitor#3` "Replace opus-on-trivial-turns with a remediable delegation rule" - opened today, 2 commits; a Codex review returned 2 P1s, both fixed in `4a2a9a2`. [action: review and merge]
  - `Aether-OS#42` "Project scope switch: scope Ledger + Optimize to a selected project" - opened today. [action: review]
  - `Aether-OS#41` busy_timeout unset in `schema.OpenDatabase`, `#40` pre-v8 DBs missing nested subagents, `#22` white screen after desktop lock. All updated 2026-08-10. [action: triage - #41 and #22 both describe production-visible failures]
- **Four remote branches stale AND 0 ahead - all four pure dead weight.** Same set as last run; ages advanced. [machine: any]
  - NMMTools `codex/remote-business-tools` - 0 ahead, author-dated 2026-07-18 (**24d**). [action: delete from origin]
  - NMMTools `feature/wpf-gui` - 0 ahead, 2026-07-18 (**24d**). [action: delete from origin, but see the local caveat below]
  - TokenMonitor `terminal-project-cwd` - 0 ahead, 2026-07-19 (**23d**). [action: delete from origin AFTER confirming the local-only `714bff9` Stryker commit on `home-matt`] [machine: home-matt to confirm]
  - TokenMonitor `fix/live-feed-follows-active-session` - 0 ahead, 2026-07-24 (**18d**). [action: delete from origin]
- **NMMToolkit REGRESSED on unpushed work.** Last run recorded `master` ahead-2 as pushed and resolved; it is now **9 ahead of `origin/master`, 10 commits on no remote across all branches**, plus 1 dirty line. Below the >20 escalation bar, so Watch List not High Priority - but this is the second time this repo has accumulated unpushed work. [action: push `master`] [machine: work-it]
- CAVEAT on NMMTools `feature/wpf-gui`: the local `Desktop\NMMToolkit` clone still holds work on no remote on its local `feature/wpf-gui`. Deleting the REMOTE branch loses nothing remote-side but strands that local branch's upstream. [action: push or discard before deleting the remote branch] [machine: work-it]
- TokenMonitorV2 `reskin-phases-3-4` - local clone on that branch, level with origin, 1 dirty line (baseline run 1, suppressed as active WIP). Still no open PR backing it. [action: open a PR or merge when the reskin lands] [machine: any]
- claude-token-tracker (clone of `mwgrant21/TokenMonitor`): now on `reframe-model-routing-finding`, level with origin, PR #3 open. Dirty count has been **1 line (`?? .claude/`) unchanged for a 4th consecutive run** - still flagged per refinement 5. That path is the worktrees directory and is arguably permanent. [action: gitignore `.claude/` or add it to Human Decisions so it stops being re-flagged] [machine: work-it]
- Aether-OS (`Desktop\Aether-OS`): `master` level with origin, working tree clean, but still **1 commit on no remote** on another local branch. [action: push or delete that branch] [machine: work-it]
- `Desktop\Aether-OS-livetest` - second local clone of `mwgrant21/Aether-OS`. Dirty count moved 3 -> 4, so the count CHANGED and it is suppressed as active WIP, not flagged. [action: none, recorded] [machine: work-it]
- `code-graph-mcp` (GitHub): still zero branches - empty, no local clone. 3rd consecutive run with this recommendation. [action: populate or delete it] [machine: any]
- TarotApp: 2 unpushed commits still absent from the remote. Not verifiable on `work-it` - no local clone here. [action: confirm/push from the owning machine] [machine: home-matt]
- tarot, Miriels, nmmtools: not verifiable on `work-it` - no local clones here. [action: re-verify on the owning machine] [machine: home-matt]
- Desktop stray `.git` (`C:\Users\IT\Desktop`): present, no remote, tracks the whole Desktop tree. Known/by-design; skipped. [action: none] [machine: work-it]

## Recent Noise (ignored this run)
<!-- Mark an item [FP] if it was a false positive. Refinement 1: the loop ALSO counts an item byte-identical across 3 consecutive runs with no human action as noise on its own evidence, without waiting for a mark. -->
- **Untriaged noise awaiting a decision (4th consecutive run)**: the **NMMTools 0-ahead branch pair** (`codex/remote-business-tools`, `feature/wpf-gui`), same "delete from origin" recommendation, no human action across runs 11-14. Counted again as loop-derived noise - `false_positives: 1`. [decision needed: delete the branches, or mark `[FP]`/suppress in Human Decisions]
- The TokenMonitor 0-ahead pair (`terminal-project-cwd`, `fix/live-feed-follows-active-session`) is now on its 2nd consecutive run with the same recommendation - one short of the 3-run bar. Named here so it is not "discovered" as new next run.
- Refinement 1's mechanical defect persists (adjustment `noise-match-on-finding-identity-not-text`, OUTSTANDING): the literal test is "byte-identical across 3 runs", but every staleness item embeds an age that increments each run (23d -> 24d), so no such item can ever satisfy it. Counted on INTENT again this run.
- `claude-token-tracker` dirty line is `?? .claude/` - the worktrees dir, 4th unchanged run. Strongest candidate for a Human Decisions suppression rather than a recurring flag.
- Local repo discovery: 12 repos + the Desktop stray + 1 worktree (`Desktop\EFI-wt-migration`, whose `.git` is a FILE not a directory). A `find -type d` scan misses worktrees entirely - caught and corrected mid-run, and it was exactly the worktree holding the top watch-list exposure.

## Human Decisions (overrides the loop must respect)
- TokenMonitor PR #1 ("Terminal project folder + repo CLAUDE.md") was the user's own active PR, tracked presence/staleness only for 9 runs. **The PR is now MERGED**, so the override is satisfied and retired. Recorded rather than silently deleted so a future run does not read its absence as the decision having been lost.

## Resolved since last run
<!-- Pruned each run per step 2. Prior entries remain in git history. -->
- **EFI 17-commit exposure CLEARED - the biggest local risk on this list.** `EFIPartitionRemediation/feature/fleet-migration-runbook` is now level with `origin` (0 ahead / 0 behind) and the `Desktop\EFI-wt-migration` worktree is clean. It had been flat at 17 commits on no remote for 3 consecutive runs, 3 short of the >20 High Priority bar.
- SPEND: no flag. Today's 112,865 output tokens is ~6.6x below the 750,000 absolute floor; the 2x-median half (2 x 311,394 = 622,788) was also not reached. Both halves fail independently.
- CACHE: no flag. Today 97.9% vs a 0.973 five-run median - ABOVE the median, and well clear of the 0.90 floor.
- Store health: `~/agent-improvement` clean and level with `origin/master` at run start; newest `domains/*.md` Added date is 2026-08-11 (0d - four lessons promoted today by agent-learn). Both discovery roots present. Buffer had 1 pending line at gather time (this session's own Stop record, appended after agent-learn truncated it).
- Branch-tips cache paid out: 28 remote branches across 19 repos, **20 served from cache**, 8 refetched, 5 `ahead_by` refetched because their base moved.
