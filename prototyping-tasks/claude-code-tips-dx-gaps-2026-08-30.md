# Plan: dx-plugin gaps from ykdojo/claude-code-tips

**Source eval:** `evaluate-repo` on https://github.com/ykdojo/claude-code-tips, 2026-08-30
**Overall verdict:** Adopt in part (confidence 8.5/10)
**Status:** PLAN ONLY — nothing built. This is a written plan; implementation is a
separate, user-initiated step (`port-gap`).

## Context

The repo is ~85% redundant against this setup — its 49 README tips describe
practices already industrialized here (its Tip 41 "automation of automation" is
a prose description of the agent-learn capture-grade-promote-sync loop). The
value is concentrated in its 9-skill `dx` plugin, not the tips.

**License constraint (material):** `Copyright (c) YK Sugi. All Rights Reserved.`
There is no grant of rights to users — only an inbound CLA-style grant to the
author. Installing the published plugin via
`claude plugin marketplace add ykdojo/claude-code-tips` is the intended use and
is fine. **Copying its scripts or skill text into local repos is not licensed.**
Techniques are unencumbered; verbatim code is not. Every item below is scoped
accordingly.

## The four gaps

### Gap 1 — `private-github-search` (repo mirror + ripgrep)

**The gap.** No cross-repo full-text content search exists here. `gh search code`
does not cover private repos; `gh api .../trees` returns filenames only;
codegraph is per-project AST; claude-mem searches conversations, not code.
24 repos, 17 private.

**Fit rationale (Fits now).** `evaluate-repo`'s own Phase 2 step 4 mandates
checking the user's repos for already-shipped capabilities before declaring a
genuine gap — the `pii-discovery-scanner` origin case. **This very evaluation
run had to execute that step and could only do it via `gh api .../trees`,
i.e. filenames only.** A recurring step in a skill already in use is directly
served by this capability.

**Minimal prototype scope.**
1. Install the published `dx` plugin (adopt the dependency — licensed).
2. Run the sync once against a small subset (3-4 repos, not all 24) and measure
   actual disk cost before committing to a full mirror.
3. Verify the sync script handles Windows paths — see Open Questions; this is
   the single largest unverified risk in the whole adoption.
4. Only if 2-3 pass: full sync, and decide on a refresh cadence (candidate:
   fold into the existing daily-triage loop rather than a new loop).

### Gap 2 — deterministic context reduction (half-clone / quarter-clone)

**The gap.** Nothing here *reduces* context deterministically. Token hooks
measure; `log-archivist` archives project logs; `remember:remember` and
CLAUDE.md's "Compact Instructions" govern *lossy* summarization. The idea worth
taking is keeping real messages (drop the first half of the conversation,
retain the rest verbatim) instead of summarizing them away.

**Fit rationale (Fits now).** Dominant working mode is long autonomous
multi-task sessions — miriel-evals ran 16 tasks / 27 commits, efi-diagnostic
ran 11 tasks / 251 tests, and a single recent run logged ~130k tokens of work.
CLAUDE.md specifies what to *preserve during* summarization but offers no
alternative *to* it.

**Do NOT adopt the shipped hook.** `check-context.sh` has two independent
defects against this environment, both pushing the same direction (its 85%
threshold would fire immediately and permanently):

