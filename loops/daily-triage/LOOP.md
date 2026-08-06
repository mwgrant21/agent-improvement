# daily-triage - Run Protocol (L1, report-only)

Morning digest of everything needing attention. L1 BOUNDARY: this loop
REPORTS on the repos it triages. Against those it never files issues,
comments, commits, pushes, branches, merges, or fixes anything - read-only,
without exception.

The one thing it does write is its OWN loop state (`STATE.md`, `runs.jsonl`)
in `~/agent-improvement`, which it must commit and push per step 5. That is
bookkeeping about the loop, not action on a triaged repo, and it has always
been in scope; step 5 only makes the previously-implicit obligation explicit
and verified.

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
     Branch-staleness cache (added 2026-08-03, after 5 multi-branch repos hit
     their first full audit and the per-branch lookup got costly): list each
     repo's branches with name + tip SHA in one call
     (`gh api repos/mwgrant21/<repo>/branches --jq '.[] | {name,sha:.commit.sha}'`),
     then diff against the `notes.branch_tips` map recorded in the most recent
     `runs.jsonl` line (read the file tail, not a re-fetch). A branch whose tip
     SHA is unchanged since last run cannot have gained new activity, so its
     previously-recorded last-commit date is still correct - skip the
     per-branch commit-date call for it and reuse that date. Only spend a
     `gh api repos/mwgrant21/<repo>/commits/<sha>` call on branches that are new
     or whose SHA changed. Carry the full current `{repo: {branch: {sha, date}}}`
     map into this run's own `notes.branch_tips` (step 3) so the next run has
     something to diff against.
   - **Token spend**: `node ~/agent-improvement/scripts/spend-summary.mjs`
     (yesterday + today), plus a second invocation with today's date only
     (`... spend-summary.mjs $(today as YYYY-MM-DD)`) for today's total.
     Thresholds (revised by the 2026-08-06 retrospective, refinement 2 - the
     originals never fired in 10 runs and structurally could not):
     - Spend: flag only when today's output tokens exceed **both** 750,000
       absolute **and** 2x the median of the last 5 recorded
       `notes.output_tokens_today` values. Skip if fewer than 3 baselines
       exist. Rationale: observed daily totals span 17k-1.98M (116x), so a
       bare relative multiple fires on noise at the low end and never at the
       high end; the absolute floor is what makes the multiple meaningful.
       Use the last 5 RUN-LOG values, not a calendar week - this loop runs
       roughly every 2.5 days, so "trailing week" is ~3 data points.
     - Cache: flag when the hit rate falls below **0.90 absolute**, or more
       than 5 percentage points below the median of the last 5 recorded
       values. Rationale: 8 recorded runs sit in a 0.96-0.99 band, so the old
       `< 50%` bar was 46 points from ever firing.
     - If a revised threshold still has not fired by the next retrospective,
       say so in the critique - a silent check is a suspect check.
   - **Store health**: pending lines in
     `~/agent-improvement/candidates/<machineId>-buffer.jsonl`, days since the
     newest `Added:` date across `domains/*.md` (> 7 -> note it), and whether
     `git -C ~/agent-improvement status -sb` shows ahead/behind or dirty.
   - **Local repo hygiene**: DISCOVER the repos, never hardcode a root
     (revised by the 2026-08-06 retrospective, refinement 3). The previous
     protocol scanned `~/projects/*`, which does not exist on `work-it` at
     all, so this source silently returned empty rather than reporting
     itself dead - see `domains/loop-design.md`,
     "A loop must assert its scan root exists".
     - Enumerate git repos by finding `.git` at depth 1-2 under `~` and
       `~/Desktop`. Home directory layouts differ per machine
       (`mwgrant21` / `matthewgr` / `work-it`); discovery is machine-agnostic,
       a hardcoded list is not.
     - If a configured or expected root is absent, emit exactly one
       `source unavailable: <root> not present on <machineId>` line. An empty
       result and an unreachable root must never look alike in the digest.
     - Known and ignored: `~/Desktop/.git` is a stray repo tracking the whole
       Desktop tree, no remote, by design per STATE.md. Skip it, do not
       re-raise it.
     - Report **unpushed commits immediately** (`git log --branches --not
       --remotes --oneline`) - machine-local-only work is the real risk this
       source exists to catch.
     - Report **uncommitted changes only when STALE** (refinement 5): compare
       each repo's `git status --porcelain` line count against
       `notes.dirty_repos` from the previous run-log line. Flag only when the
       count is unchanged across 3 consecutive runs; a changing count is
       active WIP and is suppressed. Rationale: bare "uncommitted changes
       exist" made this the noisiest source in 7 of 10 runs and was almost
       always normal in-progress work. Carry the current
       `{repo: {dirty_lines, unchanged_runs}}` map into this run's own
       `notes.dirty_repos` (step 3).
2. Update `STATE.md`:
   - Honor the **Human Decisions** section (never re-raise what it suppresses).
   - `false_positives` = human `[FP]` marks added to Recent Noise since last
     run, **plus loop-derived noise** (refinement 1). An item whose text is
     byte-identical across 3 consecutive runs and has drawn no human action
     counts as noise on its own evidence - do not wait for a mark that may
     never come. Record which of the two sources each count came from in
     `notes.fp_source`.
     Rationale: across runs 1-10 this field read 0 every time solely because
     no `[FP]` mark was ever made, so the graduation gate in
     `loops/README.md` was reading an unfed counter as evidence of
     precision. A metric only a human can increment measures the human, not
     the loop.
   - Tag every local-hygiene item with the machine whose clone it depends on
     (refinement 4): `[machine: work-it]`. On a run from a different machine,
     skip the check and say `not verifiable on <machineId>` rather than
     re-asserting last run's text - about a third of the Watch List was being
     carried forward blind this way.
   - One-line items only, each with a suggested action. Prune resolved items.
3. Append one line to `runs.jsonl` (schema in `loops/README.md`), including a
   `notes` object with today's spend metrics from step 1, e.g.
   `"notes":{"output_tokens_today":99700,"cache_hit_rate":0.944}` (today-only
   figures, not the two-day window) - this is the baseline the spend and
   cache flags read on later runs. Also include this run's full
   `branch_tips` map (`{repo: {branch: {sha, date}}}`) from step 1's
   staleness cache, so the next run can diff against it. Also include
   `dirty_repos` (step 1's stale-WIP cache) and `fp_source` (step 2).
   `duration_s` must be a REAL measured value - capture a start timestamp at
   step 0 and subtract; runs 9 and 10 both recorded `0`, which destroyed the
   duration trend the retrospective was supposed to read. Set `last_run`
   to today, increment `runs_since_retro`.
4. Return the digest: High Priority first, then Watch List, then one-line
   source summaries. Include an explicit **Untriaged noise** line naming any
   Recent Noise item still unmarked after 2+ runs and asking for a decision
   (refinement 1) - silence there is what left the precision signal unfed for
   10 runs. End the FINAL message with the post-run critique (false positives
   observed, noisiest source, one adjustment for next run) - the Stop hook
   captures this for agent-learn.
5. Commit and push this run's own writes (refinement 6). `git -C
   ~/agent-improvement add -A && git commit && git push`, then VERIFY with
   `git status -sb` that the tree is clean and not ahead of origin. Never end
   a run with a dirty tree: `~/agent-improvement` is shared with the
   agent-learn loop, and uncommitted dirt breaks the other loop's opening
   `git pull --rebase` - see `domains/loop-design.md`, "When two loops share
   one git-backed store". If the push fails (offline/blocked), keep the local
   commit and say so once in the digest; never block on it.

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
