---
loop: daily-triage
level: 1
paused: false
attempt_cap: 3
budget: soft
last_run: 2026-07-14
runs_since_retro: 1
---
## High Priority (waiting on human)
- TarotApp: 1 unpushed local commit (`3ca4d9d feat(android): deck-roster parity with web + new Waking Waite art`) not on any remote branch — push before it risks being lost. [action: `git -C ~/projects/TarotApp push`, then confirm which branch holds it]

## Watch List
- NMMTools: 2 branches inactive >14 days — `feature/jira-setup-dialog` (15d), `feature/wpf-gui` (16d). [action: review, merge or delete if abandoned]
- Miriels-publish: uncommitted changes (README.md modified, docs/memory-engine.md untracked). [action: commit or discard]
- nmmtools: uncommitted changes (README.md modified, docs/FOLLOWUP-jira-live-test.md untracked). [action: commit or discard]
- tarot: 6 untracked files under "Tarot card generation/", "public/images/lenormand test/", and repo root (art/prompt assets). [action: commit, or .gitignore if scratch/generated]
- Store health: candidates/home-matt-buffer.jsonl has 29 pending lines awaiting grading. [action: run agent-learn promote pass]
- TokenMonitor: 1 open PR (#1 "Terminal project folder + repo CLAUDE.md so Claude has context", opened today) — not stale, tracking only.

## Recent Noise (ignored this run)
<!-- Mark an item [FP] if it was a false positive; the loop counts these next run -->
(none — first run, nothing to mark yet)

## Human Decisions (overrides the loop must respect)
(none set)
