# Agent-Improvement Lessons - Matt

last-updated: 2026-08-10

Cross-machine store of lessons the agent/tooling has learned from real work.
The agent lane, parallel to `~/learning-profile` (which tracks the USER). One line
per lesson. When a session touches a domain, read
`~/agent-improvement/domains/<domain>.md` for the full lesson text. Always use `~`
paths - home directories differ between machines (`mwgrant21` at home, `matthewgr`
at work).

| Domain | Lesson | Added |
|---|---|---|
| powershell | Escape curly braces correctly in strings | 2026-07-12 |
| powershell | Save scripts as UTF-8 without BOM | 2026-07-12 |
| powershell | HKCU under SYSTEM is the wrong hive | 2026-07-12 |
| powershell | Set $ErrorActionPreference = 'Stop' at the top | 2026-07-12 |
| powershell | Never use Write-Host in logging | 2026-07-12 |
| powershell | Put #Requires -RunAsAdministrator first | 2026-07-12 |
| powershell | schtasks stderr becomes a terminating error under Stop | 2026-07-12 |
| powershell | Use ASCII only in scripts | 2026-07-12 |
| powershell | Validate extracted config values before using them in a comparison | 2026-07-14 |
| verification | Inspect the artifact itself, not proxies (git history, hashes) | 2026-07-13 |
| loop-design | Never let the maker verify its own work | 2026-07-13 |
| loop-design | Hard attempt cap, then escalate | 2026-07-13 |
| loop-design | Triage output must be structured, not narrative | 2026-07-13 |
| loop-design | L1 report-only before any autonomy | 2026-07-13 |
| loop-design | One state file per loop | 2026-07-13 |
| loop-design | Connectors start read-only | 2026-07-13 |
| loop-design | Every loop has a kill switch | 2026-07-13 |
| loop-design | Never fix flaky tests with code changes | 2026-07-13 |
| loop-design | Auto-merge only behind an explicit path allowlist | 2026-07-13 |
| loop-design | Always keep a run log | 2026-07-13 |
| app-dev | Write setup-completion flags only after long first-run work finishes | 2026-07-14 |
| tooling | Wait-then-redispatch for unresponsive background subagents | 2026-07-18 |
| tooling | Distinguish a subagent's nested child notifications from its own final report | 2026-07-18 |
| verification | Direct reviewers at the single highest-risk claim, not a generic diff pass | 2026-07-20 |
| verification | Cross-check a research subagent's findings against the actual codebase | 2026-07-20 |
| app-dev | Persisted-state whitelists silently drop new fields unless added explicitly | 2026-07-20 |
| app-dev | Fix an Electron sandbox/preload module-format mismatch by fixing the build, not disabling the sandbox | 2026-07-20 |
| app-dev | `tsc -b` and `--noEmit` conflict in composite/project-reference TypeScript setups | 2026-07-21 |
| testing | A mis-scoped `ignorePatterns` can silently zero out a mutation-testing run | 2026-07-21 |
| security | A basename-only filename check does not stop path traversal - use resolve()-based containment | 2026-07-24 |
| tooling | Order plan tasks so a type/action is defined before the task that produces it | 2026-07-24 |
| app-dev | Extend a well-tested data pipeline with an optional out-param and render-time lookups | 2026-07-24 |
| app-dev | Verify a bleeding-edge Node API's minimum version before setting the CI matrix | 2026-07-29 |
| app-dev | A stale compiled `.js` file can silently shadow its `.ts` source in dev vs. packaged Electron modes | 2026-07-29 |
| verification | A final whole-branch review is required after task-level reviews - catches cross-task bugs | 2026-07-29 |
| security | Warn before a secret enters the chat transcript, offer the `!`-command alternative | 2026-07-29 |
| testing | Test runner config must exclude worktrees - and the glob must match `.claude/worktrees/` too | 2026-08-07 |
| tooling | Verify a research fork actually did real work before trusting its report | 2026-08-02 |
| testing | Prove a new regression-detecting check is not vacuous by reverting the fix and watching it fail | 2026-08-03 |
| app-dev | Before calling an Electron blank-screen bug a code regression, check the build output is actually complete | 2026-08-03 |
| app-dev | A static name-keyed lookup table silently drops namespaced/plugin-scoped variants of the key | 2026-08-04 |
| app-dev | Snapshot a rolling baseline before recording the new value, not after | 2026-08-04 |
| security | A suspected secret in git history is a human-decision escalation, not an autonomous investigation | 2026-08-04 |
| verification | In a live, irreversible-risk incident, demand real diagnostic output before recommending any next step | 2026-08-04 |
| security | When retiring a paid-API integration, check for key leakage into spawned child processes, not just the SDK call path | 2026-08-05 |
| powershell | Gate a rescue script on the operation, not a snapshotted identifier | 2026-08-05 |
| powershell | A diagnostic must refuse on an unmet precondition, not emit noise | 2026-08-05 |
| powershell | Build fleet rescue USBs from full install media, not minimal WinPE | 2026-08-05 |
| verification | Validation machines must match the fleet security-agent config | 2026-08-05 |
| powershell | mountvol exits 0 on invalid usage; the Storage provider caches away the letter it just added | 2026-08-06 |
| testing | `[System.IO.File]` statics are not mockable in Pester 3 - declare the untestable path | 2026-08-06 |
| verification | A read-back verifier comparing the last physical line is defeated by multi-line records | 2026-08-06 |
| verification | A defect authored into the plan survives faithful implementation - do not prime the reviewer | 2026-08-06 |
| security | Removing a secret from the build - or gitignoring it - does not rotate the secret | 2026-08-06 |
| tooling | Scope a process-kill step by install path or PID, not by process name | 2026-08-06 |
| testing | Pester 5 alongside Pester 3 reports 0 passed regardless of suite state | 2026-08-06 |
| testing | Exercise cleanup and teardown on a failing run, not just a passing one | 2026-08-06 |
| verification | Grep finds stale filenames, not stale concepts - read operator-facing strings | 2026-08-06 |
| verification | Tell the reviewer which failures are meant to fail open | 2026-08-06 |
| tooling | A config-snapshot repo whose recipe stops at "commit" protects nothing | 2026-08-06 |
| loop-design | A loop must assert its scan root exists - a missing root reports as "nothing found" | 2026-08-06 |
| loop-design | Two loops sharing a git-backed store must never end a pass with a dirty tree | 2026-08-06 |
| loop-design | Measure the uncached path before adding a cache to a loop | 2026-08-06 |
| verification | A probe that cannot distinguish "not yet" from "never" is not a verification | 2026-08-06 |
| testing | Assert partition buckets plus a catch-all sum to the grand total | 2026-08-07 |
| verification | Structural gates all green says nothing about the visual layer - name the gap | 2026-08-07 |
| testing | A text-length assertion on a widget root passes on the library's injected CSS | 2026-08-10 |
| app-dev | A fallback keyed on "source unavailable" serves stale data forever | 2026-08-10 |
| app-dev | Never sum cache-read tokens into a context-window figure; clamp the percentage | 2026-08-10 |
