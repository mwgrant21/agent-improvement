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

<<<<<<< Updated upstream
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
=======
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
>>>>>>> Stashed changes
