---
loop: daily-triage
level: 1
paused: false
attempt_cap: 3
budget: soft
last_run: 2026-08-12
runs_since_retro: 5
---
## High Priority (waiting on human)
- **None this run.** No spend flag, no cache flag, no branch at the >20-commits-ahead escalation bar (nothing is ahead of its remote at all), and every source returned data. Stated explicitly so an empty section reads as "checked and clear", not as "not checked".

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
| gate-cache-flag-on-min-volume | 2026-08-07 | 1 | OUTSTANDING (age 5d, awaiting decision). Run 13 is counter-evidence, not supporting evidence: today was another low-volume day (15,603 output tokens) and the cache flag did NOT fire (95.7% vs a 0.978 median = 2.1pp, inside the 5pp trigger). One low-volume day fired, one did not - the case for a volume gate is now weaker than run 12 argued. Decide on 2 data points or hold for more. |
| noise-match-on-finding-identity-not-text | 2026-08-10 | 1 | OUTSTANDING (proposed by run 13's critique; awaiting decision) |
| distinguish-broken-probe-from-dead-source | 2026-08-11 | 2 | OUTSTANDING (age 1d, re-proposed by run 15; 1 more proposal reaches attempt_cap 3 and escalates) |
| specify-branch-tips-cache-key-format | 2026-08-11 | 1 | OUTSTANDING (age 1d, awaiting decision) |

Ledger standing: **12 of 14 landed**, 0 held, 2 outstanding (ages 3d and 0d). Before the 2026-08-06 retrospective the figure was 4 of 11 across 23 days.

Note for the next retrospective's step R1: two rows deviate from their original proposal text ON PURPOSE, and each row says how. When reconciling, check the file for what was ACTUALLY built, not for the phrase the critique used - `branch-staleness-by-commits-ahead` became author-date staleness plus a separate `ahead_by` signal, and `cache-quiet-repo-pr-issue-results` became a fleet-wide search that removes the calls rather than a cache of their answers. Both would read as never-landed under a naive text match.

## Watch List
- **1 open PR, 3 open issues** (down from 2 PRs). Counts far below the `--limit 100` on both searches, so neither result is truncated. [machine: any]
  - `TokenMonitor#3` "Replace opus-on-trivial-turns with a remediable delegation rule" - open since 2026-08-11, Codex P1s fixed in `4a2a9a2`, CI green. [action: review and merge]
  - `Aether-OS#41` busy_timeout unset in `schema.OpenDatabase`, `#40` pre-v8 DBs missing nested subagents, `#22` white screen after desktop lock. Unchanged since 2026-08-10 - 3rd run carrying them. [action: triage - #41 and #22 describe production-visible failures]
- **2 remote branches stale AND 0 ahead** (down from 4). Both on TokenMonitor. [machine: any]
  - `terminal-project-cwd` - 0 ahead, 2026-07-19 (**24d**). BLOCKED, not ignored: needs the local-only `714bff9` Stryker commit confirmed merged or abandoned first. [action: confirm from home-matt, then delete] [machine: home-matt to confirm]
  - `fix/live-feed-follows-active-session` - 0 ahead, 2026-07-24 (**19d**). No blocker. 3rd consecutive run with the same recommendation. [action: delete from origin] [machine: any]
- Aether-OS (`Desktop\Aether-OS`): `master` level with origin and clean, but still **1 commit on no remote** on another local branch. Unchanged for 3 runs. [action: push or delete that branch] [machine: work-it]
- claude-token-tracker: on `reframe-model-routing-finding` with PR #3 open, level with origin. Dirty count **1 line (`?? .claude/`) unchanged for a 5th consecutive run**. That path is the worktrees directory and is almost certainly permanent. [action: gitignore `.claude/` or add to Human Decisions so it stops being re-flagged] [machine: work-it]
- TokenMonitorV2 `reskin-phases-3-4` - level with origin, 1 dirty line, unchanged 2 runs. Still no open PR backing it. [action: open a PR or merge when the reskin lands] [machine: any]
- `Desktop\Aether-OS-livetest` - second local clone of `mwgrant21/Aether-OS`. 4 dirty lines, unchanged 2 runs - one short of the stale-WIP bar. [action: none yet, watching] [machine: work-it]
- `Desktop\EFI-wt-migration` (worktree of EFIPartitionRemediation): clean, 0 unpushed, level with origin. Recorded because a `find -type d` scan misses worktrees entirely - it must stay discoverable. [action: none] [machine: work-it]
- TarotApp: 2 unpushed commits still absent from the remote. Not verifiable on `work-it` - no local clone. [action: confirm/push from the owning machine] [machine: home-matt]
- tarot, Miriels: not verifiable on `work-it` - no local clones here. [action: re-verify on the owning machine] [machine: home-matt]
- Desktop stray `.git` (`C:\Users\IT\Desktop`): present, no remote, tracks the whole Desktop tree. Known/by-design; skipped. [action: none] [machine: work-it]

## Recent Noise (ignored this run)
<!-- Mark an item [FP] if it was a false positive. Refinement 1: the loop ALSO counts an item byte-identical across 3 consecutive runs with no human action as noise on its own evidence, without waiting for a mark. -->
- **The NMMTools 0-ahead pair is RESOLVED, not suppressed.** It was the only item ever to feed `false_positives`, carried for 4 consecutive runs (11-14). Both branches were verified to hold 0 commits absent from `master` and were deleted. Human action occurred, so it correctly does NOT count as noise this run.
- `fix/live-feed-follows-active-session` (TokenMonitor) is now on its **3rd** consecutive run with the same unblocked "delete from origin" recommendation and no action - counted as loop-derived noise, `false_positives: 1`.
- `terminal-project-cwd` is deliberately NOT counted. It carries a real cross-machine blocker (the `714bff9` confirmation from home-matt), so repetition is a dependency, not noise. Distinguishing these two is exactly what the `noise-match-on-finding-identity-not-text` adjustment is about.
- Refinement 1's mechanical defect persists (adjustment `noise-match-on-finding-identity-not-text`, OUTSTANDING): the literal test is "byte-identical across 3 runs", but every staleness item embeds an age that increments each run (18d -> 19d), so no such item can ever satisfy it. Counted on INTENT again.
- `claude-token-tracker` dirty line is `?? .claude/` - the worktrees dir, 5th unchanged run. The strongest remaining candidate for a Human Decisions suppression rather than a recurring flag.
- Store health note: the agent-learn buffer holds **52 pending records** (was 1). A single very long session generated them; the next promote pass has a large batch to grade.

## Human Decisions (overrides the loop must respect)
- TokenMonitor PR #1 ("Terminal project folder + repo CLAUDE.md") was the user's own active PR, tracked presence/staleness only for 9 runs. **The PR is now MERGED**, so the override is satisfied and retired. Recorded rather than silently deleted so a future run does not read its absence as the decision having been lost.

## Resolved since last run
<!-- Pruned each run per step 2. Prior entries remain in git history. -->
- **The 4-run untriaged-noise item is GONE.** Both NMMTools 0-ahead branches (`codex/remote-business-tools`, `feature/wpf-gui`) were verified as carrying 0 commits absent from `master` - 83 behind, same July 18 tip - and deleted from origin. The blocking caveat resolved with them: the local-only `d8a4c87` was confirmed redundant (`master` already sets `$Mode = 'GUI'`; the commit is unique, its content is not), so discarding was correct rather than pushing.
- **NMMToolkit is fully clean**: was 9 ahead / 10 unpushed / 1 dirty at run 14, now 0/0/0 with only `master` local and remote.
- **Aether-OS PRs #42 and #43 both merged** (`75b3ea6`). #42 auto-closed - its commits were entirely contained in #43. Zero open PRs on that repo. Includes the retention fix from a Codex review: `oldestRetainedAtMs` now reads rollup days plus `drift_log`/`fleet_sessions`, so the Settings privacy readout stops understating data age after compaction.
- **`code-graph-mcp` deleted** - flagged as an empty repo for 3 consecutive runs. Fleet is 18 repos, down from 19. It was superseded by `codebase-memory-mcp`, now installed and registered as an MCP server.
- **EFI worktree confirmed clean.** `Desktop\EFI-wt-migration` is discovered again this run (the `-type d` fix held) and shows 0 unpushed - the 17-commit exposure stays resolved.
- SPEND: no flag. Today's 29,716 output tokens is ~25x below the 750,000 floor; 2x-median (225,730) also not reached. Both halves fail independently.
- CACHE: no flag. Today 97.5% vs a 0.973 five-run median - above it, and well clear of the 0.90 floor.
- Branch-tips cache: 26 branches across 18 repos, **21 served from cache**, 5 refetched, 2 `ahead_by` refetched. The SHA-format normalisation from run 14 held.
