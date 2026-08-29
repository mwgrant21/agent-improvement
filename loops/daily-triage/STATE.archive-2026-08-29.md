# daily-triage STATE.md archive - 2026-08-29

Full verbatim text of everything compressed out of `STATE.md` on 2026-08-29 by the
`log-archivist` pass (adjustment `rotate-state-md-past-50kb`). Nothing here was
summarised away: the primary file keeps a one-line stub for every ledger row, and
this file holds each row's complete original status prose.

## Adjustment ledger - full row text (rows landed before 2026-08-28)

### retro-reconcile-adjustment-ledger

`first_proposed 2026-08-06 | times 1`

**LANDED 2026-08-06 (refinement 9).** ROW ADDED 2026-08-28 by retrospective 4 - the id exists in `runs.jsonl` line 14 but had never been given a ledger row, so every "N of M landed" headline since 2026-08-06 undercounted by one. Verified present: LOOP.md "Step R1 - reconcile the Adjustment ledger FIRST".

### batch-branch-commit-date-lookups

`first_proposed 2026-07-14 | times 5`

LANDED 2026-08-03 (branch_tips cache, step 1)

### fix-spend-summary-date-window

`first_proposed 2026-07-17 | times 1`

LANDED 2026-07-22 (scripts/spend-summary.mjs local-day bucketing)

### record-output-token-baseline

`first_proposed 2026-07-17 | times 1`

LANDED 2026-07-18 (step 3 notes)

### flag-branches-20-commits-ahead

`first_proposed 2026-07-18 | times 1`

LANDED 2026-08-06 (step 1, local hygiene - promotes a >20-ahead branch to High Priority). **First fired on a genuinely new finding by run 28 (`tarot`, 5 branches x 333-365 commits); fired again run 30 (`IT-KB-Pipeline`, 27 commits, no remote).**

### branch-staleness-by-commits-ahead

`first_proposed 2026-07-21 | times 1`

LANDED 2026-08-06 (step 1, GitHub - implemented as author-date staleness + `ahead_by` as a separate signal, NOT as the literal "replace date with commits-ahead")

### verify-loop-own-commit-completed

`first_proposed 2026-07-24 | times 1`

LANDED 2026-08-06 (retro refinement 6, step 5)

### self-confirming-noise-without-fp-mark

`first_proposed 2026-07-24 | times 1`

LANDED 2026-08-06 (retro refinement 1, step 2)

### promote-tokenmonitor-pr1-to-human-decisions

`first_proposed 2026-08-03 | times 2`

LANDED 2026-08-06 (Human Decisions section)

### cache-quiet-repo-pr-issue-results

`first_proposed 2026-08-04 | times 1`

LANDED 2026-08-06 (step 1, GitHub - implemented by ELIMINATING the per-repo sweep via one fleet-wide `gh search prs`/`gh search issues` call, NOT by caching a quiet-repo negative)

### drop-bare-uncommitted-changes-signal

`first_proposed 2026-08-04 | times 1`

LANDED 2026-08-06 (retro refinement 5, step 1)

### machine-tag-watchlist-items

`first_proposed 2026-08-06 | times 1`

LANDED 2026-08-06 (retro refinement 4, step 2)

### exclude-default-branches-from-staleness

`first_proposed 2026-08-06 | times 1`

LANDED 2026-08-06 (step 1, GitHub)

### noise-match-on-finding-identity-not-text

`first_proposed 2026-08-10 | times 1`

**LANDED 2026-08-17.** Step 2 now matches on finding identity (repo + branch/path + recommendation, volatile fields like age stripped) instead of literal rendered text.

### distinguish-broken-probe-from-dead-source

`first_proposed 2026-08-11 | times 3`

**LANDED 2026-08-17.** Step 1 distinguishes a dead/absent source from a multi-target source where 100% of targets fail the same way.

### specify-branch-tips-cache-key-format

`first_proposed 2026-08-11 | times 2`

**LANDED 2026-08-17.** Canonicalized on the FULL 40-char SHA; a shorter cached `sha` is a miss.

