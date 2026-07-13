# Sync - Git Discipline for the Agent-Improvement Store

Mirrors the `learning` skill's proven routine. The store at `~/agent-improvement`
syncs home <-> work through the private repo `mwgrant21/agent-improvement`. Only the
durable files sync; `local-state.json` and `candidates/` are gitignored and stay local.

## Every write

```bash
cd ~/agent-improvement
git pull --rebase          # BEFORE writing - pick up the other machine's lessons
# ... write domain files + LESSONS.md ...
git add -A
git commit -m "<what changed, e.g. 'add app-dev lesson: Electron ACL elevation'>"
git push
```

## Failure handling (never block the session)

- **Offline / push fails:** the local commit stands. Tell the user ONCE
  ("lessons saved locally; will sync next time"), then continue. Do not retry in a loop.
- **`git pull --rebase` conflict:** files are small prose. Show the user both versions
  of the conflicting lines and merge by sense. Never force-push over the remote.
- **Repo missing** (`~/agent-improvement` absent): say so and point to
  `~/agent-improvement/SETUP.md` (or offer `gh repo clone mwgrant21/agent-improvement
  ~/agent-improvement`). Do not hard-error or recreate from scratch.

## What must NEVER be committed

- `local-state.json` (machine-local: machineId, lastProcessedSession)
- `candidates/` (raw buffers + dropped.log)

Both are in `.gitignore`. If `git status` ever shows them staged, unstage and fix the
`.gitignore` - a raw buffer reaching the work machine is exactly the leak this design
prevents.
