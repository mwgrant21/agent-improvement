---
loop: pr-review-watch
level: 1
paused: false
attempt_cap: 3
budget: soft
last_run: 2026-09-06
runs_since_retro: 1
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

## Watch List

## Recent Noise (ignored this run)
<!-- Mark an item [FP] if it was a false positive; the loop counts these next run -->

- **[FP] 2026-09-06 — Aether-OS#50, `providers.live.test.ts:176`, author `mwgrant21`.**
  Reported as new review activity; it was *our own reply* on a Codex review
  thread ("Fixed in 5fba9d8…"). LOOP.md rule 3 excludes owner comments that
  start with `@codex review`, which does not cover a reply we wrote into a
  thread. Proposed refinement for the retrospective: exclude owner-authored
  comments from findings outright — a comment we wrote is never feedback *to*
  us. Not applied here; this loop never edits its own LOOP.md.

## Human Decisions (overrides the loop must respect)

- **2026-09-06, at creation: this loop must never trigger a review.** Posting
  `@codex review` spends money and is therefore a consequential operation, not
  a read. It is out of scope at L1 and stays out until there is an explicit
  policy gate for it (see LOOP.md, "Policy gate"). The loop reports what has
  landed; the human decides whether to ask for more.

## Resolved since last run
