# Loop Design

Lessons for designing recurring loops (scheduled agents, /loop, cron,
hook-driven). Seeded 2026-07-13 from loop-engineering's anti-patterns
(github.com/cobusgreyling/loop-engineering, docs/anti-patterns.md), adapted to
this environment. The loop-design skill reads this file before creating or
modifying any loop.

### Never let the maker verify its own work

- At L2+, a separate verifier (different agent/prompt, default stance REJECT)
  must confirm fixes; the implementer never marks its own work done.
- Why: confirmation bias rubber-stamps weak fixes in unattended runs.
- Evidence: imported from loop-engineering anti-pattern #1, 2026-07-13.
- Added: 2026-07-13 (home-matt)

### Hard attempt cap, then escalate

- Cap fix attempts per item (default 3 via STATE.md attempt_cap), then
  escalate with full context in the state file. Never "retry until green".
- Why: infinite fix loops burn tokens and merge wrong fixes.
- Evidence: imported from loop-engineering anti-pattern #2, 2026-07-13.
- Added: 2026-07-13 (home-matt)

### Triage output must be structured, not narrative

- Findings are one-line items under fixed STATE.md sections with an explicit
  suggested action - never paragraphs.
- Why: unparseable state rots; humans stop reading it.
- Evidence: imported from loop-engineering anti-pattern #3, 2026-07-13.
- Added: 2026-07-13 (home-matt)

### L1 report-only before any autonomy

- New loops run report-only until the run log evidences precision (see
  loops/README.md graduation gate). Never auto-fix on day one.
- Why: a loop acting on bad signal compounds errors and comprehension debt.
- Evidence: imported from loop-engineering anti-pattern #4, 2026-07-13.
- Added: 2026-07-13 (home-matt)

### One state file per loop

- Each loop owns its loops/<name>/STATE.md. Never share unstructured state
  between loops.
- Why: shared freeform state rots into conflicting actions and ghost items.
- Evidence: imported from loop-engineering anti-pattern #5, 2026-07-13.
- Added: 2026-07-13 (home-matt)

### Connectors start read-only

- External scopes (gh, MCP connectors) begin read + comment; write scopes are
  earned with graduation.
- Why: the blast radius of a bad triage decision must stay small until trust
  is evidenced.
- Evidence: imported from loop-engineering anti-pattern #6, 2026-07-13.
- Added: 2026-07-13 (home-matt)

### Every loop has a kill switch

- `paused: true` in STATE.md frontmatter; every runner checks it before any
  work and exits silently.
- Why: without a one-field stop, a misbehaving loop runs until someone
  dismantles it.
- Evidence: imported from loop-engineering anti-pattern #7, 2026-07-13.
- Added: 2026-07-13 (home-matt)

### Never fix flaky tests with code changes

- Classify failures first; flakes get quarantine/retry policy or escalation,
  not application-code edits.
- Why: code fixes for flakes mask infra problems and introduce random diffs.
- Evidence: imported from loop-engineering anti-pattern #8, 2026-07-13.
- Added: 2026-07-13 (home-matt)

### Auto-merge only behind an explicit path allowlist

- Even with a passing verifier, merges without human review require an
  allowlist; security/auth/payments/infra paths are always denylisted.
- Why: weak verifiers pass security and business-logic bugs.
- Evidence: imported from loop-engineering anti-pattern #9, 2026-07-13.
- Added: 2026-07-13 (home-matt)

### Always keep a run log

- Append one line per run to runs.jsonl (schema in loops/README.md). State
  shows now; the log explains "why did it do that Tuesday?".
- Why: without history you cannot debug, tune, or grade a loop.
- Evidence: imported from loop-engineering anti-pattern #10, 2026-07-13.
- Added: 2026-07-13 (home-matt)

### A loop must assert its scan root exists - a missing root reports as "nothing found"

- Any loop step that enumerates a directory, glob, or repo list must verify the
  root actually exists on THIS machine and report "source unavailable" when it
  does not. A scan of a path that isn't there returns an empty set, which is
  indistinguishable in the run log from a scan that genuinely found nothing.
- The same applies to state carried between runs: an entry naming a clone that
  exists only on the other machine gets re-checked and re-reported clean forever.
  Tag each such entry with its owning `machineId` so a run on the wrong machine
  skips it explicitly instead of silently passing it.
