---
name: loop-design
description: Use when creating OR modifying any recurring loop - a scheduled
  agent, /loop task, cron job, or hook-driven automation. Enforces the loop
  conventions in ~/agent-improvement/loops/README.md as required declarations
  and scaffolds the loop's state files. Also used to apply approved
  retrospective refinements to an existing loop.
---

# loop-design

Gate for creating or modifying recurring loops. A loop that does not pass this
gate does not get scheduled.

## Before designing

1. Read `~/agent-improvement/loops/README.md` (the convention: state schema,
   run-log schema, graduation rules).
2. Read `~/agent-improvement/domains/loop-design.md` and honor every lesson.
3. If modifying an existing loop, read its `LOOP.md`, `STATE.md`, and the tail
   of its `runs.jsonl` first.
4. When defining or reviewing a loop's per-source failure handling, check
   loops/README.md's `## Operational failure ladder` - a menu (not a
   required declaration) for handling a source/tool ITSELF failing, distinct
   from the Intervention ladder's finding-quality escalation.

## Required declarations (creation)

Refuse to scaffold until ALL are explicit:

- **Name** - kebab-case, becomes `loops/<name>/`.
- **Trigger** - SessionStart hook / cron / scheduled agent / manual /loop.
- **Level** - ALWAYS 1 at creation. Do not accept a higher starting level.
- **Budget** - `soft` or a token cap.
- **Attempt cap** - default 3.
- **Sources/scopes** - what it reads; external connectors start read-only.
- **L1 boundary** - what "report-only" means for this loop, stated in LOOP.md.
- **Verifier plan** - required before any future L2 promotion (who verifies,
  default stance REJECT). Recorded in LOOP.md even while the loop is L1.
- **Kill switch acknowledgment** - the runner must check `paused` first.
- **Policy gate** (only if the loop can spend money, merge, deploy, or
  delete) - a mandatory permit/block/escalate evaluation step before the
  consequential op, default-deny on evaluation failure. A config flag the
  op merely consults by convention does not satisfy this - see
  domains/loop-design.md "Formal policy gates, not config convention".
- **State ownership ledger** - every category of state this loop will
  retain anywhere (STATE.md body sections, `runs.jsonl` growth, `notes.*`
  objects, caches/maps) gets one row in STATE.md's `## State Ownership`
  section: category, where it lives, and a declared cap or explicit
  rotation policy. "Unbounded, no policy" is not a valid row - see
  loops/README.md "State ownership ledger".

## Scaffolding (creation)

1. Create `loops/<name>/STATE.md` from `loops/_templates/STATE.md.template`
   (replace `{{LOOP_NAME}}`), filling in `## State Ownership` with every
   category this loop will retain.
2. Create `loops/<name>/LOOP.md` - the run protocol: sources, per-run steps,
   state-update rules, run-log line, critique, retrospective rule, L1 boundary.
3. Create empty `loops/<name>/runs.jsonl`.
4. Add a row to the Registered loops table in `loops/README.md`.
5. Commit + push per the store's git discipline.

## Modification (incl. approved retrospective refinements)

- Apply only human-approved changes. Never let a loop edit its own LOOP.md.
- Re-check the changed design against domains/loop-design.md lessons.
- Level changes: promotion requires the evidence gate in loops/README.md and
  explicit human approval; append a promotion/demotion event to runs.jsonl.
- Commit with a message naming the loop and the refinement.

## Worked example

Required declarations for a hypothetical weekly repo-hygiene digest loop:

- **Name:** `repo-hygiene-digest`
- **Trigger:** scheduled agent, weekly (Monday 08:00).
- **Level:** 1.
- **Budget:** soft - no hard token cap yet, revisit after a few runs.
- **Attempt cap:** 3.
- **Sources/scopes:** read-only `git log`/`git status` and the GitHub PR
  list across the repos in scope; no write access.
- **L1 boundary:** posts a Slack digest of stale branches, open PRs, and
  TODO drift - never deletes branches, closes PRs, or pushes commits.
- **Verifier plan:** Matt spot-checks the digest against `git branch -a`
  weekly; default stance REJECT until a run of clean digests accumulates.
- **Kill switch acknowledgment:** runner checks `STATE.md`'s `paused` flag
  before every run and exits if true.
- **Policy gate:** not applicable - this loop only reads and posts a
  summary; it never spends money, merges, deploys, or deletes.
- **State ownership ledger** (STATE.md `## State Ownership`):

  | Category | Where it lives | Cap/rotation |
  |---|---|---|
  | Last-run digest text | STATE.md body | overwritten each run |
  | Run history | runs.jsonl | rotate after 500 lines |
  | Seen-branch cache | STATE.md `notes.seenBranches` | capped at 200, oldest evicted |

## Red flags - stop and fix the design

- "Start it at L2, I trust it" -> No. L1 first, always.
- No state file, or state shared with another loop -> one loop, one STATE.md.
- "Keep retrying until it passes" -> attempt cap + escalate.
- Write-scoped connector on day one -> read-only first.
- No run log -> not a loop, just a recurring accident.
- Retained state with no declared cap or rotation policy -> add a
  `## State Ownership` row before scaffolding, not after it grows large
  enough to notice.
