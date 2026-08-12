# Testing Lessons

Durable, graded lessons about test tooling and test-suite quality tools (mutation
testing, coverage, etc.) - distinct from `tooling.md` (Claude Code orchestration
itself). Format per `README.md` in this directory.

### A mis-scoped `ignorePatterns` can silently zero out a mutation-testing run

- When configuring Stryker (or any mutation-testing tool that sandboxes a copy of
  the repo per mutant run), never put the test directory itself (e.g. `test/**`)
  in `ignorePatterns`/exclude globs. That strips the test files from the
  sandboxed copy, so the configured test command finds zero tests and exits 0 -
  which reads as a mutation score of 0% (no mutants killed), not as an error.
  Always sanity-check a fresh/first mutation run's non-zero kill rate against a
  small known file before trusting a 0% result.
- Why: a 0% mutation score from a broken sandbox looks identical to a 0% score
  from a genuinely untested file - the tool gives no error signal to
  distinguish them, so misconfiguration silently masquerades as a real (bad)
  result.
- Evidence: 2026-07-21 session (mutation-test skill build, Task 2) -
  `ignorePatterns` included `"test/**"`, which "silently excluded the test
  directory from Stryker's sandboxed copy, causing `npm test` to find zero
  tests and exit 0 (a false 0% score)"; fixed to `["node_modules/**",
  "dist/**"]` and ported upstream to the skill's template before Task 3's full
  run confirmed a real 74.81% baseline.
- Added: 2026-07-21 (home-matt)

### Test runner config must exclude `.worktrees/**` or false failures appear

- When a project uses git worktrees for parallel task execution (e.g. under
  `.worktrees/` or `.claude/worktrees/`), the test runner's config (e.g.
  `vite.config.ts`/`vitest.config.ts` exclude list) must exclude that directory.
  Otherwise running the suite from the main checkout also picks up and runs the
  copies of the suite living inside each worktree, producing spurious failures
  that look like real regressions.
- Why: worktrees are full working copies on disk; without an explicit exclude,
  glob-based test discovery treats them as more source/test files to run,
  masking the real signal with noise from in-progress or stale worktree state.
- The exclude glob must match where the worktrees ACTUALLY live, and a
  root-anchored pattern is the trap: `.worktrees/**` never matches
  `.claude/worktrees/<branch>/`, so a config that "already excludes worktrees"
  still runs them. The repo convention and the harness's own choice differ -
  Claude Code creates worktrees under `.claude/worktrees/`. Use unanchored
  patterns covering both (`'**/.worktrees/**'`, `'**/worktrees/**'`), and
  confirm by the collected test count dropping, not by reading the config.
- Evidence: 2026-08-02 session (TokenMonitor, model-policy-stage11.5) - "`npm
  test` from the main checkout falsely reports 42 failures because
  `vite.config.ts`'s exclude list doesn't skip `.worktrees/**`, so it also runs
  the copies of the suite living in" the worktrees. Recurred 2026-08-07
  (Aether-OS, Stage 15): the exclude list DID contain `.worktrees/**`, yet a
  stale `.claude/worktrees/aether-packages-core-task4` still produced 6 false
  failures and doubled suite collection because the anchored glob never matched.
- **The test runner is not the only config that names the old path.** When a
  tool's directory convention moves, EVERY config referencing the old location
  goes stale at once, and only the noisiest one gets noticed. After fixing the
  runner, grep the whole repo for the old path - `.gitignore`, editor and
  linter ignore files, dev-server watch lists, packaging excludes, CI paths.
- Evidence for that generalisation: 2026-08-12 (TokenMonitor). The vitest config
  had been corrected to cover `.claude/worktrees/`, but `.gitignore` still
  listed only `.worktrees/`, so `?? .claude/` showed as an untracked change and
  a daily-triage loop flagged it as unresolved WIP for FIVE consecutive runs
  before anyone read the rule rather than the symptom. It was never noise; the
  ignore rule had simply never caught up with the move. Fixed by adding
  `.claude/worktrees/` - scoped to worktrees, not all of `.claude/`, so
  project-level agents/skills/settings stay trackable.
- Added: 2026-08-02 (home-matt); updated 2026-08-07 and 2026-08-12 (work-it)

### Prove a new regression-detecting check is not vacuous by reverting the fix and watching it fail

- When adding a new check/assertion whose whole point is to catch a specific
  regression (e.g. a golden-file/parity harness, a round-trip encoding check),
  don't stop at "the check passes." Temporarily revert the underlying fix,
  re-run the check, and confirm it now fails for the expected reason - then
  restore the fix. Only that failing-on-purpose run proves the check actually
  detects the regression instead of passing regardless of what it's given.
- Why: a check that always passes (wrong assertion target, comparing the wrong
  field, a no-op comparison) looks identical to a correct one until something
  regresses - by which point the false confidence has already shipped.
- Evidence: 2026-07-30 session (aether-os go-collector-hardening, PR #6) - a
  raw-bytes assertion was added to `runHookInstallParity`'s `compareState` for
  an escaping round-trip fix; the implementer "empirically confirmed the new
  harness check is non-vacuous (reverted the escaping fix as a throwaway test,
  confirmed the harness correctly caught 12 failures)" before restoring the fix.
- Added: 2026-08-03 (work-it)

### `[System.IO.File]` statics are not mockable in Pester 3 - declare the untestable path instead of faking it

- Pester 3 cannot mock .NET static methods, so any code path routed through
  `[System.IO.File]::WriteAllText` / `AppendAllText` / `ReadAllText` cannot have
  its failure branch exercised by a mock. A permission-denied write throws inside
  the static call, before execution ever reaches the read-back verification that
  the test was written to check.
- What to do: record the path in the ledger/test file as explicitly untested, with
  the reason. Do not paper over it with a test that constructs a different failure
  and therefore proves nothing about the real one. An honestly declared coverage
  gap is auditable; a vacuous passing test is worse than no test, because it
  reports the branch as covered.
- Note this is the same file-write idiom the PowerShell rules mandate for
  BOM-free output, so the gap recurs across any script following that convention.
- Evidence: 2026-08-06 session (EFI-wt-migration, Task 6) - the permission-denied
  branch of a `WriteAllText` read-back verifier was declared untestable in the
  ledger rather than covered with a substitute failure.
- Added: 2026-08-06 (work-it)

### Pester 5 installed alongside Pester 3 reports 0 passed regardless of suite state

- On machines carrying both Pester 3.4.0 (the Windows in-box module) and Pester
  5.7.1, a suite written for Pester 3 run under 5 reports **0 passed** - not an
  error, not a load failure, just zero. A wrong-version run is therefore
  indistinguishable from having deleted or broken the entire suite.
- What to do: pin the version explicitly (`Import-Module Pester -RequiredVersion
  3.4.0`) in the runner, and warn any dispatched reviewer or implementer about
  this before they run the suite. If a previously-green suite suddenly reports 0
  passed, check the loaded module version BEFORE investigating the code.
- Why: every other test failure mode this environment produces is loud. This one
  is silent and points the investigation at the wrong artifact - the natural
  reaction to "0 passed" is to go looking for what the last change destroyed.
- Evidence: 2026-08-06 session (EFI-wt-migration) - surfaced by a task reviewer
  and thereafter included as an explicit warning in later reviewer briefs:
  "under it the entire suite reports 0 passed regardless of state. Without that
  warning, a wrong-Pester run looks exactly like having destroyed 113 tests."
- See also [[system-io-file-statics-are-not-mockable-in-pester-3]] for the other
  Pester-3 constraint this environment keeps hitting.
- Added: 2026-08-06 (work-it)

### Exercise cleanup and teardown on a FAILING run, not just a passing one

- When a test or script sets up destructive/invasive state to exercise a path (a
  Deny ACL, a stopped service, a renamed file, a mounted volume), verify that its
  cleanup also runs when the body FAILS or is aborted - not only on the happy
  path. Cleanup placed after the assertions, rather than in a `finally`/trap, is
  the default mistake and it is invisible while everything passes.
- Why: the artifact left behind lands on a real workstation, and it is left
  behind precisely on the runs that were already going badly. A Deny ACL or a
  half-mounted volume surviving an aborted test is a worse outcome than the
  failure that caused it.
- Evidence: 2026-08-06 session (EFI-wt-migration) - a reviewer was explicitly
  asked to "assess cleanup on a failing run, not just a passing one" for a test
  that applied a Deny ACL to force a permission-denied path; the same session
  also forced that failure path with a real Deny ACL rather than reasoning about
  it, per [[prove-a-new-regression-detecting-check-is-not-vacuous]].
- Added: 2026-08-06 (work-it)

### When you split an aggregate into buckets, assert the parts sum to the whole in a test

- Any view that partitions a total (per-project, per-model, per-day slices of one
  all-up number) needs a test asserting `sum(buckets) + catch-all == grand total`,
  with an explicit named bucket (`unscoped`, `unknown`, `residual`) for rows the
  partition key cannot classify. Never let unclassifiable rows be silently
  dropped, and never normalize the residual away to make the numbers look tidy.
- Why: a dropped-row bug in a partition is invisible - each per-bucket figure
  looks individually plausible, and only the failure to reconcile against the
  grand total exposes it. Users compare the detail view to the summary view and
  find the discrepancy before any test does; at that point every number in the
  product is suspect, not just the broken one.
- Evidence: 2026-08-07 sessions (Aether-OS, Stages 15-16) - the Stage 15 review
  caught a residual being normalized away in the Ledger's cost aggregation
  ("residual not normalized away, `number | null` buckets never defaulting to
  `0`"); Stage 16's per-project plan then made the reconciliation a hard
  requirement - per-project totals plus `unscoped` must sum to the all-transcripts
  total - "a test, not a hope."
- Added: 2026-08-07 (work-it)

### A DOM text-length assertion on a widget's ROOT element is satisfied by the library's own injected CSS

- Never assert "this widget produced output" by measuring `textContent` length on
  the widget's root/container element. Many UI libraries inject a `<style>` block
  INSIDE that root, and `textContent` includes the text of that style block - so
  the assertion passes on CSS alone, whether or not the widget ever rendered a
  byte of real content. Target the specific content sub-element instead (for
  xterm.js: `.xterm-rows`, not `.xterm-screen`), and when auditing a suspect
  assertion, measure the split - total length vs. the `<style>` share - rather
  than eyeballing whether the number "looks big enough."
- Why: this is a vacuous test that reports as a passing integration test, i.e. the
  most expensive kind. It specifically defeats the tests guarding the hardest
  thing to test - that a real subprocess/pty/canvas actually produced output -
  and the threshold looks deliberately chosen and reasonable in the source.
- Evidence: 2026-08-10 live-test session (Aether-OS v0.2.0, `e2e/app.spec.ts:36`)
  - the committed pty test asserted `.xterm-screen` textContent `> 40` chars;
  measured live, that element held **56,039** chars of which **55,148** was
  xterm's injected `<style>` and only **826** was actual row content - the
  assertion was satisfied ~1,380x over by CSS alone. Filed as issue #21.
- See also [[prove-a-new-regression-detecting-check-is-not-vacuous]] - reverting
  the behavior under test is the general way to catch this class before shipping
  it.
- Added: 2026-08-10 (work-it)

### Two implementations of one contract need a parity harness over a committed fixture corpus, not two independent test suites

- When a rewrite/port is claimed to be a "drop-in swap" for an existing
  implementation, assert it: commit a miniature fixture corpus, have EACH
  implementation process it into a throwaway store, and assert both match one
  golden file. Keep the check language-agnostic - neither side runs the other -
  and guard identity keys (paths, ids) alongside row counts and totals, with
  each side normalising its platform separator against a canonical form in the
  golden. Passing suites on both sides prove each meets its own tests, not that
  the two agree.
- Why: equivalence asserted in a design doc is not equivalence, and a divergence
  in a shared store is worse than a crash. Two implementations keying the same
  file differently make it scanned twice and double counted - numbers stay
  plausible while being wrong in both directions.
- Evidence: 2026-08-10 Aether-OS (PR #33, commit `360c9b8`) -
  `test-fixtures/collector-parity/` plus `parity.test.ts` /
  `parity_test.go`. The Go side went red on its first run and caught all four
  dimensions at once (usage_events 1 vs 2, token totals 100 vs 7,100 input,
  tool_calls 1 vs 2, and a missing `transcript_files` key): `collector-go` had
  no `subagents/` handling at all, though Stage 10 shipped it as a "drop-in swap
  behind the Stage 2 contract." A cutover would have silently reduced what was
  collected.
- See also [[when-you-fix-a-rule-on-one-code-path]] and
  [[prove-a-new-regression-detecting-check-is-not-vacuous]].
- Added: 2026-08-11 (work-it)

### Test fixtures must mirror the real producer's record shape, or they validate a shape that does not exist

- When a rule/predicate consumes records emitted by a parser, build fixtures by
  reproducing the parser's ACTUAL output sequence, not a convenient one-object
  shorthand. If one logical unit of work spans several emitted records, the
  fixture must span them too. Before trusting a "does NOT fire" test, ask which
  record the assertion's discriminating field really lands on in production.
- Why: a fixture that concentrates a whole unit's data into one record can make
  a threshold check pass that is nearly vacuous against real data. The suite
  goes green while the predicate is wrong for every real input, and the wrongness
  is invisible precisely because the fixture never produces the failing shape.
- Evidence: 2026-08-11 TokenMonitor PR #3. `findUndelegatedLookup` gated on
  `outputTokens < 300` per record. `transcriptParser` emits one record per JSONL
  line, so a human turn is assistant(tool_use) -> user(tool_result) ->
  assistant(prose); the tool-call record's output is always tiny, making the
  ceiling near-vacuous and flagging lookup-then-analyze turns as "pure lookup".
  The tests passed only because their fixtures put the turn's entire output on
  the tool-call record - a shape real transcripts never produce. Caught in review,
  not by the suite. Fixed in `4a2a9a2` by grouping records between human prompts;
  re-running the OLD predicate against the corrected fixtures flags 3 records
  that must not be flagged, proving the new guard discriminates.
- See also [[prove-a-new-regression-detecting-check-is-not-vacuous]] and
  [[two-implementations-of-one-contract-need-a-parity-harness]].
- Added: 2026-08-11 (work-it)
