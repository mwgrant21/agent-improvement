# daily-triage STATE.md archive - 2026-09-08

Full verbatim text of everything compressed out of `STATE.md` on 2026-09-08 by the
`log-archivist` procedure (adjustment `rotate-state-md-past-50kb`), triggered at
62,850 bytes against the ~50KB rotation policy in the State Ownership table. Third
rotation; the first two are `STATE.archive-2026-08-29.md` and
`STATE.archive-2026-09-02.md`, both untouched. Nothing here was summarised away: the
primary file keeps a one-line stub plus a pointer for every ledger row below, and
this file holds each row's complete original status prose.

**Scope note, wider than the first two rotations.** Both prior passes compressed only
Adjustment-ledger rows. The file has outgrown the ~50KB trigger three times running
under that narrow scope (54,156 -> 47,000 bytes on 2026-08-29; 54,831 -> 48,772 on
2026-09-02; 62,850 bytes again by 2026-09-08, in just 2-6 runs each time), which means
ledger-row-only rotation is not buying durable headroom. This pass also archives two
blocks that are pure historical record and that neither prior rotation touched:

1. The three `## Retrospective outcome` sections (2026-08-06, 2026-08-17, 2026-08-28)
   plus `## Retrospective 4 - R2 refinement proposals` - all explicitly marked
   DECIDED/CLOSED in their own headers, and nothing in LOOP.md's steps reads them;
   R1 reconciles via `runs.jsonl` and a direct grep of LOOP.md/scripts, never via
   this prose.
2. The Adjustment ledger's accumulated "Prior standing (...)" history trail and the
   2026-08-29 ORPHAN-ID SWEEP note - superseded narration that only the CURRENT
   "Ledger standing UPDATED" line (kept live in the primary file) is actually needed
   for. Deliberately KEPT LIVE and NOT moved here: the two "Note for the next
   retrospective's step R1" lines (the line-wrap grep gotcha and the two
   deviated-from-proposal rows), since R1 actually consults those.

`discover-bare-repo-worktree-hubs` and `detect-content-duplicate-branches` are
deliberately NOT rotated - the first landed the same day as this pass, the second is
OUTSTANDING (not yet applied), and both stay in full in the primary file per the
existing "don't rotate same-day/non-landed" convention.

## Retrospective outcomes - full text (2026-08-06 through 2026-08-28)

### Retrospective outcome (2026-08-06, runs 1-10)
- Refinements 1-6 APPROVED and applied to LOOP.md via the loop-design skill: loop-derived noise counting (1), revised spend/cache thresholds (2), discovered scan roots + source-unavailable reporting (3), machine-tagged hygiene items (4), stale-only uncommitted-changes reporting (5), and a verified commit/push of the loop's own state as step 5 (6).
- Refinements 7 (branch staleness by commits-ahead rather than tip date) and 8 (cache PR/issue results for quiet repos) were HELD, then approved and applied the same day - see the ledger.
- L2 promotion HELD at the user's decision despite the gate being literally met. Re-evaluated by the 2026-08-17 retrospective: NOT MET (see below).
- Refinement 9 APPROVED and applied the same day: the retrospective now reconciles the Adjustment ledger (below) as its FIRST step, per-run critiques record a structured `notes.adjustment` entry, and an adjustment proposed `attempt_cap` (3) times without landing escalates instead of being re-proposed.

### Retrospective outcome (2026-08-17, runs 11-20)
- **Step R1 (ledger reconciliation)**: all 12 rows marked LANDED were re-verified by grepping the CURRENT `LOOP.md` text (not by trusting the ledger table) - all 12 confirmed present, none regressed. Ledger fully cleared the same day across 6 human decisions.
- **Step R2/R3**: all outstanding items decided - 4 applied, 1 held, 1 declined. See Adjustment ledger and Human Decisions.
- **L2 promotion gate, explicitly re-evaluated**: NOT MET, and for the first time a real (not silent-zero) measurement. `false_positives` non-zero on 3 of runs 11-20 (=3, above the <=2 gate) and 2 unresolved escalations open at the time against a gate requirement of 0. Recommendation: do not propose promotion.

