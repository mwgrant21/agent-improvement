# Loop Conventions + Daily Triage — Design Spec

Date: 2026-07-13
Status: Approved
Origin: Evaluation of github.com/cobusgreyling/loop-engineering. Adopting three of
its conventions (durable loop state, graduation levels, anti-pattern checklist)
plus its daily-triage pattern — each adapted to fit the existing agent-improvement
architecture rather than copied verbatim.

## Goals

1. Every recurring loop (scheduled agent, /loop, cron, hook-driven) has durable,
   machine-readable state and an auditable run history.
2. Loops earn autonomy through evidence (graduation), and lose it automatically
   on failure (demotion).
3. Loop design mistakes are gated at creation time by a skill, not remembered
   from a doc.
4. A daily-triage loop runs as the first loop under the convention, and the whole
   system continuously refines itself via three feedback layers.

## Out of scope (deferred follow-ups)

- TokenMonitor "Loops" panel (ingesting runs.jsonl, budget/kill-switch UI).
  runs.jsonl is designed to be parseable by it, but the app is untouched here.
- Any L2+ loop. daily-triage ships at L1 report-only.

## Non-negotiable rules

- Every loop starts at L1. The loop-design skill refuses to scaffold otherwise.
- `paused: true` in a loop's STATE.md frontmatter is the kill switch; every
  runner checks it first and exits silently when set.
- A loop never edits its own instructions autonomously. All self-modification
  (retrospective proposals, graduation) is human-approved, at every level.
- Hook scripts fail open: they never block a session.

## D1 — Loop state convention (`~/agent-improvement/loops/`)

Layout:

```
loops/
  README.md              # the convention + index table of registered loops
  _templates/
    STATE.md.template
  daily-triage/
    STATE.md
    runs.jsonl
```

`STATE.md` = YAML frontmatter (machine layer) + markdown body (human layer):

```markdown
---
loop: daily-triage
level: 1            # 1=report-only, 2=propose, 3=autonomous-in-allowlist
paused: false       # kill switch
attempt_cap: 3
budget: soft        # or a token number; enforced at L2+
last_run: 2026-07-14
runs_since_retro: 0
---
## High Priority (waiting on human)
## Watch List
## Recent Noise (ignored this run)
## Human Decisions (overrides the loop must respect)
```

`runs.jsonl` — one JSON object per line, per run:

```json
{"ts":"...","session_id":"...","level":1,"type":"run|retrospective|promotion|demotion",
 "findings":N,"actions":N,"escalations":N,"false_positives":N,"duration_s":N,
 "critique":"one-line self-critique / adjustment for next run"}
```

Human marks false positives by annotating items in the STATE.md body ("Recent
Noise" / "Human Decisions"); the loop counts them on its next run and records
the count in that run's log line.

## D2 — Graduation model

- L1 report-only → L2 propose (worktree branches / draft PRs, no merge) →
  L3 autonomous within an explicit path allowlist.
- Promotion: when the last 10 runs show ≤2 false positives and 0 unresolved
  escalations, the loop proposes promotion in its digest. Human approves; the
  level bumps in frontmatter and a `promotion` event is appended to runs.jsonl.
- Demotion (automatic): 3 consecutive runs containing an escalation or verifier
  reject → level drops by one, `demotion` event logged with reason. Budget
  breach at L2+ → `paused: true` immediately.

## D3 — loop-design skill + seeded lessons domain

- Master copy: `~/agent-improvement/skills/loop-design/SKILL.md`; installed by
  copy to `~/.claude/skills/loop-design/` (same distribution as agent-learn).
  SETUP.md gains the copy steps for the work machine.
- Triggers: creating OR modifying any recurring loop.
- Enforces as required declarations (no loop scheduled without them):
  level (always 1 at creation), budget, attempt_cap, verifier plan for L2+,
  state files scaffolded from `_templates/`, row added to `loops/README.md`
  index.
- Reads `domains/loop-design.md` before designing, so promoted lessons feed
  back into every loop touched.
- Seed `domains/loop-design.md` with the 10 loop-engineering anti-patterns
  adapted to this environment (maker/checker split, attempt caps, structured
  triage output, L1-before-L2, one state file per loop, read-only connectors
  first, kill switch, no code fixes for flaky tests, allowlist before
  auto-merge, always keep a run log). Add matching LESSONS.md rows.

## D4 — daily-triage loop (L1)

Trigger: SessionStart hook `hooks/daily-triage-onstart.ps1` (pattern copied from
`agent-learn-onstart.ps1`): if STATE.md `last_run < today` and not `paused`,
inject an instruction. Ordering: agent-learn's promote pass remains the first
mandated action; triage runs second.

Execution: the session dispatches a background subagent (so the first session
of the day is not blocked) which:

1. Reads the four sources:
   - GitHub: open issues/PRs, stale branches across mwgrant21 repos via `gh`.
   - Token spend: yesterday's totals from `~/.claude/projects/**/*.jsonl` via a
     new `scripts/spend-summary.mjs` (self-contained; same parsing approach as
     TokenMonitor's shared modules but no dependency on that repo existing —
     must work on the work machine).
   - Agent-improvement health: pending capture-buffer count, days since last
     promoted lesson, git sync status.
   - Local repo hygiene: uncommitted changes / unpushed branches under
     `~/projects/*`.
2. Updates STATE.md (prioritized items, prunes resolved ones, honors "Human
   Decisions"), appends the run line to runs.jsonl, sets `last_run`,
   increments `runs_since_retro`.
3. Returns a prioritized digest, relayed in the terminal.
4. Ends its final message with the post-run critique — the existing Stop hook
   captures that into the agent-learn buffer (no new plumbing).

L1 boundary: reports only. Never files issues, pushes, commits, or fixes.

## D5 — Continuous refinement (three layers)

1. Fast (per run): one-line critique + "Human Decisions" section the loop must
   respect next run. Tunes noise daily.
2. Slow (retrospective): when `runs_since_retro >= 10` (~2 weeks), the run
   becomes a retrospective instead: read ALL of runs.jsonl + STATE.md history,
   analyze trends (recurring noise, repeatedly-ignored items, precision and
   duration trends), and output a numbered refinement proposal — skill-text
   edits, threshold changes, source add/drop, and the graduation proposal when
   the evidence gate is met. Human approves items; approved changes are applied
   via the loop-design skill (re-passing the anti-pattern gates) and logged as
   a `retrospective` event. `runs_since_retro` resets.
3. Lessons lane (cross-loop): critiques flow via Stop hook → agent-learn →
   promoted lessons in `domains/loop-design.md` → read by the loop-design
   skill whenever any loop is created or modified.

## Error handling

- Hook fails open; missing/corrupt STATE.md → skip triage, note once.
- `paused: true` short-circuits before any work.
- Subagent failure → no runs.jsonl line is faked; the failure is reported in
  the digest slot and last_run is NOT advanced (so it retries next session).
- A source being unavailable (e.g. `gh` offline) degrades that section to
  "unavailable" rather than failing the run.

## Verification

- Manual end-to-end triage run before wiring the hook.
- Date gate: back-date `last_run`, confirm single fire per day.
- Kill switch: set `paused: true`, confirm silent skip.
- Hook: confirm session starts normally when store is missing (work machine
  pre-setup state).

## Work-machine rollout

SETUP.md gains: copy `loop-design` skill, copy `daily-triage-onstart.ps1`, add
the SessionStart hook entry. Loop state syncs via the existing repo; runs from
both machines interleave in the same runs.jsonl (append-only, per-line records,
machineId available via session context if ever needed — not required now).
