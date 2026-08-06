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
- Evidence: 2026-08-02 session (TokenMonitor, model-policy-stage11.5) - "`npm
  test` from the main checkout falsely reports 42 failures because
  `vite.config.ts`'s exclude list doesn't skip `.worktrees/**`, so it also runs
  the copies of the suite living in" the worktrees.
- Added: 2026-08-02 (home-matt)

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