1. It computes context as
   `input_tokens + cache_read_input_tokens + cache_creation_input_tokens`.
   This is the exact error already recorded in
   `~/agent-improvement/domains/app-dev.md` (2026-08-10): *"Never sum cache-read
   tokens into a context-window figure... Context-window utilization is
   input + output (+ cache-creation), never cache reads."* Evidence there:
   Aether-OS v0.2.0 rendered **663% USED** from this bug (issue #20).
2. `max_context=200000` is hardcoded. `settings.json` sets
   `"model": "opus[1m]"` — a 1M window. The denominator is 5x too small.

**Minimal prototype scope.**
1. Take the *mechanism* only. Write the reduction script fresh — no copied code.
2. Token math must be `input + output + cache_creation`, never `cache_read`.
   Reuse whatever TokenMonitorV2 already does correctly rather than re-deriving.
3. Read the real window size from the configured model; never hardcode.
4. Ship it manual-trigger first (an explicit invocation), **not** an automatic
   PreCompact/threshold hook. Per the loop-design lesson "L1 report-only before
   any autonomy" — an auto-firing context surgeon is exactly the wrong place to
   skip that gate.
5. Verify against a real long transcript before wiring it anywhere.

### Gap 3 — `gha` (GHA failure triage)

**The gap.** Zero coverage — a grep for `gh run` / `workflow run` across skills,
agents, and rules returns nothing. The methodology is the non-obvious part:
check the history of the *specific failing job*, not the workflow, to separate
flakiness from a real break, then bisect to the breaking commit.

**Fit rationale (Fits miriel-evals).** Task 15 landed `eval.yml` and `record.yml`
on 2026-08-30. Both are parked pending API-key activation, and `eval.yml` is
designed to fail on first run until `baseline.json` exists. Those workflows need
failure triage the moment they are activated.

**Minimal prototype scope.** Install with the plugin (Gap 1 step 1) — no
Windows-specific machinery, self-contained. Pairs with the existing loop-design
lesson "never fix flaky tests with code changes"; note that pairing wherever the
skill gets referenced.

### Gap 4 — `version-check`

**The gap.** Nothing checks which Claude Code version is safe to run.

**Fit rationale (Fits now).** `settings.json` has
`"autoUpdatesChannel": "latest"` — precisely the same-day-regression drift this
targets. The isomorphic lesson is already held in an adjacent domain
(`app-dev`, 2026-08-19: check the Electron version against recent
releases/issues *before* deep local diagnosis); it has simply never been applied
to Claude Code itself.

**Minimal prototype scope.** Install with the plugin. Lowest effort and lowest
ceiling of the four — do it last, or not at all if the plugin install is
declined.

## Explicitly out of scope

- `reddit-fetch` and `hn-summarize` are real absences with **no current or
  foreseeable fit identified** — no Reddit or HN research appears anywhere in
  the trajectory. Not advanced. Do not invent a fit for them later without new
  evidence.
- `context-bar.sh` / Tip 0 statusline: ours is better (Node to PowerShell chain
  with sdd-tracking state); theirs is broken on Windows (their issue #5, open
  since 2026-01-10, maintainer has no Windows setup).

## Open questions

1. **Does `private-github-search-sync.sh` handle Windows paths?** Its skill body
   is clean, but unlike `half-clone` it has **no Windows CI coverage**. The
   evaluation inferred this rather than verifying it — the sync script body was
   not read. Verify before a full 24-repo sync, not after.
2. **Disk cost of mirroring 24 repos.** Unmeasured. Gate the full sync on the
   3-4 repo subset measurement.
3. **Refresh cadence for the mirror.** A stale mirror silently returns wrong
   answers — the worst failure mode for a search tool. Fold into daily-triage,
   or accept manual refresh and say so explicitly in whatever wraps it?
4. **Does installing the `dx` plugin pull the defective `check-context.sh` hook
   along with it?** If the plugin registers that hook automatically, installing
   for Gaps 1/3/4 would silently activate the broken token math. Check the
   `.claude-plugin/` manifests before installing — this was listed as
   not-checked in the evaluation's coverage note.

## Steal-the-idea items (no dependency, not gaps)

Recorded here so they are not lost; none of these clear the gap bar, so none are
prototyping tasks:

- **Handoff's explicit "What Didn't Work" field** — negative results so a fresh
  agent does not re-run dead ends. Complements `remember:remember`, which
  deliberately drops the journey. Candidate: a required field in that skill.
- **Cumulative git-tracked TESTING.md** — review the verification narrative over
  time, not just the diff. Would roll up the existing per-task review packages.
- **Job-level flakiness attribution** — covered under Gap 3.
- **`CONOUT$` bypass for statusline OSC sequences** — from their issue #36,
  filed by a third party on a near-identical stack (Win 11 + Windows Terminal +
  Git Bash + worktrees) after Claude Code v2.1.3 began filtering statusline
  stdout. Solves worktree-aware duplicate-tab cwd. Third-party issue content,
  not repo code.
