# Prototyping task: empirical skill-eval loop + trigger-description optimization

**Source evaluation:** evaluate-repo run against github.com/davila7/claude-code-templates/tree/main/cli-tool/components/skills/development/skill-creator, 2026-08-16.
**Verdict on skill-creator itself:** adopt in part — its authoring-wizard role overlaps with `skill-designer`/`agent-designer` (which stay in place, they solve the earlier-stage "idea to finished draft" problem), but its *evaluation* layer is a genuine gap those two don't cover at all. Apache-2.0 licensed, appears to be Anthropic-authored content mirrored into davila7's collection rather than davila7's own work (same license pattern as the earlier `frontend-design` finding) — worth checking for an official/canonical source before treating this repo as the reference copy.

## Gap 1: Empirical skill-eval loop

**What's missing today:** `skill-designer`'s self-critique pass (and `agent-designer`'s equivalent) is a static, single-pass heuristic — a checklist judged by eye against the finished file. Neither actually runs the skill or measures whether a change made real output better or worse.

**Fit evidence (why now, not speculative):** This exact session ran `skill-designer`'s Improvement Mode three times against `evaluate-repo` (multi-repo support, trajectory future-fit check, prototyping-task generation) with zero empirical verification — every change was judged by inspection only, never by comparing actual before/after skill behavior.

**What skill-creator does that's worth taking:** parallel with-skill/baseline subagent runs on the same task, assertion-based grading, a quantitative benchmark (mean/stddev/delta across runs), an interactive HTML viewer, and cross-iteration diffing to see if a change actually helped.

**Minimal prototype scope:**
- A lightweight harness: given a skill + a set of representative task prompts, run the task with and without the skill loaded (or before/after a proposed edit), and diff the outputs.
- Skip the full HTML viewer and benchmark-aggregation machinery initially — a plain before/after transcript comparison is enough to validate the concept before investing in tooling around it.
- Natural fit as a phase inside `skill-designer`'s Improvement Mode: after synthesis, offer to run the new version against 2-3 representative prompts and show the diff before the user commits to the save.

**Open questions:**
- Does this live as a new capability inside `skill-designer` itself, or as a separate companion skill (`skill-eval`?) that `skill-designer` can optionally invoke?
- Assertion grading (skill-creator's approach) vs. a simpler "did the output change in the intended direction" LLM-judge pass — which is worth the complexity for this user's actual skill-count and edit-frequency?

## Gap 2: Trigger-description optimization

**What's missing today:** `skill-designer`'s self-critique step 1 ("Trigger specificity") is one judgment call — "could this accidentally fire on unrelated tasks?" — with no actual measurement.

**Fit evidence (why now, not speculative):** This session hand-tightened `evaluate-repo`'s `description:` field multiple times by inspection (added multi-repo phrasing, swapped an example for a multi-repo trigger case) with no way to check whether the new wording actually improved trigger accuracy or just felt better.

**What skill-creator does that's worth taking:** `run_loop.py` generates ~20 realistic should-trigger/shouldn't-trigger queries, splits them 60/40 train/test, repeats each 3x for noise reduction, iteratively proposes description rewrites, and selects on held-out test score to avoid overfitting to the training queries.

**Minimal prototype scope:**
- A smaller version: generate a handful of realistic trigger/non-trigger queries for a given skill's description, check (via a fresh-context agent call) whether each one correctly triggers or correctly doesn't, report pass/fail — skip the full train/test split and iterative rewriting loop until the basic check proves useful.
- Composes naturally with Gap 1's harness (same "run a fresh agent, check the result" mechanism).

**Open questions:**
- Same tooling-location question as Gap 1 — likely the same harness serves both.

## Not pursued: `package_skill.py` (distribution bundling)

Real absence (skill-designer only writes local files, no `.skill` bundle export) but no current or foreseeable fit — no active skill-distribution workflow surfaced this session, and the `it-claude-marketplace` repo is dormant. Not scoped as a prototype; revisit if a distribution need actually appears.

## Noted but not actioned: writing-philosophy tension

skill-creator explicitly warns against heavy `ALWAYS`/`NEVER` all-caps rule framing in favor of explaining the *why*. `skill-designer`'s and `agent-designer`'s own output templates lean toward bold "Never X" Behavior Rules sections — a direct stylistic tension worth being aware of, not something to resolve here. Flagging it in case it informs a future skill-designer template revision.

## Sequencing note

Gap 2 depends on Gap 1's harness mechanism (spawn agent, evaluate result) — build Gap 1 first, Gap 2 follows naturally as a second use of the same infrastructure.

## Status

Plan only — not started. This file is the output of an evaluate-repo run, not a commitment to build. Next step, if pursued, is user-initiated (e.g. `superpowers:writing-plans` from this doc, or a direct `skill-designer` Improvement Mode pass on `skill-designer` itself to add the eval phase).
