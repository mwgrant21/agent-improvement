# evaluate-repo: avirtual/clodex

**Verdict:** ADOPT-PARTIAL
**Evaluated:** 2026-09-10 | **Repo HEAD:** 46ae0e1 (2026-09-10T18:42Z) | **License:** Apache-2.0
**Assets read:** 36 files. 2 Claude Code assets by the skill's definition (`plugins/clodex-plugin-builder/agents/api-scout.md`, `plugins/clodex-plugin-builder/skills/create-plugin/SKILL.md`); the value is in the 8 role prompts, 6 template/exec JSON files, README, 13 `docs/notes/*.md`, and `plugins/git-branches/VERIFY.md`.

## Summary

Clodex is an Electron fleet manager for Claude Code and Codex sessions (real PTYs, a message bus between agents, cost telemetry, cross-machine peering). The app itself is unusable here: `README.md` - "Requirements — Apple Silicon Mac, macOS 12+ (Intel and Linux build from source; Linux servers run the headless engine)." Nothing runs on Windows 11.

What is worth taking is the team kit under `resources/library/kits/default/prompts/system/`: three role prompts (lead, hand, reviewer) that encode the same orchestrator / builder / cold-reviewer loop the clodex author described in the Reddit post, but written down, and with measured failure rates attached to each rule ("15 of 27 later-round findings", "39% of later rounds", "65 reviews"). The single most valuable thing is that those disciplines can be lifted into agent files we do not yet have: the post's Builder, Refuter, and Researcher roles exist here only as ad-hoc Agent-tool dispatches with a `model` override. Only `scout`, `advisor`, and `brainstormer` are on disk in `~/.claude/agents/`.

## What they do better

