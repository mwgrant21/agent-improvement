---
loop: daily-triage
level: 1
paused: false
attempt_cap: 3
budget: soft
last_run: 2026-09-11
runs_since_retro: 10
constrained_scopes: []
---
## State Ownership
<!-- Retrofitted 2026-08-22 adopting the loop-design "state ownership ledger"
     convention (loops/README.md, stolen from lidge-jun/opencodex during
     evaluate-repo). This file was 134 lines at retrofit time; the rows below
     are the honest current growth pattern, not aspirational caps. -->
| Category | Location | Cap / rotation policy |
|---|---|---|
| runs.jsonl | loops/daily-triage/runs.jsonl | Unbounded, append-only by design - source of truth for retrospectives. No cap; rotate via log-archivist if reads become slow. **Growth rate changed 2026-09-06**: a run now appends TWO lines (its `run` line at step 3, plus a `store-sync` line at step 5), so the file grows roughly twice as fast as runs 1-36 suggest. Line 27 (run 19) is known-malformed and line 39 is blank; both are frozen artifacts, not damage to repair - the log is append-only. |
| Adjustment ledger | STATE.md body | Unbounded rows, one per proposed refinement; landed rows never deleted (re-checked each retrospective per R1). Rotate older LANDED rows to a dated archive via log-archivist if STATE.md exceeds ~50KB. |
| Human Decisions | STATE.md body | Unbounded append-only; retired decisions kept (not deleted) so a future run doesn't misread absence as loss. Same log-archivist rotation trigger as the Adjustment ledger. |
| Watch List | STATE.md body | Bounded by active repo/branch count (~20 currently); an item is pruned to "Resolved since last run" once it closes, so this section self-bounds in practice. |
| High Priority | STATE.md body | Small by construction - an item here is actively awaiting a human decision; moves to Human Decisions or Resolved once decided. |
| Recent Noise / Untriaged noise | STATE.md body | Small, cleared as items get `[FP]`-marked or decided; self-bounding. |
| Resolved since last run | STATE.md body | Pruned every run per existing step-2 convention; prior entries live in git history, not here. |
| STATE.md archives | loops/daily-triage/STATE.archive-YYYY-MM-DD.md | One new dated file per log-archivist rotation; never rewritten or re-summarised once written. Append-only across files, not within one. First written 2026-08-29; second 2026-09-02 (54,831 -> 48,772 bytes, 10 resolved ledger rows moved). A rotation stub must carry the row's FINAL status - the 2026-09-02 pass first emitted a stub reading "DECLINED" for a row later overturned to LANDED, and two others truncated mid-token; all four were corrected before commit. Sentence-truncation is not a safe stub rule. Third rotation 2026-09-02 to 2026-09-08 (62,850 -> 47,531 bytes): the first two passes rotated ledger rows ONLY and the file re-hit the trigger in 2-6 runs each time, so this pass ALSO archived the three fully-decided Retrospective-outcome sections and the ledger's accumulated "Prior standing" history trail - both pure historical record that no LOOP.md step reads. The two "Note for the next retrospective's step R1" lines (grep gotchas) stayed live since R1 actually consults them. |
| constrained_scopes | STATE.md frontmatter | Empty by default; human-added/removed only (Intervention ladder step 2) - naturally small. |

## Constrained Scopes
<!-- Human-added/removed only (loops/README.md, Intervention ladder step 2).
     Each entry: {scope, reason, since, reconsider}. Empty currently -->
(none currently)

**Retrospective 4 COMPLETED 2026-08-28** (runs 21-30). `runs_since_retro` reset to 0; the next run is a normal run. This retrospective was itself nearly skipped: the home-matt store was 1 commit behind at session start and its STATE.md read `runs_since_retro: 9`, so the run was dispatched as a NORMAL run. Only a `git pull --rebase` before step 0 revealed the true value (10) - see R2 proposal 1. **Run 30 (2026-08-28, work-it)** is the first work-it run since run 24 and immediately tripped over its own stale local store: it read run 24's `runs.jsonl` tail as "previous run", built its whole first analysis on a 7-day-old baseline, and only discovered runs 25-29 (all home-matt) when its step-5 push was rejected. The analysis was redone against the true baseline before landing; the near-miss is this run's adjustment (`pull-store-before-step-0`). Run 30 also executed the `worktree-hygiene-report` and `gitignore-and-auth-drift-check` checks for the first time on work-it (its stale LOOP.md predated them).

## High Priority (waiting on human)
<!-- Run 41 (2026-09-10, work-it) ran as a FORK with a reduced-scope gather pass: GitHub PRs/issues,
     token spend, store health, and a lighter local-hygiene sweep (fetch --prune + unpushed + dirty
     + stale-lock check on 18 standalone repos, no branch_tips ahead/behind API diffing, bare-hub
     worktrees not re-verified). Flagged clearly below rather than silently presented as a full run. -->
