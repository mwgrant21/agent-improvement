# Loops — Durable State & Run History

One directory per recurring loop (scheduled agent, /loop, cron, hook-driven).
Convention adapted from github.com/cobusgreyling/loop-engineering, fitted to
this store (see docs/specs/2026-07-13-loop-conventions-design.md).

## Layout

```
loops/<loop-name>/
  LOOP.md       # the loop's run protocol (its instructions)
  STATE.md      # frontmatter (machine layer) + body (human layer)
  runs.jsonl    # append-only run history, one JSON object per line
```

## STATE.md frontmatter (machine layer)

| Field | Meaning |
|---|---|
| loop | loop name, matches directory |
| level | 1=report-only, 2=propose (worktree/draft PR, no merge), 3=autonomous within allowlist |
| paused | KILL SWITCH. true -> every runner exits silently before any work |
| attempt_cap | max fix attempts per item before escalating (L2+) |
| budget | `soft` or a token number; enforced at L2+ (breach -> paused: true) |
| last_run | YYYY-MM-DD of last completed run (gates once-per-day loops) |
| runs_since_retro | counter; at >= 10 the next run is a retrospective |

## runs.jsonl line schema

```json
{"ts":"ISO-8601","session_id":"...","level":1,
 "type":"run|retrospective|promotion|demotion",
 "findings":0,"actions":0,"escalations":0,"false_positives":0,
 "duration_s":0,"critique":"one-line self-critique"}
```

Append-only. Never rewrite or delete lines.

## Graduation

- Every loop STARTS at L1. No exceptions.
- Promotion: last 10 runs show <= 2 false positives AND 0 unresolved
  escalations -> the loop PROPOSES promotion in its digest; a human approves;
  bump `level` and append a `promotion` event.
- Demotion (automatic): 3 consecutive runs with an escalation or verifier
  reject -> drop one level, append a `demotion` event with the reason.
  Budget breach at L2+ -> set `paused: true` immediately.
- Humans mark false positives by annotating items in the STATE.md body
  (Recent Noise / Human Decisions); the loop counts them next run.

## Continuous refinement

1. Per run: one-line critique in the run log; the loop honors the Human
   Decisions section next run.
2. Retrospective (runs_since_retro >= 10): read ALL of runs.jsonl + STATE.md,
   analyze trends, output a numbered refinement proposal (LOOP.md edits,
   thresholds, source add/drop, graduation when the gate is met). Human
   approves; apply via the loop-design skill; append a `retrospective`
   event; reset runs_since_retro.
3. Cross-loop: run critiques reach agent-learn via the existing Stop hook;
   promoted lessons land in domains/loop-design.md, which the loop-design
   skill reads whenever any loop is created or modified.

A loop NEVER edits its own LOOP.md autonomously - refinement is
human-approved at every level.

## Registered loops

| Loop | Level | Trigger | Since |
|---|---|---|---|
| daily-triage | 1 | SessionStart hook (first session of the day) | 2026-07-13 |