### record-behind-by-alongside-ahead-by

`first_proposed 2026-08-21 | times 1`

**LANDED 2026-08-21 (human decision, applied via loop-design skill).** Step 1 records `behind_by` from the SAME compare call that already returns `ahead_by` (zero extra API calls), reports the pair as `Na/Mb`, and requires a divergent branch (ahead>0 AND behind>0) to be labelled `divergent, verify against the default branch before proposing a merge`.

### clarify-repo-discovery-depth-definition

`first_proposed 2026-08-18 | times 3`

**LANDED 2026-08-21 (human decision, applied via loop-design skill).** LOOP.md step 1 pins depth to the REPO DIRECTORY (`find <root> -maxdepth 3 -name .git`), names `~/Downloads` as a third scan root, and classifies a `.git` FILE as a linked worktree attributed to its parent.

### freeze-unchanged-runs-when-not-verified

`first_proposed 2026-08-21 | times 1`

**LANDED 2026-08-21 (human decision, applied via loop-design skill).** A run that does not OBSERVE a repo carries `unchanged_runs` forward frozen with `frozen_not_verified: true`.

### dedupe-same-day-spend-baseline

`first_proposed 2026-08-21 | times 1`

**LANDED 2026-08-21 (human decision, applied via loop-design skill).** Spend/cache figures identical to the previous run-log line are a RE-READ: tagged `spend_duplicate_of`, excluded from the trailing-5 median. **Run 30 note for R1: run 24's line predates the landed field name and tags its duplicate `spend_reading_duplicate_of_prev_run: true` - baseline readers must accept both spellings for that one historic line.**

### dirty-count-blind-to-content-churn

`first_proposed 2026-08-13 | times 1`

**LANDED 2026-08-17.** Staleness check compares the dirty file PATH SET, not the line count; `dirty_lines` -> `dirty_paths`.

### validate-jsonl-line-before-append

`first_proposed 2026-08-17 | times 1`

**LANDED 2026-08-17.** Round-trip `JSON.parse(JSON.stringify(...))` before appending a run's own line.

### worktree-hygiene-report

`first_proposed 2026-08-21 | times 1`

**LANDED 2026-08-21 (human decision, applied via loop-design skill, same day as proposed).** Report-only worktree staleness check. **First executed on work-it by run 30: 0 stale worktrees (the one extra worktree, `EFI-wt-migration`, is suppressed by the standing 2026-08-21 decision).**

### gitignore-and-auth-drift-check

`first_proposed 2026-08-21 | times 1`

**LANDED 2026-08-21 (human decision, applied via loop-design skill, same day as proposed).** Per-repo `.claude/worktrees/` gitignore drift check plus a once-per-run fleet-wide `gh auth status`. **Both gaps it opened (aether-os, TokenMonitorV2) are CLOSED as of run 28 on home-matt; run 30 sees the OLD pattern still in the lagging work-it clones (see Watch List) - a clone-lag echo, not a regression.**


## Retrospective 4 - R2 refinement proposals (2026-08-28) - full original section

## Retrospective 4 - R2 refinement proposals (2026-08-28) - **ALL 11 DECIDED 2026-08-28, see Human Decisions**
<!-- Step R3 applies ONLY human-approved items, via the loop-design skill. NOTHING below has been
     applied to LOOP.md. The loop never edits its own LOOP.md without approval. -->
