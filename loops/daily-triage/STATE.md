---
loop: daily-triage
level: 1
paused: false
attempt_cap: 3
budget: soft
last_run: 2026-08-14
runs_since_retro: 8
---
## High Priority (waiting on human)
- **Adjustment `distinguish-broken-probe-from-dead-source` remains AT `attempt_cap` (3).** Proposed by runs 14, 15 and 16, escalated at run 17, unchanged again this run - still awaiting a decision. The change: a source that fails for **100% of its targets** is a BROKEN PROBE, not a dead source - it should abort and report the probe failure rather than emit per-target "unavailable" lines beside a clean finding. [decision needed: apply to LOOP.md via the loop-design skill, or mark HELD with a reason]
- **NEW: the cache-hit-rate flag fired for the first time in the run history.** Today (2026-08-14) output tokens were 157,476 (third-lowest on record) and the cache hit rate was **79.7%** - below the 0.90 absolute floor AND 18.2 percentage points under the 0.979 five-run median (both independently sufficient to trigger). Root cause looks structural, not a real problem: today's total activity was dominated by a single cache-create-heavy session (94.97M cache-create tokens vs 373.48M cache-read), so on a low-volume day one session's bootstrap cost swings the ratio hard. This is new supporting evidence for the OUTSTANDING `gate-cache-flag-on-min-volume` adjustment (see ledger) - re-proposed this run with this data point attached. [decision needed: apply a volume gate to the cache flag, or accept that low-volume days will periodically trip it]

## Retrospective outcome (2026-08-06, runs 1-10)
- Refinements 1-6 APPROVED and applied to LOOP.md via the loop-design skill: loop-derived noise counting (1), revised spend/cache thresholds (2), discovered scan roots + source-unavailable reporting (3), machine-tagged hygiene items (4), stale-only uncommitted-changes reporting (5), and a verified commit/push of the loop's own state as step 5 (6).
- Refinements 7 (branch staleness by commits-ahead rather than tip date) and 8 (cache PR/issue results for quiet repos) were HELD, then approved and applied the same day - see the ledger.
- L2 promotion HELD at the user's decision despite the gate being literally met. Re-evaluate only after 10 runs in which `false_positives` is actually being fed by refinement 1. **8 of 10 done** (runs 11-18); run 13 was the first to record a non-zero `false_positives` (1, loop-derived); run 18 (today) also recorded 1, same recurring item (see Untriaged noise). [action: none until 10 runs are in]
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
| gate-cache-flag-on-min-volume | 2026-08-07 | 2 | OUTSTANDING (age 7d, re-proposed run 18/today with a NEW data point: the cache flag fired for the first time ever, on a low-volume day (157,476 output tokens), apparently because one cache-create-heavy session dominates the ratio when total volume is low. Run 12 argued for the gate, run 13 was counter-evidence (low volume, no flag), today is a THIRD data point where low volume correlated with an actual flag firing. The picture across all three: low-volume days produce erratic cache ratios in both directions, which is itself the argument for a volume gate rather than for or against any single day. Decide now or hold for more data.) |
| noise-match-on-finding-identity-not-text | 2026-08-10 | 1 | OUTSTANDING (age 4d, awaiting decision) |
| distinguish-broken-probe-from-dead-source | 2026-08-11 | 3 | **AT ATTEMPT CAP** - re-proposed by run 16, third time, escalated to High Priority at run 17. Unchanged this run - still awaiting decision. |
| specify-branch-tips-cache-key-format | 2026-08-11 | 2 | OUTSTANDING (age 3d, awaiting decision). Still relevant: the API returns full 40-char SHAs, the cache stores 7-char, comparison only works by truncating on read. Still undecided which is canonical. |
| dirty-count-blind-to-content-churn | 2026-08-13 | 1 | OUTSTANDING (age 1d, awaiting decision). Run 18 (today) adds a data point: `Aether-OS-livetest`'s file SET this run is identical to last run's post-change state (no new file appeared today), so a file-set-aware check would have agreed with the count-based check this time. That does not resolve the underlying gap - it just means today's case wasn't a counterexample. The fix is still needed for the case run 17 caught. |

Ledger standing: **12 of 17 landed**, 0 held, 4 outstanding (ages 7d, 4d, 3d, 1d), 1 escalated at attempt-cap. Unchanged from the prior run's tally - no landings or new escalations this run, one outstanding item (`gate-cache-flag-on-min-volume`) picked up its second proposal with new evidence.

Note for the next retrospective's step R1: two rows deviate from their original proposal text ON PURPOSE, and each row says how. When reconciling, check the file for what was ACTUALLY built, not for the phrase the critique used - `branch-staleness-by-commits-ahead` became author-date staleness plus a separate `ahead_by` signal, and `cache-quiet-repo-pr-issue-results` became a fleet-wide search that removes the calls rather than a cache of their answers. Both would read as never-landed under a naive text match.

