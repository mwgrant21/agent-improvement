# Grading Rubric - Generalized Four-Lens + Three-Axis Gate

This is the single source of truth for how a lesson is extracted and judged. It
generalizes the PowerShell-specific engine in
`~/.claude/skills/ps-script-learner/references/analysis-rubric.md` to any domain.
`ps-script-learner` delegates its judgment here; keep the two consistent.

The input is a finished SESSION (a buffer record, plus the transcript tail when
needed), not a single script. Ask of each session: "What would I want a future
session - on either machine - to already know?"

---

## Part A: Four-Lens Extraction

Apply all four lenses. Most sessions yield zero lessons; that is correct. Never
manufacture a lesson to fill space.

### Lens 1 - [PATTERN]: a reusable approach that worked
A technique that solved the problem cleanly and would apply again beyond this one task.
- Examples: a retry/back-off shape that worked; a project structure that paid off; a
  tool-invocation recipe (a working `gh`/`git`/`az` sequence); a debugging method that
  found the root cause fast.
- NOT a pattern: a routine action with no reusable insight ("ran the tests").

### Lens 2 - [VIOLATION]: a rule that was broken, then corrected
A conflict with an established rule in CLAUDE.md, `rules/powershell.md`, project
conventions, or a prior lesson - especially one the USER had to correct.
- Examples: used Write-Host in a PDQ script; assumed a file path that didn't exist;
  edited before reading; ignored an existing utility and rebuilt it.
- The correction IS the lesson: record what to do instead, not just the slip.

### Lens 3 - [NOVEL]: a newly discovered fact or behavior
A gotcha, environment quirk, tool behavior, or API detail not yet documented anywhere
in the store, codex.md, or CLAUDE.md.
- Examples: "gh auth persists via keyring but the work box needs a PAT"; "this MCP
  tool truncates at N tokens"; "Electron on Windows needs an ACL step for X".
- Before tagging NOVEL, confirm it is genuinely absent from the store and codex.md.

### Lens 4 - [IMPROVEMENT]: a better way, learned in hindsight
A concrete "next time, do X instead of Y" that emerged from how the session actually
went - inefficiency, a dead end, a smarter path found late.
- Examples: "grep the callers first, it's faster than reading each file"; "batch these
  reads instead of serial"; "use the schedule skill, not a hand-rolled cron".

---

## Part B: Three-Axis Grade Gate

Score each extracted candidate on all three axes. A candidate PASSES only if it clears
every axis. This gate is strict on purpose: the store syncs to the work machine.

### Axis 1 - Generality (reusable vs one-off)
- PASS: states a rule that applies to a class of future situations.
- FAIL: tied to this one file/ticket/value with no transferable rule. A one-off event
  belongs in a session journal, not the lesson store.

### Axis 2 - Evidence (verified vs speculative)
- PASS: it actually happened this session - a user correction, an observed error, a
  confirmed success, a tested result.
- FAIL: "this might help" / "probably better" with nothing to back it. No speculation.

### Axis 3 - Non-redundancy (new vs already known)
Dedup against the target `domains/<domain>.md`, then LESSONS.md, then codex.md /
CLAUDE.md:
- NEW: no similar entry exists -> promote as a new entry.
- UPDATE: a similar entry exists but this adds meaningfully different info -> revise it.
- SKIP (FAIL): already captured -> log to dropped.log, do not write.

---

## Decision

- Passes all three axes and is NEW or UPDATE -> promote to `domains/<domain>.md`,
  update LESSONS.md.
- Anything else -> one line in `candidates/dropped.log`:
  `YYYY-MM-DD [<lens>] <candidate> - dropped: <which axis failed>`.

When genuinely unsure, DROP. A missed lesson resurfaces next time it matters; a junk
lesson pollutes both machines until someone prunes it.
