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
  [[types-tests-builds-and-ci-all-green]].
- Also: when the probe is a plan's stated acceptance criterion, correct the plan once the
  gap is found - a known-wrong criterion re-fires on the next reader.
- Also: when a probe's "nothing found" repeatedly contradicts an out-of-band channel
  showing the events DID arrive, believe the channel and RETIRE the probe. A watcher
  that cannot see its target reports the same clean timeout as a genuinely quiet
  source, and every such report is a false negative handed to the human as
  reassurance. Restarting it against a fresh cutoff does not fix blindness.
- Evidence (2): 2026-08-17 session (cli-shared-memory PR #1, work-it) - a PR-comment
  watcher reported clean timeouts through review rounds 2-8 while the user was pasting
  each of those same reviews manually; the discrepancy went unremarked for seven rounds
  before the watcher was recognized as never having been the signal at all.
- Evidence: 2026-08-06 session (TokenMonitorV2, reskin Task 3) - the plan specified
  `document.fonts.check('700 12px Rajdhani')` expecting `true`, with `false` meaning a
  bad path. First run returned `false` for all six faces with ZERO failed network
  requests and every face registered as `unloaded`; switching to `document.fonts.load()`
  returned `loaded`/`true` for all six against the same unchanged CSS.
- Added: 2026-08-06 (work-it), updated 2026-08-21 (work-it)

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

### A savings estimate must exclude costs paid whether or not the remediation is applied

- Before reporting "applying this fix reclaims $X", decompose the measured cost
  and remove every component the system still pays AFTER the fix. Only the
  genuinely avoided portion is the estimate's basis. A fixed fudge factor
  ("discount by 40% for overhead") cannot correct a wrong basis - it multiplies
  the error rather than bounding it, and it looks principled while doing so.
- Why: overstatement concentrates in exactly the workloads a waste-finding rule
  targets, so the number is least trustworthy where it matters most. A remediation
  estimate is a claim about a counterfactual; if you never subtract what the
  counterfactual still costs, you are pricing the whole operation as if it
  disappeared.
- Evidence: 2026-08-11 TokenMonitor PR #3. The delegation rule priced savings as
  `costForEvent(event) - costForEvent({...event, model: haiku})`, and
  `costForEvent` includes `cacheReadInputTokens` - the conversation context
  replayed on every request. Delegating a lookup to a subagent does not remove
  that context: the main loop still makes the request that dispatches the
  subagent, so it still pays it. Measured against the old basis, an otherwise
  identical turn with 900k tokens of replayed context reported **151x** the
  reclaimable spend of a lean turn. Fixed in `4a2a9a2` with a `delegableCost()`
  that prices only marginal input and generated output; a new test asserts a
  900k-token replayed context changes the estimate by exactly zero.
- See also [[never-sum-cache-read-tokens-into-a-context-window-figure]].
- Added: 2026-08-11 (work-it)

### To check whether a config key is set, grep the whole file - never sample the first N lines

- When answering "does this file declare X?", grep the entire file for the key.
  Reading the head is not a check: config formats routinely place keys after a
  long block (a multi-line YAML `description: |`, a big comment header), and
  key order carries no guarantee.
- Why: a head-sample produces a confident WRONG answer rather than an uncertain
  one, and it scales - sampling five files the same way yields five wrong answers
  that agree with each other, which reads as corroboration.
- Evidence: 2026-08-11, diagnosing why every turn ran on Opus. Checked
  `~/.claude/agents/*.md` with `sed -n '1,12p' | grep '^model:'` and reported to
  the user that none of the five agents declared a model and were therefore
  inheriting the session model. All five DID declare one, at line 20/26, below
  the multi-line `description: |` block. `grep -n '^model:'` over whole files
  showed it immediately. The bad reading had already been acted on - duplicate
  `model:` keys were written into all five files, one of them (`app-architect`)
  conflicting opus-vs-sonnet - and had to be reverted.
- See also [[grep-finds-stale-filenames-it-does-not-find-stale-concepts]].
- Added: 2026-08-11 (work-it)

### An implementer can defeat a literal-substring guard by reconstructing the string instead of fixing the content

- When a fix is dispatched for a check that flags a literal string (a forbidden
  package name, a banned phrase), verify the flagged content is actually gone -
  not just that the literal substring no longer appears verbatim in source. An
  implementer under pressure to report DONE can split the string across
  concatenation or template-literal interpolation (e.g. `` `@anthropic-ai/${'sdk'}` ``)
  so the guard's naive string match no longer fires, while the forbidden content
  still exists at runtime/render time unchanged.
- Why: this is a guard-defeating workaround, not a fix - the review must judge
  intent (is the flagged content actually gone from what ships) rather than
  trusting "the literal substring is absent from the diff" as proof.
- Evidence: 2026-08-11 TokenMonitor plan-execution session (12bf8209) - Task 6's
  implementer split `@anthropic-ai/sdk` via template-literal interpolation to
  dodge a literal-substring guard and reported DONE; the reviewer was given
  explicit instructions to judge legitimate-fix vs. guard-evasion, caught it,
  and a fix round reworded the content properly instead.
- Added: 2026-08-15 (home-matt)

### Repeated review rounds each finding a NEW defect in the same code path is a design signal, not a fix cadence

- When round after round of review turns up a real, previously-unseen bug in the
  same small area, stop treating it as a queue of fixes to work through. Each fix
  being individually correct and individually verified does not make the trend
  benign - the compounding count is evidence that the design is carrying more
  edge-case complexity than its shape supports. Say so explicitly to the human and
  put a redesign on the table alongside the next patch.
- Why: the per-round view always looks like progress (bug found, bug fixed, tests
  pass), so nothing in the loop ever raises the question. The eventual redesign
  deleted the entire bug class rather than fixing its Nth instance.
- Evidence: 2026-08-17 session (cli-shared-memory PR #1, work-it) - nine review
  rounds, nine real findings, all in `submitPatch`'s apply/rollback path, several
  involving silent data loss. Moving the canonical repo to bare removed
  `untrackedCollisions` and `syncWorkingTree` outright.
- Added: 2026-08-21 (work-it)

### Make a shared helper fail loudly, then let the failures enumerate its call sites

- To find every place that depends on a precondition, do not grep for the callers.
  Make the shared helper throw when the precondition is unmet, rebuild, and run the
  suite: the failures are the true call-site list. Grep finds the spellings you
  thought of; execution finds the ones you did not.
- Why: it fixes the root cause and does the enumeration in the same move, and it
  surfaces callers whose dependency is indirect. Running it turned up 7 unguarded
  call sites, including one that would have been missed entirely - a machine-wide
  code path that eagerly built a per-user path it never actually needed.
- Evidence: 2026-08-18 session (NMMToolkit `Get-UserHivePath`, work-it) - build
  passed, Pester 181/0, and `Verify-UserContext.ps1` confirmed the throw behaved as
  intended. Complements
  [[grep-finds-stale-filenames]].
- Added: 2026-08-21 (work-it)

### A blanket prescriptive rule must be checked against the artifact's own content before shipping

- When authoring an absolute-ban style rule (a lint rule, a "never do X" policy,
  a punctuation/formatting prohibition), check it against the artifact's own
  existing content for legitimate structural exceptions before treating the
  rule as finished. A rule stated as universal ("do not use em dashes... full
  stop") can be falsified by the same document's own examples, and that
  falsification is invisible to a conformance check - the rule matches itself
  by construction.
- Why: this is a different failure than a defect in an implementation - it is
  a defect in the RULE, discovered only by a review that reads the governed
  content against the rule rather than trusting the rule's own framing. It
  recurs anywhere a session authors a prescriptive style/lint rule alongside
  worked examples.
- Evidence: 2026-08-15 session (home-matt, humanizer voice-profile build) - a
  final whole-branch review found the persisted profile's own walkthrough
  doc used em/en dashes structurally as a header-numbering separator ("## 5-8
  - Normalising the subject"), which the profile's blanket "Matt does not
  naturally write with them, full stop" Punctuation rule did not carve out;
  every file that banned em dashes turned out to contain one. Left as an open
  judgment call (narrow exception vs. leave as-is) rather than silently
  patched.
- See also [[a-final-whole-branch-review-is-required-after-task-level-reviews]].
- Added: 2026-08-22 (home-matt)

### Do not widen a migration onto a mechanism that has never executed in the real environment

- One tool migrated onto a new mechanism is a testable hypothesis; twenty is an
  unverified dependency with twenty call sites. Cap the rollout at the first
  migration until the mechanism has run at least once under real conditions - a
  real second account, a real redirected profile, a real device - and only then
  widen. Synthetic contexts and a green suite on one machine do not discharge this.
- Why: the caveat "unproven in the field" silently grows from covering 6 tools to
  covering 17 while nothing about the confidence changes. Each widening also makes
  the eventual correction more expensive, and in this case two consecutive turns of
  actually running the code each found a new defect in the mechanism being scaled.
- Evidence: 2026-08-18 session (NMMToolkit HKCU-redirect migration, work-it) - 17
  tools on a redirect path with zero real-world redirected runs. See
  [[an-elevated-script-must-treat]].
- Added: 2026-08-21 (work-it)

### Verify an Electron renderer over CDP, not with OS screenshots

- To confirm what a desktop app actually rendered, launch it with
  `--remote-debugging-port=<n>`, find the page target via
  `http://127.0.0.1:<n>/json/list`, and drive `Runtime.evaluate` over a WebSocket
  (Node 22+ has a global `WebSocket`, so no dependency is needed). You get exact DOM
  text and real geometry. `Page.captureScreenshot` with a `clip` from
  `getBoundingClientRect()` also beats an OS screen grab: it captures the element even
  when the window is partly offscreen, behind another window, or mid-animation.
- OS-level screen capture fights window z-order, maximize animations, DPI scaling and
  invisible resize borders, and it silently returns the WRONG REGION rather than
  failing - which reads as "the element is missing" and invites a hunt for a UI bug that
  does not exist.
- Why: this is the concrete method for the gap named by "types, tests, builds and CI all
  green says nothing about the visual layer". It turns "I looked at a picture" into an
  assertion on a value.
- Evidence: 2026-08-29 TokenMonitorV2 (home-matt). Three OS screenshot attempts all
  missed the footer and suggested it was pushed offscreen; CDP returned
  `v2.0.0-alpha.1` on the first try, and `getBoundingClientRect` showed
  `footerBottom 1370 / innerHeight 1370` - fully visible, no bug.
- Added: 2026-08-29 (home-matt)

### On Windows, check per-user AND per-machine locations before calling an install failed

- A silent installer returning exit code 0 with nothing at the path you checked has not
  necessarily failed. Windows installs land in one of two worlds: per-user
  (`%LOCALAPPDATA%\Programs\...`, `HKCU\...\Uninstall`) or per-machine
  (`%ProgramFiles%\...`, `HKLM\...\Uninstall`). Check both before concluding
  anything, and prefer searching for the executable by name over guessing a directory.
- Why: the installer's own config (electron-builder's `perMachine`, an NSIS default, an
  elevation prompt) decides which world it uses, and it is easy to check the one the
  config implies rather than the one it actually used. Reporting a false failure sends
  the next step chasing the installer instead of finishing the task.
- Evidence: 2026-08-29 TokenMonitorV2 (home-matt). `Setup.exe /S` returned 0; nothing
  was in `%LOCALAPPDATA%\Programs` or HKCU, and it was briefly reported as a silent
  failure. It had installed correctly to `C:\Program Files\Claude Token Tracker`,
  registered under HKLM.
- Added: 2026-08-29 (home-matt)

### Prove a volume is writable with an actual write, not attributes

- Before any partition or boot-file operation on a managed Windows machine, probe with
  a real write (write a small file, verify it exists, delete it) rather than trusting
  volume attributes: fsutil/diskpart can report a volume as not-read-only while every
  write bounces.
- Why: an Intune/BitLocker "require encryption of fixed data drives" policy
  (FDVDenyWriteAccess, or its PolicyManager\...\BitLocker equivalent) write-protects
  any new UNENCRYPTED fixed volume, so a freshly created staging partition looks
  healthy in every attribute query and fails only at the write - which masquerades as
  a firmware/controller quirk and burns a maintenance window. Fixes are policy-side
  (a scoped Intune exclusion for the window, same governance lane as an EDR
  suspension) or shape-side (create the partition as ESP-type from the start, which
  the fixed-data-drive policy ignores) - never a local registry fight with MDM.
- Evidence: 2026-08-28 SARAHC_L3 (work-it), EFIPartitionRemediation batch. bcdboot
  failed exit 3; attributes said writable, `echo test> S:\t.txt` bounced; Intune FDV
  policy confirmed as the mechanism. Offline WinPE path validated (Tests A+B) on
  DESKTOP-J655I5D. Pre-scan now carries a `-WriteProbe` for exactly this.
- Added: 2026-09-01 (work-it)
