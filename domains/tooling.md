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
