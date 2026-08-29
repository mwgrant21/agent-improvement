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

0. **FIRST, sync the store**: run `git -C ~/agent-improvement pull --rebase`
   BEFORE reading any state (adjustment `pull-store-before-step-0`, proposed by
   run 30 / 2026-08-28, APPROVED and applied 2026-08-28). If the pull fails,
   continue against the local store but state the staleness caveat explicitly
   in the digest - never proceed silently on a store you could not verify is
   current.
   Rationale: two independent failures on 2026-08-28, the second worse than the
   first. Run 30 (work-it) read run 24's `runs.jsonl` tail as "previous run",
   built its whole analysis on a 7-day-old baseline, and only discovered runs
   25-29 when its step-5 push was rejected. Retrospective 4's session then
   started 1 commit behind, read `runs_since_retro: 9`, and was dispatched as a
   NORMAL run - it would have silently skipped the retrospective, and nothing
   downstream would have caught it: the push would have merged cleanly and only
   the counter would have been permanently wrong.
   L1 boundary: this is a read/rebase of the loop's OWN store, not an action on
   any triaged repo. The boundary is unchanged.
   Then read `STATE.md`. If `paused: true` -> stop immediately, output nothing.
   If `runs_since_retro >= 10` -> run the Retrospective (below) instead.
   Load `constrained_scopes` (Intervention ladder, `loops/README.md`) into
   working context for step 2 - each entry names a source or finding type
   that a human has narrowed without pausing the loop.
