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

## Scaffolding (creation)

1. Create `loops/<name>/STATE.md` from `loops/_templates/STATE.md.template`
   (replace `{{LOOP_NAME}}`).
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

## Red flags - stop and fix the design

- "Start it at L2, I trust it" -> No. L1 first, always.
- No state file, or state shared with another loop -> one loop, one STATE.md.
- "Keep retrying until it passes" -> attempt cap + escalate.
- Write-scoped connector on day one -> read-only first.
- No run log -> not a loop, just a recurring accident.
