# daily-triage - Run Protocol (L1, report-only)

Morning digest of everything needing attention. L1 BOUNDARY: this loop
REPORTS. It never files issues, comments, commits, pushes, or fixes anything.

Verifier plan (pre-declared for future L2): a separate reviewer agent with
default stance REJECT must confirm any proposed fix before it is surfaced;
L2 also requires worktree isolation. Not active at L1.

## Run steps

0. Read `STATE.md`. If `paused: true` -> stop immediately, output nothing.
   If `runs_since_retro >= 10` -> run the Retrospective (below) instead.
1. Gather, tolerating per-source failure (a dead source becomes one
   "unavailable" line, never a failed run):
   - **GitHub**: for each mwgrant21 repo (`gh repo list mwgrant21 --json name`):
     open issues, open PRs and their age, branches with no activity > 14 days.
     Read-only. Command shapes: `gh search issues --owner mwgrant21 --state open`,
     `gh pr list -R mwgrant21/<repo> --json number,title,updatedAt`.
   - **Token spend**: `node ~/agent-improvement/scripts/spend-summary.mjs`
     (yesterday + today), plus a second invocation with today's date only
     (`... spend-summary.mjs $(today as YYYY-MM-DD)`) for today's total.
     Flag: today's output tokens > 2x the trailing week's daily median
     (median of `notes.output_tokens_today` across prior run-log lines;
     skip the flag if fewer than 3 baselines exist), or cache hit rate < 50%.
   - **Store health**: pending lines in
     `~/agent-improvement/candidates/<machineId>-buffer.jsonl`, days since the
     newest `Added:` date across `domains/*.md` (> 7 -> note it), and whether
     `git -C ~/agent-improvement status -sb` shows ahead/behind or dirty.
   - **Local repo hygiene**: for each git repo under `~/projects/*`:
     uncommitted changes (`git status --porcelain`) and unpushed branches
     (`git log --branches --not --remotes --oneline`).
2. Update `STATE.md`:
   - Honor the **Human Decisions** section (never re-raise what it suppresses).
   - Count `[FP]` marks added to Recent Noise since last run -> this run's
     `false_positives`; then refresh the section.
   - One-line items only, each with a suggested action. Prune resolved items.
3. Append one line to `runs.jsonl` (schema in `loops/README.md`), including a
   `notes` object with today's spend metrics from step 1, e.g.
   `"notes":{"output_tokens_today":99700,"cache_hit_rate":0.944}` (today-only
   figures, not the two-day window) — this is the baseline the 2x-median
   spend flag reads on later runs. Set `last_run`
   to today, increment `runs_since_retro`.
4. Return the digest: High Priority first, then Watch List, then one-line
   source summaries. End the FINAL message with the post-run critique
   (false positives observed, noisiest source, one adjustment for next run) -
   the Stop hook captures this for agent-learn.

If a run fails before step 3, do NOT advance `last_run` or append a run line - report the failure in the digest slot; the hook will retry next session.

## Retrospective (every 10th run)

Read ALL of `runs.jsonl` and `STATE.md`. Analyze: recurring noise, items
flagged 3+ runs without human action, precision trend (false_positives per
run), duration trend, dead sources. Output a NUMBERED refinement proposal:
LOOP.md edits, threshold changes, source add/drop, and - if the graduation
gate in `loops/README.md` is met - a promotion proposal. Apply ONLY
human-approved items, via the loop-design skill. Append a `retrospective`
event line, set `last_run` to today, and reset `runs_since_retro: 0`. This
loop never edits its own LOOP.md without human approval.
