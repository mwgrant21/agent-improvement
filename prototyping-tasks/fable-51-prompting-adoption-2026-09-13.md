# Fable 5.1 prompting guidance — fleet adoption

**Source eval:** `platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1` (evaluate-repo run, 2026-09-13)
**Status:** PLAN ONLY
**Verdict:** adopt in part — 3 genuine gaps, 4 enhancements, 1 audit item

## Framing (read before acting)

This doc is model-specific: it documents Fable 5.1 / Mythos 5.1 behavior
*relative to Fable 5*. Most sections are mitigations for quirks that
generation has (under-formats, rewrites whole files, under-searches at
`low`, goes quiet in long tool chains). Our fleet is mostly sonnet/opus
pinned, so the mitigations do NOT belong fleet-wide as written.

Two things survive that framing and are what this plan builds:

1. Guidance that is model-agnostic in substance even though the page is
   model-specific in framing (scope discipline, compaction content,
   autonomy framing for unwatched runs, name verification).
2. The **effort axis** as a routing concept, which our two-axis policy
   (model tier x risk tier) does not name at all.

Anything already shipped in the Claude Code system prompt is explicitly
OUT of scope — see "Rejected" below.

## Gap 1 — Autonomy declaration for unwatched runs (Fits now)

**The gap.** A fleet-wide grep over `~/.claude/agents/`,
`~/.claude/agents-work/`, and `~/.claude/skills/` for autonomy framing
(`operating autonomously|not watching|cannot answer|unwatched|ask
permission|end your turn|last paragraph`) returns exactly one hit, and it
is the string `[dispatched mid-task]` inside a usage example in
`agents/advisor.md:15`. Not a rule.

The only real coverage is the `subagent_type: "fork"` boilerplate ("One
shot: report once and stop"). That covers forks and nothing else — not the
27 custom agent `.md` files, not `general-purpose` dispatches, not loop
runners.

**Why it bites.** `agents-work/it-fleet/` is saturated with sign-off
language (`software-deployment-agent.md:46`, `project-orchestrator.md:33`).
Our fleet encodes *when to stop* thoroughly and *when not to stop* nowhere.
An agent steeped in sign-off language, dispatched into a session where the
user is not watching, plausibly over-asks on the reversible steps too — and
every such ask costs a full round trip.

**Fit evidence.** Every loop in `~/agent-improvement/loops/` runs
unattended by construction; the daily-triage and pr-review-watch runners
are dispatched as background subagents at SessionStart.

**Minimal scope.** New required "Autonomy Declaration" section in
`~/.claude/skills/agent-designer/SKILL.md` (after the Model Tier Selection
rubric, ~line 127), carrying the doc's three-paragraph block adapted to
pair with — never replace — the agent's own risk gates:

- para 1: operating autonomously / user not watching / proceed on
  reversible actions that follow from the request / stop only for
  destructive actions, genuine scope changes, and whatever this agent's own
  risk gates name explicitly.
- para 2: before ending the turn, check the last paragraph — if it is a
  plan, an analysis, a question, or an "I'll..." promise, do that work now
  with tool calls, including retrying after errors and gathering missing
  info.
- para 3: before a state-changing command (restarts, deletes, config
  edits), check the evidence supports that specific action; a signal that
  pattern-matches a known failure may have a different cause.

Mirror as a required declaration in `~/.claude/skills/loop-design/SKILL.md`
(12th entry under "Required declarations (creation)", after the kill-switch
bullet). Para 3 is a direct strengthening of the loop `level` model: `level`
says what a runner MAY do; nothing today says check the evidence first.

## Gap 2 — Unrequested extras and test scope (Fits now — aether-os)

**The gap.** `CLAUDE.md:10` says "Keep solutions simple and direct. No
over-engineering." The superpowers TDD skill is red-green-refactor only —
zero hits for `scratch`, `pre-existing`, or `commit tests`. Nothing anywhere
says what to do with a pre-existing bug found in passing, or what
distinguishes a scratch verification file from a committed test.

**Fit evidence.** The last two aether-os sessions created
`__probe.5a.test.ts` and `__probe.5b.test.ts` as verification probes, both
of which needed manual cleanup. Mutation testing runs against the real
suite, so every promoted scratch check inflates the denominator.

**Minimal scope.** Append one bullet to `~/.claude/CLAUDE.md` `## Approach`
(after line 10), covering: pre-existing bugs get reported as follow-ups not
fixed in-change; ambiguous tasks get the most-directly-supported reading
with the assumption stated, not both readings built; scratch scripts and
probe files are verification not deliverables and get deleted; tests are
committed only where the task asks or the repo already keeps them for this
kind of change, sized like neighboring test files; never promote a scratch
check into a permanent test file; and the closing guard — this is about
extras only, implement every behavior the task asks for completely.

The probe-file clause is the load-bearing half.

## Gap 3 — Effort as a third routing axis (Fits now)

**The gap.** Zero occurrences of `effort` in `~/.claude/CLAUDE.md`,
`~/.claude/rules/`, `agent-designer`, `skill-designer`, `loop-design`, or
`~/agent-improvement/loops/README.md`. The vocabulary already exists in the
environment — `/code-review` takes `low|medium|high|xhigh|max` — but it is
absent from policy, so every agent and every loop runs at an unexamined
default.

**Fit evidence.** Loops run unattended on a cadence; an unexamined default
effort on a recurring runner silently sets the bill. Directly adjacent to
the quota-normalized-cost work already in flight
(`quota-normalized-cost-2026-09-07.md`).

**Minimal scope.** New `### Effort axis (orthogonal to both)` subsection in
`~/.claude/CLAUDE.md` after the existing Risk axis block, establishing:

- The three axes are independent: tier picks the model, risk tier picks the
  gate, effort picks the spend. Default `high`.
- Effort level names do NOT mean the same amount of thinking across models.
  A sweep done for one model does not transfer; re-measure.
- A capable model at `low` effort often beats a smaller model at high
  effort on cost-per-task — run that comparison before dropping a tier.
- Two named per-effort quirks to route around: at `low`, search and
  retrieval fire less often and answers come from memory (raise effort for
  those turns, not the whole session); at `xhigh`/`max`, a long deliverable
  may be drafted in thinking and then written again as the reply — run
  long-deliverable requests at `high` unless a quality gain is measured.
- `/code-review` already takes an effort level: that is the pattern, not an
  exception.

Mirror as an Effort entry in `agent-designer` and `skill-designer` tier
rubrics, and as a 13th required declaration in `loop-design`.

## Enhancements (one-clause upgrades, no new structure)

| Target | Change |
|---|---|
| `CLAUDE.md:38` Compact Instructions | Ours lists artifacts (paths, errors, tests, TODOs). Add the doc's missing halves: options raised and **why they were set aside**, and the voice-weighting rule — keep what the user said close to their own words, condense your own reasoning to what it concluded. |
| `CLAUDE.md:5` edit-vs-rewrite | Ours is a bare imperative. Add the rationale (tokens spent editing are best minimized) and the escape clause (a full rewrite is right when the file is short or most of it is changing). |
| `CLAUDE.md` Live re-probe block | Ours is scoped to routing decisions. Extend to names: a half-recognized name in a fast-moving area (AI models, pricing, dev tools) is itself the thing to verify; search it as the user wrote it; partial background is what makes a stale answer sound authoritative. Trajectory evidence: TMv2 shipped a wrong placeholder pricing table (`md2-eval-steal-ideas` memory). |
| humanizer (mannered prose) | The skill covers the Wikipedia AI-tells list but NOT sentence-level metaphor-for-direct-statement substitution ("a dial worth turning" for "a parameter worth varying"). **`~/.claude/skills/humanizer/SKILL.md` is a symlink into `~/.agents/skills/humanizer/`, an external MIT package with its own CI** — editing in place drifts against upstream. Carry the rule as a `CLAUDE.md ## Approach` line, or as a local sibling section. Do not edit the vendored file. |

## Audit item — aether-os embedded Claude client

Not a fleet gap; a dated risk in the one project where we own the harness.
Flagged as worth checking, NOT verified — aether-os source was not
inspected in this pass.

- **Append-only history.** Thinking blocks are valid only in the exact
  conversation that produced them for accounts created on/after
  2026-08-31, and enforcement is expected to widen to all accounts. If the
  embedded client injects/removes per-turn reminders, summarizes older
  turns in place, or changes the system prompt mid-session, that is a
  future 400. Diagnostic: run a session with
  `thinking.block_binding.prefix_mismatch_behavior: "drop_block"` and log
  `input_transformations`, or capture consecutive requests and confirm they
  are byte-identical up to the appended turns.
- **Client-side compaction.** Safe shape is to replace the whole history
  with one summary message plus the new user turn, replaying no thinking
  blocks.
- **Progress updates.** The embedded client sees "the agent goes quiet for
  minutes" unless it sets `thinking.display: "updates"` (beta header
  `thinking-display-updates-2026-08-18`) and renders non-empty thinking
  blocks as status lines.

