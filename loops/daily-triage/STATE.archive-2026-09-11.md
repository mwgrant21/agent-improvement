# daily-triage STATE.md archive - 2026-09-11

Verbatim content compressed out of `STATE.md` on 2026-09-11. Nothing here was
summarised on the way in, and nothing in this file is ever re-compressed.

Contains: the full Retrospective 5 R1/R2 analysis block, including all 44
adjustment-ledger rows with their complete rationales. `STATE.md` keeps a
compact 4-column version of that ledger (id, first_proposed, times_proposed,
status) because `count-reconfirmation-as-reproposal` depends on those fields;
only the prose moved here.

---

## Retrospective 5 - R1/R2 analysis (2026-09-11, PENDING human decision, R3 NOT applied)
<!-- Dedicated retrospective session (home-matt), triggered because runs_since_retro hit 10 at
     run 41 per LOOP.md step 0. Per explicit instruction this session did R1 (reconcile) and R2
     (propose) ONLY and stopped - no LOOP.md edit, no counter reset. Step 0 audit passed first:
     run 41's store-sync line (commit 12965ac, committed:true, pushed:true) is confirmed an
     ancestor of this session's pulled HEAD (3f6d00b) - run 41's step 5 succeeded, no escalation
     needed there. -->

### R1 - ledger reconciliation
Standing UNCHANGED from run 40's count: 44 rows - 39 LANDED, 2 CLOSED-MOOT, 3 OUTSTANDING, 0
declined, 0 held, 0 ESCALATED. None of the 3 OUTSTANDING rows are at `attempt_cap` (3) yet.
Verification method: grepped LOOP.md for each OUTSTANDING id's landing text (absent, confirmed
still-outstanding for all 3) and spot-checked 8 of the trickiest-to-grep LANDED rows named in the
ledger's own "Note for the next retrospective's step R1" hints (`count-reconfirmation-as-
reproposal`, `verify-repo-can-change-before-noise-graduation`, `per-machine-spend-baseline`,
`stale-lock-sweep-independent-of-noise-graduation`, `record-step-5-commit-push-result-in-notes`,
`dirty-repo-cache-key-is-ambiguous-across-machines`, `adjustment-field-must-be-an-array`,
`discover-bare-repo-worktree-hubs`) - all 8 still present, 0 regressions found in that sample.
**Not exhaustively re-diffed: the remaining 31 LANDED rows were not individually re-grepped this
session** (budget); no evidence of regression in any of them, but this is a real coverage gap, not
a clean bill of health for the full 39.
- `scope-step5-git-add-to-own-loop-paths` (first_proposed 2026-09-09/run 39) - still literal
  `add -A` in LOOP.md step 5, still OUTSTANDING. Ledger's recorded `times_proposed` stays at **1**
  this session deliberately, even though this session ALSO worked around it ad hoc (scoped
  `git add` to `loops/daily-triage/` paths only at step 5, same as runs 39-41) - see R2 proposal 1
  below for why the counter is not simply bumped here.
- `detect-content-duplicate-branches` (first_proposed 2026-09-08) - still OUTSTANDING,
  `times_proposed:1`, not triggered this session (no gather ran, no untracked-LIVE branch to test
  it against).
- `record-remote-repo-name-in-local-hygiene` (first_proposed run 40/2026-09-09) - still
  OUTSTANDING, `times_proposed:1`.
- `constrained_scopes` reconsidered per R2 instructions: empty, nothing to lift or keep - no
  change proposed.
- Graduation gate re-evaluated (last 10 run-log lines, ending at run 41): `false_positives` sum =
  **2** (meets `<=2`), but `escalations` is **NOT 0** - run 41 alone currently carries 2 unresolved
  High Priority items (this retrospective's own deferral, and the STATE.md >50KB breach). Gate
  **NOT MET**, same outcome as every prior evaluation (2026-08-06, 2026-08-17, 2026-08-28). Stay at
  L1. The inputs ARE being genuinely measured (false_positives is a real sum of loop-derived +
  human-marked items, not a stuck zero) - the gate is real, just unmet.
- Duration trend (11 runs since retro 4, i.e. runs 31-41): median approx. **840s**, essentially
  flat against retro 4's recorded 870s baseline and well under the 1,200s watch-only trigger. No
  action from this axis.
- STATE.md size trend: 52,506 bytes at this session's start - already past the ~50KB rotation
  trigger again, the 3rd re-breach in under 2 weeks (rotations 2026-08-29, 09-02, 09-08 each
  bought progressively less runway: ~47,000 -> 48,772 -> 47,531 bytes post-rotation, each re-tripped
  within days). See R2 proposal 3.

### R2 - numbered proposals (none applied - human decision required, then apply via loop-design)

1. **Close the gap in `count-reconfirmation-as-reproposal` itself: require prose reliance and the
   structured `notes.adjustment` array to match before a run's step-3 append.** Evidence: run 41's
   own digest text credits `scope-step5-git-add-to-own-loop-paths` ("per the ... adjustment's
   already-established workaround") but its `notes.adjustment` array contains only
   `retrospective-5-deferred-not-silently-skipped` - the reliance was real but never structurally
   recorded, so `times_proposed` for that id is undercounted right now (still reads 1, should
   arguably be higher given at least 4 consecutive ad hoc reliances: runs 39, 40's implicit
   workaround, 41, and this session). This is the identical failure class
   `count-reconfirmation-as-reproposal` was written to close, recurring one layer up: a metric
   that depends on a run remembering to also update the structured field measures the run's
   diligence, not the underlying reality. Add a write-time cross-check: if an outstanding
   adjustment's id appears in a run's prose critique/digest as "relied on"/"workaround", it MUST
   also appear in that run's `notes.adjustment` array, or the round-trip validation
   (`validate-jsonl-line-before-append`) should refuse the line.
2. **[APPLIED 2026-09-11 - human-approved] Land `scope-step5-git-add-to-own-loop-paths` now rather than re-proposing it again.** It has
   been worked around ad hoc for at least 3-4 consecutive sessions (39, 41, this one) with zero
   downside ever observed, it is a one-line low-risk change (replace `add -A` with explicit
   `loops/daily-triage/STATE.md loops/daily-triage/runs.jsonl` paths), and the risk it guards
   against (silently committing a concurrently-running sibling loop's uncommitted writes under
   daily-triage's own commit message) was already observed for real at run 39. No reason to wait
   for the attempt cap on something this cheap and already re-validated repeatedly by direct
   execution.
3. **Re-derive the STATE.md rotation trigger, or widen what log-archivist rotates, since 50KB is
   being re-breached faster than the rotation cadence absorbs it.** Evidence in R1 above: three
   rotations in under two weeks, each buying progressively less headroom, and the file re-crossed
   50KB only ~1 run/3 days after the last one. Either raise the threshold (e.g. 55-60KB) to reduce
   rotation churn, or have log-archivist also compress the per-run regenerating boilerplate
   (machine-tag Watch List lines, "Resolved since last run") rather than only the ledger/history
   sections targeted so far.
4. **Standardize the run-log schema's count fields for the Graduation gate.** Evidence: this
   retrospective had to hand-reconcile an older flat `"escalations":N` field (used through roughly
   run 40) against run 41's newer nested `"findings":{"high_priority":N,"watch_list":N,
   "resolved":N}` shape, which drops `escalations` entirely. A future retrospective without a
   human doing that reconciliation by hand could silently miscompute "0 unresolved escalations."
   Pick one shape and require every run line to carry it.
5. **[APPLIED 2026-09-11 - human-approved, option A] Carry forward `detect-content-duplicate-branches`** (OUTSTANDING since 2026-09-08,
   `times_proposed:1`) - still needs a human scope decision (patch-id match vs.
   message+file-set heuristic vs. bounded commit window) before it can land in LOOP.md.
6. **[APPLIED 2026-09-11 - human-approved] Carry forward `record-remote-repo-name-in-local-hygiene`** (OUTSTANDING since
   2026-09-09/run 40, `times_proposed:1`) - still needs a human decision on where the resolved-
   remote field lives (new top-level `notes.local_repo_remotes` map vs. a `remote` key per
   `dirty_repos` entry).
7. **Promotion gate: report NOT MET, no LOOP.md change proposed.** See R1 above - false_positives
   condition met (2 <= 2) but escalations condition failed (2 currently unresolved). Stay at L1;
   re-evaluate at retrospective 6.
8. **Duration: report watch-only, no action.** Window median ~840s, flat vs. the 870s baseline,
   well under the 1,200s trigger.

 Ledger rows landed before 2026-08-28 keep their id/date/times/status here and point to their full original prose in STATE.archive-2026-08-29.md - no row was removed, so retrospective R1 still sees every landed id and none reads as REGRESSED. -->
<!-- Seeded 2026-08-06 from the prose critiques of runs 1-10, which predate the structured notes.adjustment field. Retrospective step R1 reconciles this every 10th run by grepping LOOP.md and scripts/ - never by trusting this table's own text. Landed rows STAY here and get re-checked; a landed row that goes missing is REGRESSED and escalates. -->
| id | first_proposed | times | status |
|---|---|---|---|
| retro-reconcile-adjustment-ledger | 2026-08-06 | 1 | **LANDED 2026-08-06** (refinement 9). [full text: STATE.archive-2026-08-29.md] |
| batch-branch-commit-date-lookups | 2026-07-14 | 5 | **LANDED 2026-08-03** (branch_tips cache, step 1) [full text: STATE.archive-2026-08-29.md] |
| fix-spend-summary-date-window | 2026-07-17 | 1 | **LANDED 2026-07-22** (scripts/spend-summary.mjs local-day bucketing) [full text: STATE.archive-2026-08-29.md] |
| record-output-token-baseline | 2026-07-17 | 1 | **LANDED 2026-07-18** (step 3 notes) [full text: STATE.archive-2026-08-29.md] |
| flag-branches-20-commits-ahead | 2026-07-18 | 1 | **LANDED 2026-08-06** (step 1, local hygiene - promotes a >20-ahead branch to High Priority). [full text: STATE.archive-2026-08-29.md] |
| branch-staleness-by-commits-ahead | 2026-07-21 | 1 | **LANDED 2026-08-06** (step 1, GitHub - implemented as author-date staleness + ahead_by as a separate signal, NOT as the literal "replace date with... [full text: STATE.archive-2026-08-29.md] |
| verify-loop-own-commit-completed | 2026-07-24 | 1 | **LANDED 2026-08-06** (retro refinement 6, step 5) [full text: STATE.archive-2026-08-29.md] |
| self-confirming-noise-without-fp-mark | 2026-07-24 | 1 | **LANDED 2026-08-06** (retro refinement 1, step 2) [full text: STATE.archive-2026-08-29.md] |
| promote-tokenmonitor-pr1-to-human-decisions | 2026-08-03 | 2 | **LANDED 2026-08-06** (Human Decisions section) [full text: STATE.archive-2026-08-29.md] |
| cache-quiet-repo-pr-issue-results | 2026-08-04 | 1 | **LANDED 2026-08-06** (step 1, GitHub - implemented by ELIMINATING the per-repo sweep via one fleet-wide gh search prs/gh search issues call, NOT by... [full text: STATE.archive-2026-08-29.md] |
| drop-bare-uncommitted-changes-signal | 2026-08-04 | 1 | **LANDED 2026-08-06** (retro refinement 5, step 1) [full text: STATE.archive-2026-08-29.md] |
| machine-tag-watchlist-items | 2026-08-06 | 1 | **LANDED 2026-08-06** (retro refinement 4, step 2) [full text: STATE.archive-2026-08-29.md] |
| exclude-default-branches-from-staleness | 2026-08-06 | 1 | **LANDED 2026-08-06** (step 1, GitHub) [full text: STATE.archive-2026-08-29.md] |
| gate-cache-flag-on-min-volume | 2026-08-07 | 3 | **LANDED 2026-08-28 (human decision, retrospective 4 proposal 2) - this OVERTURNED the 2026-08-17 DECLINE.** Below 50,000 output tokens/day the cache check reports `not evaluated - insufficient volume`, never a silent pass. Caveat: the floor came from a window mixing two machines' corpora - re-check at retrospective 5. [full text: STATE.archive-2026-09-02.md] |
| noise-match-on-finding-identity-not-text | 2026-08-10 | 1 | **LANDED 2026-08-17** [full text: STATE.archive-2026-08-29.md] |
| distinguish-broken-probe-from-dead-source | 2026-08-11 | 3 | **LANDED 2026-08-17** [full text: STATE.archive-2026-08-29.md] |
| specify-branch-tips-cache-key-format | 2026-08-11 | 2 | **LANDED 2026-08-17** [full text: STATE.archive-2026-08-29.md] |
| record-behind-by-alongside-ahead-by | 2026-08-21 | 1 | **LANDED 2026-08-21** (human decision, applied via loop-design skill). [full text: STATE.archive-2026-08-29.md] |
| clarify-repo-discovery-depth-definition | 2026-08-18 | 3 | **LANDED 2026-08-21** (human decision, applied via loop-design skill). [full text: STATE.archive-2026-08-29.md] |
| freeze-unchanged-runs-when-not-verified | 2026-08-21 | 1 | **LANDED 2026-08-21** (human decision, applied via loop-design skill). [full text: STATE.archive-2026-08-29.md] |
| dedupe-same-day-spend-baseline | 2026-08-21 | 1 | **LANDED 2026-08-21** (human decision, applied via loop-design skill). [full text: STATE.archive-2026-08-29.md] |
| dirty-count-blind-to-content-churn | 2026-08-13 | 1 | **LANDED 2026-08-17** [full text: STATE.archive-2026-08-29.md] |
| expand-home-matt-discovery-root | 2026-08-15 | 1 | **CLOSED-MOOT 2026-08-28 (human decision, retrospective 4 proposal 7).** Superseded - the root it proposed adding is already reached. Prior status: **HELD 2026-08-17 (human decision).** Rests on a single home-matt-only observation unverifiable from work-it. Re-propose with home-matt confirmation. |
| validate-jsonl-line-before-append | 2026-08-17 | 1 | **LANDED 2026-08-17** [full text: STATE.archive-2026-08-29.md] |
| worktree-hygiene-report | 2026-08-21 | 1 | **LANDED 2026-08-21** (human decision, applied via loop-design skill, same day as proposed). [full text: STATE.archive-2026-08-29.md] |
| gitignore-and-auth-drift-check | 2026-08-21 | 1 | **LANDED 2026-08-21** (human decision, applied via loop-design skill, same day as proposed). [full text: STATE.archive-2026-08-29.md] |
| close-expand-home-matt-discovery-root | 2026-08-22 | 1 | **CLOSED-MOOT 2026-08-28 (human decision, retrospective 4 proposal 7).** No LOOP.md change; supersedes and closes the held `expand-home-matt-discovery-root`. Stop carrying either forward. [full text: STATE.archive-2026-09-02.md] |
| clarify-unchanged-runs-flag-threshold | 2026-08-24 | 1 | **LANDED 2026-08-28 (human decision, retrospective 4 proposal 8, applied via loop-design skill).** Threshold pinned to `unchanged_runs >= 3`, counting only runs that OBSERVED the item, firing identically for every item at the same value. [full text: STATE.archive-2026-09-02.md] |
| fetch-prune-before-unpushed-check | 2026-08-25 | 1 | **LANDED 2026-08-28 (human decision, retrospective 4 proposal 5, applied via loop-design skill).** `git fetch --prune` now runs BEFORE the unpushed check, so a deleted-upstream branch reads as `[gone]` rather than as unpushed work. [full text: STATE.archive-2026-09-02.md] |
| detect-no-upstream-local-branches | 2026-08-26 | 1 | **LANDED 2026-08-28 (human decision, retrospective 4 proposal 6, applied via loop-design skill).** Landed WITH run 30's amendment: the check splits untracked-DEAD (0 unpushed, cleanup candidate, Watch List at most) from untracked-LIVE (unpushed>0,... [full text: STATE.archive-2026-09-02.md] |
| pull-store-before-step-0 | 2026-08-28 | 1 | **LANDED 2026-08-28 (human decision, retrospective 4 proposal 1, applied via loop-design skill).** Step 0 now begins with `git -C ~/agent-improvement pull --rebase`; on failure the run continues against the local store but MUST state the staleness... [full text: STATE.archive-2026-09-02.md] |
| verify-repo-can-change-before-noise-graduation | 2026-08-28 | 1 | **LANDED 2026-08-28 (human decision, retrospective 4 proposal 3, applied via loop-design skill).** Before graduating an item to loop-derived noise, sweep for a stale `. [full text: STATE.archive-2026-09-02.md] |
| count-reconfirmation-as-reproposal | 2026-08-28 | 1 | **LANDED 2026-08-28 (human decision, retrospective 4 proposal 4, applied via loop-design skill).** A run that re-confirms, executes ad hoc, or relies on an outstanding adjustment MUST re-emit it as its structured `notes. [full text: STATE.archive-2026-09-02.md] |
| per-machine-spend-baseline | 2026-08-28 | 1 | **LANDED 2026-08-28 (human decision, retrospective 4 proposal 11, applied via loop-design skill).** Trailing-5 spend and cache medians are computed ONLY from run-log lines whose `notes. [full text: STATE.archive-2026-09-02.md] |
| rotate-state-md-past-50kb | 2026-08-28 | 2 | **LANDED 2026-08-29, re-executed 2026-09-02 and 2026-09-08 (human decision each time, applied via log-archivist).** STATE.md 54,156 -> ~47,000 (2026-08-29); 54,831 -> 48,772 (2026-09-02); 62,850 -> 47,531 (2026-09-08, scope widened to also archive the Retrospective-outcome sections and the ledger's Prior-standing history trail after two narrow rotations re-hit the trigger in 2-6 runs each). No row ever removed, so none reads as REGRESSED. See State Ownership table and `STATE.archive-*.md` files for what moved each time. |
| normalize-machine-label-in-run-notes | 2026-08-29 | 1 | **LANDED 2026-08-29 (human decision, applied via loop-design skill).** `notes.machine` is the bare machine id; hostname goes in `notes.hostname`. Normalize both sides (trim, lowercase, take the part before the first `/`) before matching a historic line. [full text: STATE.archive-2026-09-02.md] |
| stale-lock-sweep-independent-of-noise-graduation | 2026-08-30 | 3 | **LANDED 2026-09-02** (human APPROVED at attempt cap, applied via the loop-design skill; first adjustment in the loop's history to reach the attempt cap and be resolved by it). [full text: STATE.archive-2026-09-08.md] |
| record-step-5-commit-push-result-in-notes | 2026-09-06 | 1 | **LANDED 2026-09-06** (human APPROVED same day, applied via the loop-design skill; RESHAPED on application into two append-only halves - step 5's `store-sync` line plus step 0's prior-run audit - since a line cannot record its own commit result). [full text: STATE.archive-2026-09-08.md] |
| dirty-repo-cache-key-is-ambiguous-across-machines | 2026-09-03 | 2 | **LANDED 2026-09-06** (human APPROVED at `times_proposed: 2`, applied via the loop-design skill; `notes.dirty_repos` keys now `<repo-dir-name>@<machineId>` with explicit `path`). [full text: STATE.archive-2026-09-08.md] |
| adjustment-field-must-be-an-array | 2026-09-06 | 1 | **LANDED 2026-09-06** (human ruling on the protocol collision run 36 escalated, applied via the loop-design skill; `notes.adjustment` is now always an ARRAY). [full text: STATE.archive-2026-09-08.md] |
| discover-bare-repo-worktree-hubs | 2026-09-08 | 1 | **LANDED 2026-09-08 (human APPROVED same day, applied via the loop-design skill, same day as proposed).** Step 1's local-hygiene discovery (`find <root> -maxdepth 3 -name .git`) structurally cannot see a BARE repo (no `.git` entry - the repo dir IS the git dir). New sub-step runs a separate pass over the same scan roots at the same depth bound, testing each depth-1-2 directory with `git rev-parse --is-bare-repository` (requiring the candidate be its own resolved git-dir via `--absolute-git-dir`, normalized with `cygpath -u`, to avoid false-positiving on a bare repo's own subdirectories - caught and fixed during same-session verification) rather than trusting the `*.git` naming convention alone; each bare repo's worktrees (`git worktree list --porcelain`) are folded into the same discovered-repo set so they get the same dirty/unpushed/worktree-hygiene/gitignore-drift coverage as ordinary repos. No cache, per `domains/loop-design.md`'s uncached-path-first lesson - same reasoning as Worktree hygiene. Evidence: run 38 found `cli-shared-memory.git` this way ad hoc, a bare hub with 2 worktrees invisible to every prior check. |
| scope-step5-git-add-to-own-loop-paths | 2026-09-09 | 2 | **LANDED 2026-09-11** (retrospective 5, proposal 2; human-approved, applied via loop-design). LOOP.md step 5 now stages `loops/daily-triage/STATE.md loops/daily-triage/runs.jsonl` instead of `-A`, and the rule is stated once for every loop in `loops/README.md` -> "Committing from a loop", since pr-review-watch shares the same store and had the same exposure. Worked around by hand in runs 39, 41 and 42 before landing; the hazard itself fired at run 39. Rationale now lives in the protocol, not in this row. |
| detect-content-duplicate-branches | 2026-09-08 | 2 | **LANDED 2026-09-11** (retrospective 5, proposal 5; human-approved option A). LOOP.md now runs `git cherry <upstream> <branch>` before reporting untracked-LIVE and downgrades to content-duplicate DEAD only when every commit prints `-`. Chose git's own patch-id equivalence over a hand-rolled patch-id comparison, a message+file-set heuristic (false-positives on different work touching the same files) or a bounded commit window (unnecessary - `git cherry` walks only the branch's own commits). Fails toward LIVE on any inconclusive check, because a false DEAD silences a real sole-copy exposure while a false LIVE is only noise. Verified on a local reproduction: rev-list says 1 unpushed, `git cherry` says already-upstream. Motivating case `NMMToolkit/fix/dispatch-command-not-found-message` is work-it-only and could not be re-checked from home-matt. **Hardened the same day after a Codex cross-runtime review returned two P2s, both reproduced locally before being acted on: `git cherry` omits merge commits (rev-list counted 2, cherry listed 1), and patch-id ignores whitespace (an addition indented 4 spaces and the same addition indented 8 share a patch-id). Both produce exactly the false DEAD this rule was written to avoid, and the original fail-toward-LIVE guard covered neither. The downgrade now additionally requires 0 unpushed merge commits and a whitespace-sensitive byte-for-byte confirmation; either one unestablished means LIVE/inconclusive. |
| record-remote-repo-name-in-local-hygiene | 2026-09-09 | 2 | **LANDED 2026-09-11** (retrospective 5, proposal 6; human-approved). Local hygiene now records every enumerated repo in a top-level `notes.local_repo_remotes` map rather than a `remote` key per `dirty_repos` entry: the local-dir/GitHub-name mismatch affects dirty-repo, worktree AND branch findings, so a per-entry key fixes one surface of three and duplicates the value, and a top-level map matches the shape `notes.branch_tips` already uses. Keyed `<repo-dir-name>@<machineId>` like `dirty_repos` - a bare name is ambiguous across machines, the exact failure `dirty-repo-cache-key-is-ambiguous-across-machines` closed, and the motivating case (`TriageDesk` -> `mwgrant21/Jira-Autoticketing`) exists only on work-it. `null` is recorded explicitly rather than omitted, since a missing key cannot be told from "not checked" and "no remote" is itself the sole-copy finding. Also added to step 3's carried-notes list, without which a map described in step 1 is never written. |

