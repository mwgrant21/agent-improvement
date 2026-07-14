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
