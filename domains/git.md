# Git Lessons

Durable, graded lessons about git itself - branches, history, what a commit does
and does not prove. Format per `README.md` in this directory.

### A commit missing from `master` is not the same as its content missing

- Before pushing or preserving "unpushed work", compare CONTENT, not commit
  identity. `git log master..branch` answers "which commits are not reachable
  from master", which is a different question from "what would be lost". A change
  that reached master through a separate commit - a cherry-pick, a re-apply, a
  parallel edit - leaves the original commit unique while its effect is already
  present. Use `git diff master..branch` and read the actual hunks.
- Why: the commit-count reading is the alarming one and the one tooling reports
  by default, so it drives the wrong action. It says "work at risk, push it",
  when the correct action may be to discard the branch. Acting on it can revive
  a branch that was slated for deletion in order to carry a change that already
  shipped.
- Evidence: 2026-08-12 NMMToolkit. `git log --branches --not --remotes` reported
  one unpushed commit, `d8a4c87` "feat: default to GUI mode on launch", which
  read as work about to be lost. Its entire content was a single line setting
  `$Mode = 'GUI'` in `src/entry/00-param.ps1` - and master already had exactly
  that line, arrived independently. `git diff master..feature/wpf-gui` showed the
  branch was 11,425 lines BEHIND across ~50 files and contributed nothing. The
  branch had also been on a triage watch list for four runs recommending
  deletion, blocked precisely by the belief that this commit had to be pushed
  first. Discarding was correct; pushing would have revived a dead branch to
  preserve a redundant change.
- See also [[inspect-the-artifact-itself-not-proxies]].
- Added: 2026-08-12 (work-it)

### A `.gitignore` pattern containing a mid-string slash is anchored to the repo root, not "any depth"

- A pattern like `env/.env.local` looks like it should match that path anywhere
  in the tree, but any pattern containing a `/` other than a trailing one is
  anchored to the directory holding the `.gitignore` (repo root, if it's the
  top-level file) — it only matches `env/.env.local` directly under root, not
  `teams-tab/env/.env.local` one level down. Only a bare filename pattern
  (`*.local.json`, no slash) or an explicit `**/` prefix (`**/.env.local`)
  matches at any depth.
- Why: this is invisible by inspection — the line reads as correct, gitignore
  syntax gives no error or warning for an under-matching rule, and `git status`
  showing the *other* correctly-matched patterns as ignored made the broken one
  easy to miss in a batch check. Only a per-file `git check-ignore -v <path>`
  (exit 1 = not ignored) on the specific nested path caught it.
- Evidence: 2026-08-14, uw-router-teams-tab. `.gitignore` at the repo root had
  `env/.env.local` intended to cover `teams-tab/env/.env.local`; `git status
  --ignored` showed the sibling `*.local.json` fixture files correctly ignored,
  which made the rule look like it was working. Only calling `git check-ignore
  -v teams-tab/env/.env.local` directly (exit 1) exposed that this one pattern
  never matched. Fixed by switching to `**/.env.local`.
- How to apply: for any `.gitignore` rule meant to protect a file that isn't
  directly under the repo root, either drop the slash (bare filename/extension
  glob) or prefix with `**/`, and verify with `git check-ignore -v <exact
  nested path>` — not just a general `git status --ignored` scan — before
  trusting it protects a secret or company-data file.
- Added: 2026-08-14 (work-it)

### Classify a stale branch by ahead AND behind, never by ahead alone

- "N commits ahead" does not tell you whether a branch can be merged. Always read
  `behind` from the same comparison and treat the PAIR as the classification:
  `0 ahead` is dead weight, safe to delete; `N ahead / 0 behind` is clean unmerged
  work with a fast-forward available; `N ahead / M behind` is DIVERGENT and must
  not be recommended for a plain merge, because the base has moved through code the
  branch also touches and merging can silently revert newer work. Both numbers come
  from one `gh api repos/<o>/<r>/compare/<base>...<branch>` call, so there is no
  cost argument for dropping one.
