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

### A final whole-branch review is required after task-level reviews - it catches cross-task interaction bugs no single task's review can see

- In a multi-task implementer/reviewer pipeline, per-task review confirms each
  task matches its own brief but cannot see how tasks interact once combined.
  Always run one final review of the whole branch/diff after every task has
  individually shipped clean, before merge.
- Why: repeatedly, the whole-branch pass found real, previously-invisible bugs
  that every individual task review had already passed - because the defect
  only exists in the interaction between two tasks' changes, not within either
  task alone.
- Evidence: two separate 2026-07-27/28 aether-os multi-task branches. On
  `chat-ipc-correctness` (7 tasks, all individually reviewed clean), the final
  whole-branch review (run on Opus) found a compiled-`.js`-shadowing-source
  issue and a silent key-parsing divergence between dev and Electron modes -
  see [[a-stale-compiled-js-file-can-silently-shadow-its-ts-source]]. On
  `fleet-session-picker` (12 tasks, all individually reviewed clean), the final
  whole-branch review "caught two real Important issues no task-level review
  could see (both cross-task interactions)," fixed in one wave and re-reviewed
  clean before merge.
- Added: 2026-07-29 (work-it)

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

### In a live, irreversible-risk incident, demand real diagnostic output before recommending any next step

- During active incident response where a wrong guess could turn a
  recoverable state into an unrecoverable one (e.g. a boot failure mid-
  remediation), do not infer the system's state or suggest a fix from
  what's merely plausible - ask for the actual command output (partition
  table, `bcdedit /enum firmware`, directory listings) and wait for it
  before recommending or issuing the next step, even under the user's time
  pressure.
- Why: this is distinct from post-hoc artifact inspection (see "Inspect the
  artifact itself, not proxies" above) - it's about withholding action
  during a live, high-blast-radius incident until the real state is
  confirmed, not about how a finished output was verified afterward.
- Evidence: 2026-08-04 session (EFIPartitionRemediation boot-failure
  incident) - repeatedly declined to recommend boot-menu/BCD choices from
  inference alone: "I'd rather confirm than have you guess under time
  pressure," and asked for `diskpart list volume`, `dir D:\Windows`, and
  `bcdedit /enum firmware` output at each step rather than acting on the
  probable diagnosis.
- Added: 2026-08-04 (work-it)
