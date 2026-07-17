---
loop: daily-triage
level: 1
paused: false
attempt_cap: 3
budget: soft
last_run: 2026-07-16
runs_since_retro: 2
---
## High Priority (waiting on human)
(none — previous TarotApp unpushed-commit item resolved: repo clean, branch pushed)

## Watch List
- NMMTools: 2 branches inactive >14 days — `feature/jira-setup-dialog` (17d), `feature/wpf-gui` (18d). Flagged 2nd consecutive run. [action: review, merge or delete if abandoned]
- nmmtools: uncommitted changes (README.md modified, docs/FOLLOWUP-jira-live-test.md untracked). Flagged 2nd consecutive run. [action: commit or discard]
- tarot: README.md modified + 6 untracked files (Lenormand art/prompt assets: miriel-36-card-prompts.md, miriel-art-direction.md, style-test-prompts.md, style-tests-shrink-test.png, "Tarot card generation/", "public/images/lenormand test/"). Flagged 2nd consecutive run. [action: commit, or .gitignore if scratch/generated]
- TokenMonitor: README.md modified (new this run). [action: commit or discard]
- TokenMonitor: open PR #1 "Terminal project folder + repo CLAUDE.md so Claude has context" (updated 2026-07-14, 2d old) — not stale, tracking only.
- spend-summary.mjs labels its window "2026-07-16, 2026-07-17" (today + tomorrow, not yesterday + today) — likely UTC/local date bug in the script. [action: fix date math in ~/agent-improvement/scripts/spend-summary.mjs]
- Store health: candidates/home-matt-buffer.jsonl has 7 pending lines (down from 29 — promote pass ran). [action: none urgent; next promote pass will clear]

## Recent Noise (ignored this run)
<!-- Mark an item [FP] if it was a false positive; the loop counts these next run -->
- TokenMonitor PR #1 re-flagged though it is the user's own active 2-day-old PR — mark [FP] if tracking own fresh PRs is noise.
- tarot untracked Lenormand art/prompt assets re-flagged — mark [FP] if these are intentional scratch files that should be suppressed via Human Decisions.

## Human Decisions (overrides the loop must respect)
(none set)
