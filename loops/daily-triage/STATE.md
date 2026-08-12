---
loop: daily-triage
level: 1
paused: false
attempt_cap: 3
budget: soft
last_run: 2026-08-12
runs_since_retro: 6
---
## High Priority (waiting on human)
- **Adjustment `distinguish-broken-probe-from-dead-source` has hit `attempt_cap` (3).** Proposed by runs 14, 15 and 16 and never applied, so per LOOP.md's Step R1 rule it escalates here instead of being quietly re-proposed. The change: a source that fails for **100% of its targets** is a BROKEN PROBE, not a dead source - it should abort and report the probe failure rather than emit per-target "unavailable" lines beside a clean finding. Run 14 hit exactly this: all 19 repos failed identically, and the protocol's tolerance rule would have rendered that as 19 dead sources plus "no stale branches" - a clean report from a probe that returned nothing. [decision needed: apply to LOOP.md via the loop-design skill, or mark HELD with a reason]
- Nothing else. No spend flag, no cache flag, nothing ahead of its remote, and every source returned data.

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
| distinguish-broken-probe-from-dead-source | 2026-08-11 | 3 | **AT ATTEMPT CAP** - re-proposed by run 16, third time. Per LOOP.md this now ESCALATES to High Priority rather than being re-proposed a fourth time. |
| specify-branch-tips-cache-key-format | 2026-08-11 | 1 | OUTSTANDING (age 1d, awaiting decision) |

Ledger standing: **12 of 14 landed**, 0 held, 2 outstanding (ages 3d and 0d). Before the 2026-08-06 retrospective the figure was 4 of 11 across 23 days.

Note for the next retrospective's step R1: two rows deviate from their original proposal text ON PURPOSE, and each row says how. When reconciling, check the file for what was ACTUALLY built, not for the phrase the critique used - `branch-staleness-by-commits-ahead` became author-date staleness plus a separate `ahead_by` signal, and `cache-quiet-repo-pr-issue-results` became a fleet-wide search that removes the calls rather than a cache of their answers. Both would read as never-landed under a naive text match.

## Watch List
- **Fleet has ZERO open PRs and ONE open issue** - down from 1 PR / 3 issues. [machine: any]
  - `Aether-OS#22` white screen after desktop lock. Instrumented but NOT fixed (`10efd9ca`): the dev server no longer watches build output, and lock/unlock, GPU-process death and renderer-unresponsive are now logged, so the next occurrence is diagnosable instead of lost. Deliberately left open. [action: none until it recurs - then grab the dev output and grep `[diag]` BEFORE closing the window]
- **1 stale 0-ahead branch, and it is blocked rather than ignored** (down from 4 two runs ago). [machine: any]
  - TokenMonitor `terminal-project-cwd` - 0 ahead, author-dated 2026-07-19 (**24d**). Needs the local-only `714bff9` Stryker commit confirmed merged or abandoned first. Not counted as noise: repetition here is a cross-machine dependency, not an unactioned recommendation. [action: confirm from home-matt, then delete] [machine: home-matt to confirm]
- **Two repos reached the stale-WIP bar this run** (refinement 5: dirty count unchanged across 3 consecutive runs). Both are first-time flags, not long-standing. [machine: work-it]
  - `Desktop\Aether-OS-livetest` - 4 dirty lines unchanged for 3 runs (live-test scaffolding: `package-lock.json`, `e2e/livetest.spec.ts`, `livetest-shots/`). [action: commit, gitignore, or add to Human Decisions]
  - `Desktop\TokenMonitorV2` - 1 dirty line unchanged for 3 runs, on `reskin-phases-3-4`. Still no open PR backing that branch. [action: commit or gitignore the dirty file; open a PR when the reskin lands]
- Aether-OS (`Desktop\Aether-OS`): `master` level with origin and clean, but still **1 commit on no remote** on another local branch. Unchanged for 4 runs. [action: push or delete that branch] [machine: work-it]
- `Desktop\EFI-wt-migration` (worktree of EFIPartitionRemediation): clean, 0 unpushed, level with origin. Recorded because a `find -type d` scan misses worktrees - it must stay discoverable. [action: none] [machine: work-it]
- `code-graph-mcp` is GONE from the fleet (deleted 2026-08-12) - the 3-run "empty repo" recommendation is retired, not carried. Recorded so its absence is not re-discovered as a new fact.
- TarotApp: 2 unpushed commits still absent from the remote. Not verifiable on `work-it` - no local clone. [action: confirm/push from the owning machine] [machine: home-matt]
- tarot, Miriels: not verifiable on `work-it` - no local clones here. [action: re-verify on the owning machine] [machine: home-matt]
- Desktop stray `.git` (`C:\Users\IT\Desktop`): present, no remote, tracks the whole Desktop tree. Known/by-design; skipped. [action: none] [machine: work-it]

