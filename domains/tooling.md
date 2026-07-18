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
