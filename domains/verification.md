# Verification

### Inspect the artifact itself, not proxies

- When verifying assets or outputs (images, shipped files, build artifacts), open
  and look at the actual artifact and at what actually ships. Do not conclude from
  proxies like git history, MD5/hash comparisons, or folder names.
- Why: proxy reasoning sent a session in a circle comparing hashes of two web
  folders while the real answer was visible by opening the images and checking
  what the Android app actually bundled. The user's direct pointer to the real
  asset folder resolved it immediately.
- Evidence: 2026-07-13 session (tarot/TarotApp asset port) - agent self-reported
  "I'll open the pixels first next time" after a user correction.
- Added: 2026-07-13 (home-matt)

### Direct reviewers at the single highest-risk claim, not a generic diff pass

- When dispatching a reviewer in an implementer/reviewer pipeline, name the one
  specific claim in the task most likely to be wrong or unverified (a claimed
  visual/dev-server check, a claimed build-output path, a claimed grep result, a
  claimed bundle-freshness check, boundary arithmetic, an exact-string
  transcription) and instruct the reviewer to independently reproduce that claim
  from scratch - not just confirm the code matches the brief. This also catches
  implementers who quietly substitute an easier verification method (e.g. "build
  succeeds") for the harder one the brief actually required (e.g. "visually
  confirmed in the running app"). After a fix, also check whether the same bug
  pattern recurs elsewhere in the pipeline before calling it done.
- Why: a generic "does this match the brief" review passes silently-wrong claims;
  a targeted independent reproduction of the one claim most likely to be
  unverified catches exactly the failures tests and casual review miss.
- Evidence: recurring across many 2026-07-18/19/20 sessions (TokenMonitor/aether-os
  multi-task pipelines) - reviewers were specifically instructed to: re-verify
  corrected build-output paths rather than trust the implementer's report;
  actually attempt a tab-switch persistence check instead of accepting it
  unverified; hand-verify date-boundary arithmetic rather than confirm
  code-matches-brief; independently reproduce a bundle inspection from scratch
  "since this is exactly the class of thing that's silently broken twice before
  in this migration"; and check whether a cache-token bug pattern was duplicated
  elsewhere in the pipeline after the fix landed.
- Added: 2026-07-20 (home-matt)

### Cross-check a research subagent's findings against the actual codebase

- When a dispatched research/exploration subagent reports findings that sound
  generic or textbook-plausible, verify the specific claims (config file
  presence, specific API calls used) against the real codebase directly before
  relying on the report - don't take the description at face value.
- Why: an exploration subagent described a plausible-sounding architecture
  (TrustedHosts config, WinRM handling) for a toolkit that, on direct check,
  had zero matching config and zero matching API calls - it had described a
  different/hypothetical toolkit, not the one actually being explored.
- Evidence: 2026-07-19 session (NMMTools capability-catalog research) - agent
  found "no TrustedHosts config anywhere, and zero Get-WmiObject/Invoke-WmiMethod
  calls... That agent appears to have been describing a different/hypothetical
  toolkit, not this one."
- Added: 2026-07-20 (home-matt)