**Ledger standing UPDATED 2026-09-11 (retrospective 5 application, home-matt): 44 rows - 42 LANDED, 2 CLOSED-MOOT, 0 OUTSTANDING, 0 declined, 0 held, 0 ESCALATED.** Retrospective 5 proposals 1, 2, 4, 5 and 6 all landed this date; 7 and 8 were report-only by design. The ledger has no outstanding adjustments for the first time since it was created.

**Ledger standing UPDATED 2026-09-09 (run 39): 43 rows - 39 LANDED, 2 CLOSED-MOOT, 2 OUTSTANDING (`detect-content-duplicate-branches` times_proposed:1, `scope-step5-git-add-to-own-loop-paths` times_proposed:1), 0 declined, 0 held, 0 ESCALATED.**

**Ledger standing UPDATED 2026-09-08 (interactive session, post run-38 NMMToolkit cleanup): 42 rows - 39 LANDED, 2 CLOSED-MOOT, 1 OUTSTANDING (`detect-content-duplicate-branches`, `times_proposed: 1`), 0 declined, 0 held, 0 ESCALATED.**

**Ledger standing UPDATED 2026-09-08 (human decision, run-38 proposal, applied same day): 41 rows - 39 LANDED, 2 CLOSED-MOOT, 0 OUTSTANDING, 0 declined, 0 held, 0 ESCALATED.** `discover-bare-repo-worktree-hubs` decided and applied same-day rather than waiting for retrospective 5, at the user's explicit direction.

