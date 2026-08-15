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