- Why: these home directories differ (`mwgrant21` / `matthewgr` / `work-it`) and
  so do the repo layouts, so any hardcoded scan root is a machine assumption. The
  loop keeps reporting green while an entire source of findings is dead - the
  same silent-zero failure class as
  [[a-mis-scoped-ignorepatterns-can-silently-zero-out]].
- Evidence: 2026-08-06 session (agent-improvement) - daily-triage's LOOP.md step 1
  scanned `~/projects/*`, which does not exist on `work-it`; without a correction
  it "would have reported local repo hygiene as a dead source." The same run found
  four state entries (tarot, Miriels-publish, nmmtools, TarotApp) pointing at
  clones absent from this machine and carried forward unverified every run.
- Added: 2026-08-06 (work-it)

### When two loops share one git-backed store, neither may end a pass with a dirty tree

- If more than one loop writes to the same repo (e.g. daily-triage and agent-learn
  both writing under `~/agent-improvement`), every pass must finish with
  commit-and-push in the same run. Leaving edits uncommitted is not a neutral
  "I'll finish later" state - it breaks the OTHER loop's opening
  `git pull --rebase` guard, so the second loop fails or stalls on dirt it did
  not create and cannot attribute.
- Why: the loops are independently scheduled and neither can see the other's
  intent. A dirty tree turns a shared store into a lock that nothing releases,
  and the failure lands on whichever loop happens to run next - never on the one
  that caused it. This is the git-level counterpart of
  [[one-state-file-per-loop]].
- Evidence: 2026-08-06 session (agent-improvement) - repeated pauses at "change is
  uncommitted (` M domains/app-dev.md`), want me to commit and push it?" while a
  second loop shared the same repo; noted that one loop leaving dirt "breaks the
  *other* loop's `pull --rebase` guard."
- Added: 2026-08-06 (work-it)

### Measure the uncached path before adding a cache to a loop

- When a loop's per-run cost looks like it needs a cache (a stored SHA, a memoized
  API result, a derived summary), time the uncached path FIRST. If it is already
  fast enough, do not add the cache - a cache in a scheduled loop is a permanent
  staleness liability traded for a speedup you may not need. If you do cache a
  derived value, it is only as fresh as EVERY input it derives from; enumerate the
  inputs explicitly, because the easy-to-miss one (e.g. the default-branch SHA
  behind a "commits ahead" count) is what makes the cached value silently wrong.
- Why: loops run unattended, so a stale cached value is reported as fact for as
  many runs as it takes someone to notice. Unlike an interactive session, there is
  no user in the loop to sanity-check the number. Correctness-per-run beats
  latency-per-run for anything report-shaped; see [[always-keep-a-run-log]].
- Evidence: 2026-08-06 session (agent-improvement) - a caching design for the
  daily-triage PR scan was dropped after the uncached query was measured and
  "returns exactly the two PRs STATE.md lists" fast enough; the same discussion
  identified the default-branch SHA as an input a cached "branch is N commits
  ahead" value would not track.
- Added: 2026-08-06 (work-it)

### Formal policy gates, not config convention

- Before any consequential operation (spend, deploy, merge, delete), evaluate
  it against an explicit permit/block/escalate check as a real gate step -
  not a config flag/boolean the operation merely consults by convention, and
  never a check that fails open on its own I/O errors.
- Why: Aether OS's `modelPolicy.ts` was configured to block Opus calls but a
  Sonnet/Haiku call path it never anticipated slipped through anyway
  (2026-07-31, $24 incident); its spend-ceiling guard also failed open on
  file I/O errors by design. A toggleable convention is not the same
  guarantee as a structurally-enforced gate the operation cannot bypass.
- How to apply: for any loop that can spend money, merge, deploy, or delete,
  design the gate as a mandatory evaluate-then-act step with a default-deny
  (block/escalate) posture on any evaluation failure - not a boolean flag
  that can silently drift out of sync with what the code actually calls, and
  not a check that permits on error.
- Evidence: steal-the-shape from github.com/Mathews-Tom/Enginery's policy-gate
  engine (see enginery-evaluation.md, TokenMonitor project memory) applied to
  a real incident already seen twice in this fleet.
- Added: 2026-08-07 (home-matt)

### Revision-bound evidence and approval supersession

- A verification, approval, or "tests passed" result is only valid for the
  exact revision/diff it was computed against. If the base commit or diff
  changes after approval, treat the prior approval as void - do not carry it
  forward as still-satisfied.
