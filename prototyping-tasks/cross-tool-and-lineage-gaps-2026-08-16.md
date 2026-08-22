# Prototyping task: cross-tool consistency and cross-lineage verification

**Source evaluation:** evaluate-repo multi-repo run against FerroxLabs (agents-md, wayland+wayland-core, ijfw, ferrox-factory), 2026-08-16.
**Verdict on the source repos:** agents-md (steal ideas only — MIT, real, most content already covered), wayland/wayland-core (skip as dependency — AGPL on the app, over-scoped for a single-operator engineering setup; steal ideas only), ijfw (steal ideas + 2 gaps — MIT, genuinely local-first, architecture fits cleanly), ferrox-factory (steal mechanisms, don't adopt the ~250-file dependency — MIT, real and mature, but its scale exceeds this portfolio's actual risk profile). Everything below is a **design pattern to build independently**, not code ported from any of them.

**The throughline:** six of this run's findings all point at the same underlying fact — this environment already runs two coding-agent runtimes (Claude Code and Codex CLI) on shared git trees (that's literally why `git-arbiter` exists), but several tools built *earlier this same session* (`runtime-router`, `acceptance-criteria-reviewer`) stayed single-runtime/single-lineage anyway. These gaps aren't hypothetical — they're gaps in work from a few hours ago, re-surfaced by evaluating three more repos against it.

## Gap 1: Push back on false premises, not just banned phrases (from agents-md)

**What's missing today:** `~/.claude/CLAUDE.md` bans sycophantic *phrasing* ("No sycophantic openers... Never say 'great question'") but has no rule against silently *agreeing with a wrong premise* — a different failure mode. Banning a phrase doesn't stop quietly proceeding on a false assumption the user stated.

**Fit evidence:** Direct gap in the file itself — CLAUDE.md's own Approach section was read in full during this evaluation and confirmed to lack this rule.

**Minimal prototype scope:** One new line in `~/.claude/CLAUDE.md`'s Approach section: correct a stated false premise before proceeding, rather than working around it silently. No new tooling — a policy addition, same shape as today's other Approach bullets.

**Open questions:** None — this is small enough to just write.

## Gap 2: Cross-tool config drift, CLAUDE.md vs. ~/.codex/AGENTS.md (from agents-md)

**What's missing today:** `~/.codex/AGENTS.md` is a hand-copied near-duplicate of `~/.claude/CLAUDE.md`, not symlinked or generated. **Live-verified during this evaluation**: today's own Risk-axis/R0-R3 edit to `~/.claude/CLAUDE.md` (from the `bestagentkits/orchestrate` evaluation, same session) is already absent from `~/.codex/AGENTS.md`. This isn't a future risk — it's a currently-existing, already-occurring drift.

**Fit evidence:** As direct as fit evidence gets — reproduced live, this session, on this session's own edit.

**Minimal prototype scope:**
- Simplest fix: make `~/.codex/AGENTS.md` a symlink to `~/.claude/CLAUDE.md` (or the reverse, whichever is canonical) if content is compatible as-is.
- If Codex needs Codex-specific framing agents-md's own file doesn't, a small generation step (a shared source file + a build step producing both) is the fallback — but check whether a plain symlink works first before building anything.

**Open questions:**
- Is any content in `~/.codex/AGENTS.md` actually Codex-specific (would break if it became a straight copy of CLAUDE.md)? Read both files fully before deciding symlink vs. generated.

## Gap 3: Cross-tool shared memory (from ijfw)

**What's missing today:** `claude-mem` and auto-memory curate memory *within* Claude Code. Nothing shares what's been learned/decided *across* Claude Code and Codex CLI — the same two runtimes `git-arbiter` already coordinates for concurrent writes have no equivalent coordination for memory.

**Fit evidence:** Same premise as Gap 2 — git-arbiter's entire reason for existing is that this setup already spans two runtimes on shared trees. Memory staying single-runtime is an asymmetry in an otherwise dual-runtime-aware environment.

