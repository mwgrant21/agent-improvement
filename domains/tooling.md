# Tooling Lessons

Durable, graded lessons about Claude Code tooling itself - background subagents,
orchestration, notifications, memory. Format per `README.md` in this directory.

### Wait-then-redispatch for unresponsive background subagents

- When a dispatched background subagent goes quiet and its in-progress transcript
  can't be inspected, give it a bounded wait rather than blocking indefinitely. If
  it still hasn't reported back after that, treat it as stuck and re-dispatch
  rather than waiting forever.
- Why: background subagents can stall silently with no way to peek at partial
  progress; without an explicit timeout policy the session blocks on a task that
  may never complete.
- Evidence: 2026-07-17 session (Aether OS reactor-core plan, final whole-branch
  review) - agent reasoned "I'll give it a bit more time... If it doesn't land
  soon, I'll treat it as stuck and re-dispatch rather than let it run
  indefinitely."
- Added: 2026-07-18 (home-matt)

### Distinguish a subagent's nested child notifications from its own final report

- When a dispatched background subagent itself spawns further background work
  (e.g., a dev-server check), an early notification may be a nested/child
  notification from that inner work, not the subagent's own completion report.
  Wait for the notification that actually matches the originally dispatched
  task before treating it as final.
- Why: acting on a nested notification as if it were the subagent's final report
  risks reading incomplete state as a finished result.
- Evidence: 2026-07-18 session (Aether OS Chat Phase 2b, Task 4 implementer) -
  agent identified "That's a nested notification from the implementer's own
  background dev-server check - not its final report. I'll wait for the actual
  completion notification before acting."
- Added: 2026-07-18 (home-matt)

### Order plan tasks so a type/action is defined before the task that produces it

- When writing a multi-task implementation plan where one task's code (e.g.
  an Electron/IPC layer) dispatches a new state action or type, and a later
  task defines that action/type in the reducer or state layer, reorder so the
  defining task comes first. Otherwise `tsc -b`/typecheck is transiently
  broken between the two tasks' commits.
- Why: caught during the plan's own self-review, before dispatch - avoids
  leaving the repo unbuildable between two committed tasks, which would
  otherwise force either an out-of-order task grouping or a broken
  intermediate commit.
- Evidence: aether-os Phase 3 Slice 7 (dispatch-usage tracking) plan
  self-review, 2026-07-24 - original draft had Task 2 = electron threading
  (dispatches `RECORD_DISPATCH_USAGE`), Task 3 = state/reducer (defines the
  action) - swapped so state/reducer became Task 2 and electron threading
  Task 3, with an explicit Global Constraints note added explaining the
  ordering.
- Added: 2026-07-24 (home-matt)

### Verify a research fork actually did real work before trusting its report

- A dispatched research fork/subagent can return a report without having made
  any real tool calls (no fetch, no file reads) - it just produces plausible-
  sounding prose. Before trusting a research subagent's findings, check that it
  shows evidence of real work (fetched URLs, read files, concrete quotes); if
  it looks thin or generic, relaunch it with explicit instructions to make real
  tool calls rather than accepting the first report.
- Why: an ungrounded "research" report is indistinguishable from a grounded one
  by tone alone, and downstream decisions (evaluate-repo verdicts, design specs)
  inherit its errors silently.
- Evidence: corroborated twice - 2026-07-30 session (Aether-OS, evaluate-repo
  fork) "The first fork returned without doing any actual research, so I
  relaunched it to fetch and analyze the repo for real"; 2026-07-30 session
  (code-graph-mcp design research) "The first research attempt returned
  immediately without doing any actual work, so I relaunched it with explicit
  instructions to make real tool calls."
- Added: 2026-08-02 (home-matt)

### Scope a process-kill step by install path or PID, not by process name