### Retrospective outcome (2026-08-28, runs 21-30)
- **Step R1 (ledger reconciliation)**: every LANDED row re-verified by inspecting the CURRENT `LOOP.md` / `scripts/` text, not by trusting the table. **All landed rows confirmed present; 0 REGRESSED.** Two rows verify only behaviourally (`worktree-hygiene-report`, `gitignore-and-auth-drift-check` - their ids are not literal in LOOP.md, but `git worktree list --porcelain`, `gitignore gap` and `gh auth status` all are), and `noise-match-on-finding-identity-not-text` is present but line-wrapped, so a naive grep of the bare id reads 0 for all three. Recorded here so a future R1 does not mistake them for regressions.
- **Ledger arithmetic was wrong in two ways.** The standing line read "23 of 29 landed"; the table actually held **30** rows, and a **31st adjustment id exists in `runs.jsonl` that never got a ledger row at all** - `retro-reconcile-adjustment-ledger` (line 14, first_proposed 2026-08-06), which is refinement 9 and IS landed (LOOP.md "Step R1 - reconcile the Adjustment ledger FIRST"). Corrected standing: **24 of 31 landed**, 1 declined, 1 held, 5 outstanding, **0 escalated at attempt-cap**.
- **Attempt cap fired zero times this window, and structurally could not.** All 5 outstanding items read `times_proposed: 1`, yet 4 have been re-confirmed repeatedly in prose (`close-expand-home-matt-discovery-root` across runs 25-29; `fetch-prune-before-unpushed-check` executed ad hoc by runs 28, 29 AND 30). Only a run that re-emits the id in its structured `notes.adjustment` increments the counter, and no run in this window did. The escalation machinery is unfed for exactly the items it exists to catch - the same failure class as refinement 1's "a metric only a human can increment measures the human". See R2 proposal 4.
- **Precision trend: 16 false positives across runs 21-30, against 6 across runs 11-20.** Breakdown: 13 loop-derived, 3 human-marked. The rise is concentrated in runs 27/28/29 (4/5/4) and is NOT the loop becoming noisier so much as the loop-derived rule finally firing on a backlog that the 2026-08-25 human decision pass then cleared. **But some of that count was wrong in both directions**: `TarotApp` was graduated to noise on 5 identical observations while a stale `.git/index.lock` had made the repo physically unable to commit since 2026-08-12. See R2 proposal 3.
- **Duration trend: median run 349s (runs 11-20) -> 870s (runs 21-30), a 2.5x rise, while findings/run FELL from 25/22 early in the window to a steady 9-14.** Cost per finding roughly quadrupled. `duration_s` was a real measured value on all 10 runs (the runs 9/10 zero-duration defect has not recurred). STATE.md is now ~31KB against the State Ownership ledger's own ~50KB rotation trigger; `runs.jsonl` is ~259KB. Not breached, but this is the metric to watch. See R2 proposal 10.
- **Dead sources: none.** All sources returned data on all 10 runs; the broken-probe rule (`distinguish-broken-probe-from-dead-source`) has still never needed to fire - 0 probe failures in every run of the window. A check that has never fired is a suspect check, but this one has a clean falsifiable definition and the 24/24 target counts are recorded each run, so it is reading real data rather than sitting inert.
- **Machine alternation is now structural.** The window ran 6 from home-matt (21, 22, 25, 26, 27, 28, 29 - 7 in fact) and 3 from work-it (23, 24, 30). On every run roughly half the local-hygiene fleet is frozen as "not verifiable on <machineId>". `freeze-unchanged-runs-when-not-verified` (landed 2026-08-21) is doing its job, but it means a 3-consecutive-run staleness flag can take a calendar week or more to accumulate on either machine.
- **L2 promotion gate: NOT MET, and measured rather than silently zero.** Gate requires <=2 false positives across the last 10 runs AND 0 unresolved escalations. Actual: **16 false positives** (8x the bar) and **1 unresolved escalation** (`IT-KB-Pipeline`, opened by run 30, still awaiting a human). Recommendation: do not propose promotion. **Demotion also not triggered** - escalations occurred on runs 25 and 30, which is not 3 consecutive.
- **Constrained scopes: empty, nothing to reconsider.** No source was constrained during this window and none is proposed for constraint.

