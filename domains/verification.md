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

### Validation machines must represent the fleet's security-agent configuration

- Before declaring a fleet-wide change validated, confirm the pilot machines carry
  the same EDR/AV/security agent configuration as the fleet. If they do not, the
  validation proves nothing about the machines that will actually receive it, and
  an agent exclusion or suspension may be an unwritten prerequisite for the whole
  rollout.
- Why: security agents intercept exactly the low-level operations (process
  creation, disk/partition writes, driver load) that fleet remediation scripts
  perform, so an endpoint with an agent is a materially different target than one
  without - a distinction invisible in a pass/fail validation report.
- Evidence: 2026-08-04 sessions (EFIPartitionRemediation, Andrew's laptop) - Phase1
  killed a critical process twice on the same machine while the machines that had
  "validated cleanly" apparently did not represent the fleet. The EDR interaction
  itself remained a hypothesis pending a memory dump, but the representativeness
  gap was established regardless: "that's a prerequisite nobody has written down
  yet."
- Added: 2026-08-05 (work-it)

### A read-back verifier that compares the last physical line is defeated by records that may span lines

- When code appends a record and then verifies by re-reading the file, comparing
  only the file's LAST LINE against what was handed in is correct only while every
  record is exactly one physical line. The moment the format legally allows an
  embedded newline - RFC4180 CSV quoting, pretty-printed JSON, a multi-line log
  entry - the comparison sees only the record's tail, so a truncated or corrupted
  write verifies clean.
- What to do: compare the whole appended region (seek to the pre-write length and
  read forward), or parse the file back with the same reader the format demands.
  Match the granularity of the verification to the granularity of the record, not
  to the granularity of a line.
- Why: this fails in exactly one direction - false success. The verifier exists to
  catch partial writes, and it silently stops catching them the moment a quoting
  feature elsewhere in the codebase starts producing multi-line records. The two
  changes can land in different tasks, so neither task's review sees the pairing.
- Evidence: 2026-08-06 session (EFI-wt-migration) - `Add-RecordLine` verified by
  last-line comparison while Task 2's RFC4180 quoting had made a field containing
  a newline span multiple physical lines. Caught by task review before Task 5
  built on it.
- Added: 2026-08-06 (work-it)

### A defect authored into the plan survives faithful implementation - the reviewer must not be primed with the plan's reasoning

- In an implementer/reviewer pipeline, a bug that originates in the PLAN is the
  blind spot both roles share: the implementer reproduces it faithfully because
  reproducing the plan is the job, and a reviewer told "check this against the
  plan" confirms the match and passes it. The defect is invisible to conformance
  checking by construction - it can only be found by reviewing against
  correctness.
- What to do: when a suspected defect came from the plan itself, do NOT tell the
  reviewer where to look. An independent reviewer that finds it unprompted is
  evidence the review layer is real; one that has to be pointed at it has only
  confirmed your own reading. This is the deliberate exception to
  [[direct-reviewers-at-the-single-highest-risk-claim]] - prime the reviewer when
  the risk is an unverified IMPLEMENTER claim, stay silent when the risk is a
  defect in the spec they would both be conforming to.
- Why: conformance review and correctness review are different acts, and only the
  second catches spec-level bugs. Priming destroys the only evidence that the
  second is happening.
- Evidence: 2026-08-06 session (EFI-wt-migration) - two escalations in four tasks,
  both on plan-mandated defects that no implementer would have caught "because
  both were faithfully implementing the plan"; a later suspected plan-level defect
  was deliberately withheld from the reviewer to test unprompted detection.
- Added: 2026-08-06 (work-it)

### Grep finds stale filenames; it does not find stale concepts - read the operator-facing strings

- After deleting, merging, or renaming a script, grepping the repo for the old
  FILENAME proves only that no reference shaped like a filename survives. A
  stale instruction that names the removed thing by concept - "run the
  pre-flight first", "the gates live in the checker script" - matches no
  pattern and sails straight through a clean grep.
- What to do: for operator-facing text (READMEs, prompts, on-screen
  instructions, runbooks), READ the strings rather than search them, and treat
  "grep came back empty" as covering the mechanical half of the audit only. When
  an audit method has already missed once, put a second pair of eyes on the
  conclusion, not just on the fix.
- Why: the failure is silent and lands on the operator, who follows a documented
  step that no longer exists. It also produces false confidence: an empty grep
  reads as a completed sweep.
- Evidence: 2026-08-06 session (EFI-wt-migration) - filename matching found the
  first stale instruction and missed the second, which referred to "the
  pre-flight" as a concept; a follow-up implementer's "nothing else found" claim
  did not survive checking either. Related: prime the reviewer at the weak claim
  per [[direct-reviewers-at-the-single-highest-risk-claim]].
- Added: 2026-08-06 (work-it)

### Tell the reviewer which failures are meant to fail OPEN, or correct behaviour gets flagged as a defect

- In a codebase where nearly everything fails closed, a reviewer pattern-matches
  "fail closed = correct" and will report a deliberately fail-open path as a bug.
  Before dispatch, name the steps that are best-effort - forensics, telemetry,
  optional logging, a diagnostic registry setting - and state that their failure
  must NOT abort the operation.
- What to do: classify each guard as blocking a *correctness/safety
  precondition* (fail closed) or degrading *observability* (fail open), and put
  that classification in the reviewer's brief and in the code comment. A machine
  whose registry will not accept a forensics setting is still perfectly
  operable; it just yields worse evidence if something goes wrong.
- Why: the cost is not only a wasted finding. Acting on it converts a working
  path into a refusal, so a review pass can make the tool strictly less usable
  while appearing to harden it. Note this is the mirror of
  [[a-defect-authored-into-the-plan-survives-faithful-implementation]] - stay
  silent about suspected spec defects, but be explicit about intended
  fail-open behaviour.
- Evidence: 2026-08-06 session (EFI-wt-migration) - a reviewer brief was written
  to head this off: "Everything else in this codebase fails closed, so a
  reviewer pattern-matching on 'fail closed = correct' could easily mark the
  right behaviour as a defect here."
- Added: 2026-08-06 (work-it)

### A probe that cannot distinguish "not yet" from "never" is not a verification

- Before trusting a probe as proof, ask what a negative result actually rules out. Some
  APIs report on state that is populated lazily, so a falsy answer means either "the
  thing is broken" or "nothing has demanded it yet" - and the probe cannot tell you
  which. Prefer the API that FORCES the work and then reports, over the one that only
  observes current state. Concrete instance: `document.fonts.check(spec)` never triggers
  a font fetch, so in an offscreen/unpainted window it returns `false` for a perfectly
  correct `@font-face`; `await document.fonts.load(spec)` forces the fetch and its
  result (empty array / rejection) is real evidence about the URL.
- Why: this failure mode is worse than no check, because it manufactures false alarms
  that get "fixed." Following the probe's stated criterion would have meant rewriting
  correct paths to chase a `false` that only reflected laziness. The same shape appears
  wherever state is demand-driven: caches, lazy imports, connection pools, deferred
  registrations. Related: a green suite can still be wrong
  [[a-test-suite-can-be-unanimously-green-and-still-wrong]].
- Also: when the probe is a plan's stated acceptance criterion, correct the plan once the
  gap is found - a known-wrong criterion re-fires on the next reader.
- Evidence: 2026-08-06 session (TokenMonitorV2, reskin Task 3) - the plan specified
  `document.fonts.check('700 12px Rajdhani')` expecting `true`, with `false` meaning a
  bad path. First run returned `false` for all six faces with ZERO failed network
  requests and every face registered as `unloaded`; switching to `document.fonts.load()`
  returned `loaded`/`true` for all six against the same unchanged CSS.
- Added: 2026-08-06 (work-it)

### Types, tests, builds, and CI all green says nothing about the visual layer - name that gap explicitly

- When every gate a session ran was structural (typecheck, unit tests, build,
  CI), do not let "all checks pass" stand in for the app having been looked at.
  If the change alters what a user sees, either open the app and look, or write
  the unverified check down where the next reader will hit it (`PROGRESS.md`
  under "Not verified", the PR body) - as an outstanding item, not a caveat
  buried in prose. Mounting without errors is not the same as the cards
  rendering sensible numbers.
- Why: structural green reads as done to everyone downstream, so an unstated
  visual gap ships silently and gets discovered by the user. Stating it costs
  one line and converts an invisible risk into a tracked task. This is the
  general case of [[inspect-the-artifact-itself-not-proxies]] - a passing suite
  is a proxy for the artifact, not the artifact.
- Evidence: 2026-08-07 session (Aether-OS, Stages 14-15) - the Ledger view was
  merged to `master` with every structural gate green while "nobody has opened
  the app"; the gap was recorded in `PROGRESS.md` and the PR body rather than
  left implied, and a later session confirmed only that it mounts and the nav
  entry and copy render - the cards with real numbers in them were still unseen.
- Added: 2026-08-07 (work-it)
