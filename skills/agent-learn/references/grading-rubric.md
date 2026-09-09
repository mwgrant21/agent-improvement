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

## Part B: Correctness Gate (must pass before quality is even considered)

Correctness and quality are separate questions, and conflating them lets a
well-written wrong lesson through. Answer this one first; a candidate that fails
here is dropped without grading its quality at all.

### Axis 0 - Correctness (is the CLAIM right, not merely observed?)

- PASS: the stated rule follows from what happened. If the lesson asserts a cause
  ("X fails BECAUSE Y"), that cause was actually confirmed, not inferred from a
  single correlated observation.
- FAIL: something real was observed, but the rule drawn from it does not follow.

**Why this is not Axis 2 (Evidence).** Evidence asks *did something happen*.
Correctness asks *is the conclusion drawn from it true*. A candidate can pass
Evidence and fail Correctness, and that combination is the most dangerous one in
the store, because the evidence makes it look verified.

Worked example, 2026-09-09: a session found that `~/.agents/skills/humanizer` is
not a git repository -- true, verified, directly observed -- and drew the lesson
"the humanizer fork is unprotected and one update from being lost." The evidence
was real; the conclusion was wrong. A backup existed in the synced store, in a
different file the session had not looked at. The correct lesson was almost the
opposite and far more useful: *the backup existed but had silently gone stale, so
restoring from it would have reinstated worse content.* Promoting the first
version would have put a confident falsehood on both machines.

Test to apply: **can the negation be ruled out with what was actually checked?**
If ruling it out would need a check nobody ran, the candidate fails Correctness.

## Part C: Quality Gate

Only candidates that clear Correctness reach these. A candidate PASSES only if it
clears every axis. This gate is strict on purpose: the store syncs to the work
machine.

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

## Part D: Adversarial Promotion Gate

A candidate that clears Correctness and Quality is still only a *candidate*. Before
it becomes canonical, make one genuine attempt to falsify it and WRITE THE ATTEMPT
DOWN.

This exists because `LESSONS.md` already holds "Never let the maker verify its own
work" (loop-design, 2026-07-13) -- a rule the promote pass itself was violating.
The same actor extracted, graded, and promoted, with nothing between a candidate
and the shared store but its own confidence.

Ask all three, and record the answers:

1. **What would make this wrong?** Name a concrete situation where following the
   lesson produces a worse outcome. If none can be named, the lesson is probably
   too vague to act on.
2. **Is it an artifact of one environment?** Would it still hold on the other
   machine, in a different repo, under a different harness surface? A lesson true
   only of home-matt belongs in a machine-local note, not the synced store.
3. **Is the causal claim load-bearing or decorative?** If the "because" were
   removed, would the advice still stand? A wrong "because" attached to right
   advice teaches the wrong model and misfires the next time it is applied.

**The written attempt is the deliverable, not the verdict.** "I considered it and
it seems fine" is not a falsification attempt and does not satisfy this gate --
it is unfalsifiable after the fact, which is exactly what makes the maker a poor
verifier of their own work. Record the strongest counter-case found, then say why
it does not sink the lesson.

Promotions log the attempt to `candidates/promoted.log`:

    YYYY-MM-DD [<lens>] <lesson> -> domains/<domain>.md (NEW|UPDATE)
      falsified-by-attempt: <the strongest counter-case found>
      survives-because: <why it does not sink the lesson>

If the counter-case DOES sink it, that is a success, not a wasted pass: drop it to
`dropped.log` with `dropped: adversarial (<counter-case>)`. A lesson killed at this
gate cost one paragraph. The same lesson promoted wrong costs every future session
that trusts it.

---

## Decision

- Fails Correctness -> drop immediately, do not grade quality.
- Passes Correctness + all three quality axes, is NEW or UPDATE, and survives the
  adversarial gate -> promote to `domains/<domain>.md`, update LESSONS.md, and log
  the falsification attempt to `candidates/promoted.log`.
- Anything else -> one line in `candidates/dropped.log`:
  `YYYY-MM-DD [<lens>] <candidate> - dropped: <which gate failed>`.

When genuinely unsure, DROP. A missed lesson resurfaces next time it matters; a junk
lesson pollutes both machines until someone prunes it.
