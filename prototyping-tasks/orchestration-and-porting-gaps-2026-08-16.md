# Prototyping task: multi-runtime routing, cross-run metrics, and a porting executor

**Source evaluation:** evaluate-repo multi-repo run against the bestagentkits GitHub org (agency-skills, agentkit-docs, agentkit-support, ak-cli, ck-skills, cloud-harness-mcp, orchestrate, stop-slop, uptime-monitor), 2026-08-16.
**Verdict on the source repos:** orchestrate (adopt in part — steal 3 mechanisms, don't adopt as a dependency; it's a skill/plugin bundle built for a different harness config) and ck-skills (steal specific ideas + this one genuine gap; don't adopt all 14 skills wholesale, most have no current fit). Everything below is a **design pattern to build independently** as extensions to this environment's own `Workflow` tool and `evaluate-repo` skill, not code ported from either source.

## Gap 1: Multi-runtime routing (Workflow can't dispatch outside its own session)

**What's missing today:** `Workflow`'s `agent()`/`parallel()`/`pipeline()` primitives spawn only in-session Claude subagents. Nothing routes work to a separate runtime process — a different CLI tool, a different agent framework — even when the task would be better handled there.

**Fit evidence (why now, not speculative):** `git-arbiter` exists specifically because this environment already spans two runtimes on a shared tree — Claude Code and Codex CLI — and needs a lock/mutex layer because nothing coordinates *dispatch* across them, only *concurrent writes*. The runtime-plurality this gap addresses is already real, not hypothetical.

**What orchestrate does that's worth taking:** capability- and risk-based routing across runtimes, re-probed live every run rather than trusting a stored catalog of what each runtime can do.

**Minimal prototype scope:**
- Not a `Workflow` rewrite — a routing *decision* layer: given a task, decide which runtime (in-session Claude subagent vs. an external CLI invocation, e.g. Codex) should handle it, based on live-probed capability rather than a hardcoded assumption.
- Live re-probing over a stored catalog, per orchestrate's own stated principle (tool availability drifts; caching it silently produces wrong routing later).

**Open questions:**
- Does this live inside `Workflow` itself (a new `agent()` option to target an external runtime), or as a separate routing skill that decides and then hands off?
- How much of this is actually needed today vs. speculative — git-arbiter solves the *concurrency* half already; this gap is specifically about *routing*, a different problem the environment hasn't hit yet in an acute way.

## Gap 2: Cross-run metrics/history log for orchestration decisions

**What's missing today:** `Workflow`'s `resumeFromRunId` caches results within one run's lineage, but nothing records history *across* runs — no log of which route/model tier a task took, how long it ran, or whether it worked out, that a later run could learn from.

**Fit evidence (why now, not speculative):** Same theme this session already surfaced once — the `skill-eval-loop-2026-08-16.md` plan doc exists because skill-designer changes were "judged by inspection, never measured." This is the identical problem applied to orchestration/routing decisions instead of skill edits: no mechanism today answers "did that routing choice actually work well," so every run re-guesses.

**What orchestrate does that's worth taking:** one JSON line per finished job — route taken, model tier, duration, arbiter verdict — a plain append-only log, not a database.

**Minimal prototype scope:**
- A single append-only log file (JSONL, matching the pattern already used elsewhere in this environment — e.g. claude-mem's observation records) written after each `Workflow` run or routing decision.
- No analysis tooling yet — just the log. Aggregation/analysis is a separate, later step once there's actual data to look at.

**Open questions:**
- Where does this log live — per-project, or in the cross-machine `~/agent-improvement` store (consistent with how lessons/prototyping-tasks are already tracked there)?
- Does this compose with Gap 1 (route decisions) or is it independently useful just logging `Workflow` phase outcomes today, before multi-runtime routing exists?

## Gap 3: A porting executor for evaluate-repo's own "genuine gap" findings

**What's missing today:** `evaluate-repo` (this session's own skill, extensively used and enhanced today) explicitly stops at a written plan doc — Behavior Rules forbid it from acting on its own verdicts. Every "genuine gap, worth adding" finding today dead-ends at a file in `~/agent-improvement/prototyping-tasks/` that requires a separate, manual, user-initiated step to actually build.

**Fit evidence (why now, not speculative):** This exact session produced that dead-end repeatedly today — the SDD-tracking plan doc, the skill-eval-loop plan doc, and this doc itself are three separate instances of "evaluate-repo found something real, then stopped." `ck:xia` (from `ck-skills`) is purpose-built to be the missing next step: extract/compare/copy/improve/port a feature from another repo into the user's own.

**Minimal prototype scope:**
- Not a change to `evaluate-repo` itself — `evaluate-repo`'s report-only/plan-only constraint is a deliberate, correct design (per this session's own skill-designer work), not a bug to fix.
- A **separate** skill or agent, invoked explicitly by the user against a specific plan doc (or a specific evaluate-repo finding), that does the actual build: reads the plan doc's minimal-prototype-scope section and either scaffolds it directly or hands off to `superpowers:writing-plans` for a proper plan before touching code.
- This is the natural answer to the recurring pattern in this session: "evaluate-repo found it, now who builds it?"

**Open questions:**
- Does this fold into `skill-designer`/`agent-designer` (since most findings this session ended up as agent/skill enhancements anyway), or is it a standalone "port-from-plan-doc" skill that can also produce non-skill code changes?
- Should it require the plan doc to exist first (current pattern), or can it work directly from a fresh evaluate-repo verdict without an intermediate file?

## Sequencing note

Gaps 1 and 2 are independent of each other and of Gap 3 — no hard dependency chain. Gap 3 is the most immediately actionable given how many plan docs already exist waiting for it (this doc, skill-eval-loop, sdd-requirement-tracking all have unstarted items). If only one gets picked up first, Gap 3 clears the most existing backlog.

## Status

**Built (2026-08-16):**
- **Gap 1 (multi-runtime routing)** and **Gap 2 (cross-run metrics log)** → `~/.claude/skills/runtime-router/SKILL.md`. Live-probes runtime availability and git-arbiter's lock state before routing, logs every decision to `~/agent-improvement/orchestration-log.jsonl` (append-only, one JSON line per decision).
- **Gap 3 (porting executor)** → `~/.claude/skills/port-gap/SKILL.md`. Reads a plan-doc gap, scaffolds directly when well-bounded or hands off to `superpowers:writing-plans` otherwise, and updates the source plan doc's own Status section afterward (used on itself and on `sdd-requirement-tracking-2026-08-16.md` to write these updates).
- **Orchestrate's comparable items** (two-axis capability×risk matrix, R0-R3 risk tiers, live-reprobe principle) → folded into `~/.claude/CLAUDE.md`'s Model Tiering Policy as a new "Risk axis" section, rather than a separate file — it's a global policy addition, not a skill.

Not built: the open questions above (log location vs. per-project, `port-gap`'s fold-into-skill-designer question) were resolved as stated assumptions in each skill rather than asked, since none changed the shape of the minimal scope. Empirical verification (does routing actually improve anything) is unmeasured — no routing decisions exist yet to check.
