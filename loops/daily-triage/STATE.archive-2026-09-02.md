# daily-triage STATE.md archive - 2026-09-02

Full verbatim text of everything compressed out of `STATE.md` on 2026-09-02 by the
`log-archivist` pass (adjustment `rotate-state-md-past-50kb`), triggered at 54,831
bytes against the ~50KB rotation policy in the State Ownership table. Second rotation;
the first was `STATE.archive-2026-08-29.md`, which is untouched. Nothing here was
summarised away: the primary file keeps a one-line stub plus a pointer for every row
below, and this file holds each row's complete original status prose.

`stale-lock-sweep-independent-of-noise-graduation` is deliberately NOT rotated - it
landed the same day as this pass and stays in full in the primary file.

## Adjustment ledger - full row text (rows resolved 2026-08-17 to 2026-08-29)

### gate-cache-flag-on-min-volume

`first_proposed 2026-08-07 | times 3`

**DECLINED 2026-08-17 (human decision).** Escalated at attempt_cap; 3-of-5 low-volume data points against the hypothesis. Not re-propose-eligible absent new evidence. **Run 30 note: the cache flag has now fired 3 times in 4 runs (27, 29, 30), every one on a low-volume day and never on a high-volume day - the retrospective should weigh whether this constitutes the "materially new evidence" the decline named.** **RETROSPECTIVE 4 (2026-08-28) WEIGHED IT AND SAYS YES - RE-OPEN PROPOSED (R2 proposal 2, awaiting a human).** Across runs 21-30 the separation is perfect with zero crossovers: every flagged run (23, 24, 27, 29, 30) had <=54,794 output tokens; every clean run (21, 22, 25, 26, 28) had >=232,692. The 2026-08-17 decline rested on 3-of-5 low-volume points AGAINST the hypothesis; this window is 5-of-5 FOR it. `times` NOT incremented - this is a retrospective re-open of a declined item, not a 4th proposal of an outstanding one. **RE-OPEN APPROVED 2026-08-28 (human decision, retrospective 4 proposal 2) - the 2026-08-17 decline is OVERTURNED and this is now LANDED.** Below 50,000 output tokens/day the cache check reports `not evaluated - insufficient volume (<N> output tokens)` instead of flagging, and never silently. Caveat recorded in LOOP.md: the floor was derived from a window whose medians mixed corpora, so re-check it at retrospective 5 against home-matt-only readings.

### close-expand-home-matt-discovery-root

`first_proposed 2026-08-22 | times 1`

**CLOSED-MOOT 2026-08-28 (human decision, retrospective 4 proposal 7).** Approved: no LOOP.md change needed. `~/projects` is already reached by the `~` scan root under the depth-to-repo-dir rule; re-confirmed by runs 25-29 and retrospective 4 (21 `.git` entries under `~`, `~/Desktop`, `~/Downloads`, all inside already-reached roots). Both this row and `expand-home-matt-discovery-root` are now closed; stop carrying either forward. Prior text: `~/projects` is ALREADY reached by the existing `~` scan root at the repo-dir depth-3 rule, so the HELD `expand-home-matt-discovery-root` adjustment is moot and needs no LOOP.md change - proposing to CLOSE it. Re-confirmed by runs 26, 27, and 28 (28 found 21 repos on home-matt, all under already-reached roots; nothing outside them).

### clarify-unchanged-runs-flag-threshold

`first_proposed 2026-08-24 | times 1`

**LANDED 2026-08-28 (human decision, retrospective 4 proposal 8, applied via loop-design skill).** Threshold pinned to `unchanged_runs >= 3`, counting only runs that OBSERVED the item, firing identically for every item at the same value. Sequenced to land AFTER `verify-repo-can-change-before-noise-graduation` per the human decision, since consistency without the can-it-change check would only make a wrong graduation reliable. Prior text: Run 26 flagged `TarotApp` as loop-derived noise at `unchanged_runs==3` but left `tarot`, `Miriels-publish`, and `About-me` unflagged at the identical value. Propose pinning one reading in LOOP.md so the noise rule fires identically for every item at the same counter value.

### fetch-prune-before-unpushed-check

`first_proposed 2026-08-25 | times 1`

**LANDED 2026-08-28 (human decision, retrospective 4 proposal 5, applied via loop-design skill).** `git fetch --prune` now runs BEFORE the unpushed check; LOOP.md pins it to fetch-only (never pull/merge) as the Operational failure ladder's Resync tier, so the L1 boundary is explicit. Prior text: Run `git fetch --prune` on every discovered repo with a remote BEFORE the unpushed/`[gone]` check and record `refs_refreshed: true`. Run 29 ran the fetch ad hoc again; **run 30 also ran it ad hoc on all 16 work-it repos with remotes** - the third run in a row doing by convention what the protocol still does not require.

### detect-no-upstream-local-branches

`first_proposed 2026-08-26 | times 1`