| Their pattern | Source | Our equivalent | Gap |
|---|---|---|---|
| A test for when to delegate: "Delegate work whose OUTPUT you can verify without reading its INPUTS" | `resources/library/kits/default/prompts/system/lead.md` | Reddit-post heuristic ("one-line fix or a single grep, Fable just does it"), not on disk | worse |
| Escalate cold: "escalating up-tier only from a distilled failure note — cold, never by growing the cheap attempt's context" | `lead.md` | `project-orchestrator.md` "escalate instead of issuing a third round of notes"; memory `model-routing-ladder` | worse (no "cold" rule) |
| Builder resolves reversible ambiguity itself, stops only on irreversible or wrong spec | `hand.md` | superpowers `implementer-prompt.md` "**Ask them now.** ... Don't guess or make assumptions." | worse (blanket ask) |
| Commit before red-proof; red-proof every pin; record WHICH test went red | `resources/library/prompts/append/clodex-hand.md` | `~/agent-improvement/domains/testing.md` "Prove a new regression-detecting check is not vacuous by reverting the fix" | worse (lesson only, not in any builder prompt; no commit-first rule) |
| Comment-claim audit of every changed hunk after every fix (measured 15/27 later-round findings) | `hand.md` | none | none |
| Report shape: files + one line each, machine result, what resisted, deviations flagged | `hand.md` | superpowers implementer report (DONE / DONE_WITH_CONCERNS / BLOCKED) | roughly equal; theirs names the four sections |
| Reviewer verdict has a mandatory CHECKED section; "AN ACCEPT IS AN ARGUMENT" | `reviewer.md` | `advisor.md` "If you reviewed and found nothing wrong, say what you checked" | worse (advisor only; no reviewer file) |
| Reviewer with shell: "MEASURE, DO NOT DERIVE ... RUN the named test file ... Never run the whole suite" | `resources/library/prompts/system/clodex-team-reviewer-shell.md` | superpowers `task-reviewer-prompt.md` "Do not re-run the suite to confirm their report" (contradicts the post's Refuter practice) | worse |
| Shell-redirection warning for read-only reviewers: `>` bypasses a command deny list | `clodex-team-reviewer-shell.md` | none | none |
| ACCEPT-with-prose-nits is an ACCEPT; only two prose classes may reject | `lead.md` | `~/agent-improvement/loops/README.md` "Terminating review loops" requires an `exit_criterion` but names no nit classes | worse |
| Spec cites the commit it was written against; builder checks `git merge-base --is-ancestor` before editing | `lead.md`, `hand.md` | superpowers records BASE for the review package only | worse (no builder-side check) |
| Researcher rules: state version read, quote load-bearing rules, name doc+section not line numbers, "does not specify" is a real answer | `plugins/clodex-plugin-builder/agents/api-scout.md` | none (Researcher role has no file) | none |
| Manual verify docs tag every unchecked sentence `[unrun prediction]` | `plugins/git-branches/VERIFY.md` | `evaluate-repo` path+quote rule; no tag for manual-test docs | worse |
| Task artifacts live outside the repo: `~/.clodex/projects/<leaf>-<hash>/tasks/<task>/` | `lead.md` | handoff docs, location unstandardised | worse (minor) |
| Batch independent tool calls ("~80% of those could have ridden with their neighbour") | `reviewer.md` | harness-level guidance only | worse (minor) |
| Self-reminder on dispatch sized to the task | `lead.md` | `domains/tooling.md` "Wait-then-redispatch" lesson; `ScheduleWakeup` / `Monitor` | equal |
| "Never grade your own homework" | `lead.md` | `loops/README.md` maker-never-verifies | equal |
| Lead-authored review scopes were "the measured defect" | `lead.md` | `domains/verification.md` "the reviewer must not be primed with the plan's reasoning" | equal (converging evidence) |
| Fresh context per task via START CLEAN compaction | `hand.md` | superpowers fresh subagent per task | better (ours) |

## Recommended adoptions (ranked)

1. **Create `~/.claude/agents/builder.md`** (model: sonnet; tools: all except Agent) so the Sonnet Builder role stops being an ad-hoc dispatch. Carry these rules verbatim in spirit:
   - Do exactly the spec; flag scope changes, never take them silently.
   - Reversible ambiguity: choose the safest reversible option and flag it. Irreversible or a wrong spec: stop.
   - Check the cited commit is an ancestor of HEAD before editing.
   - Commit before red-proofing. Red-proof every new test. Report which test went red.
   - Before reporting and after every rework fix, reread every changed hunk with 25 lines of context and delete any comment, docstring, or changelog line the code no longer backs.
   - Report shape: files changed with one line each, machine result, what resisted, every deviation and assumption.
   - Never merge, never push.
   Evidence: `hand.md` - "If the spec is genuinely ambiguous on a REVERSIBLE point, make the safest reversible choice, proceed, and flag the assumption — don't burn a round-trip asking." / "If the spec is WRONG, not merely ambiguous — it names a function that doesn't exist, mandates an approach that breaks the tests, is unimplementable as written — that is a blocker, not something to silently reinterpret."
   Evidence: `resources/library/prompts/append/clodex-hand.md` - "RED-PROOF every pin before you close: for each test you added that guards a production change, put the old code back ..., run the test file, and write in JOURNAL.md WHICH test went red; then restore. COMMIT before you red-proof: putting the old code back is a revert, and a revert that reaches uncommitted work destroys it with nothing to restore from (hand-673 lost work exactly this way)."
   Evidence: `hand.md` - "open every hunk you changed with 25 lines of context and read each comment, docstring and CHANGELOG sentence in or beside it as a claim against the code as it now stands. ... measured on this loop, 15 of 27 later-round findings were exactly that, and each one cost a full review round."
   Evidence: `hand.md` - "One report per dispatch, distilled so the lead verifies WITHOUT pulling your raw work into their context: what changed (files + one line each), the machine result (test count, build), what resisted, and every deviation or assumption flagged explicitly. If the lead has to read your diffs to trust your report, the report failed."
   Effort: medium (one new file, ~80 lines).

2. **Create `~/.claude/agents/refuter.md`** (model: opus; tools: Read, Grep, Glob, Bash). This is the Opus Refuter with a shell, which superpowers' reviewer template actively discourages. Rules:
   - Read-only on the tree. Bash is for `git diff/log/show`, `cat`, `sed -n`, and one named test file. Never redirect into a file.
   - Run the named test file and quote the count; never derive a result, never run the full suite.
   - Verdict format: VERDICT (ACCEPT | REWORK), MUST-FIX with `file:line` and why, NITS, CHECKED.
   - Every criticism carries its fix. An ACCEPT states which risks were hunted and why they do not bite.
   - Batch independent reads into one request.
   Evidence: `clodex-team-reviewer-shell.md` - "MEASURE, DO NOT DERIVE. When a report claims a red-proof or a passing test, RUN the named test file with `node --test` in the branch worktree and quote the count. Do not reason about whether a test would fail; a derivation can be wrong, a run cannot. Never run the whole suite"
   Evidence: `clodex-team-reviewer-shell.md` - "What it CANNOT deny is a shell redirection: `>` and `>>` are shell syntax, not argv, so `echo x > file` writes and nothing stops it. Never redirect into a file, and never write through a command the deny list happens to miss."
   Evidence: `reviewer.md` - "AN ACCEPT IS AN ARGUMENT. When the work is sound, say WHY it holds under pressure — which risks you hunted and why they don't bite — not merely that you found nothing." / "EVERY CRITICISM CARRIES ITS FIX. A MUST-FIX or NIT without a concrete mitigation or alternative is an opinion, not a finding"
   Evidence: `reviewer.md` - "**CHECKED**: what you actually verified (files read, tests traced, cases reasoned through) — so the lead can see the pass's real coverage and trust the ACCEPT, or see the gap behind a REWORK."
   Effort: medium (one new file, ~60 lines).

3. **Create `~/.claude/rules/orchestration.md`** (auto-loaded like `codex.md`) holding the Reddit-post rules plus clodex's four sharper ones, so the orchestrator discipline lives on disk instead of only in a Reddit post:
   - Delegate only work whose output is verifiable without reading its inputs.
   - One dispatch, one report, zero mid-flight exchanges; a task needing conversation had a thin spec.
   - A 3-line fix in carried context is the orchestrator's; bulk loops go down-tier; escalate cold from a distilled failure note.
   - Size each task to one worker context; context pressure is a decomposition failure.
   - Every spec cites the commit it was written against.
   - Handoff and task artifacts live outside the repo (e.g. `~/.claude/projects/<project>/handoffs/`), never as loose files in the working tree.
   - Read every report's flagged deviations before calling a task done.
   Evidence: `lead.md` - "Delegate work whose OUTPUT you can verify without reading its INPUTS (tests green, build passes, symbol found). If verifying means pulling the worker's material into your context, you're paying twice — do it yourself or restate the task until verification is cheap."
   Evidence: `lead.md` - "Minimize your turns per delegation: one dispatch, one report, zero mid-flight exchanges. If a task needs conversation, the spec was too thin."
   Evidence: `lead.md` - "A 3-line fix in context you already carry is yours. A bulk loop (test-and-fix, mechanical refactor) goes down-tier, escalating up-tier only from a distilled failure note — cold, never by growing the cheap attempt's context."
   Evidence: `lead.md` - "Size every task to fit one worker context: spec in → work → report out, no mid-task compact. A worker hitting context pressure is a decomposition failure — split the task, don't grow the context."
   Evidence: `lead.md` - "Cite the commit your spec was written against, and tell the hand to stop if it is not an ancestor of its worktree HEAD."
   Evidence: `lead.md` - "Artifacts live OUTSIDE the project, under `~/.clodex/projects/<leaf>-<hash>/tasks/<task>/` — never in the user's own repo."
   Evidence: `lead.md` - "A report's flagged deviations and assumptions are yours to adjudicate before the task counts as done — they are the part of every report you always read, even when the machine result is green."
   Effort: low.

4. **Add the ACCEPT-with-nits carve-out to `~/agent-improvement/loops/README.md`, "Terminating review loops"** as a qualifying `exit_criterion` example: an ACCEPT whose nits are comment or changelog prose is terminal; only a false coverage claim or a false user-facing changelog line may reopen it. Also put the same two-class rule in `refuter.md`'s NITS guidance.
   Evidence: `lead.md` - "An ACCEPT whose nits are comment or CHANGELOG sentences is an ACCEPT: merge it. ... Rejecting one re-buys a full cold review of a mechanism a reviewer already passed: 39% of later rounds in this loop's corpus were exactly that, 57% prose, usually under 40 lines."
   Evidence: `lead.md` - "You keep the right to reject an ACCEPT for exactly TWO kinds of prose and nothing else: 1. a claim asserting COVERAGE — "pinned by X", "covered by test Y". ... 2. a CHANGELOG line making a false USER-FACING claim — it publishes verbatim."
   Effort: low. Complements the exit-criterion adoption from the 2026-09-08 reddit-ideas eval; does not repeat it.

5. **Create `~/.claude/agents/researcher.md`** (model: sonnet; tools: Read, Grep, Glob, WebFetch) for the Sonnet Researcher role, modelled on their api-scout: state the version of the thing read, quote load-bearing rules in a short block, cite document and section heading rather than line numbers for external docs, and treat "the document does not specify this" as a real answer. Keep `scout.md`'s `file:line` rule for code; this applies to docs and contracts.
   Evidence: `plugins/clodex-plugin-builder/agents/api-scout.md` - "Quote the contract for anything load-bearing, in a short block. A paraphrase of a rule is how a wrong rule gets propagated." / "Do not cite line numbers or ticket ids. They are stale the next release. Name the document and the section heading." / "State the version you read" / "If the contract does not answer it, say so. "`plugin-api.md` does not specify this" is a real answer and is far more useful than a plausible guess the caller will build on." / "Never invent an API."
   Effort: low.

6. **Add a verification lesson to `~/agent-improvement/domains/verification.md`**: in any manual-test or verify doc, every sentence either cites `file:line` or carries an `[unrun prediction]` tag, because unmarked prediction reads as checked fact and sends the human tester to expect the wrong thing.
   Evidence: `plugins/git-branches/VERIFY.md` - "So every sentence here now either cites a `file:line` or is marked **[unrun prediction]**. Nothing is softened — if a step fails, that is the point — but you should know which sentences have been checked and which are still guesses." / "three claims in it were wrong — an ungranted verb was said to fail silently (it bounces), a re-enable was said to log a line that does not exist, and a leaked timer was said to surface as a console error (it cannot). All three told you to expect the wrong thing"
   Effort: low.

## Rejected

| Their pattern | Why not |
|---|---|
| The Clodex app, `clodexctl`, peering, wirescope proxy | macOS arm64 or Linux headless only per `README.md`; this machine is Windows 11. The IPC intent grammar (`[agent:dm]`, `[agent:task]`, `[agent:team-review]`) only works inside their engine. |
| Comments default to NONE plus a `comment-ratchet` suite gate (`hand.md` - "Every reader of this code is an agent that can read the code. A comment earns its place only by naming a WRONG CHANGE it prevents") | Wrong for the PowerShell lane: `codex.md` requires `.NOTES` blocks with documented exit codes, and PDQ operators read scripts, not agents. The narrower rule (delete a comment the code no longer backs) is taken in adoption 1. |
| Builder delegates lookups and verify loops to its own subagents (`hand.md` - "DELEGATE THE LOOKUPS AND THE VERIFY LOOPS when the Agent tool is on your roster; keep every edit and every commit yourself") | The post's model already has Fable dispatching `scout` for lookups before the builder runs; a builder spawning its own scouts hides cost from the orchestrator. Superpowers' "You Do Not Dispatch Subagents" stays. |
| START CLEAN mid-ticket compaction, `[agent:context compact]` handoff notes | Their hands are persistent seats; ours are fresh subagents per task, which removes the problem. |
| `[agent:memory]`, `[agent:remind]`, DM federation, `[agent:notify-user]` | Native here: memory directory, `ScheduleWakeup`, `Monitor`, `SendMessage`, `SendUserFile`. |
| "NEVER background a process with `&`" (22-hour orphan) | Harness-managed via `run_in_background`; not our failure mode. |
| Exec commands as JSON-schema-granted, byte-capped digests (`resources/library/exec/clodex-run-tests.json` `"maxBytes": 1024`) | Needs their engine to enforce. The principle is already in `~/.claude/CLAUDE.md` ("Cap large command output"). MONITOR: a per-project one-line `TOTALS:` test wrapper is cheap if suite output starts flooding context. |
| Lead first-turn arms NEW / TAKEOVER / INTERVIEW | Tied to their `team create` flow. The read order for a takeover (README, manifest, test runner, changelog, then reconcile against the brief) is sensible but `superpowers:brainstorming` already covers intake. |

## Where we are already ahead

- **Fresh subagent per task.** Superpowers dispatches a new implementer per task; clodex needs a page of compaction rules (`hand.md` START CLEAN, "START CLEAN ON REWORK TOO, past ~150k") to manage persistent seats.
- **Maker never verifies** is already a loop convention in `loops/README.md`; their `lead.md` says the same ("Never grade your own homework on anything that matters").
- **Reviewer priming.** Our `verification.md` lesson (2026-08-06) says not to prime the reviewer with the plan's reasoning; their `lead.md` reports the same finding independently: "the ticket path builds its own scope from the record precisely because lead-authored scopes were the measured defect." Converging evidence, nothing to add.
- **Loop authority ladder, kill switch, retrospectives.** Their loop merges automatically on ACCEPT with no L1 report-only stage; ours ladders L1 to L3 with `paused`, `attempt_cap`, and `runs_since_retro`.
- **Cross-session messaging** is native (`SendMessage`, `ListAgents`), already recorded in the 2026-09-08 reddit eval.
- **Roster breadth.** The post's five roles (scout, researcher, builder, refuter, debugger) are finer than their three (lead, hand, reviewer). What clodex adds is the discipline text per role and the measurements behind it, not the roster.

## Repo health

HEAD `46ae0e1`, pushed 2026-09-10 (same day as this eval). 3 contributors, 44 stars, 0 open issues, Apache-2.0. 1265 paths, 466 under `test/`. Very active single-author style with heavy self-documentation (`docs/notes/` one file per module, `CHANGELOG.md`). `scripts/memory-tag/applied-live-20260801-094558/snapshot.clodex/` holds ~40 committed agent-memory `.md` files; not read, contents unknown, nothing copied. The prompts quote their own measured statistics (65 reviews, 15/27 findings, 39%/57% of rounds) which is why they read as evidence rather than opinion.

## Applied 2026-09-10

Adoptions 1, 2, 3, 5 built the same day, plus a `debugger` agent the post implied but the report did not list: `~/.claude/agents/builder.md`, `refuter.md`, `researcher.md`, `debugger.md`, and `~/.claude/rules/orchestration.md` (carries the marching-orders template, the ACCEPT-with-prose-nits rule from adoption 4, and the handoff path `~/.claude/handoffs/<project>/`). Still open: adoption 4 in `loops/README.md` and adoption 6 in `domains/verification.md`.
