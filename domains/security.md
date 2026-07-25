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