- **UPDATED 2026-09-11 (home-matt, dedicated retrospective session) - Retrospective 5's R1 (ledger reconciliation) and R2 (numbered proposals) are DONE; R3 (apply) is deliberately NOT done.** Per explicit instruction this session stopped after proposing - see "## Retrospective 5 - R1/R2 analysis" below for the full ledger standing and numbered proposals. `runs_since_retro` and `last_run` left UNCHANGED at 10 that session. **Run 42 (2026-09-11, home-matt, this run) is a full normal gather run dispatched deliberately instead of R3** - `runs_since_retro` stays at 10 (deliberately not incremented; the counter's meaning under "retrospective analysed but not applied" is ambiguous and this run does not guess), `last_run` moved to 2026-09-11 since a real run did occur. [action: a human reviews the numbered proposals below and directs which to apply; then run R3 (apply + reset counters) as its own step] [machine: any]
- **`agent-improvement/loops/daily-triage/STATE.md` breached the ~50KB rotation trigger, now WORSE.** 60,314 bytes at run 42's start (was 51,121 at run 41, 49,792 at run 40) - 3rd consecutive re-breach, see Retrospective 5 R2 proposal 3. [action: run log-archivist rotation per the `rotate-state-md-past-50kb` adjustment's established pattern] [machine: any]
- **NEW 2026-09-11 (run 42, home-matt, freshly verified) - `EFIPartitionRemediation/feature/efi-diagnostic` crossed the 20-commit escalation floor: now 21 ahead / 0 behind master** (was 19 ahead at run 40, `sha bcd2ecc`, author date 2026-09-10T04:18:05Z). Has an upstream (tracked branch, not a no-upstream case) - clean unmerged work, fast-forward available. Per `flag-branches-20-commits-ahead` this promotes from Watch List to High Priority on volume alone. [action: merge or continue, human call - not urgent risk-wise since it does have an upstream, but crosses the stated threshold] [machine: any]
- **NEW 2026-09-11 (run 42, home-matt, freshly verified) - distributed-file DRIFT on a copy-based hook, escalates per LOOP.md rule.** `check-distributed.sh` reports `hooks/pr-review-onstart.ps1` DRIFT: store 59L/2026-09-11 vs live (`~/.claude/hooks/pr-review-onstart.ps1`) 55L/2026-09-09. Confirmed via `~/.claude/settings.json` line 53 that this machine invokes the hook from the **live copy**, not directly from the store - so this is a real stale-copy risk, not an expected `MISSING LIVE` line, and per LOOP.md escalates straight to High Priority: the live hook may be silently running logic 2 days out of date. [action: sync `~/.claude/hooks/pr-review-onstart.ps1` from the store's current version - diff first per the script's own guidance] [machine: home-matt]
- **RESOLVED (Aether-OS side unchanged, TokenMonitorV2 side now FURTHER RESOLVED) - both run-39 sole-copy escalations were already closed (pushed with upstream) as of run 41.** `Aether-OS/feat/quota-normalized-cost` remains divergent (29a/23b) - see Watch List, unchanged this run (cache hit, SHA unchanged). `TokenMonitorV2/feat/quota-normalized-cost` has now gone a step further than "clean, fast-forward available": it is **fully merged into `origin/main`** (confirmed 2026-09-11 via `git merge-base --is-ancestor ae53189 origin/main` = true, and `git branch --merged origin/main` lists it) - main advanced 52 commits past the home-matt clone's stale local ref, absorbing this branch along the way with no visible PR (likely a direct local merge+push, not through GitHub's PR flow). The linked worktree at `TokenMonitorV2-quota` now sits on a stale, fully-merged branch - see Watch List for the prune recommendation. [action: none required for the exposure itself; see Watch List for the worktree cleanup] [machine: any]
- **`Aether-OS` GitHub churn: 6 open issues from PRs #74/#75 remain unaddressed, freshly reverified 2026-09-11.** Issues #65, #67, #69, #71, #72, #73 (all `atomicWrite`/`hookInstaller`) still open, unchanged set. `#22` (white screen after desktop lock) unchanged, now 30 days idle. `gh search issues`/`gh search prs` fleet-wide sweep this run: 0 open PRs, 7 open issues, neither truncated - no new PR has closed any of these. [action for a human: #65-73 remain unaddressed by anything currently merged or open] [machine: any]
- **`Miriels-publish` (14 commits, no remote at all) - reverified 2026-09-11 from home-matt (its own clone): unchanged.** Untracked-LIVE sole-copy exposure, capped at Watch List by the `flag-branches-20-commits-ahead` volume rule (14 < 20). [machine: home-matt]

## Retrospective outcomes (2026-08-06 through 2026-08-28)