## Rejected — already shipped, do not duplicate

- **"# Delivering work" scope block** — already in the Claude Code system
  prompt near-verbatim, clause-for-clause on scope / ambiguity /
  blocked-parts. Duplicating it into CLAUDE.md buys nothing.
- **Remove legacy anti-formatting rules** — a no-op here. Two grep passes
  over the whole fleet returned zero anti-formatting rules; all 8 loose
  matches were false positives (model-tier rubric lines, an output-format
  spec, a code-style rule, and the word "bulletins"). Recorded so it is not
  re-investigated.
- **Batch independent tool calls** / **non-blocking subagents** — Claude
  Code already implements both, and implements all three legs of the
  subagent pattern (immediate return, result as a later notification,
  Monitor/TaskOutput as the separate wait tools).
- **`max_tokens` headroom** — not settable from the CLI.
- **Vision crop/zoom tooling** — a real gap (Read has no crop/zoom
  parameter) but **no current or foreseeable fit identified**: no recorded
  failure where a chart or screenshot could not be resolved. Not inventing
  a fit.

## Open questions

1. Does the custom-agent dispatch harness inject the same `# Delivering
   work` block the main session gets? Gap 1's verdict rests on a fleet-wide
   grep of agent *bodies* (zero hits), not on proof of what the subagent
   harness injects. If the harness already injects autonomy framing, Gap 1
   shrinks to the loop-runner case only.
2. Should the autonomy block live in `agent-designer` (applies to newly
   authored agents only) or be retrofitted across the existing 27 agents?
   The Model Tier retrofit precedent (2026-08-21) says author-time
   enforcement plus a one-time sweep.
3. Effort defaults per tier: is there a sensible mapping (haiku -> low,
   sonnet -> high, opus/fable -> high with xhigh on demand), or does
   coupling the axes defeat the point of keeping them orthogonal?