- Why: stale-diff approvals silently going stale is a real failure mode -
  code changes after a human or verifier signs off, and the signoff gets
  treated as still covering the new state.
- How to apply: bind evidence/approval records to a revision digest (commit
  hash, diff hash); before treating a prior approval as satisfied, confirm
  the digest still matches current state, not just that an approval exists.
- Evidence: steal-the-idea from github.com/Mathews-Tom/Enginery's approval
  supersession pattern (see enginery-evaluation.md, TokenMonitor project
  memory).
- Added: 2026-08-07 (home-matt)

### Verify a loop's capture actually captured, not that records accumulated

- A loop that harvests its own inputs must be checked end to end: assert the
  captured records contain usable PAYLOAD, not merely that rows are arriving.
  Where a record only references an artifact by path, verify the path resolves
  at capture time, and re-verify at processing time - the artifact may be
  written somewhere else, or be gone by the time the loop reads it.
- Why: an accumulating buffer reads as a healthy pipeline. Volume is the metric
  most likely to be watched and the one least likely to reveal that every record
  is empty, so the loop reports "N pending" for months while capturing nothing.
- Evidence: 2026-08-12, agent-learn promote pass. 36 of 60 buffered records
  across two sessions carried an empty `summary` and a `transcript_path` that
  resolved to no file, making them unusable; the same session had already been
  dropped for this on the previous pass. The correlation was exact: the one
  session whose cwd was the HOME directory had all 24 summaries, and both
  sessions whose cwd was a project directory had zero - their recorded
  transcript path pointed under the home directory's project folder, where their
  transcripts do not live. Every session doing real work in a project directory
  was being silently discarded.
- See also [[a-probe-that-cannot-distinguish]] and
  [[a-loop-must-assert-its-scan-root-exists]].
- Added: 2026-08-12 (work-it)

### A proposal deferred to dodge the attempt cap is hiding a question someone could just measure

- When a loop keeps declining to re-propose an adjustment specifically to avoid
  tripping `attempt_cap` and forcing an escalation, stop and ask what KIND of
  question it actually is. If it can be settled by running a command - two counts,
  two file listings, a version check - it is not a judgment call awaiting a human,
  and deferral is not caution. Measure it and decide. Reserve the cap-and-escalate
  path for questions that genuinely need a human's preference or authority.
- Why: the attempt cap exists to force a decision, so working around it converts a
  decision-forcing mechanism into an indefinite hold - and the item silently
  degrades the loop the whole time it waits. Worse, an ambiguous rule keeps
  producing DIFFERENT behaviour run to run while it sits undecided, so the loop's
  own output becomes inconsistent without anything saying so.
- Evidence: 2026-08-21 session (daily-triage, work-it) -
  `clarify-repo-discovery-depth-definition` sat 3 days at 2 proposals because runs
  23 and 24 each declined to re-propose it to avoid the cap. The underlying question
  ("is depth measured to `.git` or to the repo directory?") took two `find`
  invocations to settle: 16 repos vs 20, and the two runs had silently used
  different readings. See [[hard-attempt-cap]].
- Added: 2026-08-21 (work-it)

### `unchanged_runs` measures "nothing changed", not "nothing matters" - a blocked target looks identical to an idle one

- A staleness/noise heuristic that counts consecutive runs with an identical observation
  cannot tell "quiet because nobody is working on it" from "CANNOT change because
  something is jammed". Both produce the identical reading, and the second is the one
  that needs a human. Before graduating a repeating observation to noise, check whether
  the target is even capable of changing - for a repo, sweep for a stale `.git/*.lock`;
  more generally, probe the mechanism rather than recounting the observation.
- Corollary: when the blocker is later cleared, the same unchanged reading has changed
  MEANING even though its value is identical. Re-report it as materially changed rather
  than letting the run count keep climbing.
- Why: the heuristic's whole purpose is to suppress noise, so it fails toward silence -
  exactly the direction that hides a stuck target.
- Evidence: daily-triage runs 24-28 (home-matt) classified TarotApp's identical dirty
  path set as idle boilerplate across five runs; a stale `index.lock` (removed
  2026-08-25) had made the repo physically unable to change. Run 31's fleet-wide lock
  sweep found 0 locks, so the same reading now genuinely means idle WIP.
- Added: 2026-08-29 (home-matt)