## Recent Noise (ignored this run)
<!-- Mark an item [FP] if it was a false positive. Refinement 1: the loop ALSO counts an item byte-identical across 3 consecutive runs with no human action as noise on its own evidence, without waiting for a mark. -->
- **`false_positives: 0` - and this is the first run where that number means something.** Across runs 1-13 it read 0 only because no human ever added an `[FP]` mark; refinement 1 gave the loop its own evidence, runs 14 and 15 each recorded 1, and this run genuinely has none. Both previously-counted items were RESOLVED by human action (the NMMTools pair deleted, `fix/live-feed-follows-active-session` deleted), not suppressed.
- `terminal-project-cwd` is deliberately not counted, for the second run running. It carries a real cross-machine blocker, so repetition is a dependency rather than an unactioned recommendation. Distinguishing those two is the substance of the OUTSTANDING `noise-match-on-finding-identity-not-text` adjustment.
- **The `?? .claude/` item was never noise.** It was flagged for 5 consecutive runs and read as unresolved WIP; the cause was a stale `.gitignore` still listing `.worktrees/` after Claude Code moved worktrees to `.claude/worktrees/`. Fixed at the rule, not suppressed at the symptom. A loop-derived "noise" verdict would have been wrong here - worth remembering before trusting that counter to retire an item.
- Spend threshold: today's 121,313 output tokens is **4.1x the 5-run median** (29,716) and would have fired a bare relative multiple - but it is only 16% of the 750,000 absolute floor, so no flag. This is the first observed case of the two-part threshold from the 2026-08-06 retrospective doing exactly what it was designed for: the floor suppressing a relative spike on a low baseline. The check is no longer merely silent; it is demonstrably discriminating.

## Human Decisions (overrides the loop must respect)
- TokenMonitor PR #1 ("Terminal project folder + repo CLAUDE.md") was the user's own active PR, tracked presence/staleness only for 9 runs. **The PR is now MERGED**, so the override is satisfied and retired. Recorded rather than silently deleted so a future run does not read its absence as the decision having been lost.

## Resolved since last run
<!-- Pruned each run per step 2. Prior entries remain in git history. -->
- **The `?? .claude/` 5-run flag is fixed at the cause.** `.gitignore` still listed only `.worktrees/` after Claude Code moved worktrees to `.claude/worktrees/`; adding the current path cleared it. Scoped to worktrees rather than all of `.claude/`, so project-level agents/skills/settings stay trackable. claude-token-tracker is now fully clean.
- **Fleet PRs went 1 -> 0.** TokenMonitor#3 merged (`dfd63e0`) after its Codex P1s were fixed; Aether-OS #44 and #45 opened, went green on all 7 checks, and merged the same day.
- **Aether-OS issues 3 -> 1.** #41 (`busy_timeout`) fixed and closed - the Go pragma moved into the DSN so it no longer depends on caller pool config, and the Node collector, which had no timeout at all, got one. #40 closed as a documented limitation in `PROGRESS.md` note (f). Only #22 remains, open on purpose.
- **Another stale branch retired**: `fix/live-feed-follows-active-session` deleted after verifying 0 commits absent from master. Stale 0-ahead branches are down from 4 to 1 in two runs.
- **NMMToolkit stays clean** - 0 dirty, 0 unpushed, `master` only, local and remote.
- **The agent-learn capture hook was fixed** (`014138e`) after this loop's sibling pass found 36 of 60 buffered records unusable. Records now resolve the transcript by `session_id` when the payload path is wrong, and carry a `summary_source` field so a capture failure is distinguishable from a session with nothing to say.
- SPEND: no flag (see Recent Noise - the absolute floor correctly gated a 4.1x relative spike).
- CACHE: no flag. Today 97.9% vs a 0.975 five-run median.
- Branch-tips cache: 24 branches across 18 repos, **21 served from cache**, 3 refetched, 4 `ahead_by` refetched.
