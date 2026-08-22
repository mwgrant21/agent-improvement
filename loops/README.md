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
| constrained_scopes | list of `{scope, reason, since, reconsider}` objects - sources/finding-types currently narrowed without pausing the whole loop. Empty list by default. See Intervention ladder. |

## runs.jsonl line schema

```json
{"ts":"ISO-8601","session_id":"...","level":1,
 "type":"run|retrospective|promotion|demotion",
 "findings":0,"actions":0,"escalations":0,"false_positives":0,
 "duration_s":0,"critique":"one-line self-critique",
 "notes":{}}
```

`notes` is an optional object for per-run metrics that later runs use as
baselines (e.g. daily-triage records `output_tokens_today` and
`cache_hit_rate` so its 2x-median spend flag has history to compare against;
it also records a `branch_tips` map of
`{repo: {branch: {sha, author_date, ahead_by, behind_by}}}` so the next run can
skip re-fetching commit dates for branches whose tip SHA hasn't moved). `sha` is
the full 40-char SHA; `ahead_by`/`behind_by` come from one compare call and are
always refreshed together, since both go stale when the DEFAULT branch moves
even if the branch itself has not.

Append-only. Never rewrite or delete lines.

## State ownership ledger (body layer)

Every category of state a loop retains anywhere - not just STATE.md
frontmatter - gets one row in a `## State Ownership` section in STATE.md's
body: the category, where it lives, and its cap (a number, or an explicit
rotation/archival policy). No retained-state category ships without one -
"unbounded, no policy" is not a valid row.

Adapted from lidge-jun/opencodex's "bounded memory ownership" convention
(36 categories of process-retained state, each with a declared hard cap;
evaluated 2026-08-21/22, github.com/lidge-jun/opencodex). Sharper than this
store's prior default of noticing bloat reactively - e.g. `log-archivist`
compressing `aether-os/PROGRESS.md` only after it reached 206KB. Declaring
the cap up front doesn't prevent growth, but it means a loop's own
retrospective (or a human skimming STATE.md) can see which sections are
expected to keep growing and by what policy, instead of discovering it once
the file is already unwieldy.

Categories to ledger typically include: `runs.jsonl` growth, `notes.*`
per-run metrics objects, `constrained_scopes`, the Adjustment ledger (if
present), Human Decisions, Watch List, and any cache/map a loop maintains
across runs. Sections a loop already prunes each run (e.g. "Resolved since
last run") are self-bounding and get a row saying so rather than a number.

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

## Intervention ladder

Per-scope escalation, ORTHOGONAL to the L1/L2/L3 autonomy level above - a
loop can be constrained without being demoted, and demoted without anything
being constrained. Adapted from munder-difflin's steer -> constrain -> stop
model (evaluated 2026-08-15/16, github.com/chaitanyagiri/munder-difflin);
"escalate" below is the closest analog to their "steer" (a course-correction
that does not restrict scope), and "constrain"/"stop" map directly.

1. **Escalate** (existing) - an item hits `attempt_cap` (fix attempts at
   L2+, or times-proposed for an L1 adjustment/finding) -> surfaced to a
   human for a decision. No loop behavior changes automatically; the loop
   keeps running exactly as documented.
2. **Constrain** (new) - a human narrows a specific noisy or drifting
   SOURCE or finding type via a `constrained_scopes` entry in STATE.md
   (`{scope, reason, since, reconsider}`) - e.g. "cap this source's findings
   at Watch List, never High Priority" or "skip this specific check
   entirely". The rest of the loop keeps running unaffected. This is a
   human-added/removed entry, not something the loop sets on itself;
   reconsidered at the loop's next retrospective (Step R2), not automatic.
3. **Stop** (existing) - `paused: true`, the whole loop halts before any
   work, every runner checks this first. Reserved for loop-wide problems
   (budget breach, runaway behavior) - not for a single noisy source, which
   `constrain` handles without taking the whole loop offline.

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
