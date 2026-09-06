# pr-review-watch - Run Protocol (L1, report-only)

Surfaces new PR review feedback (Codex, CodeQL/GHAS, humans) on Matt's open
pull requests while a Claude Code terminal is open, on either machine, faster
than email would.

**Why it exists.** On 2026-09-06 a PR was merged while two bot reviews sat
unread on it, because CI was green and nobody read the PR's own comments. One
of those reviews contained a P1 that made an adapter non-functional on the
only platform the app targets. CI status is not review status.

## Declarations

- **Level:** 1 (report-only). No exceptions.
- **Trigger:** SessionStart hook (`hooks/pr-review-onstart.ps1`), plus an
  in-session background watcher the session launches when the hook asks for it.
- **Budget:** soft. Costs ~2 `gh api` calls per open PR per check and **zero
  model tokens while idle** - the background watcher only wakes the session
  when it finds something.
- **Attempt cap:** 3. An item re-reported 3 times without being decided is
  escalated to High Priority in STATE.md rather than re-reported a 4th time.
- **Sources/scopes:** GitHub, **read-only**, via `gh`. Open PRs authored by
  Matt; per-PR `/pulls/{n}/reviews` and `/pulls/{n}/comments`. Nothing else.

## L1 boundary (what report-only means here)

The loop MAY: read PRs, reviews, comments, check runs; write its own
`cursor.local.json`; write `STATE.md` and `runs.jsonl`; report into the session.

The loop MAY NOT, at any level below an explicit promotion: post a comment,
post `@codex review`, reply to a review, resolve a thread, react, push a
commit, merge, close, or reopen. It does not decide whether a finding is
correct - it surfaces it and stops.

## Policy gate

Reading is not a consequential operation, so no gate applies to the loop as it
stands. **Triggering a review is** - `@codex review` spends money - which is
exactly why it is excluded above rather than treated as a convenient
extension. If that is ever wanted, it needs a real permit/block/escalate gate
that defaults to deny on evaluation failure, per `domains/loop-design.md`
"Formal policy gates, not config convention". A boolean in STATE.md does not
satisfy that.

## Verifier plan (required before any L2 promotion)

Matt spot-checks a reported batch against the PR page in GitHub: every finding
reported must exist, and no finding present on the PR may be missing from the
report. Default stance REJECT. Promotion is not on the table until the run log
shows 10 runs with <= 2 false positives and 0 unresolved escalations, per
`loops/README.md`. Note that "L2" here would mean *drafting* responses to
review findings, never posting them.

## Run steps

0. **Kill switch first.** Read `STATE.md`. If `paused: true` -> stop
   immediately, output nothing.
   Do NOT `git pull` the store: this loop runs often and must never touch the
   shared tree's sync state. It reads `STATE.md` as-is; a stale read costs
   nothing because the cursor it actually depends on is machine-local.
1. **Assert the source is reachable before believing a zero.** Run
   `gh auth status`. If it fails, report `gh unavailable on <machineId>` once
   and stop - never report "no new reviews", which is indistinguishable from a
   clean check and is exactly the silent-zero failure
   `domains/loop-design.md`'s "A loop must assert its scan root exists"
   describes. `gh` is confirmed working on home-matt; **unverified on work-it**
   as of 2026-09-06.
2. **Enumerate open PRs** authored by Matt:
   `gh search prs --author @me --state open --json repository,number,title,url`.
   One call, fleet-wide. Prune `cursor.local.json` entries whose PR is no
   longer open.
3. **For each open PR, find what is new** since that PR's cursor entry:
   - `gh api repos/{owner}/{repo}/pulls/{n}/reviews` - a review is new if its
     `id` is greater than `last_review_id`.
   - `gh api repos/{owner}/{repo}/pulls/{n}/comments` - a comment is new if its
     `created_at` is later than `last_comment_at`.

   Three rules that are not obvious, each of which produced a wrong reading by
   hand on 2026-09-06:
   - **A 👀 reaction is not a verdict.** It means the bot picked the job up.
     Only a submitted review, or a 👍 on the triggering comment, is an outcome.
     Treating any reaction as a result reports "done" while it is still
     thinking.
   - **`commit_id` on an inline comment is not proof of a re-review.** GitHub
     re-anchors comments onto newer commits when their lines still resolve, so
     an old finding can appear to be attached to the newest commit. Trust the
     `reviews` records for "what has been reviewed"; use comment `commit_id`
     only for display.
   - **Do not report our own trigger comments back as findings.** A comment
     whose author is the repo owner and whose body starts with `@codex review`
     is a request, not feedback.
4. **Report.** If anything is new, surface it in the session: PR number and
   title, reviewer, count by severity if the body carries P1/P2 badges, and the
   file:line anchors. One line per finding, with the PR URL. Never paraphrase a
   finding into a verdict - the human reads the finding, not this loop's
   opinion of it.
   If nothing is new, say nothing at all in the in-session watcher path; the
   SessionStart path may report a single quiet "no new review activity" line.
5. **Update state.**
   - Always: write `cursor.local.json` (machine-local, gitignored).
   - Only when something was reported, or when this was a SessionStart check:
     append one line to `runs.jsonl` and update `last_run`. **A background poll
     that found nothing is NOT a run line** - logging one per 10-minute tick
     would bury the log and defeat its purpose. Carry the count in
     `notes.polls_since_report` instead, so the quiet time is still visible.
   - `STATE.md` is committed to the shared store on the normal cadence of
     whatever session is running - this loop does not commit on its own, and
     must never leave the store dirty at the end of a session it triggered.

## Run-log line

```json
{"ts":"ISO-8601","session_id":"...","level":1,"type":"run",
 "findings":0,"actions":0,"escalations":0,"false_positives":0,
 "duration_s":0,"critique":"one line",
 "notes":{"machine":"home-matt","trigger":"session-start|watcher",
          "prs_checked":0,"polls_since_report":0,"gh_ok":true,
          "reported":[{"repo":"...","pr":47,"reviewer":"...","review_id":0}]}}
```

`notes.adjustment` is an ARRAY here from the start, per the 2026-09-06 ruling
in `loops/README.md` - this loop never repeats daily-triage's one-slot
collision.

## Continuous refinement

One-line critique per logged run. Retrospective at `runs_since_retro >= 10`,
same as every loop: read the full run log, propose numbered refinements, human
approves, apply via the loop-design skill. **This loop never edits its own
LOOP.md.**

## Known limitation

This catches reviews only while a terminal is open on one of Matt's machines.
Genuinely away-from-desk delivery would need a scheduled runner plus a push
channel; that is deliberately not built, and should not be bolted on without
its own design pass - a background poller that can notify is a different risk
profile from one that can only speak into a session the human is already
looking at.