- Any plan step that kills a process before a build, install, or file swap must
  target the specific instance - filter on the executable's path under the project
  directory, or on a PID captured when that instance was launched. Killing by
  process name (`Stop-Process -Name app`, `taskkill /IM app.exe`) also kills the
  user's own running copy, any other checkout, and any packaged install of the
  same app.
- Why: it is a silent, out-of-scope destructive action on the user's environment,
  and it becomes far more likely exactly when it hurts most - v1-vs-v2 migrations,
  side-by-side comparisons, and dev-vs-packaged testing all mean two same-named
  processes are running on purpose.
- Evidence: 2026-08-05 session (TokenMonitorV2) - a plan step would have killed
  the user's other running app; caught before dispatch and rescoped to processes
  under `TokenMonitorV2`, then corrected in the two later tasks carrying the same
  instruction.
- Added: 2026-08-06 (work-it)

### Use absolute executable paths for Windows stdio MCP servers

- Configure a Windows stdio MCP server with an absolute path to its runtime (for
  example, `C:\\Program Files\\nodejs\\node.exe`) and an absolute server-script
  path; do not rely on an interactive shell's PATH.
- Why: MCP hosts spawn the child directly and can inherit a different or incomplete
  environment, causing a server that works in a terminal to fail at startup.
- Evidence: 2026-08-10 home-matt `code-graph` MCP registration initially hit a
  Windows PATH launch issue; changing both paths to absolute values made the Claude
  MCP health check report the server connected.
- Added: 2026-08-10 (home-matt)

### A config-snapshot repo whose documented recipe stops at "commit" protects nothing

- For a repo whose job is to mirror live config for another machine
  (`claude-config` mirroring `~/.claude`, dotfile snapshots, exported settings),
  the update procedure must end at PUSH, and the README must say so. A recipe
  that stops at "copy the file here and commit" buys local version history and
  zero cross-machine protection - which is the entire reason the repo exists.
- What to do: before trusting any such snapshot, DIFF it against the live file
  rather than reading its commit date; a snapshot can be days stale in content
  while looking maintained. Then fix the recipe, not just the drift.
- Why: the drift is invisible from the side that matters. The machine that needs
  the config never sees a missing push - it just quietly runs an old
  configuration, and the failure surfaces as "why doesn't my hook exist over
  here" weeks later.
- Evidence: 2026-08-06 session (claude-config) - the snapshot was last updated
  2026-07-22 and was missing the `PostToolUse` and `Notification` hook blocks
  plus three top-level keys, so a portability fix made that day did not reach
  the home machine at all. Root cause traced to the README's own instruction,
  "Update by copying the live file(s) here and committing" - no push step.
- Added: 2026-08-06 (work-it)

### Claude Code cannot switch its own model mid-session - routing is delegation via agent frontmatter

- A running session's model is resolved by the harness before inference. No
  skill, hook, CLAUDE.md line, or in-session instruction can change it. The only
  real levers are: `settings.json` `"model"` (session default), `/model`
  (manual), and `model:` in an agent's frontmatter (per subagent). "Route cheap
  work to a cheaper model" therefore means DELEGATE to a subagent that declares
  that model - not switch. There is likewise no automatic "escalate when stuck"
  trigger; escalation is a judgment call to dispatch, or a manual `/model`.
- Why: writing model-routing policy into CLAUDE.md is a control-plane/data-plane
  confusion. The file is data the assistant reads; model selection is resolved
  before it reads anything. The result is a documented policy that no component
  enforces - and it fails silently, because the text is present and looks obeyed.
- Evidence: 2026-08-11. "Everything keeps running on Opus" traced to a single
  line, `settings.json` `"model": "opus"`; the agents were already routed
  correctly. A token-tracker rule had been "remediating" this by upserting
  "Prefer Sonnet for short/trivial turns" into `~/.claude/CLAUDE.md`, which the
  assistant can read and can do nothing about. Separately, Aether-OS's deleted
  `modelPolicy.ts` (tier->model table) governed that app's own outbound API
  calls, never Claude Code's session model - a conflation worth not repeating.
