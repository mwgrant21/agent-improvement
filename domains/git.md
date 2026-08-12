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
