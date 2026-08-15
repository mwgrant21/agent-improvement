---
loop: daily-triage
level: 1
paused: false
attempt_cap: 3
budget: soft
last_run: 2026-08-15
runs_since_retro: 9
---
## High Priority (waiting on human)
- **Adjustment `distinguish-broken-probe-from-dead-source` remains AT `attempt_cap` (3).** Proposed by runs 14, 15 and 16, escalated at run 17, unchanged since - still awaiting a decision. The change: a source that fails for **100% of its targets** is a BROKEN PROBE, not a dead source - it should abort and report the probe failure rather than emit per-target "unavailable" lines beside a clean finding. [decision needed: apply to LOOP.md via the loop-design skill, or mark HELD with a reason]
- **NEW: untracked `secrets/` directory in `TokenMonitor` (home-matt) holds plaintext credential files not covered by `.gitignore`.** `secrets/publish-token.txt` and `secrets/update-token.txt` exist as untracked working-tree content; `.gitignore` has no `secrets/` entry, so a broad `git add -A` in that repo would stage and could commit live tokens. Contents were not read (security discipline: this is a human-decision item, not something to inspect further). [action: add `secrets/` to `.gitignore` immediately; if either token has ever been staged/committed anywhere, rotate it - gitignoring does not rotate] [machine: home-matt]
- **RE-SURFACED: `code-graph-mcp` (home-matt) still has 21 commits on `master` with no upstream tracking, unverified for 3 runs.** First flagged at run 15 (2026-08-11), then invisible through runs 16-18 because those ran from work-it, which has no local clone. Re-checked this run: still 21 unpushed, `origin` remote IS configured (`github.com/mwgrant21/code-graph-mcp`, contrary to run 15's "no upstream configured at all" read - the remote exists, the local `master` branch simply was never pushed/tracked to it), plus 1 dirty line (`package-lock.json`, unchanged). Exceeds the >20-commit escalation bar. [action: `git push -u origin master`] [machine: home-matt]
- **NEW: home-matt's local-hygiene discovery root has been missing `~/projects/*` for at least 3 runs, producing false "no local clone" findings.** Runs 12-15 reported "no local clone of TarotApp/tarot/Miriels/nmmtools exists on home-matt" - all four actually live under `~/projects/`, which the discovery step never scanned (only `~` depth 1-2 and `~/Desktop`). This run scanned `~/projects/*` directly and found 12 additional repos, 4 of them with real unpushed work (see Watch List). Not a probe failure - the scan ran and returned a clean answer from an incomplete root, which is a worse failure mode because it looks authoritative. [decision needed: apply adjustment `expand-home-matt-discovery-root` (add `~/projects/*` as a third discovery root, machine-conditional since `work-it`'s layout differs) via the loop-design skill]

