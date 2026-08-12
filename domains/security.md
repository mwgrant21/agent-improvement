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

### A suspected secret in git history is a human-decision escalation, not an autonomous investigation

- When a suspected real credential (e.g. a keystore password) may have been
  committed to a still-public repo's history, escalate it as a High Priority
  item for the user to confirm and decide on (was a real secret exposed? is a
  history rewrite + credential rotation warranted?) rather than digging
  further or attempting a fix autonomously. History rewrites (BFG/`git
  filter-repo`) and credential rotation are high-stakes, hard-to-reverse
  actions that need the repo owner's call, not an agent's.
- Why: an agent-led investigation or rewrite of git history for a suspected
  leaked secret risks acting on an unconfirmed finding with an irreversible
  tool; the correct first move is surfacing the question, not answering it.
- Evidence: 2026-08-03 session (TarotApp daily-triage sweep) - a possible
  keystore password in a public commit was flagged and escalated as High
  Priority with the explicit questions "was the real keystore password ever
  committed to a still-public commit, and if so, is a history rewrite... plus
  a fresh credential rotation warranted?" rather than acted on directly;
  later closed out only after the finding was confirmed (no real secret was
  ever actually committed).
- Added: 2026-08-04 (work-it)

### When retiring a paid-API integration, check for key leakage into spawned child processes, not just the direct SDK call path

- Removing a feature's direct SDK usage (imports, API calls) is not sufficient
  to guarantee no more calls can happen. If the app auto-launches a child
  process or pty (e.g. a `claude` CLI session) that inherits the parent's
  environment, a leftover `ANTHROPIC_API_KEY` (or similar) in that environment
  lets the child make paid calls even after the integration code is deleted.
  Scrub the env var from the spawn call, not just delete the SDK code.
- Why: a final whole-branch review that traced "does *any* path remain for a
  paid API call" (rather than trusting the removal PR's own test) found this
  exact gap - the actual mechanism most likely behind the incident that
  prompted the teardown in the first place.
- Evidence: 2026-08-04 session (TokenMonitor Chat-feature teardown branch,
  Task 2/final-review fix wave) - `ANTHROPIC_API_KEY` was still present in the
  environment of an auto-launched `claude` pty after the Chat feature's SDK
  code, `.env` key loading, and IPC surface were removed; scrubbing it from
  the pty spawn closed the last live path, independently re-verified in a
  scoped re-review.
- Added: 2026-08-05 (home-matt)

### Removing a secret from the build - or gitignoring it - does not rotate the secret

- A branch that strips a hardcoded token from the source and stops future builds
  from bundling it changes nothing about the copy already sitting in the install
  directory of every machine deployed before the fix. The vulnerability window
  does not close at merge; it closes at rotation.
- The same holds for the containment moves that feel like fixes: adding a
  `.gitignore` rule for an untracked `.env`, un-staging a file, or deleting it
  from the working tree. Ignored is not rotated. Those steps stop the NEXT
  exposure; they say nothing about whether the key is still live or who has
  already seen it.
- What to do: treat "stop shipping it" and "rotate it" as two separate items and
  say so explicitly. Keep rotation out of the automated scope - it is a human
  decision with blast radius - but never let the merged fix imply the exposure is
  resolved. Carry it as an open item until the user confirms rotation.
- Why: the code change is visible and satisfying and produces a green branch,
  which is precisely what makes it easy to mistake for remediation. The live
  credential is unaffected by any amount of clean code.
- Evidence: 2026-08-05 sessions (TokenMonitorV2) - a deployed GitHub token
  remained live on already-deployed machines after the branch removed it from the
  build; flagged repeatedly as out of scope and still outstanding at session end.
  Corroborated 2026-08-06 (Aether-OS) - an untracked `.env` holding a possibly-live
  key was protected only by never having been staged; adding the `.gitignore` rule
  closed the exposure route and was explicitly recorded as not closing the key
  ("Ignored != rotated"). Both remained open credential decisions for the user.
  See [[when-retiring-a-paid-api-integration-check-for-key-leakage]] for the
  companion case on the same project.
- Added: 2026-08-06 (work-it), updated 2026-08-06 (work-it)

### Match hardening effort to the actual threat model before recommending it

- Before proposing security hardening (ACL tightening, SID sets, inheritance
  rules, verification pipelines), name the concrete threat actors first: other
  local accounts, local admins, SYSTEM, malware under the user's own token.
  On a single-user Windows machine with no other logins, no shared service,
  and no elevation boundary, most of these threats either don't exist or
  can't be defended against with ACLs anyway (admins/SYSTEM can always take
  ownership; malware under the user's token already has the user's access).
  Proposing enterprise multi-tenant hardening (explicit SID grants, reparse-
  point handling, ACL repair/verify UI) in that context is engineering effort
  spent on theater, not defense - and it displaces time from the gaps that
  are actually real (in this case, project scoping and dispatch persistence).
- Why: an adversarial review had flagged the missing hardening as a "critical
  gap," but a threat-model walkthrough showed Windows' default inherited
  ACLs already exclude non-admin accounts since Vista, and no proposed
  control changed the admin/SYSTEM/malware-under-own-token picture at all.
- Evidence: 2026-08-10 session (aether-os `~/.aether-os/` ACL hardening
  question) - walked through each threat actor, found the SID-set/
  inheritance/reparse-point engineering addressed only enterprise multi-
  tenant scenarios, and recommended dropping it entirely for a confirmed
  single-account machine in favor of two real functional gaps.
- Added: 2026-08-11 (home-matt)
