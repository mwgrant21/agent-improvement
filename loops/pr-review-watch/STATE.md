---
loop: pr-review-watch
level: 1
paused: false
attempt_cap: 3
budget: soft
last_run: 2026-09-10
runs_since_retro: 2
constrained_scopes: []
---
## State Ownership
<!-- One row per category of state this loop retains anywhere. See
     loops/README.md "State ownership ledger". -->
| Category | Location | Cap / rotation policy |
|---|---|---|
| runs.jsonl | loops/pr-review-watch/runs.jsonl | Append-only, but written ONLY when the loop actually reports findings or performs a SessionStart check - never per background poll. At a realistic 1-3 open PRs that is a few lines a day, not one per 10 minutes. Rotate via log-archivist past 500 lines. |
| Seen-review cursor | loops/pr-review-watch/cursor.local.json (**gitignored, machine-local**) | One entry per open PR, `{repo, pr, last_review_id, last_comment_at, polls_since_report}`. Entries for closed/merged PRs are pruned on every SessionStart check, so it is bounded by open-PR count (~5). |
| High Priority | STATE.md body | Small by construction - a reported batch moves to Resolved once the human acts or explicitly dismisses it. |
| Watch List | STATE.md body | Bounded by open-PR count; an entry is pruned when its PR closes. |
| Human Decisions | STATE.md body | Append-only; retired decisions kept so a future run cannot misread absence as loss. Same log-archivist trigger as other loops. |
| Recent Noise | STATE.md body | Cleared as items are `[FP]`-marked or decided; self-bounding. |

### Why the cursor is machine-local, and not in this file

`~/agent-improvement` is shared with `daily-triage` and `agent-learn`, and
`domains/loop-design.md` records the consequence: *"When two loops share one
git-backed store, neither may end a pass with a dirty tree"* - uncommitted dirt
breaks the other loops' opening `git pull --rebase`. This loop polls on a
~10-minute cadence, so a cursor written into a tracked file would generate
near-continuous dirt and conflicts, and would be the single worst offender
against a rule this store has already been burned by (run 35 left the store
dirty for 3 days).

`local-state.json` at the store root is the existing precedent for
machine-local state. Splitting by write frequency keeps the convention intact:
one STATE.md per loop for the human/decision layer, a gitignored cursor for the
high-frequency machine layer.

It also gives the behaviour we want across machines: home-matt and work-it keep
independent cursors, so **each terminal reports to its own operator** rather
than one machine's read marking the other's as seen.

## Constrained Scopes
<!-- Human-added only (Intervention ladder step 2). Empty by default. -->

## High Priority (waiting on human)

Carried from the 2026-09-10 retrospective. Both were proposed and DECLINED this
round - recorded here so a later run does not rediscover them as if they were new.

- **R3: `check.mjs` cannot see a Codex CLEAN verdict.** It polls
  `/pulls/{n}/reviews` and `/pulls/{n}/comments`; a clean Codex result arrives as
  an `/issues/{n}/comments` entry with a `Reviewed commit:` SHA. LOOP.md step 3
  names this case explicitly, and `domains/loop-design.md` carries the general
  lesson, but the script has never implemented either. Consequence: a clean
  verdict and a job still running are indistinguishable to this loop.
- **R5: the attempt cap is decorative for adjustments.** The stale-Watch-List
  item was re-proposed across 6 consecutive runs against `attempt_cap: 3` and was
  never escalated here. Nothing in step 5 requires a runner to count prior
  occurrences of an adjustment, so the cap has no mechanism behind it.

## Watch List

_(empty - no open PRs authored by mwgrant21 as of 2026-09-10)_

### Closed since last report

- **Aether-OS#75 - Local Windows packaging (electron-builder + NSIS).** MERGED
  2026-09-09T15:43:14Z. The two Codex threads (`build/installer.nsh:14` P1,
  `package.json:19` P2) were never re-reviewed by Codex, so they were open at
  merge time - but both fixes had been landed in `badd161` and verified
  against the working tree by hand on 2026-09-08. Recording this because the
  *shape* is the 2026-09-06 incident (merged with unresolved bot threads);
  the difference is that the findings were verified remediated first rather
  than unread. No action outstanding.

## Recent Noise (ignored this run)
<!-- Mark an item [FP] if it was a false positive; the loop counts these next run -->

- **[FP] 2026-09-06 — Aether-OS#50, `providers.live.test.ts:176`, author `mwgrant21`.**
  Reported as new review activity; it was *our own reply* on a Codex review
  thread ("Fixed in 5fba9d8…"). LOOP.md rule 3 excludes owner comments that
  start with `@codex review`, which does not cover a reply we wrote into a
  thread. Proposed refinement for the retrospective: exclude owner-authored
  comments from findings outright — a comment we wrote is never feedback *to*
  us. Not applied here; this loop never edits its own LOOP.md.

- **[FP] 2026-09-07 (x5) — Aether-OS#62, #64, #68.** The same pattern as the
  2026-09-06 entry above, five more times in one session, on three PRs. Two
  distinct shapes, both non-findings:
  1. **Our own replies.** Every time we answered a Codex thread ("Agreed and
     fixed in <sha>…"), the next poll reported those replies as new review
     activity.
  2. **Findings already fixed.** A Codex P2 was reported on a poll that ran
     after we had already pushed the fix, replied, and resolved the thread.
  Evidence for the retrospective, strengthening the proposed refinement above:
  (a) exclude owner-authored comments from findings outright, and (b) skip a
  thread whose `isResolved` is true, since a resolved thread has been decided
  by definition. On an actively-iterated PR the loop currently fires roughly
  once per review round, which is exactly when its signal is least useful.
  Not applied here; this loop never edits its own LOOP.md.

## Human Decisions (overrides the loop must respect)

- **2026-09-06, at creation: this loop must never trigger a review.** Posting
  `@codex review` spends money and is therefore a consequential operation, not
  a read. It is out of scope at L1 and stays out until there is an explicit
  policy gate for it (see LOOP.md, "Policy gate"). The loop reports what has
  landed; the human decides whether to ask for more.

## Resolved since last run

- **2026-09-08 — Aether-OS#74 merged** (`07f9639`, squash). All 4 Codex threads
  resolved, 10/10 checks green. Pruned from the cursor this run.