## Retrospective outcome (2026-08-06, runs 1-10)
- Refinements 1-6 APPROVED and applied to LOOP.md via the loop-design skill: loop-derived noise counting (1), revised spend/cache thresholds (2), discovered scan roots + source-unavailable reporting (3), machine-tagged hygiene items (4), stale-only uncommitted-changes reporting (5), and a verified commit/push of the loop's own state as step 5 (6).
- Refinements 7 (branch staleness by commits-ahead rather than tip date) and 8 (cache PR/issue results for quiet repos) were HELD, then approved and applied the same day - see the ledger.
- L2 promotion HELD at the user's decision despite the gate being literally met. Re-evaluate only after 10 runs in which `false_positives` is actually being fed by refinement 1. **9 of 10 done** (runs 11-19); run 13 was the first to record a non-zero `false_positives` (1, loop-derived); runs 18 and 19 (today) also recorded 1, same recurring item (see Untriaged noise). [action: none until 10 runs are in - next run completes the count]
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
| gate-cache-flag-on-min-volume | 2026-08-07 | 3 | OUTSTANDING (age 8d, re-proposed run 19/today - THIS run is a fourth data point and it CUTS AGAINST the gate: today's volume was also low (68,195 output tokens, lower than run 18's 157,476) yet the cache hit rate was 95.6%, well clear of both thresholds. Across four points: two low-volume days flagged, two did not. Low volume alone does not predict a flag either way, which weakens the case that a volume gate would fix anything rather than just suppressing real signal on low-volume days. Decide now (including "decline") rather than let this keep re-proposing on thinning evidence.) |
| noise-match-on-finding-identity-not-text | 2026-08-10 | 1 | OUTSTANDING (age 5d, awaiting decision) |
| distinguish-broken-probe-from-dead-source | 2026-08-11 | 3 | **AT ATTEMPT CAP** - re-proposed by run 16, third time, escalated to High Priority at run 17. Unchanged this run - still awaiting decision. |
| specify-branch-tips-cache-key-format | 2026-08-11 | 2 | OUTSTANDING (age 4d, awaiting decision). Still relevant: the API returns full 40-char SHAs, the cache stores 7-char, comparison only works by truncating on read. Still undecided which is canonical. |
| dirty-count-blind-to-content-churn | 2026-08-13 | 1 | OUTSTANDING (age 2d, awaiting decision). No new data point this run (GitHub-adjacent check, not touched by today's local-hygiene pass). |
| expand-home-matt-discovery-root | 2026-08-15 | 1 | NEW (proposed by this run). Add `~/projects/*` as a discovery root on home-matt, alongside `~` depth 1-2 and `~/Desktop`. Evidence: this run found 12 repos under `~/projects/` that prior home-matt runs never scanned, 4 with real unpushed work, and the missing root caused 3+ runs of incorrect "no local clone" findings for TarotApp/tarot/Miriels/nmmtools rather than an honest "not scanned". |

Ledger standing: **12 of 18 landed**, 0 held, 5 outstanding (ages 8d, 5d, 4d, 2d, 0d), 1 escalated at attempt-cap. One new adjustment proposed this run (`expand-home-matt-discovery-root`); `gate-cache-flag-on-min-volume` picked up a 3rd proposal with evidence now trending against it rather than for it.

Note for the next retrospective's step R1: two rows deviate from their original proposal text ON PURPOSE, and each row says how. When reconciling, check the file for what was ACTUALLY built, not for the phrase the critique used - `branch-staleness-by-commits-ahead` became author-date staleness plus a separate `ahead_by` signal, and `cache-quiet-repo-pr-issue-results` became a fleet-wide search that removes the calls rather than a cache of their answers. Both would read as never-landed under a naive text match.

## Watch List
- **Fleet PR/issue counts unchanged**: 1 open PR, 1 open issue, same as last run. [machine: any]
  - `TokenMonitorV2#1` "Reskin phases 3-4: Aether token layer, palettes, chrome pass, version check", no new activity since last run. [action: none, tracking]
  - `Aether-OS#22` white screen after desktop lock. Still instrumented but NOT fixed, unchanged. Deliberately left open. [action: none until it recurs - then grab the dev output and grep `[diag]` BEFORE closing the window]
- **TarotApp - 3 unpushed commits (up from 2), 8 ahead of `origin/master`, 3 dirty lines.** Newly re-verified on home-matt: `ded153e`/`7dcf7d2`/`f84f60a` - Android Given Ground + Lenormand deck parity, Carried Set rename, v1.14 bump. Below the >20-commit escalation bar. [action: push `master`] [machine: home-matt]
- **`tarot` - 3 unpushed commits, no upstream tracking configured on local `master`, 4 dirty lines.** `f33c888`/`c09bbb2`/`b4b9fc0` - GPU-crash workaround attempts (superseded by the actual root-cause fix, see `domains/app-dev.md` "restrictive shell Job Object") and a deck rename. `origin` remote is `github.com/mwgrant21/tarot` but `master` has no upstream set. [action: `git push -u origin master`] [machine: home-matt]
- **`Miriels-publish` - 1 unpushed commit (`ebfede7`, deck roster reorg), ahead 1, 3 dirty lines.** Same GPU-crash/greeting-system session as tarot, different repo. [action: push] [machine: home-matt]
- **`TokenMonitor` (this repo, home-matt) - 1 unpushed commit (`714bff9`, Stryker mutation-testing adopt), 3 untracked dirs.** RESOLVES part of the `terminal-project-cwd` open question below: `714bff9` is present on the current `design-v2-phase5` branch, confirming it survived (was not abandoned) independent of that stale branch. [action: push, or fold into the next PR] [machine: home-matt]
- **`terminal-project-cwd` (TokenMonitor) - 0 ahead, now safe to re-evaluate for deletion.** Given the finding directly above, the local-only `714bff9` Stryker commit is confirmed alive on `design-v2-phase5`, so this branch's copy is very likely redundant. [action: delete from origin once confirmed redundant] [machine: home-matt]
- `aether-os` (home-matt, `~/projects/aether-os`) - clean on commits (0 unpushed, level with origin) but 7 dirty lines, first observation on this machine/repo - not flagged per refinement 5 (needs 3 unchanged runs). [action: none yet, tracking] [machine: home-matt]
- `About-me`, `nmmtools` (home-matt) - 1 dirty line each, first observation. [action: none yet, tracking] [machine: home-matt]
- `TokenMonitorV2` (home-matt) - 13 behind `origin/main`, 0 unpushed, clean. Stale local clone, not at risk. [action: none] [machine: home-matt]
- `agent-improvement`'s own store had a rebase conflict this run (LESSONS.md + domains/app-dev.md/tooling.md/verification.md, plus a superseded local daily-triage run-15 commit) from a stale/offline home-matt clone diverging against 3 runs' worth of work-it + sibling agent-learn commits. Resolved by merging both sides' additive rows/entries and skipping the superseded run-15 commit; pushed clean. Not a data-loss event, but noted because it is exactly the shared-store risk `domains/loop-design.md` warns about. [action: none, resolved this run] [machine: home-matt]
- `Desktop\Aether-OS-livetest`, `Desktop\EFI-wt-migration`: not verifiable this run - home-matt has no `Desktop` clones of these; carried forward unchanged from work-it's run 18. [action: none] [machine: work-it]
- Desktop stray `.git` (`C:\Users\IT\Desktop`): known/by-design; skipped. [action: none] [machine: work-it]

## Recent Noise (ignored this run)
<!-- Mark an item [FP] if it was a false positive. Refinement 1: the loop ALSO counts an item byte-identical across 3 consecutive runs with no human action as noise on its own evidence, without waiting for a mark. -->
- **Aether-OS "1 commit on no remote" branch - still unresolved, not re-verifiable this run (no `Desktop\Aether-OS` clone on home-matt).** Carried forward unchanged from run 18/work-it. See Untriaged noise below.
- Spend threshold: today's 68,195 output tokens is far under both halves of the two-part gate - no flag.
- Cache threshold: today's 95.6% - well clear of both the 0.90 floor and the 5pp-below-median trigger. Run 18's flag did NOT repeat. See Adjustment ledger (`gate-cache-flag-on-min-volume`).

## Untriaged noise
- **Aether-OS "1 commit on no remote" branch** has now gone unmarked for 6+ consecutive runs (since run 14), though not independently re-checked this run (no local clone on home-matt). Still requesting an explicit decision: push, delete, or add a permanent Human Decision.

## Human Decisions (overrides the loop must respect)
- TokenMonitor PR #1 ("Terminal project folder + repo CLAUDE.md") was the user's own active PR, tracked presence/staleness only for 9 runs. **The PR is now MERGED**, so the override is satisfied and retired. Recorded rather than silently deleted so a future run does not read its absence as the decision having been lost.

## Resolved since last run
<!-- Pruned each run per step 2. Prior entries remain in git history. -->
- CACHE: run 18's flag did NOT recur - resolved, see Recent Noise. Fed as new counter-evidence into `gate-cache-flag-on-min-volume`.
- SPEND: no flag - see Recent Noise.
- `agent-improvement` store: rebase conflict from a stale home-matt clone resolved and pushed clean this run (see Watch List) - tree is clean, level with origin.
- Local hygiene root gap discovered and reported this run (see High Priority `expand-home-matt-discovery-root`) rather than resolved - flagging as new, not fixing it, per the L1 report-only boundary.
- Branch-tips cache was NOT consulted this run (home-matt's local-hygiene pass used direct `git status`/`git log` on discovered repos, not the GitHub branch-tips cache; the GitHub source itself was not re-queried beyond the fleet PR/issue search, since no repo/branch enumeration was needed to answer the local-hygiene questions this run focused on).