**LANDED 2026-08-28 (human decision, retrospective 4 proposal 6, applied via loop-design skill).** Landed WITH run 30's amendment: the check splits untracked-DEAD (0 unpushed, cleanup candidate, Watch List at most) from untracked-LIVE (unpushed>0, sole-copy exposure, 20-commit volume rule applies). The split is mandatory, not optional. Prior text: Enumerate every local branch, classify as tracked-and-live / tracked-but-gone / untracked, and report the last two together as dead weight when `git log <branch> --not --remotes` returns 0. **Run 30 adds a work-it data point: `NMMToolkit`'s `fix/dispatch-command-not-found-message` is exactly the untracked class - but with 1 UNPUSHED commit, i.e. the check must separate untracked-dead (0 unpushed) from untracked-live (unpushed > 0), which is real exposure, not dead weight.**

### pull-store-before-step-0

`first_proposed 2026-08-28 | times 1`

**LANDED 2026-08-28 (human decision, retrospective 4 proposal 1, applied via loop-design skill).** Step 0 now begins with `git -C ~/agent-improvement pull --rebase`; on failure the run continues against the local store but MUST state the staleness caveat in the digest. Prior text: Step 0 must begin with `git -C ~/agent-improvement pull --rebase` (report-and-continue-on-local if it fails, with an explicit staleness caveat in the digest). Evidence: run 30 started from a work-it store last synced 2026-08-21, read run 24's line as "the previous run", computed baselines and consecutive-flag counts against it, and produced a whole first analysis (wrong run number, wrong cache-flag streak, five stale home-matt findings re-raised) that had to be discarded when the step-5 push was rejected and revealed runs 25-29. On a two-machine loop, the runs.jsonl tail is only "the previous run" AFTER a sync; nothing in the protocol currently says so.

### verify-repo-can-change-before-noise-graduation

`first_proposed 2026-08-28 | times 1`

**LANDED 2026-08-28 (human decision, retrospective 4 proposal 3, applied via loop-design skill).** Before graduating an item to loop-derived noise, sweep for a stale `.git/*.lock` (no holding process, mtime >~1h). A locked repo reports as BLOCKED with the lock path and age; the item is not counted as noise and its `unchanged_runs` is not stepped. Evidence: `TarotApp` graduated to noise on 5 identical observations while an empty `index.lock` dated 2026-08-12 had blocked every commit for 13 days - the rule read "settled" where the truth was "broken". Runs 29/30 swept ad hoc and found 0 fleet-wide: RARE, not unneeded.

### count-reconfirmation-as-reproposal

`first_proposed 2026-08-28 | times 1`

**LANDED 2026-08-28 (human decision, retrospective 4 proposal 4, applied via loop-design skill).** A run that re-confirms, executes ad hoc, or relies on an outstanding adjustment MUST re-emit it as its structured `notes.adjustment` with `first_proposed` carried forward - prose re-confirmation no longer counts. Corollary pinned in LOOP.md: a RETROSPECTIVE carrying an item forward is not a re-proposal and does not increment. Fixes the hole where all 5 outstanding items read `times_proposed: 1` despite `fetch-prune-before-unpushed-check` being run ad hoc 3x and `close-expand-home-matt-discovery-root` re-confirmed 5x, leaving the attempt cap structurally unable to fire.

### per-machine-spend-baseline

`first_proposed 2026-08-28 | times 1`

**LANDED 2026-08-28 (human decision, retrospective 4 proposal 11, applied via loop-design skill).** Trailing-5 spend and cache medians are computed ONLY from run-log lines whose `notes.machine` matches the current machine; when fewer than 3 same-machine baselines exist the digest says so and the existing skip-if-under-3 rule applies. `notes.machine` was already recorded on every line, so no schema change was needed. Evidence: `spend-summary.mjs` reads the LOCAL `~/.claude/projects` via `homedir()`; work-it read 2,722/2,722/3,835 output tokens on runs 23/24/30 against home-matt's 11,371-1,488,880 on runs 21/22/25-29, a ~500x spread that is machine identity, not behaviour. ~1/3 of every median in the window came from the wrong corpus, and **every spend/cache flag since run 23 rests on a partly-foreign baseline.**

### normalize-machine-label-in-run-notes

`first_proposed 2026-08-29 | times 1`

**LANDED 2026-08-29 (human decision, applied via loop-design skill).** `notes.machine` is pinned to the BARE machine id (`home-matt` / `work-it`, the same value as `machineId` in `local-state.json`); the hostname goes in `notes.hostname` and is never appended. The baseline matcher NORMALIZES both sides before comparing - trim, lowercase, take the portion before the first `/` - so historic lines still count. Verified on the real run log at apply time: the two spellings are present (8 `home-matt`, 2 `home-matt/TITAN`), strict matching selects 8 lines and normalized matching selects 10, moving the trailing-5 cache median. Prior text: `notes.machine` is written inconsistently - `home-matt` on runs 21/22/25/26/29 and the retro lines, but `home-matt/TITAN` on runs 27 and 28 - so the exact-match rule landed 2026-08-28 as `per-machine-spend-baseline` silently drops 2 of the 7 home-matt readings. Strict match gives a trailing-5 median of 232,692 out / 0.970 cache; normalizing on the `home-matt` prefix gives 54,794 / 0.872. Neither changes run 31's outcome (no flag either way), but a 10-point cache-median swing decides borderline days. Proposal: pin `notes.machine` to a canonical machine id (`home-matt` / `work-it`, with hostname in `notes.hostname`, which runs 27/28 already record) and have the baseline matcher normalize on prefix so historic lines still count.

