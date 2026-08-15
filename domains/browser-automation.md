# Browser Automation Lessons

### claude-in-chrome does not see an already-open window automatically

- The extension's default new tab is blank until you explicitly call
  `tabs_context_mcp` (to discover existing tabs) or `navigate` to the target URL.
  Never assume a browser task can see whatever window/tab the user currently has
  open - ask for the URL or navigate there yourself.
- Why: without this, the agent stalls on a blank tab and has to ask the user for a
  URL mid-task instead of starting from `tabs_context_mcp`.
- Evidence: 2026-08-13 session, underwriting round robin Teams/browser work - agent
  reported "I only see a blank new tab - the extension can't see your existing
  window automatically" and had to ask for the tool's URL.
- Added: 2026-08-14 (work-it)
