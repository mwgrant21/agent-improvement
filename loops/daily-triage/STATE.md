---
loop: daily-triage
level: 1
paused: false
attempt_cap: 3
budget: soft
last_run: 2026-08-10
runs_since_retro: 3
---
## High Priority (waiting on human)
- **None this run.** No spend flag, no cache flag, no branch at the >20-commits-ahead escalation bar (the EFI branch remains at 17), and no source unavailable. Stated explicitly so an empty section reads as "checked and clear", not as "not checked".

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
| gate-cache-flag-on-min-volume | 2026-08-07 | 1 | OUTSTANDING (age 3d, awaiting decision). Run 13 is counter-evidence, not supporting evidence: today was another low-volume day (15,603 output tokens) and the cache flag did NOT fire (95.7% vs a 0.978 median = 2.1pp, inside the 5pp trigger). One low-volume day fired, one did not - the case for a volume gate is now weaker than run 12 argued. Decide on 2 data points or hold for more. |
| noise-match-on-finding-identity-not-text | 2026-08-10 | 1 | OUTSTANDING (proposed by run 13's critique; awaiting decision) |

Ledger standing: **12 of 14 landed**, 0 held, 2 outstanding (ages 3d and 0d). Before the 2026-08-06 retrospective the figure was 4 of 11 across 23 days.

Note for the next retrospective's step R1: two rows deviate from their original proposal text ON PURPOSE, and each row says how. When reconciling, check the file for what was ACTUALLY built, not for the phrase the critique used - `branch-staleness-by-commits-ahead` became author-date staleness plus a separate `ahead_by` signal, and `cache-quiet-repo-pr-issue-results` became a fleet-wide search that removes the calls rather than a cache of their answers. Both would read as never-landed under a naive text match.

## Watch List
- **Fleet has ZERO open PRs and ZERO open issues** - down from 3 open PRs last run. TokenMonitor #1 and #2 and Aether-OS #9 all merged. The empty `gh search prs` result was re-verified with a per-repo `gh pr list` drill-down on TokenMonitor and Aether-OS before being believed, because an empty result and a broken source must never look alike. [action: none, recorded] [machine: any]
- **Four remote branches are now stale AND 0 ahead - all four are pure dead weight.** This is a new shape: last run only 2 of 4 were losslessly deletable. [machine: any]
  - NMMTools `codex/remote-business-tools` - 0 ahead / 61 behind `master`, author-dated 2026-07-18 (**23d**). Cached tip, unchanged. [action: delete from origin]
  - NMMTools `feature/wpf-gui` - 0 ahead / 61 behind, 2026-07-18 (**23d**). [action: delete from origin, but see the NMMToolkit local caveat below first]
  - TokenMonitor `terminal-project-cwd` - **now 0 ahead** / 9 behind (was 8 ahead); PR #1 merged. 2026-07-19 (**22d**). [action: delete from origin AFTER confirming the local-only `714bff9` Stryker commit on `home-matt` is either merged or abandoned] [machine: home-matt to confirm]
  - TokenMonitor `fix/live-feed-follows-active-session` - **now 0 ahead** / 12 behind (was 3 ahead); PR #2 merged. 2026-07-24 (**17d**). [action: delete from origin]
- CAVEAT on NMMTools `feature/wpf-gui`: the local `Desktop\NMMToolkit` clone holds 1 commit on no remote, `d8a4c87` "feat: default to GUI mode on launch", on its local `feature/wpf-gui`. Deleting the REMOTE branch still loses nothing remote-side, but it strands that local branch's upstream. [action: push or discard `d8a4c87` before deleting the remote branch] [machine: work-it]
- Aether-OS `real-projects-view-stage16` (GitHub) - NEW this run, 0 ahead / 58 behind `master`, author-dated 2026-08-08 (2d). Already merged into `master`; not stale. [action: delete from origin] [machine: any]
- TokenMonitorV2 `reskin-phases-3-4` - ahead **12** / behind 0, author-dated 2026-08-06 (4d). Tip SHA unchanged (`26ea258`) and `main` unchanged (`54f5be9`), so both fields served from cache. Active work, still no open PR backing it. [action: open a PR or merge when the reskin lands] [machine: any]
- EFIPartitionRemediation / EFI-wt-migration (`Desktop\EFI-wt-migration` is a worktree of `Desktop\EFIPartitionRemediation`): `feature/fleet-migration-runbook` holds **17 commits on no remote**, flat for a 3rd consecutive run. Counted once - worktree and parent report the same commits. Still 3 short of the >20 High Priority escalation. [action: push the branch] [machine: work-it]
- claude-token-tracker (clone of `mwgrant21/TokenMonitor`): behind `origin/master` by 2, 1 commit on no remote (`43fde10` on `worktree-packages-core-wiring`). Dirty count has been **1 line (`?? .claude/`) unchanged for 3 consecutive runs -> STALE WIP, flagged per refinement 5** (first time this rule has fired). [action: `git pull`; commit or gitignore `.claude/`; decide whether `43fde10` belongs in TokenMonitorV2 instead] [machine: work-it]
- Aether-OS (`Desktop\Aether-OS`): local clone back on `master` and now **behind origin by 66** after the Stage-14/16 merges. Working tree is CLEAN (was 2 dirty lines). Still 1 commit on no remote (`1454dea` on `closing-the-loop`). [action: `git pull`; push or delete `closing-the-loop`] [machine: work-it]
- NEW local repo `Desktop\Aether-OS-livetest` - a SECOND local clone of `mwgrant21/Aether-OS`, not a new remote. `master` level with origin, 0 unpushed, 3 dirty lines (`package-lock.json`, `e2e/livetest.spec.ts`, `livetest-shots/`) - live-test scaffolding, baseline run 1, suppressed as active WIP. [action: none, recorded so a future run does not report it as fleet growth] [machine: work-it]
- `code-graph-mcp` (GitHub): still a repo with **zero branches** - empty, no local clone anywhere. 2nd consecutive run with this recommendation. [action: populate or delete it] [machine: any]
- TarotApp: 2 unpushed commits (`7dcf7d2` deck parity, `f84f60a` merge) still absent from `mwgrant21/TarotApp` (remote `master` unchanged at `37a480a`). Not verifiable on `work-it` - no local clone here. [action: confirm/push from the machine holding these] [machine: home-matt]
- tarot, Miriels, nmmtools: not verifiable on `work-it` - no local clones here. [action: re-verify on the owning machine] [machine: home-matt]
- Desktop stray `.git` (`C:\Users\IT\Desktop`): present, no remote, tracks the whole Desktop tree. Known/by-design; skipped by the discovery step. [action: none] [machine: work-it]

## Recent Noise (ignored this run)
<!-- Mark an item [FP] if it was a false positive. Refinement 1: the loop ALSO counts an item byte-identical across 3 consecutive runs with no human action as noise on its own evidence, without waiting for a mark. -->
- **Untriaged noise awaiting a decision**: the **NMMTools 0-ahead branch pair** (`codex/remote-business-tools`, `feature/wpf-gui`). Same finding, same "delete from origin" recommendation, no human action, for **3 consecutive runs** (11, 12, 13). Counted as loop-derived noise under refinement 1 - `false_positives: 1`, the FIRST non-zero value this field has ever carried. [decision needed: delete the branches, or mark this `[FP]`/suppress it in Human Decisions so it stops being re-raised]
- Refinement 1 mechanical defect (see this run's adjustment): the rule's literal test is "byte-identical across 3 consecutive runs", but every GitHub staleness item embeds an age in days that increments every run (20d -> 23d here), so no such item can EVER be byte-identical and the counter can never fire on its own terms. The NMMTools pair was counted on the rule's INTENT, not its letter. This is the same class of un-fireable check the 2026-08-06 retrospective removed from the spend and cache thresholds.
- The other run-12 noise candidate, the **NMMToolkit ahead-2 push item, RESOLVED** - `master` is now level with `origin/master`. Human action occurred, so it correctly does NOT count as noise.
- Uncommitted-changes baseline (refinement 5): `claude-token-tracker` reached 3 unchanged runs at 1 dirty line and **flagged**. `Aether-OS` went 2 -> 0 dirty lines (clean, dropped from the map). `Aether-OS-livetest` enters at 3 dirty lines, baseline run 1.
- Local-clone bookkeeping holds: `Desktop\TriageDesk` -> `Jira-Autoticketing`, `Downloads\uw-mail-router` -> `RoundRobin`, and now `Desktop\Aether-OS-livetest` -> `Aether-OS`. 14 local repos discovered, up from 12, but ZERO new remotes.

## Human Decisions (overrides the loop must respect)
- TokenMonitor PR #1 ("Terminal project folder + repo CLAUDE.md") was the user's own active PR, tracked presence/staleness only for 9 runs. **The PR is now MERGED**, so the override is satisfied and retired. Recorded rather than silently deleted so a future run does not read its absence as the decision having been lost.

## Resolved since last run
<!-- Pruned each run per step 2. Prior entries remain in git history. -->
- **CACHE FLAG cleared.** Today: 95.7% hit rate vs a 0.978 five-run median = 2.1pp below, inside the 5pp trigger, and well clear of the 0.90 floor. Run 12's firing was correctly diagnosed as a low-volume artifact and needed no threshold edit to go quiet.
- SPEND: no flag. Today's 15,603 output tokens is ~48x below the 750,000 absolute floor; the 2x-median half was never reached.
- **All 3 open PRs merged** (TokenMonitor #1, #2; Aether-OS #9). Aether-OS `comms-deck-stage14` was merged AND its branch deleted - the clean end-to-end outcome the Watch List has been tracking.
- NMMToolkit `master` ahead-2 / 3-unpushed: **pushed and resolved**. Only `d8a4c87` on `feature/wpf-gui` remains.
- Branch-tips cache paid out again: 24 remote branches enumerated, **15 served from cache**, 9 needed a call (4 default tips moved: agent-improvement, Aether-OS, TokenMonitor, NMMTools; 1 new branch; and 4 non-default branches whose `ahead_by` had to be refetched because their base moved - exactly the relative-staleness rule working as designed).
- Store health: `~/agent-improvement` clean and level with `origin/master` at run start; `work-it-buffer.jsonl` empty (0 pending); newest `domains/*.md` Added date is 2026-08-07 (3d old, inside the 7-day bar). Both discovery roots (`~`, `~/Desktop`) present. Step 5 verifies sync again at the end.