## Watch List
- **Fleet PR/issue counts unchanged**: 1 open PR, 1 open issue, same as last run. [machine: any]
  - `TokenMonitorV2#1` "Reskin phases 3-4: Aether token layer, palettes, chrome pass, version check", no new activity since last run. Local work remains ahead on `reskin-phase-5` (20 ahead of `main`) and `reskin-phases-3-4` (19 ahead), both pushed - not at loss risk. [action: none, tracking]
  - `Aether-OS#22` white screen after desktop lock. Still instrumented but NOT fixed, unchanged. Deliberately left open. [action: none until it recurs - then grab the dev output and grep `[diag]` BEFORE closing the window]
- **1 stale 0-ahead branch, still blocked rather than ignored.** [machine: any]
  - TokenMonitor `terminal-project-cwd` - 0 ahead, author-dated 2026-07-19 (**26d**, up from 25d). Needs the local-only `714bff9` Stryker commit confirmed merged or abandoned first. Not counted as noise: repetition here is a cross-machine dependency, not an unactioned recommendation. [action: confirm from home-matt, then delete] [machine: home-matt to confirm]
- **`Desktop\Aether-OS-livetest` stale-WIP flag, 5th consecutive run.** [machine: work-it]
  - Dirty-line count still 4 (`package-lock.json` modified, `e2e/livetest.spec.ts`, `e2e/livetest2.spec.ts`, `livetest-shots/` untracked). Unlike run 17, this run's actual file SET is identical to last run's - no new file appeared - so this is now genuinely stale under a file-set-aware check too, not just the count. [action: commit, gitignore, or add to Human Decisions]
- `agent-improvement`'s own `master` advanced again (`3ab29ab` -> `ee17fb8`) via the sibling agent-learn loop promoting a lesson ("Add browser-automation domain: claude-in-chrome tab visibility lesson") - normal shared-store activity, not this loop's own write, noted so the branch-tip change isn't mistaken for drift.
- `Desktop\EFI-wt-migration` (worktree of EFIPartitionRemediation): clean, 0 unpushed, level with origin. Recorded because a `find -type d` scan misses worktrees - it must stay discoverable. [action: none] [machine: work-it]
- TarotApp: 2 unpushed commits still absent from the remote. Not verifiable on `work-it` - no local clone. [action: confirm/push from the owning machine] [machine: home-matt]
- tarot, Miriels: not verifiable on `work-it` - no local clones here. [action: re-verify on the owning machine] [machine: home-matt]
- Desktop stray `.git` (`C:\Users\IT\Desktop`): present, no remote, tracks the whole Desktop tree. Known/by-design; skipped. [action: none] [machine: work-it]

## Recent Noise (ignored this run)
<!-- Mark an item [FP] if it was a false positive. Refinement 1: the loop ALSO counts an item byte-identical across 3 consecutive runs with no human action as noise on its own evidence, without waiting for a mark. -->
- **Aether-OS "1 commit on no remote" branch - still unresolved, 6th consecutive run.** Recommendation ("push or delete that branch") is byte-identical since run 14 with zero human action; specifically the local merge commit `1454dea` ("Merge pull request #2 from mwgrant21/presentation-handoff") never matches any remote SHA because GitHub's merge of PR #2 used a different merge strategy locally-vs-remote, so this may never self-resolve by pushing. Counted again as loop-derived `false_positives` this run. **[decision needed: push, delete, or explicitly mark Human Decision to keep ignoring]** - see Untriaged noise below.
- `terminal-project-cwd` is deliberately not counted, for the fourth run running. It carries a real cross-machine blocker, so repetition is a dependency rather than an unactioned recommendation. Distinguishing those two is the substance of the OUTSTANDING `noise-match-on-finding-identity-not-text` adjustment.
- Spend threshold: today's 157,476 output tokens is well under both halves of the two-part gate (< 750,000 absolute; 2x the 112,865 five-run median is 225,730, also cleared) - no flag.
- Cache threshold: today's 79.7% FLAGGED - see High Priority. Not noise; moved up.

## Untriaged noise
- **Aether-OS "1 commit on no remote" branch** (see Recent Noise above) has now gone unmarked for 6+ consecutive runs since run 14. It has crossed the refinement-1 bar repeatedly and no `[FP]` mark or Human Decision has been recorded. Requesting an explicit decision: push the commit, delete the stray local merge, or add a permanent Human Decision to keep suppressing it as a known artifact of divergent merge strategies.

## Human Decisions (overrides the loop must respect)
- TokenMonitor PR #1 ("Terminal project folder + repo CLAUDE.md") was the user's own active PR, tracked presence/staleness only for 9 runs. **The PR is now MERGED**, so the override is satisfied and retired. Recorded rather than silently deleted so a future run does not read its absence as the decision having been lost.

## Resolved since last run
<!-- Pruned each run per step 2. Prior entries remain in git history. -->
- No Watch List items resolved this run - fleet state (PRs, issues, branch staleness, dirty repos) is essentially unchanged from run 17.
- SPEND: no flag - see Recent Noise.
- CACHE: **FLAGGED for the first time** - moved to High Priority, not resolved.
- Branch-tips cache: 26 branches across 18 repos, **25 served from cache**, 1 refetched (`agent-improvement/master`, moved by the sibling agent-learn loop), 0 `ahead_by` refetches needed (no branch's own SHA changed and no default branch besides `agent-improvement`'s own moved).