All three retrospectives to date (runs 1-10, 11-20, 21-30) and Retrospective 4's
11 R2 proposals are DECIDED/CLOSED. Full text moved to `STATE.archive-2026-09-08.md`
by the 2026-09-08 log-archivist pass (pure historical record; nothing in LOOP.md's
steps reads these sections). Headline results, for a human skimming: L2 promotion
has never been met (evaluated at 2026-08-06 held-not-promoted, 2026-08-17 NOT MET,
2026-08-28 NOT MET at 16 false positives / 8x the gate); all 11 Retrospective-4
proposals were decided the same day (8 landed, 1 closed-moot, 2 accept-as-reported).
Retrospective 5 triggers at `runs_since_retro >= 10`.

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
6. **Carry forward `record-remote-repo-name-in-local-hygiene`** (OUTSTANDING since
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
| record-remote-repo-name-in-local-hygiene | 2026-09-09 | 1 | **OUTSTANDING - proposed run 40, NOT applied.** Local hygiene reports findings keyed by LOCAL DIRECTORY name; GitHub findings (`branch_tips`, PR/issue search) are keyed by GITHUB REPO name. The two usually match, but this run found a case where they don't: work-it's `Desktop/TriageDesk` clone (`git remote -v` confirms) actually points at `mwgrant21/Jira-Autoticketing`, not a repo named `TriageDesk` at all (no such repo exists on GitHub). A reader trying to correlate a local-hygiene line for `TriageDesk` with the GitHub-side `Jira-Autoticketing` findings for the same underlying repo has no link between them today - the two entries look like they describe different repos. This is a distinct failure class from the existing worktree `.git`-as-file resolution (which already resolves a linked worktree to its parent via the `gitdir:` pointer) - here there is no worktree indirection at all, just a renamed local directory for an ordinary standalone clone. Proposed fix: local hygiene records each repo's resolved `origin` remote (or GitHub `owner/repo`) alongside its local directory name in `notes.dirty_repos` / worktree / branch findings, so a reader can match a local finding to its GitHub counterpart without re-running `git remote -v` by hand. Needs a human decision on where exactly to carry the field (a new top-level `notes.local_repo_remotes` map, or a `remote` key added to each `dirty_repos` entry) before it can land in LOOP.md. |

**Ledger standing UPDATED 2026-09-11 (retrospective 5 application, home-matt): 44 rows - 41 LANDED, 2 CLOSED-MOOT, 1 OUTSTANDING (`record-remote-repo-name-in-local-hygiene` times_proposed:1), 0 declined, 0 held, 0 ESCALATED.** `scope-step5-git-add-to-own-loop-paths` and `detect-content-duplicate-branches` both landed this date.

**Ledger standing UPDATED 2026-09-09 (run 39): 43 rows - 39 LANDED, 2 CLOSED-MOOT, 2 OUTSTANDING (`detect-content-duplicate-branches` times_proposed:1, `scope-step5-git-add-to-own-loop-paths` times_proposed:1), 0 declined, 0 held, 0 ESCALATED.**

**Ledger standing UPDATED 2026-09-08 (interactive session, post run-38 NMMToolkit cleanup): 42 rows - 39 LANDED, 2 CLOSED-MOOT, 1 OUTSTANDING (`detect-content-duplicate-branches`, `times_proposed: 1`), 0 declined, 0 held, 0 ESCALATED.**

**Ledger standing UPDATED 2026-09-08 (human decision, run-38 proposal, applied same day): 41 rows - 39 LANDED, 2 CLOSED-MOOT, 0 OUTSTANDING, 0 declined, 0 held, 0 ESCALATED.** `discover-bare-repo-worktree-hubs` decided and applied same-day rather than waiting for retrospective 5, at the user's explicit direction.

**Ledger standing history 2026-08-28 through 2026-09-06 (10 superseded "Ledger standing"/"Prior standing" entries plus the 2026-08-29 ORPHAN-ID SWEEP note) moved to `STATE.archive-2026-09-08.md` by the 2026-09-08 log-archivist pass - only the current standing line above is needed live.**

Note for the next retrospective's step R1, ADDED 2026-08-28: `count-reconfirmation-as-reproposal` is present in LOOP.md but LINE-WRAPPED (`count-reconfirmation-as-` / `reproposal`), so a naive grep of the bare id reads 0. Same trap as `noise-match-on-finding-identity-not-text`. Grep a distinctive phrase from the rule's body, not the bare id, for these four rows. Also note `verify-repo-can-change-before-noise-graduation` and `per-machine-spend-baseline` verify by id normally.

Note for the next retrospective's step R1: two rows deviate from their original proposal text ON PURPOSE, and each row says how - `branch-staleness-by-commits-ahead` became author-date staleness plus a separate `ahead_by` signal, and `cache-quiet-repo-pr-issue-results` became a fleet-wide search that removes the calls rather than a cache of their answers. Both would read as never-landed under a naive text match. Also: when reading `runs.jsonl` in full for R1, line 27 is invalid JSON - use a tolerant per-line parse that logs-and-skips rather than aborting.

## Watch List
<!-- Run 42 (2026-09-11, home-matt, FULL gather run - first home-matt run since run 29). Machine-tag
     directionality flips: home-matt items below go from frozen to live-verified; work-it-only items
     (NMMToolkit, Aether-OS-livetest, Desktop stray, candidates/work-it-buffer.jsonl, TriageDesk) are
     carried forward FROZEN, not incremented, per freeze-unchanged-runs-when-not-verified. -->
- **NEW 2026-09-11 - `agent-improvement` (home-matt clone, this loop's own store) has a local-only branch `backup/pre-rebase-2026-09-11`, 8 commits, no remote at all.** Contains 8 `pr-review-watch:`-prefixed commits (tip `ba4eb39`), clearly a safety backup made ahead of a rebase during today's earlier session, not daily-triage's own work. Untracked-LIVE by the DEAD/LIVE split (8 commits not on any remote), under the 20-commit escalation floor. [action: human call - delete once the rebase it backed up is confirmed safe, or keep as insurance] [machine: home-matt]
- **`TokenMonitorV2/feat/quota-normalized-cost` - now FULLY MERGED into `origin/main` (0 ahead / 30 behind, was "23 ahead / 0 behind, clean" at run 41).** See High Priority for the merge confirmation. The linked worktree `C:/Users/Matt/projects/TokenMonitorV2-quota` sits on this now-fully-absorbed branch. [action: prune the stale worktree once confirmed nothing local depends on it - a human action, not this loop's] [machine: home-matt]
- **`Aether-OS` (home-matt clone) - primary worktree is checked out on `wip/packaging-installer`, a branch already merged via PR #75 (2026-09-09).** Also has 9 untracked paths (`.archex/ .claude/ .codex/ .cursor/ .omp/ .opencode/ .pi/ .superpowers/ AGENTS.md` - AI-tool config scaffolding, not code) and is 2 commits behind `origin/master` (needs a pull). Linked worktree `aether-os-quota` remains on `feat/quota-normalized-cost` (still divergent 29a/23b, see High Priority - not stale). [action: human call on switching the main worktree back to master and pulling; untracked config dirs are informational only] [machine: home-matt]
- **`Aether-OS/wip/packaging-installer` branch still exists post-merge (PR #75, merged 2026-09-09), 12 ahead / 1 behind master by SHA** - same content-already-landed shape the outstanding `detect-content-duplicate-branches` adjustment was written for (a squash-style merge leaves the source branch's own commits permanently "ahead" by SHA even though the content is in master). Safe-to-delete candidate. [action: delete once confirmed nothing depends on it locally] [machine: home-matt]
- **RESOLVED 2026-09-11 - `.claude` (dotclaude, home-matt) is now CLEAN**, contradicting the old frozen note of "unpushed commits + 64 dirty paths". Freshly verified: 0 unpushed, 0 dirty paths. [machine: home-matt]
- **RESOLVED 2026-09-11 - `EFIPartitionRemediation` (home-matt clone) no longer behind.** Old frozen note said "behind-by-4"; freshly verified master now shows 0 ahead / 0 behind its upstream. [machine: home-matt]
- **NEW 2026-09-11 - `vexjoy-agent` discovered for the first time**, at the unusual path `~/vexjoy-agent` (a directory literally named `~`) - `git -C`/`--git-dir` both choke on the literal tilde (had to `cd` in directly to inspect). Remote is `notque/vexjoy-agent` - an external tracking clone, not this user's own work, same treatment as `.agency-agents`/`claude-power-automate`. Clean, 0 unpushed, 0 stale locks. [action: none] [machine: home-matt]
- **`nmmtools` (home-matt clone) - 3 dirty paths, first live baseline this window**: `M src/core/09-ui-wpf.ps1`, `?? .github/`, `?? LICENSE`. `unchanged_runs` starts at 1 (no prior home-matt path-set to compare against). [machine: home-matt]
- **`mwgrant21` (home-matt clone, the profile repo) - `M README.md`, first live baseline this window.** [machine: home-matt]
- **`TokenMonitor` (v1, FINAL per Human Decision) - `M AGENTS.md`, `?? LICENSE`.** Per the FINAL carve-out ("report only if something genuinely changes"): this is a live baseline reading, not previously recorded with this detail - flagging once for the record, not implying v1 is back in scope. [machine: home-matt]
- `TokenMonitorV2` (home-matt clone) - 52 commits behind `origin/main` (needs a pull; local clone is stale, unrelated to the merged-branch finding above). `Claude-Files` (home-matt clone) - 2 behind `origin/main`. `.agency-agents` - 15 behind `origin/main`, external tracking clone, no action. [machine: home-matt]
- `Aether-OS/feat/quota-normalized-cost` - still DIVERGENT: 29 ahead / 23 behind master (cache hit, SHA unchanged since run 40 - freshly confirmed via SHA comparison, not re-fetched). Per `record-behind-by-alongside-ahead-by`: not a clean fast-forward, human reconciliation only. [machine: any]
- `EFIPartitionRemediation/feature/fleet-migration-runbook` - still suppressed by the 2026-08-21 decision (`0a/1b`, branch cache hit). Not re-raised. [machine: any]
- `Aether-OS/docs/collector-write-path-handoff` - branch tip unchanged since run 40 (cache hit). [machine: any]
- `TokenMonitor/req-12-stryker-ci-gate` - GitHub side unchanged (`1a/0b`, branch cache hit, ~18 days). v1 FINAL, no action. [machine: any]
- `cli-shared-memory.git` bare hub (work-it): 2 linked worktrees flagged stale at run 41 - NOT re-verified this run (a targeted bare-repo discovery pass on home-matt's own scan roots found only `_backup-Miriels-prepurge-20260831-005454`, confirming this hub is work-it-only). [machine: work-it, frozen]
- `gh auth status`: OK, `mwgrant21`, active, scopes gist/read:org/repo/workflow (checked once this run, shared credential). [machine: any]
- **`candidates/home-matt-buffer.jsonl` - 49 pending lines** (last recorded 59 at the 2026-08-27 observation; net change reflects ongoing agent-learn promote passes, not a growth alarm). [machine: home-matt]
- **`runs.jsonl` corpus damage unchanged: line 27 malformed JSON (known since run 19) and a stray blank line.** Not re-verified line-by-line this run. [action for a human: repair line 27, or record it as permanent so R1 stops rediscovering it] [machine: any]
- **FROZEN, NOT VERIFIABLE FROM HOME-MATT THIS RUN (work-it-only, per `freeze-unchanged-runs-when-not-verified`):** `NMMToolkit` master 3 unpushed commits, `Aether-OS-livetest` dirty-WIP (`unchanged_runs:3` at run 41 - stays 3, frozen not incremented), `Desktop` known-ignored stray, `candidates/work-it-buffer.jsonl` (45 pending at run 41), `TriageDesk` local-name/GitHub-name mismatch. [action: none from home-matt; resume next work-it run] [machine: work-it]
## Recent Noise (ignored this run)
<!-- Run 42 (2026-09-11, home-matt, full gather run). Mark an item [FP] if it was a false
     positive. Stale-lock sweep ran on 24 home-matt standalone repos + 1 bare-repo candidate this run, 0 locks found. -->
- **Spend threshold: NOT flagged (home-matt).** 277,878 output tokens today - under the 750,000 absolute floor (2x the 196,791 five-run home-matt median would be 393,582; today doesn't clear either, and the absolute floor alone already fails it).
- **Cache threshold: NOT flagged (home-matt).** 95.2% today - above the 0.90 absolute floor and within 5pp of the 0.97 five-run home-matt median (1.8pp gap); volume (277,878 out) clears the 50,000 floor so this is a real evaluation, not a skip.
- `TokenMonitorV2` `codesign/` / `dist/` / `buildInfo.json` - not re-checked this run (home-matt local-hygiene pass reported 0 dirty paths for `TokenMonitorV2`, consistent with staying ignored). [machine: home-matt]
- Default branches excluded from the staleness rule; all 26 repos' default-branch SHAs recorded in `notes.branch_tips` regardless (2 moved beyond cache this run: `TokenMonitorV2/main` and `EFIPartitionRemediation/feature/efi-diagnostic`'s own SHA moved along with it; most other repos were cache hits).

## Untriaged noise
- **`Aether-OS-livetest` WIP (work-it clone) - crossed to `unchanged_runs:3` at run 41, still awaiting a human decision (commit/discard vs. intentional ongoing WIP).** Not re-verifiable from home-matt this run - frozen at 3, not incremented. [machine: work-it]

## Human Decisions (overrides the loop must respect)
- **2026-09-02: `IT-KB-Pipeline` BUNDLED - both branches, restore-tested. Exposure REDUCED, not closed.** Matt chose the `git bundle` option from run 34's High Priority item. `git bundle create ... --all` from `C:\Users\IT\Desktop\IT-KB-Pipeline` to **`C:\Users\IT\backups\it-kb-pipeline-2026-09-02.bundle`** (85 KB), following the `tarot` precedent's naming and location convention. Contents verified two ways: `git bundle verify` reports okay / complete history, AND a throwaway `git clone --bare` from the bundle reproduced `master` at `d087e711f667cd5482e8d30091ffdf3ed6e9cf07` / 27 commits and `feat/phase1-pipeline` at `efe97271b18d45c430bf5c739b3ee32f6d4fc01d` / 23 commits, `git fsck` clean. The restore test is the evidence; `bundle verify` alone runs against the SOURCE repo and can lean on objects the bundle does not itself carry. The repo had no tags, no stashes and no unreachable commits, so `--all` is the complete picture. Source repo untouched - still no remote, tree still clean.
  **SUPERSEDED THE SAME DAY - 2026-09-02: private remote created, finding CLOSED.** Matt reversed the 2026-08-25 no-remote decision after being shown it and the scan of what the history carries. `mwgrant21/IT-KB-Pipeline`, visibility PRIVATE, both branches pushed and verified at 0 ahead / 0 behind against the remote tips (`master` d087e711, `feat/phase1-pipeline` efe97271). Default branch was corrected to `master` - `gh repo create --source` had set it to `feat/phase1-pipeline`, which would have made every future ahead/behind reading in this loop nonsense. `feat/phase1-pipeline` read 0 ahead / 4 behind master and was **DELETED 2026-09-02, local and remote** (tip was `efe97271`), after three independent confirmations that it was contained in master: `git rev-list feat/phase1-pipeline --not master` returned 0, `git branch --merged master` listed it, and `git merge-base --is-ancestor` passed; the delete used `git branch -d`, which would have refused an unmerged branch, as a fourth. Recoverable from `master` itself, which provably contains every one of its commits, and from the local reflog. NOT from the bundle any more: the bundle was REFRESHED 2026-09-02 after this deletion and no longer carries the `feat/phase1-pipeline` ref - see the bundle note above. Nothing is lost by that, but do not cite the bundle as the recovery path for this branch. `master` intact at 27 commits, `d087e711`, tree clean. **Bundle REFRESHED 2026-09-02** after the `.gitattributes` commit and the branch deletion: same path `C:\Users\IT\backups\it-kb-pipeline-2026-09-02.bundle` (86 KB), now `master` only at `00992f73bb9c8499a12b4ab1ab3d7d4122e71525` / 28 commits, restore-tested the same way (bare clone from the bundle, 28 commits, fsck clean). It SUPERSEDES the 27-commit two-branch version whose SHAs this entry records above; those SHAs describe the FIRST bundle, which no longer exists at that path. The bundle stays as the local second copy. **No OneDrive copy was made** - offered 2026-09-02 and declined: the only OneDrive folder on work-it is the PERSONAL consumer account (`C:\Users\IT\OneDrive`; the NMM business account is signed in but syncs no local folder), and the private GitHub remote already provides the off-machine copy the original finding asked for. Pre-push scan of all 27 commits found no credentials (env-var driven, `.env` gitignored) and no real employee names; it does carry NMM tenant identifiers, which was the substance of the decision Matt reversed. Drop this from High Priority AND from Watch List - it is closed, not downgraded.
  Superseded text follows, kept because the reasoning still applies if the remote is ever removed: **this is NOT resolved, it is DOWNGRADED.** The bundle sits on the SAME DISK as the repo, so it covers tree damage, a bad rebase, or accidental deletion - it does NOT address the original finding, which was that one disk holds the only copy. Report the residual at **Watch List** severity, worded as "bundled 2026-09-02, still no off-disk copy" - not High Priority, and never as resolved. It returns to High Priority if the bundle goes missing, or if the repo gains commits past `d087e711` with no newer bundle beside them. Closing it properly needs a private remote or a copy to removable / another-machine storage; no removable drive was mounted on 2026-09-02 to copy it to. [machine: work-it]
- **2026-09-02: `stale-lock-sweep-independent-of-noise-graduation` APPROVED at the attempt cap.** Decided by Matt on the run-34 digest, the same day the cap fired; applied to LOOP.md via the loop-design skill in that session. The loop did not edit its own LOOP.md. What changed: the stale-`.git`-lock sweep is now a first-class source in step 1, run over EVERY repo local hygiene enumerates, every run - its coverage no longer depends on whether some other finding is a noise-graduation candidate. The step-2 graduation gate stops sweeping and instead READS `notes.stale_locks`; an absent or failed sweep BLOCKS graduation rather than passing it, so a broken sweep can never read as a clean one. Runs must record `notes.stale_locks` AND the swept-repo count, and phrase a clean result as `0 stale locks fleet-wide (N/N repos swept)`. **L1 unchanged: the sweep REPORTS a lock and never deletes one, at any age, on any machine** - clearing a lock stays a human action, because a lock the loop misjudges as stale is a lock a live process is holding. Standing consequence: the 8 home-matt locks in High Priority are still a human remediation, not something the loop will now clear for you.
- **2026-08-28 (post-retrospective-4): ALL 11 R2 proposals DECIDED in one pass.** Decided interactively by Matt, one proposal at a time; applied to LOOP.md via the loop-design skill in the same session. The loop did not edit its own LOOP.md - every edit traces to an explicit approval here.
  - **APPROVED and applied (8 LOOP.md edits):** (1) `pull-store-before-step-0` - step 0 pulls first, staleness caveat on failure. (2) `gate-cache-flag-on-min-volume` **re-opened, overturning the 2026-08-17 decline** - 50,000-output-token floor, reported as `not evaluated`, never silent. (3) `verify-repo-can-change-before-noise-graduation` - stale-lock sweep before noise graduation. (4) `count-reconfirmation-as-reproposal` - the RUN re-emits (chosen over the R1-counts-rows variant), so the increment lands at the point of observation. (5) `fetch-prune-before-unpushed-check`. (6) `detect-no-upstream-local-branches` **with the DEAD/LIVE split mandatory**. (8) `clarify-unchanged-runs-flag-threshold` - pinned to `>=3`, **explicitly sequenced to land AFTER (3)**, since consistency without the can-it-change check only makes a wrong graduation reliable. (11) `per-machine-spend-baseline`.
  - **CLOSED-MOOT:** (7) `close-expand-home-matt-discovery-root` and the held `expand-home-matt-discovery-root` it supersedes. No LOOP.md change. Stop carrying either forward.
  - **ACCEPTED as reported, no LOOP.md change:** (9) **stay at L1**; the promotion gate stays LIVE and is re-evaluated at retrospective 5 - L1 is a gate outcome here, not a settled preference, so do not stop computing it. (10) run-cost baseline recorded watch-only: median 349s -> 870s, triggers are STATE.md >~50KB or median duration >~1,200s.
  - **Known consequence to weigh at retrospective 5:** proposals 5 and 6 add per-repo fetch and branch work across ~24 repos, so duration will RISE this window. Read that against proposal 10's baseline as expected cost, not unexplained drift.
  - **Known caveat carried forward:** the 50,000-token floor in (2) was derived from a window whose medians mixed home-matt and work-it corpora - the very defect (11) fixes. Re-derive it from home-matt-only readings once >=3 same-machine baselines exist.
- **2026-08-25 (post-run-28): run 28's High Priority and dead-weight findings AUTHORIZED and EXECUTED out-of-band.** L1 boundary intact - the loop reported, the human authorized each item explicitly, a separate session acted. Do not re-raise any of these.
  - **`tarot` orphaned pre-rewrite history - BUNDLED, then DELETED.** All 5 branches verified first: `git merge-base` empty against `origin/master` for every one. Bundled to `C:\Users\Matt\backups\tarot-prerewrite-2026-08-25.bundle` (**1.9 GB** - the deck art is in that history), `git bundle verify` reporting "okay / complete history" with all 5 tips matching (`b4b9fc0`, `836d594`, `b0bbc3c`, `4b824c0`, `ef7924c`). Only then deleted with `-D`. **`tarot` is now `master` only, 0 unpushed.** The bundle is the sole surviving copy - if it is ever moved or deleted, the history is gone.
  - **11 `[gone]` dead-weight branches DELETED** across `TarotApp` (5), `TokenMonitor` (4), `aether-os` (1, closing the 2026-08-21 cleanup residue), `nmmtools` (1). Each was re-verified at 0 commits not on a remote immediately before deletion, not trusted from the run-28 digest.
  - **`TarotApp` divergence RESOLVED - merged and pushed (`37a480a..941b7de`).** The `behind 1` was a phantom: remote `37a480a` and local `f84f60a` were DUPLICATE merges of the same two parents with byte-identical trees. **Note for future runs: `ahead/behind` correctly flagged this as not-fast-forwardable, but "behind" did NOT mean "the remote has work you lack" - only a tree comparison settles graph-vs-content divergence.**
  - **ROOT CAUSE FOUND for `TarotApp`'s 5-run-identical dirty paths: a stale, empty `.git/index.lock` dated 2026-08-12** - removed; fleet-wide sweep found no others. The loop had read "unchanged for 5 runs" as idle WIP when the repo was actually unable to commit.
  - **`Miriels-publish` and `tarot` GPU-debug leftovers DISCARDED 2026-08-25 (user-authorized).** Diffs preserved at `C:\Users\Matt\backups\{tarot,Miriels-publish}-gpu-debug-leftovers-2026-08-25.patch`. Both 5-run noise findings genuinely CLOSED.
  - **`tarot/GPU-CRASH-NOTES.md` DELIBERATELY KEPT** - untracked, its own only copy, records the crash occurring on Electron 35.7.5. [action for a human: commit it so the record stops being one `rm` from gone] [machine: home-matt]
  - **FACT CORRECTION for future runs: neither `tarot` nor `Miriels-publish` has moved off Electron 35** (`"electron": "^35.0.0"` at HEAD, no `node_modules`). Do not assume the fleet is uniformly on a current Electron.
- **2026-08-25 (post-run-28): project-status decisions given directly by the user.**
  - **`tarot` - project is COMPLETE**; dirty working-tree paths are deliberate. Do not re-raise the dirty-path finding. (The orphaned-branch question was separate and is now closed above.)
  - **`About-me` - FROZEN by explicit request.** Do not re-raise, never propose committing or discarding `README.md`.
  - **`TokenMonitor` (v1) - FINAL.** v2 is the current line. Report v1 findings only if something genuinely CHANGES there.
  - **`TarotApp` (Android) - NOT NOISE, RECLASSIFIED.** Divergence clause SATISFIED AND RETIRED 2026-08-26 (run 29); the not-noise clause STANDS - the 3 dirty paths remain a real Watch List finding.
  - **`Miriels-publish` - CLOSED 2026-08-26 (run 29) without needing a decision** (leftovers reverted under the authorization above; tree clean).
- **2026-08-22: `TokenMonitorV2` branch disappearance - HELD, pending Monday 2026-08-24.** Superseded by the follow-up below.
- **2026-08-24 FOLLOW-UP: `TokenMonitorV2` confirmed ACTIVE on work-it, not silently trimmed.** Merged cleanly and pushed (`5a76f39`); routine-cleanup explanation confirmed. RESOLVED, do not re-raise. (Run 30's `footerVersion.js` Watch List item is the narrow one-file remainder, not a reopening of this.)
- TokenMonitor PR #1 was the user's own active PR. **MERGED**; override satisfied and retired.
- **2026-08-17: adjustment `gate-cache-flag-on-min-volume` DECLINED.** Treat as closed; do not re-propose absent materially new evidence.
- **2026-08-17: adjustment `distinguish-broken-probe-from-dead-source` APPLIED.** User delegated the accept/decline call to the agent.
- **2026-08-17: remaining 5 OUTSTANDING adjustments decided in one pass.** 4 APPLIED, 1 HELD (`expand-home-matt-discovery-root`).
- **2026-08-21: `Aether-OS` branch cleanup APPROVED and EXECUTED out-of-band.** Baseline zero extra branches. Run 30: GitHub still `master` only; the work-it clone's new DIRTY PATHS are working-tree WIP, not branches - baseline not contradicted.
- **2026-08-21: fleet-wide branch cleanup APPROVED and EXECUTED out-of-band.** Do not re-raise.
- **2026-08-21: `TokenMonitor` `worktree-packages-core-wiring` ABANDONED.** Commit preserved for recovery: `43fde10ab80909e50cf0d6c2768a96d29108ac28`. Do not re-raise.
- **2026-08-21: `EFIPartitionRemediation` `feature/fleet-migration-runbook` MERGED; branch deliberately kept** (checked out in live worktree `~/Desktop/EFI-wt-migration`). Run 30 measures it `0a/0b`, author-date 2026-08-06 (22 days), worktree present and clean - **suppressed by this decision, not re-raised, including by the new worktree-hygiene check.**
- **2026-08-21: `cli-shared-memory` (home-matt) untracked `.claude/` - DECISION IS `commit it`. SATISFIED AND RETIRED 2026-08-25 (run 28).** Recorded rather than deleted.
- **2026-08-21: adjustments `worktree-hygiene-report` and `gitignore-and-auth-drift-check` APPLIED** by direct human request. Run 28 closed both gaps on home-matt; run 30 ran both checks on work-it for the first time (0 stale worktrees, auth OK, drift only in lagging clones).

## Resolved since last run
<!-- Pruned each run per step 2. Prior entries remain in git history. -->
- **STEP 0 AUDIT: PASSED.** The prior session (2026-09-11 retrospective R1/R2) recorded TWO `store-sync` lines (commits `e95e07a` and `cff235f`, both `committed:true, pushed:true`); this run's `git pull --rebase` succeeded cleanly (already up to date) and confirmed both commits as ancestors of HEAD before starting. No escalation needed.
- **GitHub PR/issue sweep, freshly re-run: 0 open PRs, 7 open issues (unchanged set: #73,#72,#71,#69,#67,#65,#22, all `Aether-OS`).** Neither list truncated (limit 100, well under).
- **Branch staleness/ahead-behind FULLY REFRESHED this run** (first full refresh since run 40) across all 26 GitHub repos: 1 stale non-default branch (`EFIPartitionRemediation/feature/fleet-migration-runbook`, suppressed by standing decision), 1 new High Priority escalation (`EFIPartitionRemediation/feature/efi-diagnostic` crossed 20 ahead), 1 branch now fully merged (`TokenMonitorV2/feat/quota-normalized-cost`). 0 probe failures across 26 repos.
- **LOCAL PROBE (home-matt, FULL scope, first full home-matt run since run 29):** 24 standalone repos + 1 bare-repo candidate (`_backup-Miriels-prepurge-20260831-005454`) discovered and swept (fetch --prune, unpushed/no-upstream classification, dirty paths, stale-lock check, worktree hygiene, gitignore drift). 0 stale locks found across all 25. 1 new repo discovered fleet-wide (`vexjoy-agent`, external tracking clone, no action). 2 items RESOLVED (dotclaude now clean; EFIPartitionRemediation home-matt clone no longer behind). 1 new untracked-LIVE local branch found (`agent-improvement backup/pre-rebase-2026-09-11`, 8 commits). See Watch List for full detail.
- SPEND: no flag (277,878 out today, under the 750,000 floor and under 2x the 196,791 five-run home-matt median). CACHE: no flag (95.2%, clears both the 0.90 floor and the median-minus-5pp floor).
- **STATE.md re-breached the ~50KB rotation trigger, now at 60,314+ bytes** - already flagged to High Priority since run 41, now worse (3rd consecutive re-breach - see Retrospective 5 R2 proposal 3).
- **`candidates/home-matt-buffer.jsonl` - 49 pending lines** (informational; last recorded 59 on 2026-08-27).
- **`hooks/pr-review-onstart.ps1` distributed-file DRIFT found and escalated to High Priority** - live copy on this machine is 2 days stale vs the store.
- **Retrospective 5 remains PENDING human decision (R1/R2 done 2026-09-11, R3 not run).** This run is a normal full gather run, not R3; `runs_since_retro` deliberately left at 10 (ambiguous under "analysed but not applied" - not guessed), `last_run` moved to 2026-09-11.
- **No daily-triage write collision this run** - `git add` at step 5 scoped explicitly to `loops/daily-triage/STATE.md loops/daily-triage/runs.jsonl`, per the OUTSTANDING `scope-step5-git-add-to-own-loop-paths` adjustment's established workaround (re-emitted as this run's structured `notes.adjustment`).
