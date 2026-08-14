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