### Retrospective 4 - R2 refinement proposals (2026-08-28) - ALL 11 DECIDED, CLOSED

All 11 proposals were decided by the human in one pass on 2026-08-28: 8 landed as
LOOP.md edits (proposals 1-6, 8, 11), 1 closed as moot (7, plus the held row it
supersedes), and 2 were accept-as-reported with no LOOP.md change (9 stay-L1,
10 watch-only). The binding decisions are recorded in `## Human Decisions`; the
per-item outcome for each is in the `## Adjustment ledger` row for its id.
Full original proposal text: `STATE.archive-2026-08-29.md`.

## Adjustment ledger - full row text (rows resolved 2026-09-02 to 2026-09-06)

### stale-lock-sweep-independent-of-noise-graduation
first_proposed 2026-08-30, times_proposed 3.
**LANDED 2026-09-02 (human APPROVED at attempt cap, applied via the loop-design skill).** The stale-`.git`-lock sweep is now a first-class source in step 1, run over every repo local hygiene enumerates, every run - independent of noise-graduation candidacy. The step-2 graduation gate no longer sweeps: it READS `notes.stale_locks` from step 1, and an absent or failed sweep BLOCKS graduation rather than passing it. `notes.stale_locks` plus a swept-repo count are now recorded so "swept, found none" is distinguishable from "did not sweep". L1 unchanged - the sweep reports a lock, never deletes one. This is the first adjustment in the loop's history to reach the attempt cap and be resolved by it. Prior status: **ESCALATED AT ATTEMPT CAP 2026-09-02 (run 34) - see High Priority.** Third proposal; run 34 again swept all 18 work-it repos fleet-wide (0 locks found) where the current LOOP.md wording would have reached only the 2 noise-graduation candidates, and re-emits the id per `count-reconfirmation-as-reproposal`. Per LOOP.md the cap means it is escalated for a human decision, NOT re-proposed a 4th time. Prior status: **OUTSTANDING, proposed by run 32, RE-PROPOSED by run 33** (2026-09-01, work-it): run 33 executed the fleet-wide sweep ad hoc on all 18 work-it repos (0 locks found - a clean result is still a result the current wording would never have produced for the 14 repos with no noise-graduation candidacy), and re-emits the id as its structured `notes.adjustment` per `count-reconfirmation-as-reproposal`. One more re-proposal reaches the attempt cap (3). Run the stale-`.git`-lock sweep fleet-wide as its own finding source every run, not only as the gate immediately before noise-graduation. Current LOOP.md text ties the sweep to "BEFORE graduating anything to noise" - a repo with 0 dirty paths, or one whose path set just changed, never reaches the noise-graduation check at all, so the sweep as currently scoped would never run for it. Evidence: run 32 found 8 repos with a stale `index.lock` (all dated 2026-08-29 17:28-17:29 local, no holding process). Only `TarotApp` and `aether-os` were noise-graduation candidates (`unchanged_runs>=3`) that the current wording would reach. The other 6 (`Claude-Files`, `Miriels-publish`, `nmmtools`, `tarot`, `TokenMonitor`, `TokenMonitorV2`) were caught only because run 32 swept ALL repos rather than restricting itself to noise-graduation candidates - a strict reading of the current LOOP.md text would have missed them, including `Miriels-publish`, which has substantial uncommitted deck-rework WIP sitting behind the block.