1. Gather, tolerating per-source failure (a dead source becomes one
   "unavailable" line, never a failed run). **Distinguish a dead source from a
   BROKEN PROBE** (adjustment `distinguish-broken-probe-from-dead-source`,
   proposed runs 14-16 / 2026-08-11, applied 2026-08-17): the "unavailable"
   line above is for a source/root that does not exist at all (see "source
   unavailable: <root> not present" below). It is a DIFFERENT failure when a
   source that iterates multiple targets (per-repo, per-branch, per-API-call)
   reaches those targets but gets an error back from ALL of them the same way
   - that is the probe mechanism itself broken (auth expired, rate-limited,
   network down), not N individually-dead targets. Detect this by comparing
   failure count to target count for that source this run:
   - If 100% of a multi-target source's targets fail the SAME way, ABORT that
     source and emit exactly ONE line: `probe failure: <source> - <error>,
     <N>/<N> targets failed`. Do NOT also emit per-target "unavailable" lines
     for it, and do NOT let the rest of the digest imply a clean/quiet result
     for that source this run - a fully broken probe must never look like
     "nothing found."
   - If some but not all targets fail, per-target "unavailable" lines are
     still correct (that is genuine partial dead-target noise, not a broken
     probe).
   - **GitHub**: open issues, open PRs and their age, and NON-DEFAULT
     branches with no activity > 14 days. Read-only.
     **Default branches are excluded from the staleness rule** (adjustment
     `exclude-default-branches-from-staleness`, proposed and applied
     2026-08-06). A dormant repo's `master`/`main` being old is not stale
     feature work - it is just a repo nobody is working in, which is a normal
     and permanent condition, not something to action. On 2026-08-06 three of
     six staleness hits were exactly this shape (`Jira-Autoticketing/master`
     29d, `learning-profile/main` 24d, `cli-shared-memory/master` 15d).
     Nothing is lost by excluding them: unmerged work is caught by `ahead_by`
     below, unpushed local work by the local-hygiene source, and the default
     branch's author date is still recorded in `notes.branch_tips` for any
     future retrospective that wants it. Excluded from the FINDING, not from
     the data.
     Get PRs and issues FLEET-WIDE in two calls, not per repo (adjustment
     `cache-quiet-repo-pr-issue-results`, proposed run 9 / 2026-08-04, held
     2026-08-06, then applied the same day by explicit decision):
     `gh search prs --owner mwgrant21 --state open --json
     repository,number,title,updatedAt,isDraft,url --limit 100`
     `gh search issues --owner mwgrant21 --state open --json
     repository,number,title,updatedAt,url --limit 100`
     A repo absent from those results has no open PRs/issues. That is a
     positive fact established by an authoritative call, NOT a cached
     negative - which is why this replaces the per-repo `gh pr list` sweep
     instead of caching its result. Run 9 asked to cache "quiet repo" answers
     for repos confirmed quiet twice running; that would have introduced a
     window in which a newly opened PR goes unreported, on a loop whose only
     job is surfacing things. Eliminating the call beats caching its answer.
     **Always pass `--limit` explicitly and check for truncation.** The
     default is 30. If the returned count EQUALS the limit, the result is
     probably truncated - say so in the digest and re-run with a higher
     limit. A silently truncated list reads as "fewer open PRs", which is the
     same silent-under-report class as a mis-scoped test glob.
     `gh pr list -R mwgrant21/<repo> --json number,title,updatedAt` is now
     only for drilling into one repo's PR detail, never for the fleet sweep.
     Repo enumeration (`gh repo list mwgrant21 --json name`) is still needed
     for the branch checks below.
     Staleness is measured on the tip commit's **AUTHOR date**
     (`--jq '.commit.author.date'`), never its committer date (adjustment
     `branch-staleness-by-commits-ahead`, proposed run 5 / 2026-07-21, held
     2026-08-06, then applied the same day by explicit decision).
     Rationale: `git rebase` preserves the author date and writes a NEW
     committer date, so a rebase with no new work resets a committer-date
     staleness clock and a genuinely abandoned branch silently drops off the
     stale list. Run 5 caught exactly this - NMMTools `feature/wpf-gui`
     appeared to be 3 days old with no apparent new work. The old protocol
     never specified WHICH date it read, which is half of why the bug was
     possible at all.
     Also record `ahead_by` AND `behind_by` against the repo's default branch
     (`gh api repos/mwgrant21/<repo>/compare/<default>...<branch> --jq
     '{ahead:.ahead_by,behind:.behind_by}'`) and report BOTH alongside the age.
     `behind_by` comes back in the SAME response `ahead_by` already reads, so
     recording it costs zero extra API calls (adjustment
     `record-behind-by-alongside-ahead-by`, proposed and applied 2026-08-21).
     Age and divergence are different signals: age says "nobody has touched
     this", ahead says "there is unmerged work in it", behind says "the base
     has moved underneath it". Report the pair as `Na/Mb`, never collapsed
     into one number. The four cases are NOT interchangeable, and the
     recommendation differs for each:
     - `0 ahead` (any behind): dead weight. Fully absorbed, safe to delete.
     - `N ahead / 0 behind`: clean unmerged work, fast-forward available.
       "Merge or abandon" is a fair framing here.
     - `N ahead / M behind`: **DIVERGENT - do not label this "N ahead" and do
       not recommend a plain merge.** The base moved through code the branch
       also touches, so a merge can silently delete newer work. Report it as
       `divergent, verify against the default branch before proposing a merge`
       and leave the merge/rework/abandon call to the human.
     - The higher `M` relative to the branch's age, the more likely the branch
       is stale-by-supersession rather than stale-by-neglect.
     Rationale: on 2026-08-21 two branches this loop had reported identically
     as "stale, N ahead, merge or abandon" resolved OPPOSITELY.
     `EFIPartitionRemediation/feature/fleet-migration-runbook` was 17a/0b and
     fast-forwarded cleanly. `TokenMonitor/worktree-packages-core-wiring` was
     1a/45b, and its one commit deleted four source files plus their tests that
     the default branch had since extended with a whole new rule - merging it
     would have silently reverted that work. `ahead_by` alone cannot tell those
     apart, and the digest's wording actively invited the wrong action on the
     second one.
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
     or whose SHA changed. Carry the full current
     `{repo: {branch: {sha, author_date, ahead_by, behind_by}}}` map into this
     run's own `notes.branch_tips` (step 3) so the next run has something to
     diff against.
     Cache rules for the three fields, so adding `ahead_by`/`behind_by` does NOT undo this
     optimization (it took five proposals across three weeks to land - do not
     casually regress it):
     - `author_date`: refetch only when the branch's own SHA changed. A
       rebase changes the SHA and busts the cache, but the refetched author
       date comes back unchanged, so the staleness clock correctly does not
       reset.
     - `ahead_by` and `behind_by`: refetch when the branch's SHA changed **or**
       when the repo's DEFAULT-branch SHA changed. Both are relative, so they
       go stale when the base moves even if the branch does not - and the
       default branch's SHA is already in the same one-call branch listing, so
       this costs nothing extra to detect. They come from ONE compare call and
       must always be refetched and stored TOGETHER; a `behind_by` cached from
       an older base while `ahead_by` is fresh is exactly the silently-wrong
       derived value `domains/loop-design.md` "Measure the uncached path before
       adding a cache" warns about. Never read one from cache and the other
       live.
     - Pre-2026-08-06 cache entries carry `date` instead of `author_date` and
       no `ahead_by`; entries written before 2026-08-21 have no `behind_by`.
       Treat ANY missing field as a cache miss and refetch that branch once;
       do not assume the old `date` was an author date, because the protocol
       never said which one it was, and never infer `behind_by` from a stored
       `ahead_by`.
     - **`sha` is the FULL 40-character SHA, never truncated** (adjustment
       `specify-branch-tips-cache-key-format`, proposed 2026-08-11, applied
       2026-08-17). The API call above (`--jq '.[] | {name,sha:.commit.sha}'`)
       already returns the full SHA - store and compare it as-is. Same failure
       class as the `date`/`author_date` ambiguity just above: an unspecified
       format let different runs write 7-char short SHAs, forcing every read
       to truncate for comparison to work at all, which is a silent precision
       loss (a 7-char prefix is not guaranteed globally unique) for no
       benefit. Treat a cached `sha` shorter than 40 characters as a cache
       miss and refetch that branch once, same as a missing `author_date`.
   - **Token spend**: `node ~/agent-improvement/scripts/spend-summary.mjs`
     (yesterday + today), plus a second invocation with today's date only
     (`... spend-summary.mjs $(today as YYYY-MM-DD)`) for today's total.
     **Before using the figures, check them against the previous run-log
     line's `notes.output_tokens_today` / `notes.cache_hit_rate`. If they are
     identical, this run is RE-READING the previous run's measurement, not
     taking a new one** (adjustment `dedupe-same-day-spend-baseline`, proposed
     and applied 2026-08-21) - normal on a second same-day run, since the
     usage log may not have advanced between them. In that case:
     - Record the figures in `notes` as usual, but add
       `"spend_duplicate_of":"<previous run's session_id>"`.
     - A duplicate reading MUST NOT enter the trailing-5 median as an
       independent sample. Skip it when computing the spend and cache
       baselines; duplicates drag the median toward whatever the last measured
       day happened to be, quietly corrupting the very baseline these
       thresholds compare against.
     - If a threshold still fires on a duplicate, label it in the digest as
       `same reading as run <N>`, never as an independent second flag.
     Evidence: runs 23 and 24 (both 2026-08-21) returned byte-identical
     figures (in 8 / out 2722 / cacheRead 337137 / cacheCreate 80809) and the
     cache threshold fired twice on that one measurement.
     **Compute BOTH baselines PER MACHINE** (adjustment
     `per-machine-spend-baseline`, proposed by retrospective 4 / 2026-08-28,
     APPROVED and applied 2026-08-28). `scripts/spend-summary.mjs` reads
     `~/.claude/projects/**/*.jsonl` via `homedir()`, so a reading measures
     THIS machine's usage log and nothing else. Draw the trailing-5 spend and
     cache medians only from run-log lines whose `notes.machine` matches the
     current machine, and say so in the digest when fewer than 3 same-machine
     baselines exist - the existing "skip if fewer than 3 baselines" rule then
     does the right thing instead of silently borrowing the other machine's
     numbers. Record `notes.machine` on every run-log line so this is
     computable.
     **Canonical machine id, and normalize before matching** (adjustment
     `normalize-machine-label-in-run-notes`, proposed by run 31 / 2026-08-29,
     APPROVED and applied 2026-08-29). `notes.machine` is the BARE machine id
     and nothing else - `home-matt` or `work-it`, the same value as
     `machineId` in `~/agent-improvement/local-state.json`. The hostname goes
     in `notes.hostname` (`TITAN`, ...), never appended to the machine id.
     When matching a historic line, NORMALIZE both sides first: trim, lowercase,
     and take only the portion before the first `/`. A run whose
     `notes.machine` reads `home-matt/TITAN` is a home-matt reading and MUST
     count toward home-matt's baseline.
     Rationale: the exact-match rule landed one day earlier assumed one
     spelling, but runs 27 and 28 wrote `home-matt/TITAN` while runs 21, 22,
     25, 26, 29 and the retrospective lines wrote `home-matt`. Strict matching
     silently drops 2 of the 7 home-matt readings and swings the trailing-5
     figures from 54,794 out / 0.872 cache to 232,692 / 0.970. It changed no
     outcome on run 31, but a 10-point cache-median swing decides a borderline
     day - and the failure is silent, because a dropped line looks exactly like
     a line that was never written. Same family as the `date`/`author_date` and
     short-SHA ambiguities: a field that two writers spell differently is not a
     key until something normalizes it.
     Rationale: since the loop went two-machine at run 23 (2026-08-21), every
     threshold comparison spanning a machine flip compared two different
     corpora. Across runs 21-30, work-it read 2,722 / 2,722 / 3,835 output
     tokens (runs 23, 24, 30) while home-matt read 11,371 to 1,488,880 (runs
     21, 22, 25-29) - a ~500x spread that is machine identity, not a change in
     behaviour. The window ran 7 home-matt and 3 work-it, so roughly a third of
     every median was drawn from the wrong corpus, and every spend/cache flag
     recorded since run 23 rests on a partly-foreign baseline.
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
     - **Gate the cache flag on a minimum volume floor** (adjustment
       `gate-cache-flag-on-min-volume`, DECLINED 2026-08-17, RE-OPENED and
       APPROVED 2026-08-28 by retrospective 4 on materially new evidence).
       When today's output tokens are below **50,000**, the cache check
       reports `not evaluated - insufficient volume (<N> output tokens)` in
       the digest INSTEAD of flagging. It must never be suppressed silently: a
       silent check is a suspect check, so the not-evaluated line is mandatory
       whenever the floor is hit.
       Rationale: the 2026-08-17 decline rested on 3-of-5 low-volume data
       points running against the hypothesis. Runs 21-30 separate perfectly by
       volume with zero crossovers - flagged: runs 23/24 (2,722 out), 27
       (54,794), 29 (11,371), 30 (3,835); clean: 21 (455,934), 22 (232,692),
       25 (386,911), 26 (1,488,880), 28 (307,463). Correcting for the machine
       confound above, the three work-it readings are consistent-with rather
       than independent evidence, but within home-matt alone the separation is
       still 7-for-7 with zero crossovers. On a low-volume day the ratio is
       dominated by a handful of requests and measures nothing about cache
       health.
       Note the floor was derived from a window whose medians mixed corpora
       (see `per-machine-spend-baseline`); re-check it at retrospective 5
       against home-matt-only readings.
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
     - Enumerate git repos under the scan roots `~`, `~/Desktop`, and
       `~/Downloads`. Home directory layouts differ per machine
       (`mwgrant21` / `matthewgr` / `work-it`); discovery is machine-agnostic,
       a hardcoded list is not.
     - **Depth is measured to the REPO DIRECTORY (the parent of `.git`), not
       to the `.git` entry itself: a repo counts when its own directory sits
       at depth 1-2 below a scan root, i.e. `find <root> -maxdepth 3 -name
       .git`** (adjustment `clarify-repo-discovery-depth-definition`, first
       proposed 2026-08-18, applied 2026-08-21).
       Rationale: "depth 1-2" was never pinned to a referent, and the two
       readings return different fleets from the same disk - on work-it,
       depth-to-`.git` yields 16 repos and depth-to-repo-dir yields 20. Run 23
       used the first and run 24 the second, so two runs hours apart triaged
       different repo sets with nothing in the digest saying so. The repo-dir
       reading is the correct one because it reaches ordinary nested project
       layouts (`~/Downloads/UWRouter/uw-mail-router`) that the other silently
       drops, and a missed repo is a silent under-report - the exact failure
       class this source exists to prevent.
     - **A `.git` that is a FILE, not a directory, is a linked git worktree,
       not a repo.** Resolve it to the parent repo named in its `gitdir:`
       pointer and attribute any finding there; never count or report it as an
       independent repo. Its commits live in the parent's object store, so
       reporting both double-counts the same work. On work-it this correctly
       excludes `~/Desktop/EFI-wt-migration` and
       `~/Desktop/cli-shared-memory-agents/{claude,codex}`. Test it directly
       (`[ -d <path>/.git ]` = standalone repo, `[ -f <path>/.git ]` =
       worktree); do not infer it from a directory's name.
     - If a configured or expected root is absent, emit exactly one
       `source unavailable: <root> not present on <machineId>` line. An empty
       result and an unreachable root must never look alike in the digest.
     - Known and ignored: `~/Desktop/.git` is a stray repo tracking the whole
       Desktop tree, no remote, by design per STATE.md. Skip it, do not
       re-raise it.
     - **Run `git fetch --prune` BEFORE the unpushed check** (adjustment
       `fetch-prune-before-unpushed-check`, proposed run 28, APPROVED and
       applied 2026-08-28). Without it the comparison runs against stale
       remote-tracking refs, so work already pushed can read as unpushed and -
       worse - orphaned commits stay hidden behind refs that no longer exist.
       Evidence: runs 28, 29 and 30 all ran this ad hoc; run 28's version is
       what exposed `tarot`'s 1,771 orphaned commits that stale refs had
       hidden. Three consecutive runs did by convention what the protocol did
       not require.
       L1 boundary: fetch ONLY - never pull, merge, or prune remote refs. This
       is the Operational failure ladder's "Resync" tier (`loops/README.md`),
       which is data-gathering, not a corrective action.
     - Report **unpushed commits immediately** (`git log --branches --not
       --remotes --oneline`) - machine-local-only work is the real risk this
       source exists to catch.
     - **Escalate on VOLUME, not just presence** (adjustment
       `flag-branches-20-commits-ahead`, proposed run 3 / 2026-07-18, applied
       2026-08-06). A branch more than **20 commits** ahead of its tracking
       remote - or with no upstream at all and more than 20 commits on no
       remote - goes to **High Priority**, not the Watch List. This PROMOTES
       the existing unpushed-commits finding; it does not add a second line
       for the same branch.
       Rationale: the bare check detects presence but flattens severity, so
       "3 unpushed doc commits" and "51 unpushed commits" read identically.
       They are not the same risk - the second is a single disk failure away
       from being the only copy. Run 3 (2026-07-18) caught aether-os sitting
       51 commits ahead only because a human noticed it inside routine
       hygiene noise, which is exactly the accident this rule removes.
       L1 boundary reminder: this REPORTS the exposure with a suggested
       action. The loop never pushes the work itself, at any volume.
     - **Detect local branches with NO UPSTREAM, split DEAD from LIVE**
       (adjustment `detect-no-upstream-local-branches`, proposed run 29,
       amended by run 30, APPROVED and applied 2026-08-28). Enumerate branches
       with no tracking remote (`git for-each-ref --format
       '%(refname:short) %(upstream)' refs/heads`), then classify EACH by how
       many of its commits are absent from every remote:
       - **untracked-DEAD** (0 commits not on a remote): the branch's work is
         fully present elsewhere. Report as a **cleanup candidate**, Watch List
         at most. Run 29's 5 home-matt branches were all this shape.
       - **untracked-LIVE** (unpushed > 0): real sole-copy exposure - this work
         exists on one disk only. Report as a genuine risk, and apply the
         20-commit volume rule above to decide Watch List vs High Priority.
         `NMMToolkit`'s `fix/dispatch-command-not-found-message` is this shape.
       The split is the point of the adjustment, not an optional refinement.
       Reporting the two identically would repeat exactly the severity
       flattening that `flag-branches-20-commits-ahead` was written to fix - a
       branch safe to delete and a branch one disk failure from total loss must
       never render as the same line.
       L1 boundary: both classes are REPORTED with a suggested action. The loop
       never deletes a dead branch nor pushes a live one.
     - Report **uncommitted changes only when STALE** (refinement 5): compare
       each repo's `git status --porcelain` **file path SET**, not just the
       line count, against `notes.dirty_repos` from the previous run-log line
       (adjustment `dirty-count-blind-to-content-churn`, proposed 2026-08-13,
       applied 2026-08-17 - a count-only comparison misses a repo that sheds
       one file and gains a different one in the same run, which held
       `Aether-OS-livetest` at "4 dirty lines, unchanged" for a 4th run while
       the WIP was actually still moving). Flag only when the path SET is
       identical across 3 consecutive runs; any change to which files are
       dirty - not just how many - counts as active WIP and is suppressed.
       Rationale: bare "uncommitted changes exist" made this the noisiest
       source in 7 of 10 runs and was almost always normal in-progress work.
       Carry the current `{repo: {dirty_paths: [...], unchanged_runs}}` map
       into this run's own `notes.dirty_repos` (step 3) - `dirty_paths`
       replaces `dirty_lines`; treat a cache entry that still has
       `dirty_lines` instead of `dirty_paths` as a miss and re-baseline that
       repo's `unchanged_runs` to 0 rather than guessing membership from a
       bare count.
     - **A run that did not OBSERVE a repo must carry its `unchanged_runs`
       forward FROZEN, never incremented** (adjustment
       `freeze-unchanged-runs-when-not-verified`, proposed by run 23 /
       2026-08-21, applied 2026-08-21). When the check is skipped because the
       repo lives on another machine (refinement 4 below), write the entry
       through unchanged with `"frozen_not_verified": true` alongside it. The
       3-consecutive-run staleness flag may only count runs that actually
       looked at the path set.
       Rationale: refinement 4 makes the DIGEST say "not verifiable on
       <machineId>", but nothing stopped the cache from stepping the counter
       on a run that never looked. Runs 21 and 22 both wrote
       `note: "not verified this run"` while stepping `Aether-OS-livetest`
       from 6 to 7, and run 23's first live check proved the cached path set
       had been wrong the entire time - 4 paths cached against 5 actually
       dirty. The loop reported a 7-run-stale finding built entirely on
       observations nobody made. A counter that advances without an
       observation is not evidence, and this is the same class as
       `domains/verification.md`, "A probe that cannot distinguish 'not yet'
       from 'never' is not a verification".
     - **Worktree hygiene** (added 2026-08-21): for each discovered repo, run
       `git worktree list --porcelain`. For each worktree beyond the main
       one, check whether its branch has already been merged into the repo's
       default branch (`git branch --merged <default>`) or no longer exists
       (`[gone]`/deleted upstream with no local ref). Flag each as a one-line
       finding: `stale worktree: <repo> - <path> (branch <name>, merged/gone)
       [action: prune merged worktree at <path>]`. **Report only - this loop
       never runs `git worktree remove`**, the same boundary it already
       holds for unpushed commits (reported, never pushed). No cache: a
       repo's worktree count is small (typically 0-2) and `git worktree
       list` plus a merge-check is cheap enough to run in full every run -
       per `domains/loop-design.md`, "measure the uncached path before
       adding a cache," don't add one speculatively here.
     - **Cross-repo config/gitignore drift** (added 2026-08-21): two related
       checks, both grounded in `domains/testing.md` lessons that have hit
       this fleet more than once.
       - Per discovered repo, if `.gitignore` contains a `.worktrees/` or
         `worktrees/` pattern, confirm it also covers `.claude/worktrees/`
         (either an explicit `.claude/worktrees/` line or an unanchored
         `**/worktrees/**`-style pattern that matches both). If it only has
         the anchored `.worktrees/` form, flag: `gitignore gap: <repo> -
         .gitignore excludes .worktrees/ but not .claude/worktrees/, the
         path Claude Code actually uses [action: add .claude/worktrees/ to
         .gitignore]`. This is the exact drift that silently produced false
         test failures in both TokenMonitor and aether-os (see
         `domains/testing.md`, "Test runner config must exclude
         `.worktrees/**`").
       - **GitHub push-credential health, checked ONCE per run, never
         per-repo**: run `gh auth status`. This is a single shared machine
         credential, not a per-repo property - checking it once mirrors how
         the existing broken-probe handling above treats one failing cause
         as one finding, not N. If it reports invalid/expired, emit exactly
         one finding: `GitHub auth: gh auth status reports <error> - likely
         also blocks git push to any GitHub-hosted repo (seen before: tarot,
         TarotApp, agent-improvement, code-graph-mcp all failed push with
         "Invalid username or token" from this same underlying cause)
         [action: gh auth refresh -h github.com]`. Be honest this is a
         correlate, not a direct push test - this loop never runs `git push`
         itself, so it cannot confirm push would succeed even when `gh auth
         status` looks clean; word the finding as "likely also blocks", not
         "blocks".
2. Update `STATE.md`:
   - Honor the **Human Decisions** section (never re-raise what it suppresses).
   - Honor **Constrained Scopes** (step 0's `constrained_scopes` list): a
     finding whose source/type matches an active entry is capped per that
     entry's stated limit (e.g. "never promote past Watch List", or "skip
     this specific check") instead of the normal severity rule. Note the
     constraint's `reason` inline on the item so a human reading the digest
     sees why it did not escalate the way it normally would have. This is
     independent of `false_positives`/noise handling below - a constrained
     item is still a real finding, just capped, not suppressed.
   - `false_positives` = human `[FP]` marks added to Recent Noise since last
     run, **plus loop-derived noise** (refinement 1). An item whose **finding
     identity** - not its literal rendered text - is unchanged across 3
     consecutive runs and has drawn no human action counts as noise on its
     own evidence - do not wait for a mark that may never come. Record which
     of the two sources each count came from in `notes.fp_source`.
     **Match on finding identity (repo + branch/path + recommendation), never
     on byte-identical text** (adjustment `noise-match-on-finding-identity-
     not-text`, proposed 2026-08-10, applied 2026-08-17). A GitHub staleness
     finding embeds its current age in days (e.g. "40 days stale"), which
     increments every run by construction - a literal byte-identical check
     can therefore never fire for the loop's most common finding type, and
     refinement 1 was silently inert for it since the day it landed. Strip
     the volatile field(s) - age/day-count, timestamp, any other value that
     changes purely with the passage of time rather than with the underlying
     state - before comparing; the identity tuple is what makes something
     "the same finding," not the exact sentence used to describe it this run.
     Rationale: across runs 1-10 this field read 0 every time solely because
     no `[FP]` mark was ever made, so the graduation gate in
     `loops/README.md` was reading an unfed counter as evidence of
     precision. A metric only a human can increment measures the human, not
     the loop.
     **BEFORE graduating anything to noise, verify the repo is ABLE to change**
     (adjustment `verify-repo-can-change-before-noise-graduation`, proposed by
     retrospective 4 / 2026-08-28, APPROVED and applied 2026-08-28). Sweep for
     a stale lock - a `.git/*.lock` file with no git process holding it and an
     mtime older than ~1h. If one is found, the repo is BLOCKED, not settled:
     report it as blocked with the lock path and its age, and do NOT count the
     item as noise or step its `unchanged_runs`.
     Rationale: `TarotApp` was graduated to noise on 5 identical observations
     while an empty `index.lock` dated 2026-08-12 had blocked every
     index-modifying operation for 13 days. The rule read "settled" where the
     truth was "broken" - an unchanging finding meant the repo COULDN'T change,
     which is the opposite of the precision the graduation was crediting.
     Runs 29 and 30 both swept ad hoc and found 0 fleet-wide: the condition is
     RARE, not unnecessary. It silently corrupted a finding for 5 consecutive
     runs the one time it occurred. Same class as `domains/verification.md`,
     "A probe that cannot distinguish 'not yet' from 'never' is not a
     verification."
     **The 3-consecutive-run threshold is PINNED to one reading** (adjustment
     `clarify-unchanged-runs-flag-threshold`, proposed run 27, APPROVED and
     applied 2026-08-28, sequenced to land AFTER the can-it-change check
     above). The rule fires when `unchanged_runs >= 3` - that is, on the THIRD
     consecutive run observing the same finding identity, counting only runs
     that actually OBSERVED the item (frozen runs do not count, per
     `freeze-unchanged-runs-when-not-verified`). It fires identically for every
     item at the same counter value; a run may not flag one item and spare
     another at the same number.
     Rationale: run 26 flagged `TarotApp` at `unchanged_runs == 3` while
     leaving `tarot`, `Miriels-publish` and `About-me` unflagged at the
     identical value - same input, different outcome, no stated reason. Note
     the ordering dependency: pinning the threshold WITHOUT the can-it-change
     check above would only make the wrong graduation happen more
     consistently, which is why the two land together and in this order.
   - Tag every local-hygiene item with the machine whose clone it depends on
     (refinement 4): `[machine: work-it]`. On a run from a different machine,
     skip the check and say `not verifiable on <machineId>` rather than
     re-asserting last run's text - about a third of the Watch List was being
     carried forward blind this way. A skipped check must ALSO freeze that
     repo's `unchanged_runs` rather than incrementing it - see
     `freeze-unchanged-runs-when-not-verified` in step 1's stale-WIP rules.
   - One-line items only, each with a suggested action. Prune resolved items.
3. Append one line to `runs.jsonl` (schema in `loops/README.md`), including a
   `notes` object with today's spend metrics from step 1, e.g.
   `"notes":{"output_tokens_today":99700,"cache_hit_rate":0.944}` (today-only
   figures, not the two-day window) - this is the baseline the spend and
   cache flags read on later runs. Also include this run's full
   `branch_tips` map (`{repo: {branch: {sha, author_date, ahead_by, behind_by}}}`) from step 1's
   staleness cache, so the next run can diff against it. Also include
   `dirty_repos` (step 1's stale-WIP cache) and `fp_source` (step 2).
   Record step 4's one adjustment as a STRUCTURED entry (refinement 9), not
   only as prose inside `critique`:
   `"adjustment":{"id":"kebab-slug","text":"one line","first_proposed":"YYYY-MM-DD"}`.
   Reuse the SAME `id` when re-proposing an adjustment from an earlier run,
   and carry that run's `first_proposed` date forward unchanged - that is what
   makes "proposed N times, still not landed" countable instead of a thing
   someone has to notice by re-reading ten prose critiques.
   **A run that RE-CONFIRMS an outstanding adjustment MUST re-emit it as its
   structured `notes.adjustment`** (adjustment `count-reconfirmation-as-
   reproposal`, proposed by retrospective 4 / 2026-08-28, APPROVED and applied
   2026-08-28). Re-confirming in prose only does not count. If a run executes
   an outstanding adjustment ad hoc, restates its case, or otherwise relies on
   it, that run re-emits the id with `first_proposed` carried forward unchanged
   - which increments `times_proposed` and lets the attempt cap actually fire.
   Rationale: at retrospective 4 all 5 outstanding items read
   `times_proposed: 1` while `fetch-prune-before-unpushed-check` had been
   executed ad hoc by three consecutive runs and
   `close-expand-home-matt-discovery-root` re-confirmed by five. Only a
   structured entry increments the counter, so the escalation mechanism
   refinement 9 exists to provide could not fire on exactly the items most in
   need of it - the same failure class as refinement 1's "a metric only a human
   can increment measures the human".
   Corollary for the retrospective: a retrospective CARRYING an item forward is
   not itself a re-proposal and does not increment the counter. The increment
   belongs at the point of observation, in the run that relied on the item.
   `duration_s` must be a REAL measured value - capture a start timestamp at
   step 0 and subtract; runs 9 and 10 both recorded `0`, which destroyed the
   duration trend the retrospective was supposed to read. Set `last_run`
   to today, increment `runs_since_retro`.
   **Before appending, round-trip the line through `JSON.parse(JSON.stringify(...))`
   (or equivalent) and verify it succeeds** (adjustment
   `validate-jsonl-line-before-append`, proposed 2026-08-17, applied
   2026-08-17). If it fails, do NOT append the malformed line - fix the
   offending value (most likely an un-escaped character, e.g. a Windows path
   backslash, interpolated into `critique` or an adjustment's `text` without
   JSON-escaping) and retry the round-trip before writing. Evidence: run 19's
   line 27 sat as corpus damage undetected until a full-file read (this
   retrospective) happened to hit it - a write-time check catches it for free
   instead of leaving it for whichever future reader parses the whole file.
4. Return the digest: High Priority first, then Watch List, then one-line
   source summaries. Include an explicit **Untriaged noise** line naming any
   Recent Noise item still unmarked after 2+ runs and asking for a decision
   (refinement 1) - silence there is what left the precision signal unfed for
   10 runs. End the FINAL message with the post-run critique (false positives
   observed, noisiest source, one adjustment for next run) - the Stop hook
   captures this for agent-learn. State the adjustment's `id` in the critique
   text so the prose and the structured `notes.adjustment` entry cannot drift
   apart. If that same `id` already sits in STATE.md's Adjustment ledger as
   OUTSTANDING, say how many times it has now been proposed.
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
run), duration trend, dead sources.

### Step R1 - reconcile the Adjustment ledger FIRST (refinement 9)

Before proposing anything new, audit what was already proposed. Collect every
`notes.adjustment` entry across `runs.jsonl` (and, for runs predating that
field, the seeded rows in STATE.md's Adjustment ledger). For each `id`,
determine its status by INSPECTING THE ARTIFACT - grep this `LOOP.md` and the
relevant file under `~/agent-improvement/scripts/` for the change itself:

- LANDED - the change is present in the current LOOP.md or script. Record the
  date, and KEEP it in the ledger; re-check it every retrospective.
- REGRESSED - previously LANDED, now absent. Escalate immediately to High
  Priority. Do not assume this cannot happen: run 9 (2026-08-04) found
  `nmmtools/testResults.xml` back after being marked resolved two runs
  earlier, so "fixed once" is not a durable state in this store.
- OUTSTANDING - proposed, never applied. Record `times_proposed` and the age
  in days since `first_proposed`.
- HELD - explicitly declined by a human. Never silently re-propose a HELD item
  as if it were new; if re-raising it, say it was previously held and why that
  has changed.

Do not infer status from the fact that a critique proposed it, that a past
retrospective listed it, or that it sounds like something that was done. Only
the file's current contents settle it - see `domains/verification.md`,
"Inspect the artifact itself, not proxies".

Then apply the attempt cap: any OUTSTANDING adjustment with
`times_proposed >= attempt_cap` (3, per STATE.md frontmatter) is ESCALATED to
High Priority with its full age and proposal count, not quietly re-proposed an
Nth time. Refresh the ledger section in STATE.md, and report the headline
number in the digest: `<landed>/<total> adjustments landed`.

Why this step exists: across runs 1-10, eleven adjustments were proposed and
only four ever reached LOOP.md. The branch-tips cache - the single biggest
win, cutting run 10 from 17 repo lookups to 5 - was proposed five times over
three weeks before it landed. Nothing in the protocol noticed, because
"proposed" and "applied" were never compared. A loop that critiques itself
well and cannot act on the critique is just a well-documented standstill.

Note on self-verification: this step does not violate
`domains/loop-design.md`, "Never let the maker verify its own work". The loop
is not grading the quality of its own fixes - it is mechanically checking
whether a string is present in a file it is forbidden to edit. Every actual
change still requires human approval and the loop-design skill.

### Step R2 - propose

Output a NUMBERED refinement proposal: LOOP.md edits, threshold changes,
source add/drop, and - if the graduation gate in `loops/README.md` is met - a
promotion proposal. Carry forward every OUTSTANDING and ESCALATED item from
R1 as a numbered candidate in its own right, so a twice-ignored adjustment
competes for approval alongside the new ideas instead of dropping off the
list. Before proposing promotion, confirm the gate's inputs are actually
being MEASURED, not merely reading zero.

Also reconsider every entry currently in `constrained_scopes` (Intervention
ladder, `loops/README.md`): report whether the constrained source has stayed
noisy (keep constraining), gone quiet (propose lifting it), or the
constraint's `reason` no longer applies. This is a proposal like any other -
the loop never adds or removes a `constrained_scopes` entry itself.

### Step R3 - close out

Apply ONLY human-approved items, via the loop-design skill. Append a
`retrospective` event line (a second line recording what was applied is
correct - `runs.jsonl` is append-only, so the analysis line is never edited
to match the outcome). Set `last_run` to today, and reset
`runs_since_retro: 0`. This loop never edits its own LOOP.md without human
approval.