- Why: age and ahead-count both point the wrong way here. A branch can be old,
  barely ahead, and still dangerous - while a much older branch with far more
  commits merges cleanly. Reporting only `ahead` makes those two look identical and
  actively invites the destructive action on the wrong one.
- Evidence: 2026-08-21 session (work-it fleet triage) - two branches reported
  identically as "stale, N ahead, merge or abandon" resolved oppositely.
  `EFIPartitionRemediation/feature/fleet-migration-runbook` at 17a/0b
  fast-forwarded clean; `TokenMonitor/worktree-packages-core-wiring` at 1a/45b had
  one commit deleting four source files plus their tests that the base had since
  extended with an entire new rule - merging it would have reverted that silently.
  See [[a-commit-missing-from-master]].
- Added: 2026-08-21 (work-it)

### A `.git` that is a FILE is a linked worktree, not a repository

- When enumerating repositories by scanning for `.git`, test whether each hit is a
  directory or a file. A directory is a standalone repo; a FILE containing
  `gitdir: <path>` is a linked worktree whose commits live in the parent's object
  store. Resolve it to that parent and attribute findings there - counting it as its
  own repo double-reports the same work and inflates every fleet total. Test it
  directly (`[ -d p/.git ]` vs `[ -f p/.git ]`); never infer it from the directory's
  name.
- Why: worktrees look exactly like repos to any name-based or path-based scan, and
  the duplicate they create is invisible - both entries report real, identical
  commits, so nothing looks wrong.
- Evidence: 2026-08-21 session (work-it repo discovery) - `~/Desktop/EFI-wt-migration`
  and `~/Desktop/cli-shared-memory-agents/{claude,codex}` all carry a `.git` file and
  were being counted as three separate repositories.
- Added: 2026-08-21 (work-it)

### Never pre-write a commit message for edits made in the same command chain

- When a single shell invocation both produces edits and commits them, an early
  failure can skip the edit while a later, separately-terminated command still runs
  the commit - landing a message that describes changes the commit does not contain.
  `&&` only guards what follows it on that line; a newline-separated `git commit`
  after it runs regardless. Either bind the whole chain, or verify with
  `git show --stat HEAD` what actually landed rather than trusting the message you
  wrote in advance.
- Why: the commit succeeds, the exit status is 0, and the message reads exactly as
  intended - so nothing prompts a second look. The lie is discovered later by
  someone trusting git history as a record of what happened.
- Evidence: 2026-08-21 session (agent-improvement, work-it) - `git pull --rebase`
  failed on unstaged edits, so the Python heredoc that was supposed to edit
  `STATE.md` never ran, but the following `git add -A && git commit` did; commit
  `4248982` landed with `LOOP.md` only under a message describing STATE.md changes
  that were not in it. Caught by `git show --stat`, not by the exit code. Same
  family as [[a-fallback-must-never-be-a-weaker-version]].
- Added: 2026-08-21 (work-it)

### conventional-changelog reads any bare `#token` in a commit body as an issue reference

- Generating a changelog from conventional commits turns `#anything` into a GitHub issue
  link. In a repo whose commit bodies carry hex colours (`#0f7f55`), CSS selectors
  (`.hdr/.seg/#footer-status`) or anchors, the result is a changelog whose references are
  mostly dead links to issues that do not exist - and a reader cannot tell those from the
  real ones. Set `parserOpts.issuePrefixes` to an explicit prefix (e.g. `['GH-']`) so a
  reference that survives is one someone meant to write.
- Watch your own commit messages too: writing the example prefix literally in the message
  that introduces the fix will itself be linkified.
- Why: nothing errors, and the changelog is generated at release time - so it is usually
  discovered by whoever receives the release, not by whoever cut it.
- Evidence: 2026-08-29 TokenMonitorV2 (home-matt). The first generated CHANGELOG.md
  linked `#0f7f55`, `#ff6b6b` and `.hdr/.seg/#footer-status` to nonexistent issues.
  Caught only because the release runbook step said to read the changelog as if handing
  it to someone.
- Added: 2026-08-29 (home-matt)
