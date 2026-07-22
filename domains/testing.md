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
