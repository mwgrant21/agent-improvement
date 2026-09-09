# evaluate-repo: local file `reddit-ideas.md` (19-item curated idea list)

**Verdict:** ADOPT-PARTIAL
**Evaluated:** 2026-09-08 | **Target:** `C:\Users\IT\Downloads\reddit-ideas.md` (835 lines, 42,676 bytes, mtime 2026-09-08 10:20) | **License:** n/a (personal notes)
**Assets read:** 1 file, 19 numbered ideas + a `## Notes` footer

## Scope caveat — read this before acting on anything below

This target is **not a repository**. It is a secondhand notes file *about* 19 repos and
posts. Nothing in it was verified against the upstream source in this run, and the file
itself carries vendor marketing numbers as if they were measurements:

> "**88% fewer tool calls** / **53% faster execution** / **62% fewer tokens** / **44% cheaper**" — `reddit-ideas.md:519-522` (CodeGraph)

> "Achieves 98% context reduction (315 KB -> 5.4 KB on a Playwright snapshot)" — `reddit-ideas.md:200`

> "**Launch speed**: ~14ms (vs 383-3,437ms for competitors)" — `reddit-ideas.md:660`

Treat every such figure as a claim to test, never as a finding. Per the tooling-domain
lesson "A tool named in a plan is not evidence it is still maintained - check
last-publish", anything promoted from this list to real adoption needs its own
`/evaluate-repo` run against the actual repo.

The file also contains one factual error about our own setup:

> "**You already care about this**: You have `matt-writing-voice` skill built from your own samples" — `reddit-ideas.md:95`

No `matt-writing-voice` skill exists on this machine (`~/.claude/skills/` holds
agent-designer, agent-learn, android-development, evaluate-repo, find-skills,
frontend-design, humanizer, loop-design, penpot-uiux-design, skill-designer). Either it
is home-machine-only or the note is wrong. Flagged, not assumed.

## Vantage-point caveat — added 2026-09-09 from Claude Code on home-matt

This evaluation was produced **from the GUI**, against a different environment than
Claude Code sees. That is not a defect in the reasoning, but it bounds which of its
verdicts can be used as-is.

Measured on home-matt: the report inventories **10** skills; Claude Code here has **21**.
Six overlap (`agent-designer`, `agent-learn`, `evaluate-repo`, `humanizer`, `loop-design`,
`skill-designer`). Four it lists are absent from Code here (`android-development`,
`find-skills`, `frontend-design`, `penpot-uiux-design`). **Fifteen Code skills were
invisible to it**, including `runtime-router`, `mutation-test`, `port-gap`,
`mcp-server-adopter`, `sdd-tracking`, `doubt-driven-review`, `ps-codex`, `interview-me`.

So the verdicts split by source:

- **Sound** — anything drawn from `~/agent-improvement/` (`loops/README.md`, `LESSONS.md`,
  `domains/`, `prototyping-tasks/`). That store is git-synced, so both surfaces read the
  same bytes. The two top-ranked adoptions (#2 adversarial promotion, #4 quota axis) rest
  entirely on those files and stand unchanged.
- **Needs a Code-side re-check** — every "our equivalent" cell that names a skill or agent.
  A verdict of "we have nothing" or "worse" may only mean the GUI could not see it. This
  applies to #4, #6, #12 and #19 at minimum.

Two specific items re-checked from Code on 2026-09-09:

- **`matt-writing-voice` (report's "factual error about our own setup").** The skill does
  not exist on either machine, so that much is right -- but the *capability* does, which
  the report could not see: `voice-profiles/` in this store holds `matt-default.md` and
  `matt-jira.md` (plus portable variants), wired into humanizer's Voice Calibration section
  and specified in `docs/specs/2026-08-15-voice-profile-persistence-design.md`.
  reddit-ideas.md was right in substance, wrong in form. Do not carry "the note is wrong"
  forward.
- **Adoption #1's premise (humanizer has no scripts).** The file inventory in that section
  does not describe Code's humanizer here, which is a symlink to `~/.agents/skills/humanizer`
  and does contain `scripts/`, `agents/` and `docs/` (and no `WARP.md`). The premise
  nevertheless **holds**: `scripts/validate-package.py` validates the skill's own package
  surfaces, not prose. There is still no deterministic detector pass, so #1 remains valid --
  on verified evidence rather than the inventory quoted there.

## Summary

Nineteen ideas spanning agent messaging, model routing, config versioning, context
economy, agent-system case studies, and long-horizon loop control. Two are **already
adopted** and should be struck from the list rather than re-evaluated. Roughly half
describe capabilities the harness already gives us natively (cross-session messaging,
worktrees, progressive skill loading) and are worth recording as "we have it better" so
the next pass does not re-propose them. The genuinely valuable residue is **six
process/convention changes**, not tools — the strongest being Impeccable's deterministic
detector rules, the self-improving-ecosystem's correctness-vs-quality split with
adversarial promotion, and the scope-anchor discipline buried in idea #1. One real
capability gap exists (MarkItDown, document->markdown intake). One item is rejected on
policy grounds, not capability (#8).

## Item-by-item verdict

| # | Idea | Our equivalent | Gap | Action |
|---|---|---|---|---|
| 1 | Claude/Codex bridge | `SendMessage` + `ListAgents` (native, cross-session + cloud) | **better** — but the *scope-anchor* lesson is new | ADD (lesson only) |
| 2 | Model stratification for quota | `runtime-router`, model-routing-ladder memory, per-agent `model:` frontmatter | **worse** — no quota axis, no review-loop exit criterion | ADD |
| 3 | Dotfiles + GNU Stow for `~/.claude` | `claude-config` (copy-then-commit), `Claude-Files` (portable backup) | **worse on one axis** — no pre-experiment snapshot gate | ADD (principle), reject Stow |
| 4 | Elements of Style skill | `humanizer` (SKILL.md only, no `references/`) | **worse** — no progressive-disclosure pattern for big references | ADD (small) |
| 5 | repo-rules (GitHub org governance) | `compliance-baseline-agent` (endpoints, not repos) | none that matters — wrong lane | REJECT |
| 6 | MarkItDown | **none** | **we have nothing** | ADD |
| 7 | Context Mode MCP | harness output-persistence, `Explore`/`scout`, `out_dir` | **partial** — code-first-analysis rule is new | ADD (rule), MONITOR (server) |
| 8 | Camoufox anti-detection | n/a | n/a | REJECT (policy) |
| 9 | ECC (68 agents / 286 skills) | 24 agents + 14 skills, deliberately scoped | **better** on scope; **worse** on config auditing | ADD (AgentShield idea only) |
| 10 | NoSignups directory | n/a | not a pattern | REJECT |
| 11 | DeerFlow | loop L1/L2/L3 authority ladder | **worse** — authority is laddered, execution isolation is not | ADD (small) |
| 12 | Impeccable | `humanizer` (LLM-judgment only) | **worse** — no deterministic pre-LLM detector pass | **ADD (top)** |
| 13 | OpenCodex | already evaluated 2026-08-21/22 | **already adopted** | STRIKE |
| 14 | CodeGraph | already installed v1.5.0, MCP registered | **already adopted, unfinished** | FINISH |
| 15 | LoopX | `loops/README.md` STATE.md + runs.jsonl + kill switch | **better** on evidence/kill switch; **worse** on work-claiming | ADD (lease convention) |
| 16 | Self-improving agent ecosystem | `agent-improvement` itself | **worse** — no correctness/quality split, no adversarial promotion gate | **ADD (top)** |
| 17 | jcode harness | Claude Code | n/a — harness replacement | MONITOR |
| 18 | Worktrunk | `EnterWorktree`/`ExitWorktree`, `isolation: "worktree"`, `superpowers:using-git-worktrees` | **better** — native | REJECT |
| 19 | Gentleman-Book-MCP | LESSONS.md injected by hook, domain files read on demand | **worse at scale** — no semantic search over 40+ lessons | ADD (deferred) |

## Recommended adoptions (ranked by value / effort)

### 1. Deterministic detector rules as a pre-LLM pass — change `~/.claude/skills/humanizer/`

Add a `references/detectors.md` (or a small script) enumerating the mechanically
detectable AI-writing tells the skill already describes in prose — em-dash density,
rule-of-three triads, "not just X but Y" negative parallelism, the known vocabulary list —
so they are caught by pattern before any model judgment is spent on them.

Evidence: `reddit-ideas.md:410` — "**Deterministic Rules**: 61 rules for pattern detection
without API calls (cost-effective validation)"; and `reddit-ideas.md:412` — "**Separation
of Concerns**: Detection != Generation; offline checks before online refinement"

Why it fits us specifically: `humanizer/` contains only `SKILL.md`, `README.md`, `WARP.md`,
`LICENSE` — no `references/`, no scripts. Every check is model judgment today. This is also
the cheap half of a pattern we already trust elsewhere: the `it-sysadmin-suite` review gates
run static checks before human sign-off.
**Effort: low.**

### 2. Split correctness from quality, and add an adversarial gate to promotion — change `~/agent-improvement/skills/agent-learn/`

Their four-part contract is the closest external analog to what `agent-improvement` already
is, and it names two things our promote pass does not do: grade *correctness* separately
from *quality*, and require a candidate to survive a skeptical reviewer before it becomes
canonical.

Evidence: `reddit-ideas.md:617` — "Correctness and quality are separate; candidates are
isolated from canonical state; a would-be winner is adversarially verified; every attempt
retains exact evidence and lineage."

Why it fits us specifically: we already hold "Never let the maker verify its own work"
(`LESSONS.md`, loop-design, 2026-07-13) and we already have `candidates/` isolated from
`domains/`. So three of their four contracts are in place; the missing one is the
adversarial step *at the promotion boundary*, plus the correctness/quality axis split.
This is a genuine hole in the exact system this file is being evaluated for.
**Effort: medium.**

### 3. MarkItDown as document-intake preprocessing — new capability, no existing file

The only outright capability gap in the list. Converts PDF/Word/Excel/PowerPoint/images/
HTML/CSV into LLM-ready Markdown.

Evidence: `reddit-ideas.md:151` — "Microsoft's Python utility that converts various file
formats into Markdown, optimized for LLM analysis."

Why it fits us specifically: the `IT-KB-Pipeline` project (Jira -> Confluence KB generator,
memory `it-kb-pipeline.md`) and any ticket-attachment triage both need exactly this and
currently have nothing. Microsoft-maintained, so the maintenance risk is low — but per the
scope caveat above, confirm last-publish before installing.
**Effort: low** (`pip install markitdown`), **but gate it on a real `/evaluate-repo` run.**

### 4. Add a quota axis and a review-loop exit criterion — change `~/agent-improvement/` model-routing notes and `loops/README.md`

Two separable pieces:
- **Quota-aware routing.** Our ladder routes by *task complexity* only. Theirs also routes
  by *remaining budget*, restructuring the workflow when the top tier would be exhausted
  early.
- **A terminating review loop.** A named exit condition rather than "review until it looks
  done."

Evidence: `reddit-ideas.md:35` — "**Final review loop**: Codex GPT-5.6 Sol xhigh (iterate
until no Critical/High findings)"; and `reddit-ideas.md:44` — "noticed would max Fable quota
by day 3-4, restructured workflow instead"

Why it fits us specifically: `loops/README.md` already has a `budget` field ("`soft` or a
token number; enforced at L2+ (breach -> paused: true)") — but breaching it *pauses* the
loop rather than *downshifting* it. A budget that can only halt is strictly less useful than
one that can also route cheaper. The severity-gated exit also pairs with the existing
`attempt_cap`.
**Effort: low.**

### 5. Work-claiming leases for multi-agent loops — change `~/agent-improvement/loops/README.md`

Add a claim/lease convention to the loop spec so two agents working the same queue cannot
take the same item.

Evidence: `reddit-ideas.md:571` — "Typed todos with peer claims and leases (ownership
tracking)"

Why it fits us specifically: this is the principled form of a lesson we already learned the
hard way — "Serialize fix-implementer dispatches that may touch shared files" (`LESSONS.md`,
tooling, 2026-08-22). Serializing is the blunt fix; a lease lets work proceed in parallel
where it genuinely does not overlap. Only worth building when a second multi-agent loop
exists; `daily-triage` is single-runner today.
**Effort: medium. Defer until a second concurrent loop exists.**

### 6. "Commit before you experiment" gate — change `~/.claude/CLAUDE.md` or add a hook

Not Stow — the principle underneath it.

Evidence: `reddit-ideas.md:70` — "Commit before you experiment, especially before you let AI
rewrite its own config"

Why it fits us specifically: `claude-config` is a *copy-then-commit snapshot* repo (HEAD
`611a8c9`), so it captures state only when someone remembers to sync it. A session that
rewrites `~/.claude/settings.json` or a SKILL.md has no automatic rollback point. A
`SessionStart` or `PreToolUse` hook that snapshots on first write to `~/.claude` closes
that. GNU Stow itself is rejected below.
**Effort: low-medium.**

### 7. Code-first analysis as a stated rule — change `~/agent-improvement/domains/tooling.md`

Evidence: `reddit-ideas.md:203` — "**Code-First Analysis**: Write a script to analyze 50
files instead of reading them all. One tool call replaces ten (~100x context savings)"

We do this by instinct (this very evaluation used `grep`/`sed` over `Read`), but it is
nowhere written down as a preference, so it is not reliably applied. One lesson line.
**Effort: trivial.**

### 8. Config-permission self-audit — new, low priority

Evidence: `reddit-ideas.md:270` — "**AgentShield** security scanning (config & permissions)"

We have `/fewer-permission-prompts`, which only ever *widens* the allowlist. Nothing ever
audits `settings.json` `permissions.allow` for entries that became over-broad. Worth a
periodic check, not a new skill.
**Effort: low. Priority: low.**

### 9. Execution-isolation dimension for loop levels — change `~/agent-improvement/loops/README.md`

Evidence: `reddit-ideas.md:349` — "Code execution in isolated Docker containers or local
sandboxes with configurable access levels (bash, file writes). Safe agent autonomy within
defined boundaries."

Our L1/L2/L3 ladder governs *what a loop may decide*; it says nothing about *where its code
runs*. An L3 loop today runs with the session's full authority. Worth one paragraph noting
isolation as an orthogonal axis.
**Effort: low. Priority: low.**

### 10. Semantic search over our own lessons corpus — deferred

Evidence: `reddit-ideas.md:797` — "**Tiered capabilities**: Start simple (list, read,
search), layer in sophistication (prompts, semantic)"

`LESSONS.md` is at 40+ indexed lessons and grows every promote pass. It is injected whole by
the `agent-learn-onstart` hook, and domain files are read on match. That is tier 1 of their
three tiers and it will degrade as the corpus grows. Not a problem yet; note it as the
shape of the eventual fix so it is not reinvented from scratch.
**Effort: high. Priority: defer — revisit when LESSONS.md injection becomes costly.**

## Already adopted — strike from the list

| # | Idea | Status |
|---|---|---|
| 13 | OpenCodex | Evaluated 2026-08-21/22. Its "bounded memory ownership" convention is already in `~/agent-improvement/loops/README.md:59-61` — "Adapted from lidge-jun/opencodex's 'bounded memory ownership' convention (36 categories of process-retained state, each with a declared hard cap; evaluated 2026-08-21/22)". Also cited in `loops/daily-triage/STATE.md:13`. |
| 14 | CodeGraph | Evaluated 2026-08-22, **installed and registered**. `prototyping-tasks/codegraph-adopt-primary-2026-08-22.md` is marked **BUILT**: "UNBLOCKED and REGISTERED 2026-08-22 ... the user ran `npm install -g @colbymchenry/codegraph` themselves (v1.5.0 confirmed via `npm list -g`)." |

**Open follow-up on #14 — this is an unfinished action, not an adoption:** the same doc
records "Deliberately NOT done: did not run `codegraph init` against any real project" and
"**Next step:** user decides which project(s) to `codegraph init` first". Nothing in this
list needs deciding; that does.

## Rejected

| # | Their pattern | Why not |
|---|---|---|
| 3 | GNU Stow symlink farm for `~/.claude` | Windows symlink friction, and `~/CLAUDE.md` states the standing rule directly: "Never `git init` or commit in `C:\Users\IT` or `~/.claude`." The snapshot repo is the deliberate alternative. Take the commit-before-experiment principle, not the mechanism. |
| 5 | repo-rules org governance | Wrong lane. Our compliance surface is ~200 Windows endpoints via PDQ/Intune, covered by `compliance-baseline-agent`. GitHub side is a private marketplace plus a handful of personal repos — nothing to govern at scale. |
| 8 | Camoufox anti-detection browser | Its purpose is defeating a site's access controls. The source file flags this itself — `reddit-ideas.md:246`: "before using, confirm it's acceptable to circumvent the Reddit block. If the block is policy-level, this isn't the answer regardless of technical capability." It reads as policy-level. Not adopted, and not a close call. |
| 9 | 68 agents / 286 skills at scale | Scale is not the virtue being demonstrated. We run 24 agents and 14 skills deliberately; `agent-designer` and `skill-designer` exist to keep new ones justified. Only the config-scanning idea was extracted. |
| 10 | NoSignups directory | A bookmark, not a pattern. Nothing to adopt. |
| 17 | jcode harness | Replacing Claude Code is not on the table; every hook, skill, plugin, and MCP registration here is harness-specific. The embedding-based auto-recall idea is real but not adoptable without harness control. |
| 18 | Worktrunk | We are ahead. Native `EnterWorktree`/`ExitWorktree` tools, `isolation: "worktree"` on the Agent tool, and `superpowers:using-git-worktrees` cover this without a Rust dependency. |

## Where we are already ahead

- **Cross-session agent messaging (#1).** `SendMessage` + `ListAgents` reach in-process
  subagents, teammates, other local sessions, and cloud sessions. Their bridge is a
  prototype requiring `--dangerously-load-development-channels` (`reddit-ideas.md:23`).
- **Worktree management (#18).** Native tooling, no external CLI.
- **Progressive skill loading (#11).** Description-gated `Skill` invocation already loads
  on demand; this is the harness default, not something to build.
- **Loop state and safety (#15).** `loops/README.md` already specifies durable STATE.md
  frontmatter, append-only `runs.jsonl`, an explicit kill switch (`paused`), `attempt_cap`,
  `budget`, L1-mandatory graduation, and a state-ownership ledger. LoopX's five questions
  are largely answered; only work-claiming leases are missing.
- **Evidence discipline.** The maker-never-verifies rule and candidate isolation predate
  this list by two months.

## Repo health

n/a — local notes file, not a repo. Last modified 2026-09-08 10:20. Self-described at
`reddit-ideas.md:829-835` as a running capture list: "19 ideas total ... Keep this updated
as you find things." Two of its 19 entries were already stale at the time of this
evaluation (#13, #14), which suggests the list is written faster than it is reconciled
against what has actually been adopted.

## Recommended next action

None of the ranked adoptions above are applied by this report — this skill is report-only.
The two highest-value items (#1 humanizer detectors, #2 agent-learn adversarial promotion)
are both small, self-contained, and touch files we own outright. The one item needing an
*upstream* evaluation before any install is MarkItDown.
