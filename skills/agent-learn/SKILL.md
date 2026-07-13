---
name: agent-learn
description: Use when the SessionStart hook injects an "agent-learn: N candidate sessions pending" instruction, or when the user runs /agent-learn (promote pass) or /agent-learn status. Extracts durable lessons from finished-session buffers, grades them, and promotes only high-quality ones to the cross-machine store at ~/agent-improvement. This is the AGENT/tooling lane, parallel to the `learning` skill (which tracks the USER).
---

# agent-learn Skill

Closes the agentic self-improvement loop. Reads raw records left by the Stop hook,
extracts candidate lessons, grades them, and promotes survivors to the git-synced
store at `~/agent-improvement`. Always use `~` paths - home dirs differ between
machines (`mwgrant21` home, `matthewgr` work).

**This lane = the AGENT/tooling.** The USER lane is the separate `learning` skill /
`~/learning-profile`. Never write user-skill data here or agent-tooling data there.

## Store layout

- `~/agent-improvement/LESSONS.md` - index table `| Domain | Lesson | Added |` plus a
  `last-updated:` line. Loaded cheaply at session start for read-back.
- `~/agent-improvement/domains/<domain>.md` - full lesson entries (format in the
  domains/README.md there). Domains are open-ended: powershell, app-dev, tooling,
  browser-automation, azure, git, ...
- `~/agent-improvement/candidates/<machineId>-buffer.jsonl` - raw finished-session
  records the Stop hook appends. Gitignored, local only.
- `~/agent-improvement/candidates/dropped.log` - below-threshold candidates, logged
  and discarded. Gitignored.
- `~/agent-improvement/local-state.json` - gitignored:
  `{"machineId": "...", "lastProcessedSession": "..."}`.

## Buffer record format (one JSON object per line)

```json
{"session_id":"...","ended_at":"YYYY-MM-DDTHH:MM:SS","cwd":"...","transcript_path":"...","summary":"<tail of last assistant turn>"}
```

`summary` is a cheap hint. When a record looks like it holds a real lesson but the
summary is thin, open `transcript_path` and read only the relevant tail - never load
a whole transcript blindly.

## Git discipline (every write) - copy of the learning skill's, see references/sync.md

1. Before writing: `cd ~/agent-improvement && git pull --rebase`
2. After writing: `git add -A && git commit -m "<what changed>" && git push`
   (local-state.json and candidates/ are gitignored - they never commit).
3. If pull/push fails (offline/blocked): keep the local commit, say ONCE
   "lessons saved locally; will sync next time", continue. NEVER block the session.
4. Rebase conflict that survives: show both versions of the conflicting lines and
   merge per prose sense (files are small).
5. If `~/agent-improvement` is missing: say so and point to its SETUP.md. Do not
   hard-error.

## Behaviors

### Promote pass (automatic via SessionStart, or manual `/agent-learn`)

Run this as the FIRST action when the SessionStart hook reports pending candidates,
before the user's own work. Keep it fast and silent unless something lands.

1. Read `local-state.json` and `candidates/<machineId>-buffer.jsonl`. If the buffer
   is empty or absent, say nothing (or, if run manually, "No pending sessions.") and stop.
2. For EACH session record, apply the four-lens extraction (see
   `references/grading-rubric.md`) to produce candidate lessons:
   `[PATTERN]` / `[VIOLATION]` / `[NOVEL]` / `[IMPROVEMENT]`. A session may yield
   zero - most do. Do not invent lessons to fill a quota.
3. GRADE each candidate on the three axes (generality, evidence, non-redundancy) and
   dedup against the relevant `domains/<domain>.md` -> NEW / UPDATE / SKIP. Only
   NEW/UPDATE that clear the threshold pass the gate.
4. `git pull --rebase`, then PROMOTE survivors: append/UPDATE the domain file entry
   and add/refresh its `LESSONS.md` row + `last-updated` date. Log every dropped or
   SKIP'd candidate as one line in `candidates/dropped.log` (so nothing vanishes
   without a trace) - dropped.log is NOT synced.
5. Truncate the buffer to empty and set `lastProcessedSession` to the newest
   `session_id` processed in `local-state.json` (not committed).
6. Commit + push per git discipline. Report ONE compact line per promoted lesson,
   e.g. `[app-dev] Electron ACL fix needs elevation check -> domains/app-dev.md (NEW)`.
   If nothing passed, stay silent (automatic) or say "N sessions reviewed, nothing
   worth promoting" (manual).

### `/agent-learn status`

1. Read `LESSONS.md` (count + last-updated) and the buffer (pending record count).
2. Report: total lessons by domain, `last-updated`, and how many sessions are waiting
   in the buffer for the next promote pass. One short block, no writes.

## Guardrails

- The gate protects a SHARED store that syncs to the work machine. When unsure whether
  a candidate is general/verified enough, DROP it - false negatives cost nothing, junk
  on the work machine costs trust.
- Never write speculation. A lesson needs evidence it actually happened (a correction
  the user made, an error observed, a verified success) - not "this might be good."
- Never delete or overwrite another machine's lesson; UPDATE in place or add alongside.
- Automatic runs must be quiet on empty. Do not narrate an empty promote pass to the user.