**Ledger standing history 2026-08-28 through 2026-09-06 (10 superseded "Ledger standing"/"Prior standing" entries plus the 2026-08-29 ORPHAN-ID SWEEP note) moved to `STATE.archive-2026-09-08.md` by the 2026-09-08 log-archivist pass - only the current standing line above is needed live.**

Note for the next retrospective's step R1, ADDED 2026-08-28: `count-reconfirmation-as-reproposal` is present in LOOP.md but LINE-WRAPPED (`count-reconfirmation-as-` / `reproposal`), so a naive grep of the bare id reads 0. Same trap as `noise-match-on-finding-identity-not-text`. Grep a distinctive phrase from the rule's body, not the bare id, for these four rows. Also note `verify-repo-can-change-before-noise-graduation` and `per-machine-spend-baseline` verify by id normally.

Note for the next retrospective's step R1: two rows deviate from their original proposal text ON PURPOSE, and each row says how - `branch-staleness-by-commits-ahead` became author-date staleness plus a separate `ahead_by` signal, and `cache-quiet-repo-pr-issue-results` became a fleet-wide search that removes the calls rather than a cache of their answers. Both would read as never-landed under a naive text match. Also: when reading `runs.jsonl` in full for R1, line 27 is invalid JSON - use a tolerant per-line parse that logs-and-skips rather than aborting.