### record-step-5-commit-push-result-in-notes
first_proposed 2026-09-06, times_proposed 1.
**LANDED 2026-09-06 (human APPROVED same day, applied via the loop-design skill).** APPROVED in intent but RESHAPED on application: as proposed it was unimplementable. Step 3 appends the run line BEFORE step 5 runs and `runs.jsonl` is append-only, so a line cannot record its own commit result. Implemented as two append-only halves instead - step 5 appends a separate `type:"store-sync"` line after the push (immediate record), and step 0 audits the PREVIOUS run's step 5 by comparing store HEAD against the SHA that run recorded pulling (catches a run that died before writing its store-sync line). Run 36's ad-hoc `notes.store_step5_prior_run` check is now the formalized version of the second half.

### dirty-repo-cache-key-is-ambiguous-across-machines
first_proposed 2026-09-03, times_proposed 2.
**LANDED 2026-09-06 (human APPROVED at `times_proposed: 2`, applied via the loop-design skill).** Deliberately decided one short of the attempt cap rather than held for a third proposal: this is a naming rule, not a judgment call awaiting authority, and `domains/loop-design.md` "A proposal deferred to dodge the attempt cap is hiding a question someone could just measure" says to settle those rather than let them degrade the loop while they wait. `notes.dirty_repos` keys are now `<repo-dir-name>@<machineId>` with an explicit `path` on every entry; a key lacking `@<machineId>` is treated as a cache MISS and that repo's `unchanged_runs` re-baselines to 0.

### adjustment-field-must-be-an-array
first_proposed 2026-09-06, times_proposed 1.
**LANDED 2026-09-06 (human ruling on the protocol collision run 36 escalated; applied via the loop-design skill).** Step 3 asked for ONE structured adjustment while `count-reconfirmation-as-reproposal` REQUIRES a run that relied on an outstanding adjustment to re-emit it - a run doing both had two entries and one slot. Run 36's `notes.adjustment_new` workaround would have made any future sweep under-count exactly the items the attempt cap exists to escalate. `notes.adjustment` is now always an ARRAY. `runs.jsonl` is append-only so the 31 historical object-shaped lines stay as they are; `loops/README.md` carries a required reader-normalization snippet covering object / array / absent / run-36's `adjustment_new`, which is now a frozen artifact writers must never produce again. "One adjustment per run" still means one NEW one.

## Ledger standing history (superseded, 2026-08-28 through 2026-09-06)

**Ledger standing UPDATED 2026-09-06 (run 36): 39 rows - 35 LANDED, 2 CLOSED-MOOT, 2 OUTSTANDING (`dirty-repo-cache-key-is-ambiguous-across-machines` `times_proposed: 2`; `record-step-5-commit-push-result-in-notes` `times_proposed: 1`, new this run), 0 declined, 0 held, 0 ESCALATED.**
**PROTOCOL COLLISION, needs a human ruling at retrospective 5:** step 3 says to record "step 4's ONE adjustment" as the structured `notes.adjustment`, while `count-reconfirmation-as-reproposal` says a run that relies on an outstanding adjustment MUST re-emit that id as its structured `notes.adjustment`. Both bound run 36. It resolved the clash by putting the mandatory re-proposal in `notes.adjustment` and the genuinely new proposal in a new `notes.adjustment_new` field, and by writing both ledger rows here so neither counter is lost. That is a workaround, not a rule - a future R1 sweeping `runs.jsonl` for adjustment ids must read `adjustment_new` as well as `adjustment`, or it will under-count. The clean fix is to let `notes.adjustment` be an array; that is a LOOP.md change and this loop does not make its own. **RESOLVED 2026-09-06 by `adjustment-field-must-be-an-array`, above.**

Prior standing (2026-09-03, run 35): 38 rows - 35 LANDED, 2 CLOSED-MOOT, 1 OUTSTANDING (`dirty-repo-cache-key-is-ambiguous-across-machines`, `times_proposed: 1`, new this run), 0 declined, 0 held, 0 ESCALATED. The attempt-cap escalation opened at run 34 closed in one cycle on 2026-09-02, so this run opens with a clean ledger and adds exactly one new row.

