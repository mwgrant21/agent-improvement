# Prototyping task: SDD tracking, review gate, statusline, and remote-MCP-auth patterns

**Source evaluation:** evaluate-repo multi-repo run against BrainGridAI (braingrid, radial, grabbit-mcp, unikraft-claude-code), 2026-08-16.
**Verdict on the source repos:** all four skipped as dependencies — braingrid (proprietary license, explicit anti-reverse-engineer clause, cloud/OAuth SaaS shape mismatch), radial ($50/seat/year, no source in repo, team-scale mismatch), grabbit-mcp (closed-source hosted vendor, no matching need), unikraft-claude-code (scale/shape mismatch — hosted multi-tenant infra this single-machine setup doesn't need). Everything below is a **design pattern to build independently**, not code ported from any of them.

## Gap 1: Persistent requirement/task IDs auto-linked to git branches

**What's missing today:** SDD-style work (e.g. the git-arbiter 9-task implementation this session) is tracked ad hoc — task numbering and status live in conversation/memory summaries, not a durable, branch-linked schema. Nothing ties "REQ-3 / Task 4" to a specific git branch or survives cleanly across sessions the way a structured ID would.

**Fit evidence (why now, not speculative):** This session ran exactly this kind of orchestration for git-arbiter — a 9-task plan with a "final-gate re-review" step re-verifying findings — and tracked it entirely through free-text memory entries (see S1932-S1936 in this session's observations). That's the concrete, already-occurred gap this would close.

**Minimal prototype scope:**
- A lightweight local ID scheme (e.g. `PROJ-N` / `TASK-N.M`) stored in a per-project state file (matches the loop-design convention of one state file per loop/initiative — reuse that pattern rather than inventing a new one).
- A helper (PowerShell or a skill) that stamps the ID into the branch name on `git checkout -b` and reads it back out for status reporting.
- No cloud sync, no OAuth — stays local/git-synced like everything else in this environment.

**Open questions:**
- Does this belong as a skill (`sdd-tracking`?) or as an extension of the existing `loop-design` skill's state-file convention?
- Should IDs be scoped per-repo or per cross-machine agent-improvement store?

## Gap 2: Acceptance-criteria-gated PR review

**What's missing today:** Existing review agents (`pr-review-toolkit:pr-test-analyzer`, `code-reviewer`) check code quality and test coverage generically. None validate a PR against the *specific stated acceptance criteria* of the requirement/task it claims to close.

**Fit evidence (why now, not speculative):** The git-arbiter SDD loop already runs an informal version of this — a "final-gate re-review" agent independently verdicts each of the 8 findings from the final review before merge (S1933-S1934). That's a manual, one-off version of exactly this gate.

**Minimal prototype scope:**
- Extend (not replace) the existing pr-review-toolkit flow: accept a requirement/acceptance-criteria block (produced by Gap 1's ID scheme or written inline) and check the PR diff against each criterion explicitly, pass/fail per criterion.
- Reuse the "final-gate re-review, independent agent" pattern already validated in the git-arbiter loop rather than designing a new review shape from scratch.

**Open questions:**
- Does this live as a new pr-review-toolkit agent, or as a mode/flag on the existing `code-reviewer`?
- Where do acceptance criteria get authored — inline in the plan doc (superpowers:writing-plans output), or in Gap 1's state file?

**Cross-reference (2026-08-16, bestagentkits/orchestrate evaluation):** orchestrate's "independent arbiter" stage is a cleaner worked design for this same gap — a separate review route (different-model-family preferred), blocking "finished" status until it verdicts, rather than a bolt-on check. Treat as reinforcement of this gap's shape, not a second independent finding: an arbiter stage should verify against the acceptance criteria described here, not be built as an unrelated capability.

## Idea 3: Statusline task-progress display (steal-the-idea, from braingrid)

**What's missing today:** No ambient view of SDD/task progress (e.g. `PROJ-3 > REQ-128 [2/5]`) in the user's statusline — progress is only visible by asking or scrolling back through conversation/memory.

**Fit evidence:** Directly composes with Gap 1 — once persistent REQ/TASK IDs exist, a statusline segment reading that state file is a small addition, not a new subsystem. Same "Fits now" grounding as Gap 1 (git-arbiter's 9-task run had no ambient progress indicator).

**Minimal prototype scope:**
- A statusline segment (see `statusline-setup` agent / `~/.claude/settings.json` statusline config) that reads Gap 1's per-project state file and renders current ID + fraction complete.
- No new tracking logic — purely a read/render layer on top of Gap 1.

**Dependency:** Needs Gap 1's ID/state-file scheme to exist first — unlike Gaps 1 and 2, this one is a hard dependency, not just sequencing convenience.

## Idea 4: OAuth device-flow for remote MCP auth (steal-the-idea, from radial)

**What's missing today:** git-arbiter (the user's only shipped MCP server) is local-stdio-only — no pattern exists yet for authenticating a remote/multi-machine MCP client without distributing static keys.

**Fit evidence:** Speculative relative to Gaps 1-3 — no current MCP server needs multi-machine reach today. Recorded because git-arbiter is actively evolving and cross-machine sync (home/work) is already a pattern used elsewhere in this environment (e.g. the agent-improvement store itself syncs via git). If a future MCP server needs to be reachable from more than one machine, device-flow OAuth is the pattern to reach for instead of designing key distribution from scratch.

**Minimal prototype scope (if/when triggered):**
- Not scoped yet — this is a "remember this pattern," not a near-term build. No prototype until a concrete MCP server actually needs remote/multi-machine auth.

**Future fit:** No current or foreseeable fit identified as a standalone task — kept here as a design-pattern note attached to this plan rather than a scoped prototype, per the user's request to capture it alongside Gaps 1-2.

**Correction (2026-08-16, bestagentkits/cloud-harness-mcp evaluation):** don't treat OAuth device-flow as validated by a second source. cloud-harness-mcp — a real, working remote-MCP system — explicitly rejected OAuth for its own remote auth, using a single long-lived bearer token instead, documenting it as "not OAuth or a general authorization server" by deliberate choice for a single-trusted-owner setup. If a future MCP server needs remote auth, the two options on the table are now: **device-flow OAuth** (radial's pattern — right fit for genuinely multi-machine, no-shared-secret access) vs. **static bearer token** (cloud-harness-mcp's pattern — simpler, right fit for one trusted owner across their own machines, which is closer to this user's actual home/work setup). Pick based on the real threat model when the need appears, don't default to OAuth just because it was the first pattern noted.

**Reference: remote-MCP security patterns (from bestagentkits/cloud-harness-mcp, copy-paste-ready for whenever a real need appears — git-arbiter is local-stdio-only today, so none of this attaches to code yet):**

1. **Timing-safe bearer-token auth.** A single static secret, compared with a constant-time comparison (not `===`/string equality, which leaks timing information about how many leading characters matched). Pair with a documented rotate-on-disclosure runbook — if the token ever leaks, the fix is "generate a new one and redeploy," not a scramble.
2. **Docker executor sandbox, for running any less-trusted code remotely.** Non-root user inside the container, read-only root filesystem, all capabilities dropped except what's explicitly needed, network access off by default (opt-in per job), TTL-based cleanup so abandoned containers don't accumulate, and path-traversal-safe workspace roots (validate every path a job requests stays inside its assigned directory). This is the pattern to reach for the day something executes code from a source this environment doesn't fully trust — not applicable to git-arbiter's current threat model (a single trusted local operator), but the concrete checklist to use if that ever changes.
3. **Credential-free clone + short-lived token broker.** The executor environment never holds a long-lived push credential — it requests a scoped, short-lived token (e.g. a GitHub App installation token) from a broker at the moment it needs to push, and the token expires shortly after. Cleaner than baking a long-lived deploy key into anything that runs less-trusted code.
4. **Locked-down deploy SSH key.** A forced-command key (can only run one specific command, nothing else), pinned to an exact commit SHA rather than accepting arbitrary refs, kept separate from the operator's own personal key. Platform-agnostic — applies to any future deploy pipeline, Windows or not.

Not scoped as a prototype — nothing in this environment currently executes untrusted code or exposes an MCP server remotely. Revisit this section (not the whole plan doc) the day either of those becomes real, rather than re-deriving these patterns from scratch.

## Sequencing note

Gap 2 is more useful once Gap 1 exists (acceptance criteria need somewhere durable to live and link to a PR), but Gap 2 could also be prototyped standalone against a manually-supplied criteria block. Idea 3 hard-depends on Gap 1. Idea 4 has no dependency on the others — it's dormant until a triggering need appears.

## Status

**Built (2026-08-16, via `port-gap`):**
- **Gap 1 (persistent requirement/task IDs)** → `~/.claude/skills/sdd-tracking/` (SKILL.md, README.md, three PowerShell scripts: `New-SddRequirement.ps1`, `Update-SddTask.ps1`, `Get-SddStatus.ps1`). State file convention: `.sdd/STATE.md` at each project's repo root, scoped per-repo (resolved open question 2: per-repo, not the cross-machine store — task IDs are tied to that project's own branches). Resolved open question 1: a standalone skill, not a `loop-design` extension — loops repeat indefinitely, SDD requirements ship and close, different lifecycles. All three scripts tested end-to-end in a scratch repo (create REQ, mark task done/undone including the invalid-task error path, full and statusline status formats) — one real bug found and fixed during testing (a regex singleline-mode bug that swallowed the Tasks section into the Acceptance Criteria output).
- **Gap 2 (acceptance-criteria-gated PR review)** → `~/.claude/agents/acceptance-criteria-reviewer.md`. Built as a new, independent agent (not a `pr-review-toolkit` modification — that plugin is third-party/marketplace-distributed, same do-not-edit reasoning applied to `frontend-design` earlier this session) on the opus tier, matching Model Tiering Policy's "blocking review gate" criterion. Resolved open question 2: reads acceptance criteria from Gap 1's `.sdd/STATE.md` via `Get-SddStatus.ps1 -ReqId <N>`, or accepts them inline — both, not a forced single source. Incorporates the orchestrate cross-reference above directly (independent route, blocks "finished" status, doesn't defer to the implementer's own claims).
- **Idea 3 (statusline task-progress display)** → `~/.claude/skills/sdd-tracking/scripts/Get-FullStatusLine.ps1`, wired into `~/.claude/settings.json`'s `statusLine.command`. A real wrinkle the plan doc didn't anticipate: the existing statusline wasn't a custom script but a third-party npm tool (`ccstatusline`) — resolved as an implementation detail (wrap it, don't replace it) rather than escalated, since it didn't change the shape of the result. Verified the actual Claude Code statusline JSON schema (`cwd`, `workspace.current_dir`) against official docs before writing the payload-parsing logic, rather than guessing. Tested end-to-end with fake stdin payloads: active-requirement segment renders correctly, no-state-file path degrades silently, malformed/absent `cwd` falls back gracefully — one cosmetic bug (stray `" | "` prefix when `ccstatusline`'s own output is empty) found and fixed during testing.

Verification note: all three items were exercised against scratch git repos, not the user's real projects — the next real SDD initiative (e.g. via `sdd-tracking`) is the first live test in production use.

**Idea 4 (remote-MCP auth) and its cloud-harness-mcp reference section:** the *reference material* is now complete and actionable (2026-08-16) — the correction and the four security patterns above are ready to use. No code was written, deliberately: nothing in this environment executes untrusted code or exposes an MCP server remotely today, so there's no attachment point yet. This section is done being a plan and is now simply documentation to pull from when a real need appears.
