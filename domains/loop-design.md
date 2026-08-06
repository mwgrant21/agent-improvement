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