Prior standing (2026-09-02, post-run-34 human decision): 37 rows - 35 LANDED, 2 CLOSED-MOOT, 0 OUTSTANDING, 0 declined, 0 held, 0 ESCALATED. `stale-lock-sweep-independent-of-noise-graduation` was APPROVED and applied the same day the cap fired, closing the loop's first-ever attempt-cap escalation in one cycle. The cap did exactly what it exists for: it converted a suggestion the runs kept quietly working around into a decision someone had to make.

Prior standing (2026-09-02, run 34): 37 rows - 34 LANDED, 2 CLOSED-MOOT, 0 OUTSTANDING, 0 declined, 0 held, 1 ESCALATED AT ATTEMPT CAP (`stale-lock-sweep-independent-of-noise-graduation`, `times_proposed: 3`, first_proposed 2026-08-30, awaiting a human decision - see High Priority). This is the first time the attempt cap has ever fired; `count-reconfirmation-as-reproposal` (landed 2026-08-28) is what made it able to.

Prior standing (2026-09-01, run 33): 37 rows - 34 LANDED, 2 CLOSED-MOOT, 1 OUTSTANDING (`times_proposed: 2`), 0 declined, 0 held, 0 escalated at attempt-cap.

Prior standing (2026-08-30, run 32): 37 rows - 34 LANDED, 2 CLOSED-MOOT, 1 OUTSTANDING, 0 declined, 0 held, 0 escalated at attempt-cap. `stale-lock-sweep-independent-of-noise-graduation` is new this run (`times_proposed: 1`), added directly to the ledger so a future R1 does not have to reconstruct it from `runs.jsonl` (closing the same accounting-hole pattern flagged twice before).

Prior standing (2026-08-29, post-run-31 human decision pass): 36 rows - 34 LANDED, 2 CLOSED-MOOT, 0 OUTSTANDING, 0 declined, 0 held, 0 escalated at attempt-cap. Both items run 31 raised were decided and applied the same day: `normalize-machine-label-in-run-notes` (LOOP.md, via loop-design) and `rotate-state-md-past-50kb` (this file, via log-archivist).

**ORPHAN-ID SWEEP RUN 2026-08-29 - RESULT: 0 orphans.** The standing note asked R1 at retrospective 5 to sweep `runs.jsonl` for adjustment ids with no ledger row rather than trusting this table. That sweep was run early, on all 43 lines (1 unparseable - the known-bad line 27 - skipped tolerantly): 20 distinct adjustment ids appear in `runs.jsonl` and every one has a ledger row. The 16 ledger rows that never appear in `runs.jsonl` are the rows seeded 2026-08-06 from the prose critiques of runs 1-10, which predate the structured `notes.adjustment` field - expected, not orphans. The accounting hole that produced three missing rows is closed as of now; R1 should still re-run the sweep rather than trust this result, but it starts from a clean table. The 2026-08-28 "fully cleared" standing held for exactly one run. Note that `rotate-state-md-past-50kb` was proposed on 2026-08-28 and had NO ledger row until run 31 added one - the third instance of the same accounting hole (after `retro-reconcile-adjustment-ledger`), so R1 at retrospective 5 should sweep `runs.jsonl` for adjustment ids with no ledger row rather than trusting this table's completeness.

Prior standing (2026-08-28, retrospective 4 + human decision pass): 34 rows - 32 LANDED, 2 CLOSED-MOOT, 0 outstanding, 0 declined, 0 held, 0 escalated at attempt-cap. All 11 retrospective-4 proposals were decided by the human in one pass on 2026-08-28: 8 landed as LOOP.md edits (proposals 1-6, 8, 11), 1 closed as moot (7, plus the held row it supersedes), and 2 were accept-as-reported with no LOOP.md change (9 stay-L1, 10 watch-only). The 5 items that could not escalate because they all read `times_proposed: 1` are now moot - all five are decided - and `count-reconfirmation-as-reproposal` closes the accounting hole so a future backlog CAN reach the cap. Prior standing, for the record: 24 of 31 landed, 1 declined, 1 held, 5 awaiting decision.
