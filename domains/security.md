# Security Lessons

Durable, graded lessons about security-relevant fixes (path/input validation,
credential handling, sandboxing) confirmed across projects. Format per
`README.md` in this directory.

### A basename-only filename check does not stop path traversal - use resolve()-based containment

- When validating a renderer/user-supplied filename against path traversal
  (e.g. an Electron IPC handler like remove/thumbnail/open), a
  `path.basename(input) === input` equality check alone is insufficient - a
  bare `..` passes that check (`basename('..') === '..'`) yet still resolves
  outside the sandboxed directory. Combine the flat-name check with a
  `path.resolve()`-based containment check (resolve the candidate path,
  confirm it stays under the intended root) before performing any fs
  operation.
- Why: verified directly - live `node` calls showed `open('..')` opened
  `~/.aether-os`, one level outside the intended attachments sandbox, even
  after the basename-only fix was in place. Only the resolve()-based
  containment check closed it, independently re-confirmed across three
  separate review passes (up to 19 traversal vectors under win32 semantics in
  the final one).
- Evidence: aether-os Files/Attachments slice, Task 2, 2026-07-23 - round 1
  (basename-equality) left a bare `..` escaping the sandbox by one directory,
  verified via live node calls; round 2 (resolve()-based containment,
  `assertSafeName`) closed it, re-verified by an 11-case reviewer script and
  later a 19-vector final whole-branch review.
- Added: 2026-07-24 (home-matt)

### Warn before a secret enters the chat transcript, and offer the `!`-command alternative

- When a user is about to paste a live credential or API key directly into
  chat (e.g. to wire up a test run), proactively warn that the value will be
  visible in the session transcript before they paste it, note that it can be
  rotated afterward if that's a concern, and point to the `!`-prefixed
  shell-command method as a way to use the secret without it landing in the
  transcript at all.
- Why: pasting a live secret into chat is often the fastest path for the user
  in the moment, but the transcript-visibility tradeoff is easy to overlook
  unless it's raised before the paste, not after.
- Evidence: 2026-07-24 session (claude-token-tracker Electron test run) - agent
  flagged "Quick heads-up since you picked this route: the key will be visible
  in this chat transcript... you can still rotate it in the Anthropic console
  after the test run, or switch to the `!`-command method" before the user
  pasted an `sk-ant-` key.
- Added: 2026-07-29 (work-it)
