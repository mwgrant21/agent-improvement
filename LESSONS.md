# Agent-Improvement Lessons - Matt

last-updated: 2026-07-21

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
