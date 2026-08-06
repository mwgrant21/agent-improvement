---
loop: daily-triage
level: 1
paused: false
attempt_cap: 3
budget: soft
last_run: 2026-08-06
runs_since_retro: 1
---
## High Priority (waiting on human)
- SPEND FLAG FIRED (first firing of the revised threshold, refinement 2): today's output tokens **808,943**, past both the 750k absolute floor and 2x the 177,083 median of the last 5 runs. Cause is known and legitimate - this session ran the first retrospective plus seven refinement applications - so this is a true positive, not a threshold miscalibration. [action: none; recorded so the next run's median reflects it]
- STALE RESOLVED-ITEM CORRECTION: the "Resolved" entry asserting `claude-config` is remote-less by design and should be dropped from the hygiene sweep is now FALSE. `mwgrant21/claude-config` exists on GitHub (default `main`), and the local clone has an upstream and is 0/0 with it. The instruction to skip it has been removed. [action: none, corrected below - but note a resolved item silently went stale, which is the same class the ledger's REGRESSED status exists to catch]

## Retrospective outcome (2026-08-06, runs 1-10)
- Refinements 1-6 APPROVED and applied to LOOP.md via the loop-design skill: loop-derived noise counting (1), revised spend/cache thresholds (2), discovered scan roots + source-unavailable reporting (3), machine-tagged hygiene items (4), stale-only uncommitted-changes reporting (5), and a verified commit/push of the loop's own state as step 5 (6).
- Refinements 7 (branch staleness by commits-ahead rather than tip date) and 8 (cache PR/issue results for quiet repos) HELD by decision - re-evaluate at the next retrospective with post-refinement data.
- L2 promotion HELD at the user's decision despite the gate being literally met. Re-evaluate only after 10 runs in which `false_positives` is actually being fed by refinement 1. [action: none until then]
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

Ledger standing after the 2026-08-06 retrospective: **11 of 11 landed**, 0 held, 0 outstanding. Every adjustment proposed across runs 1-10 is now applied. Seven of the eleven landed on 2026-08-06; before the retrospective the figure was 4 of 11 across 23 days.

Note for the next retrospective's step R1: two rows deviate from their original proposal text ON PURPOSE, and each row says how. When reconciling, check the file for what was ACTUALLY built, not for the phrase the critique used - `branch-staleness-by-commits-ahead` became author-date staleness plus a separate `ahead_by` signal, and `cache-quiet-repo-pr-issue-results` became a fleet-wide search that removes the calls rather than a cache of their answers. Both would read as never-landed under a naive text match.

## Watch List
- NMMTools (GitHub) `codex/remote-business-tools` and `feature/wpf-gui`: RECLASSIFIED by the new `ahead_by` signal - both are **0 ahead / 59 behind** `master`, author-dated 2026-07-18 (18d). They carry no unmerged work at all. Five prior runs had these as "tracking only" purely because they were old; divergence data makes them actionable. [action: delete both from origin - 0 ahead means nothing is lost] [machine: any]
- TokenMonitor `terminal-project-cwd`: ahead 8 / behind 4, author-dated 2026-07-19 (18d). Backs open PR #1, and still holds the local-machine-only "feat: adopt Stryker Mutator" commit (`714bff9`). Real unmerged work - do NOT treat like the NMMTools pair. [action: push `714bff9` from whichever machine has it] [machine: home-matt]
- TokenMonitor `fix/live-feed-follows-active-session`: ahead 3 / behind 2, author-dated 2026-07-24 (12d), backs open PR #2. [action: none, tracking only] [machine: any]
- TokenMonitor open PRs: #1 (18d stale, Human Decision below - presence/staleness only) and #2 "fix: make the live feed actually follow the active session" (13d stale, no new commits). Both confirmed open this run by the fleet-wide `gh search prs` call. [action: none, tracking only]
- EFIPartitionRemediation / EFI-wt-migration (`Desktop\EFI-wt-migration` is a worktree of `Desktop\EFIPartitionRemediation`): `feature/fleet-migration-runbook` now has **17 commits on no remote**, up from 5 last run, and no upstream branch at all. Counted once - the worktree and its parent report the same commits. This is 3 short of the >20 High Priority escalation. [action: push the branch; at this growth rate it escalates next run] [machine: work-it]
- NMMToolkit (`Desktop\NMMToolkit`): `master` ahead 2 of `origin/master`, 3 commits on no remote. Unchanged in character from last run. [action: push the doc-spec commits when ready] [machine: work-it]
- claude-token-tracker (local clone of TokenMonitor, the frozen v1): behind `origin/master` by 2, and now also 1 uncommitted file and 1 commit on no remote - it was clean last run. [action: `git pull`; check what the local commit is] [machine: work-it]
- Aether-OS (`Desktop\Aether-OS`): 1 uncommitted file and 1 commit on no remote. The `.env` exposure route from last run is closed (`.gitignore` rule added), but per `domains/security.md` that is containment, not rotation - the key itself remains a decision for the user. [action: push the local commit; rotate the key if it was ever live] [machine: work-it]
- TarotApp: 2 unpushed commits (`7dcf7d2` deck parity, `f84f60a` merge) still absent from `mwgrant21/TarotApp`. Not verifiable on `work-it` - no local clone here. [action: confirm/push from the machine holding these] [machine: home-matt]
- tarot, Miriels-publish, nmmtools: not verifiable on `work-it` - no local clones here. Previously carried forward as if checked; now explicitly skipped per refinement 4 rather than re-asserted blind. [action: re-verify on the owning machine] [machine: home-matt]
- Quiet default branches over 14 days by author date: `Jira-Autoticketing/master` (29d), `learning-profile/main` (24d), `cli-shared-memory/master` (15d). These are dormant repos, not stale feature work - see this run's critique, the staleness rule should probably exclude default branches. [action: none] [machine: any]
- Desktop stray `.git` (`C:\Users\IT\Desktop`): present, no remote, tracks the whole Desktop tree. Known/by-design; now skipped explicitly by the discovery step rather than re-reported. [action: none] [machine: work-it]

## Recent Noise (ignored this run)
<!-- Mark an item [FP] if it was a false positive. Refinement 1: the loop ALSO counts an item byte-identical across 3 consecutive runs with no human action as noise on its own evidence, without waiting for a mark. -->
- Untriaged noise awaiting a decision: none. Nothing is currently sitting unmarked after 2+ runs.
- Refinement 1 status: this is run 1 under the new rule, so no item yet has 3 runs of byte-identical history to judge against. `false_positives` is 0 for a STATED reason this run, not by silence - the mechanism starts accumulating now and first becomes capable of firing on the third consecutive run.
- Uncommitted-changes baseline (refinement 5): this run establishes the first `notes.dirty_repos` map. No dirty-tree finding is reported as stale WIP this run because none has 3 runs of history yet - `claude-token-tracker` (1 file) and `Aether-OS` (1 file) are recorded as baseline, not flagged.

## Human Decisions (overrides the loop must respect)
- TokenMonitor PR #1 ("Terminal project folder + repo CLAUDE.md") is the user's own active PR, unmarked as noise for 7 runs running - promoted here per the last 2 runs' critiques. Track presence/staleness only, do not re-flag as an open question each run.

## Resolved since last run
<!-- Pruned 2026-08-06 per step 2 ("prune resolved items"). Eighteen entries carried since 2026-07-14 were removed; they remain in git history. One of them had gone silently stale - see the claude-config correction in High Priority - which is why this section is now pruned each run rather than accumulated. -->
- TokenMonitorV2: BOTH branches now pushed. `main` was 13 commits ahead of `origin/main` and is now level; `reskin-phases-3-4` was "never pushed, no tracking branch" and now exists on origin with an upstream (ahead 4 of `main`, author-dated today). The untracked `packages/core/LICENSE` is committed. Closes the largest unpushed-work item on the list.
- Dead source repaired: local repo hygiene previously scanned `~/projects/*`, which does not exist on `work-it`, and returned empty rather than reporting itself unavailable. Discovery now finds **12 real repos** under `~` and `~/Desktop`. Every prior run's "local hygiene" result on this machine should be read as unverified, not clean.
- claude-config remote: CORRECTED, not resolved. The prior entry claimed no `mwgrant21/claude-config` repo existed and told future runs to skip it. The repo now exists (default `main`), the local clone has an upstream, and it is 0 ahead / 0 behind with a clean tree. The skip instruction is withdrawn.
- Aether-OS `.env`: the `.gitignore` rule is in place, so the accidental-staging route is closed. Per `domains/security.md` this is containment, not rotation - the key remains the user's decision and is NOT counted as resolved.
- Meta: `~/agent-improvement` clean and in sync with `origin/master` at the start of this run; step 5 verifies the same at the end.
