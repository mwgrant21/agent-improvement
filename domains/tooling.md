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