- See also [[a-config-snapshot-repo-whose-documented-recipe-stops-at-commit]].
- Added: 2026-08-11 (work-it)

### `gh auth login` mints a fresh scope set - re-login silently drops scopes you still need

- To ADD a scope use `gh auth refresh -h github.com -s <scope>`, which is
  additive. To REMOVE one, a fresh `gh auth login` works - it mints a new token
  with the default scope set rather than the union - but it drops every
  non-default scope at once, not just the one being removed. After either, run
  `gh auth status` and compare the scope list against what the repos actually
  need.
- Why: the collateral loss is latent. Nothing fails at the time; the missing
  scope surfaces later as an unrelated-looking failure, and `workflow` is the
  common casualty - without it any `git push` touching `.github/workflows/` is
  rejected with a message that reads like a repo permission problem.
- Evidence: 2026-08-12. `delete_repo` was granted for a one-off repo deletion,
  then removed with a fresh `gh auth login` - which also dropped `workflow`,
  silently breaking future CI edits in four repos that have GitHub Actions.
  Restored with `gh auth refresh -s workflow`, which added it back without
  reinstating `delete_repo`.
- Added: 2026-08-12 (work-it)

### A device-code CLI login (`gh auth refresh`, `az login`) is a browser flow that never resolves on its own

- When `gh auth refresh -h github.com` (or `gh auth login`) is needed mid-session,
  it prints a one-time code and a URL (`https://github.com/login/device`) and then
  blocks waiting for the user to complete the flow in a browser - it will not
  progress on its own, and polling or re-running it does not help. Surface the
  code and URL to the user immediately, then wait for their explicit confirmation
  before retrying the blocked git operation.
- Why: treating it like any other CLI command that "just runs" wastes turns
  either silently waiting or re-invoking it, when the actual blocker is a human
  action in a browser the agent cannot see or trigger.
- The same holds for `az login`, with two extra traps. (1) NEVER launch a second
  `az login --use-device-code` while one is pending: each run mints its own code and
  the user cannot tell which is live - one session generated two competing codes and
  had to be told which to type. Ask the user to run it themselves via the `!` prefix
  and wait. (2) On a tenant with no Azure subscription, plain `az login` fails after
  the whole browser round-trip; use
  `az login --use-device-code --allow-no-subscriptions` on the FIRST attempt so the
  human does the sign-in once, not twice.
- Evidence: 2026-08-12 session (TokenMonitor/agent-improvement, home-matt) - push
  blocked twice (lesson sync and a PR branch) by an expired GitHub auth session;
  `gh auth refresh` returned code `E620-AA73` and the device URL, the agent
  surfaced both and waited, and the push succeeded once the user confirmed the
  browser step was done.
- Evidence (2): 2026-08-16 session (uw-router-teams-tab, work-it) - eight sessions
  of turnaround on a single `az login`: subscription-less tenant, then duplicate
  device codes, then a re-run for `--allow-no-subscriptions`.
- Added: 2026-08-15 (home-matt), updated 2026-08-21 (work-it)

### A CI-watching monitor can silently exceed its own timeout before the run finishes

- Do not treat a watch/monitor tool's silence or timeout as the final word on
  whether a CI run passed or failed. If the watcher times out before the run
  completes, follow up with a direct status query (e.g. `gh pr checks`) rather
  than assuming failure, re-polling blind, or leaving it unresolved.
- Why: the watcher's timeout is a property of the watcher, not of the CI run -
  a run that takes longer than the watch window can finish green while the
  watcher reports nothing, which looks identical to "still running" or "lost
  track of it" from the agent's side.
- Evidence: 2026-08-12 session (TokenMonitor, home-matt) - PR #43's CI monitor
  hit its 30-minute timeout without catching completion; a direct `gh pr checks`
  immediately after confirmed both `test-and-build` jobs (22.x, 24.x) had passed.