1. **ADOPT `pull-store-before-step-0` (outstanding, first_proposed 2026-08-28 by run 30).** Step 0 begins with `git -C ~/agent-improvement pull --rebase`; on failure, continue against the local store but state the staleness caveat explicitly in the digest. **Second independent failure in one day, and this one is the worse mode**: run 30's stale store was caught by a step-5 push rejection, but retrospective 4's session started 1 commit behind reading `runs_since_retro: 9` and would have executed a NORMAL run - silently skipping this retrospective. Nothing downstream would have caught that: the push would have merged cleanly and only the counter would have been wrong, permanently. **Highest-priority item in this set.**
2. **RE-OPEN `gate-cache-flag-on-min-volume` (DECLINED 2026-08-17) on materially new evidence.** Runs 21-30 separate perfectly by volume with zero crossovers - flagged: 23/24 (2,722 out), 27 (54,794), 29 (11,371), 30 (3,835); clean: 21 (455,934), 22 (232,692), 25 (386,911), 26 (1,488,880), 28 (307,463). **Corrected for the machine confound found while writing this run's line (proposal 11): the three work-it readings (23, 24, 30) are all low-volume AND all flagged, but they measure a different machine's usage log, so they are consistent-with rather than independent evidence. Within home-matt alone the separation is still 7-for-7 with zero crossovers - flagged at 54,794 and 11,371, clean at >=232,692.** The decline named "3-of-5 low-volume data points against"; the home-matt-only subset of this window is 7-of-7 for. Proposed shape: below a floor (~50,000 output tokens/day) the cache check reports `not evaluated - insufficient volume` in the digest rather than flagging, and never silently. A silent check is a suspect check, so suppression must stay visible.
3. **NEW `verify-repo-can-change-before-noise-graduation`.** Before graduating an item to loop-derived noise on N identical observations, confirm the repo is ABLE to change - sweep for a stale `.git/*.lock` (no git process holding it, mtime older than ~1h). Evidence: `TarotApp` was graduated to noise on 5 identical observations while an empty `index.lock` dated 2026-08-12 had blocked every index-modifying operation for 13 days. The rule read "settled" where the truth was "broken". Runs 29 and 30 both swept ad hoc and found 0 fleet-wide, which shows the condition is RARE, not that the check is unneeded - it was silently corrupting a finding for 5 consecutive runs the one time it mattered. Same class as `domains/verification.md`, "A probe that cannot distinguish 'not yet' from 'never' is not a verification."
4. **NEW `count-reconfirmation-as-reproposal`.** A run that re-confirms an outstanding adjustment must re-emit it as its structured `notes.adjustment` (carrying `first_proposed` forward unchanged), OR R1 must count ledger-row re-confirmations toward `times_proposed`. Today all 5 outstanding items read 1 while `fetch-prune-before-unpushed-check` has been executed ad hoc by three consecutive runs and `close-expand-home-matt-discovery-root` re-confirmed by five. The attempt cap - the whole escalation mechanism refinement 9 exists for - therefore cannot fire on the items most in need of it.
5. **CARRIED `fetch-prune-before-unpushed-check`** (outstanding 3d, run 28). Runs 28, 29 and 30 all ran `git fetch --prune` ad hoc; run 28's version of this exposed `tarot`'s 1,771 orphaned commits that stale refs had hidden. Three runs now do by convention what the protocol does not require. Stays read-only, so the L1 boundary is unchanged.
6. **CARRIED `detect-no-upstream-local-branches`** (outstanding 2d, run 29), **with run 30's amendment**: the check must split untracked-DEAD (0 commits not on a remote - safe cleanup, e.g. run 29's 5 home-matt branches) from untracked-LIVE (unpushed > 0 - real sole-copy exposure, e.g. `NMMToolkit`'s `fix/dispatch-command-not-found-message`). Reporting them identically would repeat the severity-flattening that `flag-branches-20-commits-ahead` was written to fix.
7. **CARRIED `close-expand-home-matt-discovery-root`** (outstanding 6d, run 25). `~/projects` is already reached by the `~` scan root under the depth-to-repo-dir rule; the HELD adjustment is moot and needs no LOOP.md change. Re-confirmed by runs 25-29 and again this run (21 `.git` entries found under `~`, `~/Desktop`, `~/Downloads`, all inside already-reached roots). Near-zero-cost close-out.
8. **CARRIED `clarify-unchanged-runs-flag-threshold`** (outstanding 4d, run 27). Pin one reading of the 3-consecutive-run noise rule in LOOP.md so it fires identically for every item at the same counter value. Run 26 flagged `TarotApp` at `unchanged_runs==3` while leaving `tarot`, `Miriels-publish` and `About-me` unflagged at the identical value. Note this interacts with proposal 3: pinning the threshold without the can-it-change check just makes the wrong graduation happen more consistently.
9. **L2 PROMOTION: NOT PROPOSED.** Gate is <=2 false positives across the last 10 runs AND 0 unresolved escalations. Actual: 16 and 1. Both inputs are genuinely measured, not silent zeros (13 of the 16 are loop-derived, recorded per run in `notes.fp_source`). Demotion is also not triggered - escalations on runs 25 and 30 are not 3 consecutive.
10. **WATCH-ONLY, no LOOP.md edit proposed: run cost.** Median duration 349s -> 870s across the two windows while findings/run fell to 9-14. Re-evaluate at retrospective 5; run `log-archivist` on STATE.md if it crosses the ~50KB trigger its own State Ownership ledger sets (currently ~37KB) or if median duration crosses ~1,200s. Recording the trend now so the next retrospective compares against a stated baseline rather than noticing it fresh.

11. **NEW `per-machine-spend-baseline` - the strongest genuinely new finding of this retrospective, discovered while writing this run's own log line.** `scripts/spend-summary.mjs` reads `~/.claude/projects/**/*.jsonl` via `homedir()`, so a reading is that MACHINE's usage log and nothing else. The trailing-5 spend and cache medians in step 1 mix home-matt and work-it readings indiscriminately, so every threshold comparison taken across a machine flip compares two different corpora. Evidence from this window: work-it read 2,722 / 2,722 / 3,835 output tokens on runs 23, 24 and 30 while home-matt read 11,371 to 1,488,880 on runs 21, 22, 25-29 - a ~500x spread that is machine identity, not a change in behaviour. The window ran 7 home-matt and 3 work-it, so roughly a third of every median was drawn from the wrong corpus. **Proposal: compute the trailing-5 spend and cache baselines from run-log lines whose `notes.machine` matches the current machine, and say so in the digest when fewer than 3 same-machine baselines exist (the existing "skip if fewer than 3 baselines" rule then does the right thing instead of silently borrowing the other machine's).** This also partly explains proposal 10's duration growth being hard to read, and it means every spend/cache flag recorded since the loop went two-machine (run 23, 2026-08-21) rests on a partly-foreign baseline.

## rotate-state-md-past-50kb - what the 2026-08-29 rotation did

- STATE.md 54,156 -> ~47,000 bytes, back under the ~50KB State Ownership trigger.
- Ledger rows that landed BEFORE 2026-08-28 keep their id / first_proposed / times /
  terminal status in the primary file and point here for their full original prose. No
  row was removed. That was the binding constraint on how this could be done at all: the
  ledger header rule says landed rows STAY and get re-checked, and a landed row that goes
  missing is REGRESSED and escalates - so a rotation that moved rows wholesale would have
  manufactured 24 false regressions at retrospective 5.
- The Retrospective-4 proposals section (7,373 B) moved here behind a pointer. All 11 of
  its items were decided 2026-08-28; the binding decisions live in `## Human Decisions`
  and the per-item outcomes in the ledger rows, so the section was pure duplication.
- DELIBERATELY NOT compressed: the 12 rows landed 2026-08-28/29, which retrospective 5
  must still re-verify against LOOP.md; and the runs 21-30 retrospective outcome, which
  holds the trend baselines (16 false positives, 870s median duration, the L2 gate
  arithmetic) that retrospective 5 compares against. Compressing either would have cost
  the next retrospective its inputs to save a few KB.
- HEADROOM IS THIN - roughly 3KB under the trigger, so expect this adjustment to fire
  again within a run or two. The next rotation should take the 2026-08-28 ledger wave
  once retrospective 5 has re-verified it, and the runs 21-30 outcome once retrospective
  5 supersedes it. Note also that the close-out bookkeeping for this rotation itself cost
  ~1.3KB of the ~7.4KB saved; keep rotation prose in this archive, not in STATE.md.
