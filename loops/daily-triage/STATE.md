---
loop: daily-triage
level: 1
paused: false
attempt_cap: 3
budget: soft
last_run: 2026-08-03
runs_since_retro: 7
---
## High Priority (waiting on human)
(none)

## Watch List
- tarot: same 6 non-master branches still >14 days inactive - `portfolio-phase1`/`security-hardening` (31 days), `joint-second-order-hardening` (29 days), `portfolio-phase2`/`portfolio-phase3`/`portfolio-tscheck` (30 days). Unchanged tip commits since last run. NEW: `swap-thoth-to-plate-keeps` (last commit 07-18, 16 days) has now also crossed the 14-day threshold - previously the active branch with a clean working tree. [action: review and prune stale branches]
- TarotApp: NEW - 5 of 6 non-master branches are >14 days inactive: `android-prompt-injection-parity`/`fix-android-image-manifest`/`joint-second-order-hardening` (29 days), `swap-thoth-to-plate-keeps` (21 days), `android-deck-parity` (20 days). First full branch audit of this repo. [action: review and prune stale branches]
- TarotApp: 2 unpushed commits (`7dcf7d2` deck parity, `f84f60a` merge) confirmed still absent from `mwgrant21/TarotApp` remote (verified via `gh api commits/<sha>` = 422 not found). No local clone on this machine to push from. [action: confirm intentional; push when ready from the machine holding these commits]
- TokenMonitor: NEW - 7 non-active branches >14 days inactive: `design-v2-phase1`..`phase5` (23-24 days), `plan-aware-usage` (23 days), `token-tracker-impl` (25 days), `cli-copy-paste` (21 days). First full branch audit of this repo - sizeable stale-branch backlog. [action: review and prune]
- TokenMonitor: `terminal-project-cwd` (holding unpushed commit `714bff9`, feat: adopt Stryker Mutator) has itself now crossed 14 days inactive (last commit 07-19). Local clone on this machine (`claude-token-tracker`) does not have this branch fetched, so it could not be re-verified locally this run - carried forward from GitHub view only. 3rd consecutive run. [action: none urgent, confirm before losing local-only work]
- TokenMonitor: open PR #1 "Terminal project folder + repo CLAUDE.md so Claude has context" - still open, last updated 2026-07-19 (now 15 days stale). Tracking only.
- TokenMonitor: open PR #2 "fix: make the live feed actually follow the active session" - still open, unchanged since 2026-07-24 (10 days stale, no new commits). [action: none, tracking only]
- NMMToolkit (local): uncommitted changes to 2 files (`src/core/05-ui-console.ps1`, `src/tools/business/Get-RingCentralStatus.ps1`) on checked-out branch `test/business-tools-20260722`; `master` is ahead 2/behind 21 and `feature/wpf-gui` ahead 1/behind 11 of their remotes. [action: commit or discard local WIP; review branch divergence]
- claude-config: 2 local commits (`60ae270`, `e970169`) with no git remote configured on this clone at all - informational only, unclear if a remote is intended by design for this snapshot repo. [action: confirm whether this repo should have a remote]

## Recent Noise (ignored this run)
<!-- Mark an item [FP] if it was a false positive; the loop counts these next run -->
- TokenMonitor PR #1 re-flagged though it is the user's own active PR - mark [FP] if tracking own fresh PRs is noise. (Unmarked 5 runs running.)

## Human Decisions (overrides the loop must respect)
(none)

## Resolved since last run
- Aether-OS PR #8 "Model policy (Stage 11.5): stop unpoliced model calls, add spend ceiling": merged 2026-08-03 (merge commit `a9fed62`), branch deleted.
- Aether-OS: untracked `test-results/.last-run.json` resolved - `.gitignore` now has `test-results/` (commit `677400a`, pushed).
- NMMTools `feature/jira-setup-dialog`: the "35 days inactive" signal was misleading - the feature was already fully implemented and merged into this machine's local `master` (`Desktop\NMMToolkit`) weeks ago, just never pushed. Reconciled with the 21 commits origin/master had picked up meanwhile (one small conflict in `tests/output.tests.ps1`, resolved by keeping both added Describe blocks), verified (148/148 Pester tests, build clean), and pushed to origin/master (`8edae9c`). Branch deleted locally and on origin, now fully closed out - not just quieted.
- nmmtools: untracked `testResults.xml` resolved - repo now gitignores it (commit "chore: ignore Pester -CI testResults.xml").
- TokenMonitor: the 3 untracked plan docs under `docs/superpowers/plans/` are gone from the local clone's working tree (clean status on `master`) - presumably committed or discarded.
- aether-os: the 6 untracked design-mockup jpgs are gone from the repo root.
- NMMTools `feature/wpf-gui` / `codex/remote-business-tools` timestamp concern: closed out (no further resets across 4+ runs) - no LOOP.md change needed.
- Meta: `~/agent-improvement` git status is clean and in sync with `origin/master` this run.