- Added: 2026-08-15 (home-matt)

### `run_in_background` can report exit code 0 for a GUI app that actually crashed

- Launching a GUI/Electron app via `run_in_background` is not a reliable
  reproduction method for a bug report: the process can throw and die, yet the
  background job still reports exit code 0. A clean exit code from a
  background-launched GUI app is therefore not evidence the app ran correctly
  - relaunch it in a real (foreground) terminal before trusting that signal,
  especially when reproducing a specific crash/bug report.
- Why: the false-positive exit code makes a crash look like a successful run,
  which would have led to closing or misdiagnosing the bug as unreproducible.
- Evidence: 2026-08-12 session (agent-improvement) - "launching this app via
  `run_in_background` will reliably fail this way, so #22 reproduction
  attempts need a real terminal; and the exit code was reported as 0 despite
  the throw, which means a background launch of this app can look successful
  while having crashed."
- Added: 2026-08-13 (work-it)

### A `||` fallback must never be a weaker version of the command it falls back from

- When a guarded command fails, `cmd-with-guard || cmd-without-guard` converts the
  guard's REJECTION into an unconditional execution - the safety check is not just
  bypassed, it is inverted into a trigger. If a compare-and-swap, a `--dry-run`
  gate, or a precondition check fails, stop and report; never let the fallback do
  the same operation with the check removed.
