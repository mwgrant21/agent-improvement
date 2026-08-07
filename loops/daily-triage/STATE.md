---
loop: daily-triage
level: 1
paused: false
attempt_cap: 3
budget: soft
last_run: 2026-08-07
runs_since_retro: 2
---
## High Priority (waiting on human)
- CACHE FLAG FIRED (first firing of the revised cache threshold, refinement 2): today's hit rate **91.3%**, which is 6.5 points below the 0.978 median of the last 5 runs (trigger is >5 points). It clears the 0.90 absolute floor. **Read this as a threshold artifact, not a regression**: today's sample is 39 input / 6,831 output tokens on a single model - this triage run itself and essentially nothing else. A near-empty day makes the ratio swing on a handful of requests. The revised threshold works (it fired at the first opportunity, unlike the old one), but it has no volume gate. [action: none on cache; approve `gate-cache-flag-on-min-volume` below or accept a recurring low-traffic-day false positive]

## Retrospective outcome (2026-08-06, runs 1-10)
- Refinements 1-6 APPROVED and applied to LOOP.md via the loop-design skill: loop-derived noise counting (1), revised spend/cache thresholds (2), discovered scan roots + source-unavailable reporting (3), machine-tagged hygiene items (4), stale-only uncommitted-changes reporting (5), and a verified commit/push of the loop's own state as step 5 (6).
- Refinements 7 (branch staleness by commits-ahead rather than tip date) and 8 (cache PR/issue results for quiet repos) were HELD, then approved and applied the same day - see the ledger.
- L2 promotion HELD at the user's decision despite the gate being literally met. Re-evaluate only after 10 runs in which `false_positives` is actually being fed by refinement 1. **2 of 10 done** (runs 11 and 12). [action: none until then]
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
| gate-cache-flag-on-min-volume | 2026-08-07 | 1 | OUTSTANDING (proposed by run 12's critique; awaiting decision) |

Ledger standing: **12 of 13 landed**, 0 held, 1 outstanding (age 0 days). Before the 2026-08-06 retrospective the figure was 4 of 11 across 23 days.

Note for the next retrospective's step R1: two rows deviate from their original proposal text ON PURPOSE, and each row says how. When reconciling, check the file for what was ACTUALLY built, not for the phrase the critique used - `branch-staleness-by-commits-ahead` became author-date staleness plus a separate `ahead_by` signal, and `cache-quiet-repo-pr-issue-results` became a fleet-wide search that removes the calls rather than a cache of their answers. Both would read as never-landed under a naive text match.

## Watch List
- Aether-OS open PR **#9 "Stage 14: Comms Deck"** - NEW this run, opened/updated today. Branch `comms-deck-stage14` is ahead 12 / behind 1 of `master`, author-dated today. Live work, not stale. [action: none, tracking only] [machine: any]
- NMMTools (GitHub) `codex/remote-business-tools` and `feature/wpf-gui`: still **0 ahead / 59 behind** `master`, author-dated 2026-07-18 (**20d**, up from 18d). Unchanged tip SHAs, so this is carried from cache, not re-fetched. They carry no unmerged work at all. Second consecutive run with this recommendation and no action. [action: delete both from origin - 0 ahead means nothing is lost] [machine: any]
- TokenMonitor `terminal-project-cwd`: ahead 8 / behind 4, author-dated 2026-07-19 (**19d**). Backs open PR #1, and still holds the local-machine-only "feat: adopt Stryker Mutator" commit (`714bff9`). Real unmerged work - do NOT treat like the NMMTools pair. [action: push `714bff9` from whichever machine has it] [machine: home-matt]
- TokenMonitor `fix/live-feed-follows-active-session`: ahead 3 / behind 2, author-dated 2026-07-24 - now **exactly 14d**, one day short of the >14 staleness rule. Backs open PR #2. Will cross the line next run. [action: none yet, tracking only] [machine: any]
- TokenMonitorV2 `reskin-phases-3-4`: tip moved (`9b5ba71` -> `26ea258`), now ahead **12** of `main` / behind 0, author-dated 2026-08-06. Active work, no open PR backing it. [action: open a PR or merge when the reskin lands] [machine: any]
- TokenMonitor open PRs #1 (19d stale, Human Decision below - presence/staleness only) and #2 (14d stale, no new commits). Both re-confirmed open by the fleet-wide `gh search prs` call. [action: none, tracking only]
- EFIPartitionRemediation / EFI-wt-migration (`Desktop\EFI-wt-migration` is a worktree of `Desktop\EFIPartitionRemediation`): `feature/fleet-migration-runbook` holds **17 commits on no remote**, unchanged from last run (it grew 5 -> 17 the run before, now flat). Counted once - worktree and parent report the same commits. Still 3 short of the >20 High Priority escalation, and no longer accelerating. [action: push the branch] [machine: work-it]
- NMMToolkit (`Desktop\NMMToolkit`): `master` ahead 2 of `origin/master`, 3 commits on no remote. Byte-identical to last run - **2 consecutive runs**; one more and refinement 1 counts it as loop-derived noise. [action: push the doc-spec commits when ready] [machine: work-it]
- claude-token-tracker: behind `origin/master` by 2, 1 commit on no remote (`43fde10` on `worktree-packages-core-wiring`, the core-wiring work), 1 uncommitted file. Dirty count unchanged for 2 runs - not yet stale WIP (needs 3). [action: `git pull`; decide whether `43fde10` belongs in TokenMonitorV2 instead] [machine: work-it]
- Aether-OS (`Desktop\Aether-OS`): local clone now checked out on `comms-deck-stage14`, level with its upstream. 1 commit on no remote (`1454dea` on `closing-the-loop`), and 2 uncommitted files (up from 1 - **active WIP, suppressed per refinement 5**). The `.env` exposure route stays closed via `.gitignore`; per `domains/security.md` that is containment, not rotation. [action: push or delete `closing-the-loop`; rotate the key if it was ever live] [machine: work-it]
- `code-graph-mcp` (GitHub): repo exists with **zero branches** - an empty repo, no local clone anywhere. First time it has been enumerated as a branch-listing target. [action: populate or delete it] [machine: any]
- TarotApp: 2 unpushed commits (`7dcf7d2` deck parity, `f84f60a` merge) still absent from `mwgrant21/TarotApp`. Not verifiable on `work-it` - no local clone here. [action: confirm/push from the machine holding these] [machine: home-matt]
- tarot, Miriels-publish, nmmtools: not verifiable on `work-it` - no local clones here. [action: re-verify on the owning machine] [machine: home-matt]
- Desktop stray `.git` (`C:\Users\IT\Desktop`): present, no remote, tracks the whole Desktop tree. Known/by-design; skipped by the discovery step. [action: none] [machine: work-it]

## Recent Noise (ignored this run)
<!-- Mark an item [FP] if it was a false positive. Refinement 1: the loop ALSO counts an item byte-identical across 3 consecutive runs with no human action as noise on its own evidence, without waiting for a mark. -->
- Untriaged noise awaiting a decision: **none**. No item has yet sat unmarked for 2+ runs under the refinement-1 rule.
- Refinement 1 status: this is run **2 of 3** under the new rule. Two Watch List items are now on their second byte-identical run and are the first candidates to auto-count as noise on run 13 if nothing acts on them: the NMMTools 0-ahead branch pair, and the NMMToolkit ahead-2 push item. `false_positives` is 0 for a stated structural reason again, not by silence.
- Uncommitted-changes baseline (refinement 5): `claude-token-tracker` is at 1 dirty line for a 2nd consecutive run (flags at 3). `Aether-OS` went 1 -> 2 dirty lines, which resets its counter to 1 - correctly read as active WIP, not stale.
- Two "new" local repos appeared in discovery (`Desktop\TriageDesk`, `Downloads\uw-mail-router`) but are NOT new remotes: they are clones of `Jira-Autoticketing` and `RoundRobin` respectively, both clean and level. Recorded so a future run does not report them as new.

## Human Decisions (overrides the loop must respect)
- TokenMonitor PR #1 ("Terminal project folder + repo CLAUDE.md") is the user's own active PR, unmarked as noise for 8 runs running. Track presence/staleness only, do not re-flag as an open question each run.

## Resolved since last run
<!-- Pruned each run per step 2. Prior entries remain in git history. -->
- SPEND FLAG cleared. Yesterday's 808,943 output tokens were the retrospective session; today is 6,831 - three orders of magnitude below the 750k floor. The flag behaved exactly as designed: it fired on a real spike and went quiet the next day without a threshold edit.
- `claude-config` correction from last run holds: local clone is 0/0 with `origin/main`, clean tree, and `main` advanced to `9ea9589` (2026-08-06). No longer a correction, just a healthy repo.
- Branch-tips cache paid out again: 23 remote branches enumerated, only **4** needed a commit/compare call (Aether-OS `comms-deck-stage14` new, TokenMonitorV2 `reskin-phases-3-4` moved, and the `agent-improvement` / `claude-config` default tips). 19 branches served from cache.
- Store health: `~/agent-improvement` clean and in sync with `origin/master` at run start; candidate buffer `work-it-buffer.jsonl` is empty (0 pending); newest `domains/*.md` Added date is 2026-08-06 (1 day old, well inside the 7-day bar). Step 5 verifies sync again at the end.
