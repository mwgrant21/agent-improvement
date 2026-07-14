# Loop Conventions + Daily Triage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add durable loop-state conventions, an evidence-gated graduation model, a loop-design gate skill, and an L1 daily-triage loop to `~/agent-improvement`.

**Architecture:** All artifacts live in the git-synced `~/agent-improvement` store and are distributed to `~/.claude/` by copy (same pattern as agent-learn). Loop state = YAML-frontmatter STATE.md + append-only runs.jsonl. The triage loop is triggered by a SessionStart hook that injects an instruction once per day.

**Tech Stack:** Markdown conventions, PowerShell 5.1-compatible hook script, one Node.js (ESM) script with `node --test` coverage.

**Spec:** `~/agent-improvement/docs/specs/2026-07-13-loop-conventions-design.md`

## Global Constraints

- All repo writes follow the store's git discipline: `git pull --rebase` before, `git add -A && git commit && git push` after. If push fails offline, keep the local commit and continue.
- PowerShell: `Write-Output` only (no Write-Host), UTF-8 without BOM, ASCII-only content, PS 5.1 compatible, never throws out of a hook (`try/catch` + `exit 0`).
- Hook scripts fail open: missing store/files → silent `exit 0`.
- Home dirs differ between machines — scripts resolve the store via `$env:USERPROFILE\agent-improvement`; docs use `~` paths.
- Every loop starts at `level: 1`. `paused: true` is the kill switch and is checked before any work.
- After writing/modifying any `.ps1`, invoke the `ps-script-learner` skill (user's standing rule).
- Working directory for all tasks: `C:\Users\Matt\agent-improvement` (referred to as `$STORE`).

---

### Task 1: Loop state convention (`loops/` + template)

**Files:**
- Create: `loops/README.md`
- Create: `loops/_templates/STATE.md.template`

**Interfaces:**
- Produces: the STATE.md frontmatter schema (`loop`, `level`, `paused`, `attempt_cap`, `budget`, `last_run`, `runs_since_retro`) and the runs.jsonl line schema consumed by Tasks 3, 5, 6.

- [ ] **Step 1: Write `loops/README.md`**

````markdown
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
````

- [ ] **Step 2: Write `loops/_templates/STATE.md.template`**

```markdown
---
loop: {{LOOP_NAME}}
level: 1
paused: false
attempt_cap: 3
budget: soft
last_run: 1970-01-01
runs_since_retro: 0
---
## High Priority (waiting on human)

## Watch List

## Recent Noise (ignored this run)
<!-- Mark an item [FP] if it was a false positive; the loop counts these next run -->

## Human Decisions (overrides the loop must respect)
```

- [ ] **Step 3: Verify frontmatter parses**

Run: `cd $STORE && node -e "const m=require('fs').readFileSync('loops/_templates/STATE.md.template','utf8').match(/^---\r?\n([\s\S]*?)\r?\n---/); if(!m) throw new Error('no frontmatter'); console.log('frontmatter OK:', m[1].split(/\r?\n/).length, 'fields')"`
Expected: `frontmatter OK: 7 fields`

- [ ] **Step 4: Commit**

```bash
cd ~/agent-improvement && git pull --rebase && git add loops/ && git commit -m "Add loop state convention (loops/ layout, STATE.md schema, graduation rules)" && git push
```

---

### Task 2: Seed `domains/loop-design.md` + LESSONS.md rows

**Files:**
- Create: `domains/loop-design.md`
- Modify: `LESSONS.md` (append rows, bump last-updated)

**Interfaces:**
- Produces: `domains/loop-design.md`, read by the loop-design skill (Task 3).

- [ ] **Step 1: Write `domains/loop-design.md`** (10 lessons adapted from loop-engineering's anti-patterns; Evidence cites the import)

```markdown
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
```

- [ ] **Step 2: Append rows to `LESSONS.md`** — set `last-updated: 2026-07-13` and add after the last table row:

```markdown
| loop-design | Never let the maker verify its own work | 2026-07-13 |
| loop-design | Hard attempt cap, then escalate | 2026-07-13 |
| loop-design | Triage output must be structured, not narrative | 2026-07-13 |
| loop-design | L1 report-only before any autonomy | 2026-07-13 |
| loop-design | One state file per loop | 2026-07-13 |
| loop-design | Connectors start read-only | 2026-07-13 |
| loop-design | Every loop has a kill switch | 2026-07-13 |
| loop-design | Never fix flaky tests with code changes | 2026-07-13 |
| loop-design | Auto-merge only behind an explicit path allowlist | 2026-07-13 |
| loop-design | Always keep a run log | 2026-07-13 |
```

- [ ] **Step 3: Verify index and domain agree**

Run: `cd $STORE && node -e "const l=require('fs').readFileSync('LESSONS.md','utf8'),d=require('fs').readFileSync('domains/loop-design.md','utf8'); const rows=(l.match(/\| loop-design \|/g)||[]).length, entries=(d.match(/^### /gm)||[]).length; if(rows!==entries) throw new Error(rows+' rows vs '+entries+' entries'); console.log('OK:', rows, 'lessons')"`
Expected: `OK: 10 lessons`

- [ ] **Step 4: Commit**

```bash
cd ~/agent-improvement && git pull --rebase && git add domains/loop-design.md LESSONS.md && git commit -m "Seed loop-design domain with 10 adapted anti-pattern lessons" && git push
```

---

### Task 3: loop-design skill (master + install)

**Files:**
- Create: `skills/loop-design/SKILL.md` (master)
- Create: `C:\Users\Matt\.claude\skills\loop-design\SKILL.md` (installed copy)

**Interfaces:**
- Consumes: STATE.md template and graduation rules from Task 1; `domains/loop-design.md` from Task 2.
- Produces: the gate every future loop creation/modification goes through (referenced by Task 5's LOOP.md retrospective step).

- [ ] **Step 1: Write `skills/loop-design/SKILL.md`**

```markdown
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
```

- [ ] **Step 2: Install the skill**

Run: `mkdir -p ~/.claude/skills/loop-design && cp ~/agent-improvement/skills/loop-design/SKILL.md ~/.claude/skills/loop-design/SKILL.md && ls ~/.claude/skills/loop-design/`
Expected: `SKILL.md`

- [ ] **Step 3: Commit**

```bash
cd ~/agent-improvement && git pull --rebase && git add skills/loop-design/ && git commit -m "Add loop-design skill (creation/modification gate for recurring loops)" && git push
```

---

### Task 4: `scripts/spend-summary.mjs` (+ test)

**Files:**
- Create: `scripts/spend-summary.mjs`
- Test: `scripts/spend-summary.test.mjs`

**Interfaces:**
- Produces: `summarizeUsage(lines, isoDates)` export and a CLI printing a markdown token summary for yesterday+today. Consumed by Task 5's LOOP.md (triage source #2).

- [ ] **Step 1: Write the failing test `scripts/spend-summary.test.mjs`**

```javascript
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { summarizeUsage } from './spend-summary.mjs';

const line = (id, ts, model, usage) => JSON.stringify({
  type: 'assistant', timestamp: ts,
  message: { id, model, usage },
});

test('sums tokens per model for matching dates only', () => {
  const lines = [
    line('m1', '2026-07-13T08:00:00.000Z', 'claude-fable-5',
      { input_tokens: 10, output_tokens: 100, cache_read_input_tokens: 900, cache_creation_input_tokens: 90 }),
    line('m2', '2026-07-12T08:00:00.000Z', 'claude-fable-5',      // wrong date - ignored
      { input_tokens: 999, output_tokens: 999 }),
    line('m3', '2026-07-13T09:00:00.000Z', 'claude-haiku-4-5',
      { input_tokens: 5, output_tokens: 50, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 }),
  ];
  const s = summarizeUsage(lines, ['2026-07-13']);
  assert.equal(s.byModel['claude-fable-5'].output, 100);
  assert.equal(s.byModel['claude-haiku-4-5'].output, 50);
  assert.equal(s.totals.input, 15);
  assert.equal(s.totals.cacheRead, 900);
  // hit rate = cacheRead / (cacheRead + cacheCreate + input) = 900/1005
  assert.ok(Math.abs(s.cacheHitRate - 900 / 1005) < 1e-9);
});

test('dedups streamed duplicates by message id (last wins)', () => {
  const lines = [
    line('dup', '2026-07-13T08:00:00.000Z', 'claude-fable-5', { input_tokens: 1, output_tokens: 10 }),
    line('dup', '2026-07-13T08:00:01.000Z', 'claude-fable-5', { input_tokens: 1, output_tokens: 25 }),
  ];
  const s = summarizeUsage(lines, ['2026-07-13']);
  assert.equal(s.totals.output, 25);
});

test('tolerates malformed lines and non-assistant records', () => {
  const s = summarizeUsage(['not json', '{"type":"user"}', ''], ['2026-07-13']);
  assert.equal(s.totals.output, 0);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd $STORE && node --test scripts/spend-summary.test.mjs`
Expected: FAIL (`Cannot find module ... spend-summary.mjs`)

- [ ] **Step 3: Write `scripts/spend-summary.mjs`**

```javascript
#!/usr/bin/env node
// Summarize Claude Code token usage from ~/.claude/projects/**/*.jsonl for
// given dates (default: yesterday and today). Self-contained on purpose - no
// dependency on the TokenMonitor repo, must run on any machine with Node.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

export function summarizeUsage(lines, isoDates) {
  const dates = new Set(isoDates);
  const byId = new Map();          // message id -> {model, usage} (last wins)
  let anon = 0;
  for (const raw of lines) {
    let rec;
    try { rec = JSON.parse(raw); } catch { continue; }
    if (rec?.type !== 'assistant' || !rec.message?.usage) continue;
    const day = String(rec.timestamp || '').slice(0, 10);
    if (!dates.has(day)) continue;
    byId.set(rec.message.id ?? `anon-${anon++}`, rec.message);
  }
  const byModel = {}; const totals = { input: 0, output: 0, cacheRead: 0, cacheCreate: 0 };
  for (const msg of byId.values()) {
    const u = msg.usage;
    const m = byModel[msg.model || 'unknown'] ??= { input: 0, output: 0, cacheRead: 0, cacheCreate: 0 };
    m.input += u.input_tokens || 0;            totals.input += u.input_tokens || 0;
    m.output += u.output_tokens || 0;          totals.output += u.output_tokens || 0;
    m.cacheRead += u.cache_read_input_tokens || 0;       totals.cacheRead += u.cache_read_input_tokens || 0;
    m.cacheCreate += u.cache_creation_input_tokens || 0; totals.cacheCreate += u.cache_creation_input_tokens || 0;
  }
  const denom = totals.cacheRead + totals.cacheCreate + totals.input;
  return { byModel, totals, cacheHitRate: denom ? totals.cacheRead / denom : 0 };
}

function* jsonlFiles(dir) {
  let entries = [];
  try { entries = readdirSync(dir, { withFileTypes: true }); } catch { return; }
  for (const e of entries) {
    const p = join(dir, e.name);
    if (e.isDirectory()) yield* jsonlFiles(p);
    else if (e.name.endsWith('.jsonl')) yield p;
  }
}

function isoDay(d) { return d.toISOString().slice(0, 10); }

if (process.argv[1] && import.meta.url.endsWith(process.argv[1].replace(/\\/g, '/').split('/').pop())) {
  const today = new Date();
  const yesterday = new Date(today.getTime() - 86400000);
  const dates = process.argv.slice(2).length ? process.argv.slice(2) : [isoDay(yesterday), isoDay(today)];
  const root = join(homedir(), '.claude', 'projects');
  const cutoff = Date.now() - 3 * 86400000;   // skip files untouched for 3+ days
  const lines = [];
  for (const f of jsonlFiles(root)) {
    try {
      if (statSync(f).mtimeMs < cutoff) continue;
      lines.push(...readFileSync(f, 'utf8').split('\n'));
    } catch { /* unreadable file - skip */ }
  }
  const s = summarizeUsage(lines, dates);
  console.log(`Token usage for ${dates.join(', ')}:`);
  for (const [model, m] of Object.entries(s.byModel)) {
    console.log(`- ${model}: in ${m.input} / out ${m.output} / cacheRead ${m.cacheRead} / cacheCreate ${m.cacheCreate}`);
  }
  console.log(`- TOTAL: in ${s.totals.input} / out ${s.totals.output} / cache hit rate ${(s.cacheHitRate * 100).toFixed(1)}%`);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd $STORE && node --test scripts/spend-summary.test.mjs`
Expected: `pass 3` / `fail 0`

- [ ] **Step 5: Smoke the CLI against real data**

Run: `cd $STORE && node scripts/spend-summary.mjs`
Expected: a `Token usage for <yesterday>, <today>:` block with at least one model row and a TOTAL line (this machine has transcripts).

- [ ] **Step 6: Commit**

```bash
cd ~/agent-improvement && git pull --rebase && git add scripts/spend-summary.mjs scripts/spend-summary.test.mjs && git commit -m "Add spend-summary script for daily-triage token source" && git push
```

---

### Task 5: daily-triage loop instance

**Files:**
- Create: `loops/daily-triage/LOOP.md`
- Create: `loops/daily-triage/STATE.md`
- Create: `loops/daily-triage/runs.jsonl` (empty)

**Interfaces:**
- Consumes: STATE schema (Task 1), spend-summary CLI (Task 4), loop-design skill (Task 3, referenced for retrospectives).
- Produces: `loops/daily-triage/LOOP.md`, the protocol the hook instruction (Task 6) points at.

- [ ] **Step 1: Write `loops/daily-triage/LOOP.md`**

````markdown
# daily-triage - Run Protocol (L1, report-only)

Morning digest of everything needing attention. L1 BOUNDARY: this loop
REPORTS. It never files issues, comments, commits, pushes, or fixes anything.

Verifier plan (pre-declared for future L2): a separate reviewer agent with
default stance REJECT must confirm any proposed fix before it is surfaced;
L2 also requires worktree isolation. Not active at L1.

## Run steps

0. Read `STATE.md`. If `paused: true` -> stop immediately, output nothing.
   If `runs_since_retro >= 10` -> run the Retrospective (below) instead.
1. Gather, tolerating per-source failure (a dead source becomes one
   "unavailable" line, never a failed run):
   - **GitHub**: for each mwgrant21 repo (`gh repo list mwgrant21 --json name`):
     open issues, open PRs and their age, branches with no activity > 14 days.
     Read-only. Command shapes: `gh search issues --owner mwgrant21 --state open`,
     `gh pr list -R mwgrant21/<repo> --json number,title,updatedAt`.
   - **Token spend**: `node ~/agent-improvement/scripts/spend-summary.mjs`
     (yesterday + today). Flag: total output tokens > 2x the trailing week's
     daily median (from prior run-log lines' notes if present), or cache hit
     rate < 50%.
   - **Store health**: pending lines in
     `~/agent-improvement/candidates/<machineId>-buffer.jsonl`, days since the
     newest `Added:` date across `domains/*.md` (> 7 -> note it), and whether
     `git -C ~/agent-improvement status -sb` shows ahead/behind or dirty.
   - **Local repo hygiene**: for each git repo under `~/projects/*`:
     uncommitted changes (`git status --porcelain`) and unpushed branches
     (`git log --branches --not --remotes --oneline`).
2. Update `STATE.md`:
   - Honor the **Human Decisions** section (never re-raise what it suppresses).
   - Count `[FP]` marks added to Recent Noise since last run -> this run's
     `false_positives`; then refresh the section.
   - One-line items only, each with a suggested action. Prune resolved items.
3. Append one line to `runs.jsonl` (schema in `loops/README.md`), set
   `last_run` to today, increment `runs_since_retro`.
4. Return the digest: High Priority first, then Watch List, then one-line
   source summaries. End the FINAL message with the post-run critique
   (false positives observed, noisiest source, one adjustment for next run) -
   the Stop hook captures this for agent-learn.

## Retrospective (every 10th run)

Read ALL of `runs.jsonl` and `STATE.md`. Analyze: recurring noise, items
flagged 3+ runs without human action, precision trend (false_positives per
run), duration trend, dead sources. Output a NUMBERED refinement proposal:
LOOP.md edits, threshold changes, source add/drop, and - if the graduation
gate in `loops/README.md` is met - a promotion proposal. Apply ONLY
human-approved items, via the loop-design skill. Append a `retrospective`
event line and reset `runs_since_retro: 0`. This loop never edits its own
LOOP.md without human approval.
````

- [ ] **Step 2: Create `loops/daily-triage/STATE.md`** from the template with `loop: daily-triage` (all other frontmatter fields as in the template, body sections empty).

- [ ] **Step 3: Create empty run log**

Run: `cd $STORE && touch loops/daily-triage/runs.jsonl && git status -s loops/`
Expected: three new files listed under `loops/daily-triage/`.

- [ ] **Step 4: Commit**

```bash
cd ~/agent-improvement && git pull --rebase && git add loops/daily-triage/ && git commit -m "Register daily-triage loop (L1) with run protocol and state" && git push
```

---

### Task 6: SessionStart hook (master + install + wiring)

**Files:**
- Create: `hooks/daily-triage-onstart.ps1` (master)
- Create: `C:\Users\Matt\.claude\hooks\daily-triage-onstart.ps1` (installed copy)
- Modify: `C:\Users\Matt\.claude\settings.json` (add third SessionStart entry after the agent-learn one)

**Interfaces:**
- Consumes: `loops/daily-triage/STATE.md` frontmatter (`paused`, `last_run`).
- Produces: SessionStart `additionalContext` instructing the session to run the triage per `LOOP.md`.

- [ ] **Step 1: Write `hooks/daily-triage-onstart.ps1`** (mirrors agent-learn-onstart.ps1; UTF-8 no BOM, ASCII only)

```powershell
# daily-triage-onstart.ps1
# EVENT: SessionStart
# If the daily-triage loop has not run today (STATE.md last_run < today) and is
# not paused, emit additionalContext instructing the session to execute the run
# protocol in ~/agent-improvement/loops/daily-triage/LOOP.md.
#
# Never throws; always exits 0. Fails open (missing store/state -> silent).

$ErrorActionPreference = 'Stop'
try {
    try { [void][Console]::In.ReadToEnd() } catch {}

    $statePath = Join-Path $env:USERPROFILE 'agent-improvement\loops\daily-triage\STATE.md'
    if (-not (Test-Path $statePath)) { exit 0 }

    $state = Get-Content $statePath -Raw

    $paused = [regex]::Match($state, '(?m)^paused:\s*(\S+)').Groups[1].Value
    if ($paused -eq 'true') { exit 0 }

    $lastRun = [regex]::Match($state, '(?m)^last_run:\s*(\S+)').Groups[1].Value
    $today = Get-Date -Format 'yyyy-MM-dd'
    if ($lastRun -ge $today) { exit 0 }

    $context = "daily-triage: no run recorded today (last_run: $lastRun). After the agent-learn promote pass (if one was requested), dispatch a background subagent to execute the run protocol in ~/agent-improvement/loops/daily-triage/LOOP.md, then relay its digest to the user. Do not block the user's own request while it runs. L1: report only."
    @{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $context } } | ConvertTo-Json -Compress
}
catch { }
exit 0
```

- [ ] **Step 2: Install the hook**

Run: `cp ~/agent-improvement/hooks/daily-triage-onstart.ps1 ~/.claude/hooks/daily-triage-onstart.ps1`

- [ ] **Step 3: Test the hook standalone (fires when stale)**

Run: `echo '{}' | powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME/.claude/hooks/daily-triage-onstart.ps1"`
Expected: one compact JSON line containing `daily-triage: no run recorded today` (STATE.md ships with `last_run: 1970-01-01`).

- [ ] **Step 4: Test the kill switch and date gate**

Temporarily set `paused: true` in `loops/daily-triage/STATE.md`, rerun Step 3's command → expect NO output. Restore `paused: false`. Then set `last_run:` to today's date, rerun → expect NO output. Restore `last_run: 1970-01-01`.

- [ ] **Step 5: Wire into settings.json** — in `C:\Users\Matt\.claude\settings.json`, append to the `"SessionStart"` array (after the agent-learn entry):

```json
{
  "hooks": [
    {
      "type": "command",
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\Matt\\.claude\\hooks\\daily-triage-onstart.ps1\"",
      "timeout": 30,
      "statusMessage": "Checking daily-triage loop..."
    }
  ]
}
```

Verify JSON parses: `node -e "JSON.parse(require('fs').readFileSync(process.env.USERPROFILE + '/.claude/settings.json','utf8')); console.log('settings.json OK')"`
Expected: `settings.json OK`

- [ ] **Step 6: Run ps-script-learner on the new .ps1** (user's standing rule for any new PowerShell file).

- [ ] **Step 7: Commit**

```bash
cd ~/agent-improvement && git pull --rebase && git add hooks/daily-triage-onstart.ps1 && git commit -m "Add daily-triage SessionStart hook" && git push
```

---

### Task 7: SETUP.md work-machine rollout

**Files:**
- Modify: `SETUP.md` (append a section)

- [ ] **Step 1: Append to `SETUP.md`**

```markdown
## 7. Loop conventions (added 2026-07-13)

Install the loop-design skill and the daily-triage hook:

    mkdir C:\Users\matthewgr\.claude\skills\loop-design
    copy C:\Users\matthewgr\agent-improvement\skills\loop-design\SKILL.md C:\Users\matthewgr\.claude\skills\loop-design\SKILL.md
    copy C:\Users\matthewgr\agent-improvement\hooks\daily-triage-onstart.ps1 C:\Users\matthewgr\.claude\hooks\daily-triage-onstart.ps1

Add a third SessionStart entry to settings.json (same shape as the agent-learn
one) pointing at daily-triage-onstart.ps1.

Note: loop state (loops/daily-triage/STATE.md) is SHARED via the repo - the
first machine to run triage on a given day sets last_run, so the other machine
skips it after a pull. Requires Node on PATH for scripts/spend-summary.mjs.
```

- [ ] **Step 2: Commit**

```bash
cd ~/agent-improvement && git pull --rebase && git add SETUP.md && git commit -m "Document loop-convention rollout for the work machine" && git push
```

---

### Task 8: End-to-end verification

**Files:** none created; exercises everything above.

- [ ] **Step 1: Manual first triage run** — in this session, execute `loops/daily-triage/LOOP.md` end to end (all four sources, STATE.md update, runs.jsonl append, digest + critique). This is the real verification that the protocol is executable as written.

- [ ] **Step 2: Verify state advanced**

Run: `cd $STORE && node -e "const s=require('fs').readFileSync('loops/daily-triage/STATE.md','utf8'); console.log(s.match(/^last_run:.*/m)[0]); console.log(require('fs').readFileSync('loops/daily-triage/runs.jsonl','utf8').trim().split(/\r?\n/).length, 'run line(s)')"`
Expected: `last_run: <today>` and `1 run line(s)`; the run line parses as JSON with `"type":"run"`.

- [ ] **Step 3: Confirm the hook now stays silent**

Run: `echo '{}' | powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME/.claude/hooks/daily-triage-onstart.ps1"`
Expected: no output (last_run is today).

- [ ] **Step 4: Commit the run artifacts + push**

```bash
cd ~/agent-improvement && git pull --rebase && git add loops/daily-triage/ && git commit -m "daily-triage: first verified run" && git push
```