- Why: the fallback is written for the transport-error case ("the command didn't
  run") but fires identically for the safety case ("the command ran and said no").
  The outcome can still be correct by luck, which is what makes it survive review.
- Evidence: 2026-08-17 session (cli-shared-memory, work-it) - a `git update-ref`
  compare-and-swap with a guessed old-value SHA failed correctly, and the `||`
  fallback then ran the unguarded ref update. Fast-forward safety happened to have
  been verified separately with `merge-base`, so nothing broke.
- Added: 2026-08-21 (work-it)

### An MCP server that loses its transport stays broken for the session - restart, do not retry

- When an MCP tool starts failing mid-session because its underlying path or network
  route went away, retrying the call does not recover it and neither does waiting.
  The connection is established at session start; ask the user to restart Claude
  Code (or otherwise restart the MCP connections) rather than burning turns on
  retries or hunting for a bug in the request.
- Why: the failure surfaces as an ordinary tool error, which reads as "this call was
  wrong" rather than "this transport is dead," so the natural response is to retry
  with different arguments - which can never work.
- Evidence: 2026-08-16 session (UW Router flow, `power-automate` flowagent MCP,
  work-it) - the server needed a full terminal restart to reconnect; retries did
  nothing.
- Added: 2026-08-21 (work-it)

### Serialize fix-implementer dispatches that may touch shared files; only read-only dispatches (reviews) are safe in parallel

- When a multi-task plan needs post-review fixes applied to more than one
  already-committed task at once, dispatch those fix-implementers one at a
  time if their files could overlap, not in parallel. Reviews (read-only) can
  safely run in parallel against the same tree; writers cannot.
- Why: two implementers editing overlapping files at the same time risk a lost
  update or a merge conflict that neither implementer's own report would
  surface - the failure mode is silent until something actually collides.
- Evidence: 2026-08-15/16 session (cli-shared-memory git-arbiter build,
  home-matt) - self-caught mid-dispatch: "I also caught myself dispatching
  both fixes in parallel against shared files - no actual damage happened,
  but I'm watching closely." The same session later ran Task 1's fix
  re-review and Task 2's full review in parallel deliberately, noting "both
  read-only, so no repeat of the earlier dispatch issue."
- Added: 2026-08-22 (home-matt)

### The Bash tool's working directory does not reliably persist a bare `cd` across separate tool calls - verify inside the same chained command

- Do not rely on a `cd <dir>` issued in one Bash call to still be in effect for
  an unchained command in a later call, especially against a scratch/throwaway
  clone. Chain the `cd` and the git-mutating command together
  (`cd <dir> && <command>`), and verify the target with `git rev-parse
  --show-toplevel` inside that SAME chained command rather than trusting a
  prior `cd`.
- Why: this can silently fall back to the previous/default working directory,
  so a command intended for a disposable scratch clone instead runs against
  the primary working copy - indistinguishable from success until the wrong
  repository's state changes.
- Evidence: 2026-08-21 session (home-matt, tarot secrets purge) - several git
  branch/fetch operations meant for a disposable scratch clone actually ran
  against the primary `~/projects/tarot` working copy, briefly orphaning a
  real local commit (`swap-thoth-to-plate-keeps`) from its branch ref before
  it was caught via reflog and restored. Recorded as a near-miss in
  `tarot-repos-pending-items.md`.
- Added: 2026-08-22 (home-matt)

### `gh` subcommands backed by GraphQL can be down while the REST API still works

- `gh pr list`, `gh issue list`, `gh search`, and `gh pr comment` go through
  GitHub's GraphQL API and can 503 as a group while `gh api repos/...` REST
  endpoints answer normally. A wall of 503s from those commands is NOT evidence
  that GitHub is unreachable or that the repo is quiet - fall back to REST and
  finish the job.
- Why: for any sweep or triage that enumerates PRs/issues, a GraphQL outage
  otherwise renders as "nothing open," which is the silent-under-report failure
  class. Say which API answered when reporting results.
- Evidence: 2026-08-17 session (fleet triage across Aether-OS,
  claude-token-tracker, TokenMonitorV2, work-it) - 503s across every GraphQL-backed
  `gh` command; the REST fallback worked throughout.
- Added: 2026-08-21 (work-it)

### A tool named in a plan or doc is not evidence it is still maintained - check last-publish first

- Before adopting a named dependency that a plan, README or older doc prescribes, spend
  one command on whether it is still alive: `npm view <pkg> version time.modified
  deprecated` (or the registry equivalent). A package can be years unmaintained, or
  formally sunset with a maintained fork under a different name, while every document
  recommending it still reads as current.
- If you substitute, say so explicitly and record it in the plan - a silent swap leaves
  the next reader unable to tell whether the deviation was considered or accidental.
- Why: docs freeze at their writing date, and the plan being specific makes it feel
  authoritative. This is the "live re-probe, never trust a cached capability claim" rule
  applied to dependencies rather than to services.
- Evidence: 2026-08-29 TokenMonitorV2 (home-matt). The release plan specified
  `standard-version`; `npm view` showed its last publish as 2023-04-01 (sunset
  upstream). Its maintained fork `commit-and-tag-version` was at 13.1.2, published
  2026-07-28 - drop-in, same CLI and config.
- Added: 2026-08-29 (home-matt)

### A skill or agent present on disk but absent from the session listing may be disabled, not broken

- When something is in `~/.claude/skills` or `~/.claude/agents` but does not appear in
  the session's listing, check `skillOverrides` (and equivalent disable blocks) in
  `~/.claude/settings.json` BEFORE debugging the file's frontmatter, description or
  format. A disabled entry looks exactly like a malformed one from the session's side.
- The inverse is also worth knowing: moving an agent directory out of `~/.claude/agents`
  removes it from the roster, and the roster is the ground truth for whether definitions
  are actually being loaded and paid for in context on this machine.
- Why: the default assumption is a broken file, which sends you into frontmatter
  archaeology on something that is working exactly as configured.
- Evidence: 2026-08-24 (home-matt) skill-fleet triage. Four skills (`find-skills`,
  `frontend-design`, `mutation-test`, `penpot-uiux-design`) read as missing/broken; all
  four were disabled via `skillOverrides` in `settings.json`. The 2026-08-25 agent-fleet
  pass confirmed the roster reading directly - relocating the it-fleet agents dropped
  them from that session's roster.
- Added: 2026-08-29 (home-matt)