**Minimal prototype scope:**
- Not a rebuild of claude-mem — a narrow bridge: when a genuinely cross-cutting decision or lesson is recorded (the kind that already goes in auto-memory's `project`/`feedback` types), also write a plain-text or JSONL copy somewhere Codex CLI can read it (its own memory/context file, if it has one, or a shared file both tools are configured to check).
- Scope this *down* from ijfw's full MCP-server-across-16-tools architecture — this environment only actually has two runtimes to bridge, not sixteen.

**Open questions:**
- Does Codex CLI have its own memory/context-loading mechanism today that a bridge could feed? Needs checking before design, not assumed.
- One-way (Claude → Codex) or bidirectional? Start one-way (simpler, and Claude Code is the primary driver here) unless a concrete Codex-originated need appears.

## Gap 4: Cross-lineage multi-model audit (from ijfw + ferrox-factory, same underlying gap from two angles)

**What's missing today:** `acceptance-criteria-reviewer` (built earlier this session) and git-arbiter's "final-gate re-review" pattern are both single-lineage — an Opus-tier Claude model reviewing Claude-produced work. Both ijfw (cross-lineage audit, different labs) and ferrox-factory (3-lineage cross-audit fan-out) independently flagged the same gap: genuine model-lineage diversity catches a different failure class than same-family independent review, and Codex CLI is already present in this environment to provide it.

**Fit evidence:** Both repos found this independently against the same two just-built tools — the strongest kind of convergent evidence this session has produced.

**Minimal prototype scope:**
- Extend `acceptance-criteria-reviewer`'s design (don't replace it) with an optional cross-lineage mode: when Codex CLI is available (checked via `runtime-router`'s live-probe, not assumed), route the review through it instead of, or in addition to, the Claude-based agent.
- Start with 2-lineage (Claude + Codex), not ferrox-factory's 3-lineage — this environment has two runtimes, not three.

**Open questions:**
- Does this live inside `acceptance-criteria-reviewer` (a routing option), or as a separate wrapper that calls it once per available lineage and reconciles the verdicts? The reconciliation logic (what happens when Claude says PASS and Codex says FAIL) is a real design decision — probably worth a `superpowers:writing-plans` pass rather than scaffolding blind.

## Gap 5: Deterministic machine-checked gates, distinct from LLM review (from ferrox-factory)

**What's missing today:** `acceptance-criteria-reviewer` is an LLM judging criteria — exactly the "another model marks the homework" pattern ferrox-factory's own README names as the failure mode it exists to kill with scripts that can't be talked past.

**Fit evidence:** Built this same session as precisely the mechanism ferrox-factory's design explicitly argues against.

**Minimal prototype scope:**
- Not a replacement for `acceptance-criteria-reviewer` — a *first pass* ahead of it. For criteria that are mechanically checkable (a test passes, a lint rule holds, a file exists, a specific string appears/doesn't appear), a plain script check runs first and blocks before the LLM reviewer even runs. `acceptance-criteria-reviewer` stays for the judgment calls a script genuinely can't make.
- Compose the two: machine gate first (cheap, can't be talked past), LLM review second (for what's left).

**Open questions:**
- Where do machine-checkable criteria get declared — as a new field in `.sdd/STATE.md`'s acceptance-criteria list (e.g. a criterion tagged with a check command), or a separate mechanism? Given `sdd-tracking` already owns the state file, extending it is probably right, but that's a real design call, not a naming detail.

## Gap 6: Workstream ownership / hot-seam enforcement (from ferrox-factory)

**What's missing today:** `runtime-router` (built this session) only *documents* the shared-lockfile/migration sequencing caveat as something to remember when isolating work in a worktree — it doesn't check for it. ferrox-factory enforces the same concern mechanically (`coord-ownership-check`, `coord-hot-seam-check`).

**Fit evidence:** A written warning vs. an enforced check is the exact gap this session's own new tool already flagged in its own guidance section, one evaluation run later.

**Minimal prototype scope:**
- A small check `runtime-router` runs before dispatching to a worktree: does the task's file scope touch a known shared file (lockfiles, migration directories — a short, explicitly-maintained list, not automatic detection of "sharedness")? If yes, block/warn instead of just noting the caveat in prose.
- Keep the "known shared files" list explicit and short at first — over-detecting shared-ness defeats the point of parallelizing work at all.

**Open questions:** None major — this is a bounded addition to an existing skill (`runtime-router`), not a new system.

## Not pursued from this run

- **wayland/wayland-core**: no item cleared both the genuine-gap and Fits-now bars — its one real gap (25-channel remote deployment) has no surfaced need. Steal-idea only: the worktree dirty-checkout guard (incident-derived, from a real v0.2.2 contamination bug) is worth folding into Gap 6's design when it's built.
- **ferrox-factory's 20-domain gate registry**: real capability, no current need for gates-whose-own-correctness-needs-validating — nothing in this environment builds gates today. Revisit only if that changes.
- **ijfw's bi-temporal facts + graduation-threshold consolidation, Wave Table pre-approval artifact, DESIGN.md contract**: all comparable-item steals, not gaps — noted here for reference, not scoped as prototypes.

## Sequencing note

Gaps 1 and 2 are small and independent — buildable immediately, no design work needed. Gap 3 needs one check (does Codex have a memory mechanism to feed) before any design. Gaps 4, 5, and 6 all extend tools built earlier this session (`acceptance-criteria-reviewer`, `sdd-tracking`, `runtime-router` respectively) — each is an extension, not a new system, but Gate 4 and 5 both have a real open design question worth a `writing-plans` pass rather than scaffolding blind.

## Status

**Built (2026-08-16, via `port-gap`):**
- **Gap 1 (false-premise pushback)** → one new line in `~/.claude/CLAUDE.md`'s Approach section.
- **Gap 2 (CLAUDE.md ↔ AGENTS.md drift)** → investigation found the files were genuinely hand-adapted, not blind duplicates (and the hand-adaptation had already introduced a real bug — a wrong path at line 62). Asked the user directly (shape-changing decision, not a naming detail) rather than assuming; chose "shared source + generated deltas." Built `~/.claude/scripts/Generate-CodexAgentsMd.ps1` (self-reference swap only — investigation showed all the "missing" content was pure staleness dated after AGENTS.md's last manual sync, not intentional Codex-specific trims). Ran it: regenerated AGENTS.md now carries today's Risk-axis/live-reprobe additions and the path bug is fixed as a side effect of regenerating from the correct source.
- **Gap 3 (cross-tool shared memory)** → investigated Codex's actual context mechanism (`~/.codex/hooks/user-prompt-inject-context.sh`, a per-project `docs/learnings/*.md` filename-keyword-matcher, not a global store). Full automatic bridging would require editing the harness's built-in auto-memory behavior, which isn't an editable file — same limitation class as the `Workflow` tool. Built the honest, real piece instead: `~/.claude/scripts/Add-CodexLearning.ps1`, an on-demand bridge writer. Not automatic — flagged clearly in its own header comment.
- **Gap 4 and Gap 5 (cross-lineage audit, machine gates)** → handed off to `superpowers:writing-plans` per this doc's own instruction. Full implementation plan at `C:\Users\Matt\docs\superpowers\plans\2026-08-16-cross-lineage-audit-and-machine-gates.md`, including concrete resolutions to both open questions (conservative AND-of-verdicts-plus-CONTESTED reconciliation for Gap 4; `[check: <command>]` inline tags on `sdd-tracking`'s existing criteria list for Gap 5). Not yet implemented — plan awaits an execution-approach choice (subagent-driven vs. inline).
- **Gap 6 (workstream ownership / hot-seam enforcement)** → `~/.claude/skills/runtime-router/scripts/Test-HotSeam.ps1`, wired into `runtime-router/SKILL.md`'s Worktree caveat section as a mandatory pre-isolation check (was documentation-only before). Also folded in wayland's dirty-checkout guard (steal-idea, noted as "not pursued" above) since it's a small, directly relevant addition to the same section.

Verification: Gaps 1, 2, 3, and 6 were tested against scratch repos/directories with real inputs (not just read back) — all passed. Gaps 4 and 5 are plan-only per the hand-off; no code exists yet to verify.
