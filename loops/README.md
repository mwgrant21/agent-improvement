# Loops — Durable State & Run History

One directory per recurring loop (scheduled agent, /loop, cron, hook-driven).
Convention adapted from github.com/cobusgreyling/loop-engineering, fitted to
this store (see docs/specs/2026-07-13-loop-conventions-design.md).

## Layout

```
loops/<loop-name>/
  LOOP.md       # the loop's run protocol (its instructions)
  STATE.md      # frontmatter (machine layer) + body (human layer)
  runs.jsonl    # append-only run history, one JSON object per line
```

## STATE.md frontmatter (machine layer)

| Field | Meaning |
|---|---|
| loop | loop name, matches directory |
| level | 1=report-only, 2=propose (worktree/draft PR, no merge), 3=autonomous within allowlist |
| paused | KILL SWITCH. true -> every runner exits silently before any work |
| attempt_cap | max fix attempts per item before escalating (L2+) |
| budget | `soft` or a token number; enforced at L2+. On breach: downshift if the loop
  declares `on_budget_breach: downshift`, else `paused: true` (the default) |
| on_budget_breach | `pause` (default) or `downshift` - see "Budget that downshifts" below |
| exit_criterion | for a loop that iterates to convergence: the NAMED condition that ends it |
| isolation | `session` (default), `subagent`, or `sandbox` - see "Execution isolation" |
| last_run | YYYY-MM-DD of last completed run (gates once-per-day loops) |
| runs_since_retro | counter; at >= 10 the next run is a retrospective |
| constrained_scopes | list of `{scope, reason, since, reconsider}` objects - sources/finding-types currently narrowed without pausing the whole loop. Empty list by default. See Intervention ladder. |

## runs.jsonl line schema

```json
{"ts":"ISO-8601","session_id":"...","level":1,
 "type":"run|retrospective|promotion|demotion|store-sync",
 "findings":0,"actions":0,"escalations":0,"false_positives":0,
 "duration_s":0,"critique":"one-line self-critique",
 "notes":{}}
```

`notes` is an optional object for per-run metrics that later runs use as
baselines (e.g. daily-triage records `output_tokens_today` and
`cache_hit_rate` so its 2x-median spend flag has history to compare against;
it also records a `branch_tips` map of
`{repo: {branch: {sha, author_date, ahead_by, behind_by}}}` so the next run can
skip re-fetching commit dates for branches whose tip SHA hasn't moved). `sha` is
the full 40-char SHA; `ahead_by`/`behind_by` come from one compare call and are
always refreshed together, since both go stale when the DEFAULT branch moves
even if the branch itself has not.

### The four count fields are required scalars

`findings`, `actions`, `escalations` and `false_positives` are REQUIRED on every
`type:"run"` line and are plain integers. Do not replace one with an object and
do not drop one: a loop wanting a breakdown puts it in `notes` (e.g.
`notes.findings_by_bucket`) and still emits the scalar.

Why it is worth a rule: daily-triage run 41 emitted a nested
`"findings":{"high_priority":N,...}` and dropped `escalations` entirely, so
retrospective 5 had to hand-reconcile two shapes to compute the graduation gate -
which turns on "0 unresolved escalations". A future retrospective doing that
without a human noticing could silently miscompute the gate and promote a loop
that had not earned it. (Retrospective 5, proposal 4, human-approved 2026-09-11.)

Append-only. Never rewrite or delete lines.

### `notes.adjustment` is an ARRAY (ruled 2026-09-06)

A run may legitimately emit more than one adjustment: `daily-triage`'s
`count-reconfirmation-as-reproposal` REQUIRES a run that relied on an outstanding
adjustment to re-emit it, and that run may also propose a new one. The prior
single-object shape could not hold both, and run 36 worked around it with an
ad-hoc second key. Writers now always emit an array, even for one entry.

Because this log is append-only, historical lines cannot be migrated. **Every
reader sweeping for adjustment ids MUST normalize all four shapes** or it will
under-count exactly the items the attempt cap exists to escalate:

```js
const adj = [
  ...(Array.isArray(n.adjustment) ? n.adjustment : n.adjustment ? [n.adjustment] : []),
  ...(n.adjustment_new ? [n.adjustment_new] : []),  // run 36 only; never write this again
];
```

As of the ruling: 31 lines carry an object, 1 line (run 36, 2026-09-06) also
carries `adjustment_new`, and the rest carry none. `adjustment_new` is a frozen
historical artifact — readers absorb it, writers never produce it.

### `store-sync` lines

A run's own line is appended BEFORE the run commits and pushes, so it can never
record whether that commit and push succeeded. A loop whose final step writes to
a shared git store appends a second, separate line after that step instead:
`{"ts":...,"type":"store-sync","notes":{"committed":true,"pushed":true,"status_sb":"## master...origin/master"}}`.
Append-only-safe, and it makes a skipped final step visible in the log rather than
only discoverable by comparing SHAs across runs.

## State ownership ledger (body layer)

Every category of state a loop retains anywhere - not just STATE.md
frontmatter - gets one row in a `## State Ownership` section in STATE.md's
body: the category, where it lives, and its cap (a number, or an explicit
rotation/archival policy). No retained-state category ships without one -
"unbounded, no policy" is not a valid row.

Adapted from lidge-jun/opencodex's "bounded memory ownership" convention
(36 categories of process-retained state, each with a declared hard cap;
evaluated 2026-08-21/22, github.com/lidge-jun/opencodex). Sharper than this
store's prior default of noticing bloat reactively - e.g. `log-archivist`
compressing `aether-os/PROGRESS.md` only after it reached 206KB. Declaring
the cap up front doesn't prevent growth, but it means a loop's own
retrospective (or a human skimming STATE.md) can see which sections are
expected to keep growing and by what policy, instead of discovering it once
the file is already unwieldy.

Categories to ledger typically include: `runs.jsonl` growth, `notes.*`
per-run metrics objects, `constrained_scopes`, the Adjustment ledger (if
present), Human Decisions, Watch List, and any cache/map a loop maintains
across runs. Sections a loop already prunes each run (e.g. "Resolved since
last run") are self-bounding and get a row saying so rather than a number.

## Committing from a loop

Every loop that commits to this store MUST stage only its own `loops/<name>/`
paths:

```
git -C ~/agent-improvement add loops/<name>/STATE.md loops/<name>/runs.jsonl
```

**Never `git add -A`, never `git add .`.** More than one loop runs against this
single working tree, sometimes concurrently on the same machine, so a blanket
add stages whatever a sibling loop has in flight and commits its unfinished
state under your loop's commit message.

Not hypothetical: daily-triage run 39 (2026-09-09) found the store mid-flight
with two uncommitted `loops/pr-review-watch/` files written by a concurrently
running watcher session. Runs 39, 41 and 42 each worked around it by hand before
the rule was written down - which is the signal that it belonged in the protocol
rather than in each runner's memory.

`domains/loop-design.md`'s "When two loops share one git-backed store" covers the
READ side: a dirty tree breaks the next loop's `pull --rebase`. This is the WRITE
side of the same hazard. Both apply - scope the add, AND end the run clean.

## Graduation

- Every loop STARTS at L1. No exceptions.
- Promotion: last 10 runs show <= 2 false positives AND 0 unresolved
  escalations -> the loop PROPOSES promotion in its digest; a human approves;
  bump `level` and append a `promotion` event.
- Demotion (automatic): 3 consecutive runs with an escalation or verifier
  reject -> drop one level, append a `demotion` event with the reason.
  Budget breach at L2+ -> set `paused: true` immediately.
- Humans mark false positives by annotating items in the STATE.md body
  (Recent Noise / Human Decisions); the loop counts them next run.

## Budget that downshifts, not only halts

`budget` today can do exactly one thing on breach: stop the loop. A budget that can
only halt is strictly less useful than one that can also route cheaper -- the work
still needs doing, and pausing defers the cost rather than reducing it.

A loop may declare `on_budget_breach: downshift`. On breach it then, in order:

1. Drops to the cheapest model that can still do the task (see the four-tier policy
   in `~/.claude/CLAUDE.md`), and records `downshift` in the run line's `notes`.
2. Widens its own interval, if it has one, rather than dropping work.
3. Only pauses if neither is possible.

`pause` stays the default, because downshifting silently is its own failure mode: a
loop quietly producing cheaper, worse output for a week is harder to notice than one
that stopped. A loop that downshifts MUST say so in its digest, every run, until the
budget resets.

**Route on remaining budget, not only on task complexity.** The model-tier policy
picks a tier from what the task needs. That is the right question only while the
budget is not the binding constraint. A loop that will exhaust its top tier partway
through a queue should restructure the work up front -- cheap tier for triage, top
tier for the few items triage flags -- rather than run at full cost until it is cut
off mid-queue with the remainder unprocessed.

## Terminating review loops

A loop that iterates until something "looks done" has no defined end and will either
stop early or run forever. Any loop that reviews-then-fixes-then-reviews MUST declare
an `exit_criterion` naming the condition that ends it, in terms the loop can evaluate
without judgment. Examples that qualify:

- "no findings at severity P1 or P2 remain"
- "two consecutive review passes produce zero new findings"
- "`attempt_cap` reached" (the existing escape hatch, which is a floor, not a plan)

"Until it looks good" and "until the reviewer is satisfied" do not qualify. Pair the
criterion with `attempt_cap`: the criterion is how the loop succeeds, the cap is how
it gives up. A loop with only a cap has no success condition, and one with only a
criterion cannot fail safely.

Evidence this is needed: a review-and-fix cycle run by hand on 2026-09-08/09 (Codex
on PR #75) produced a new finding on every one of four passes, several of them in the
fixes from the previous pass. Nothing in the setup defined when to stop; the human
called it. That decision should have been declared up front.

## Execution isolation (orthogonal to level)

The L1/L2/L3 ladder governs **what a loop may decide**. It says nothing about **where
its code runs** -- an L3 loop today executes with the full authority of the session
that hosts it. Those are independent axes and conflating them means a loop earns
execution privilege by demonstrating good judgment, which does not follow.

Declare `isolation` alongside `level`:

| Value | Meaning |
|---|---|
| `session` | Runs with the host session's authority. The default, and what every loop does today. |
| `subagent` | Runs in a subagent with a restricted tool set. Cannot touch what it was not given. |
| `sandbox` | Runs where filesystem and network are confined independently of the harness. |

A high level does NOT imply a permissive isolation, and a restrictive isolation does
not cap the level: an L3 loop with real decision authority can still be confined to a
subagent that can only read and report. Record both; neither implies the other.

## Intervention ladder

Per-scope escalation, ORTHOGONAL to the L1/L2/L3 autonomy level above - a
loop can be constrained without being demoted, and demoted without anything
being constrained. Adapted from munder-difflin's steer -> constrain -> stop
model (evaluated 2026-08-15/16, github.com/chaitanyagiri/munder-difflin);
"escalate" below is the closest analog to their "steer" (a course-correction
that does not restrict scope), and "constrain"/"stop" map directly.

1. **Escalate** (existing) - an item hits `attempt_cap` (fix attempts at
   L2+, or times-proposed for an L1 adjustment/finding) -> surfaced to a
   human for a decision. No loop behavior changes automatically; the loop
   keeps running exactly as documented.
2. **Constrain** (new) - a human narrows a specific noisy or drifting
   SOURCE or finding type via a `constrained_scopes` entry in STATE.md
   (`{scope, reason, since, reconsider}`) - e.g. "cap this source's findings
   at Watch List, never High Priority" or "skip this specific check
   entirely". The rest of the loop keeps running unaffected. This is a
   human-added/removed entry, not something the loop sets on itself;
   reconsidered at the loop's next retrospective (Step R2), not automatic.
3. **Stop** (existing) - `paused: true`, the whole loop halts before any
   work, every runner checks this first. Reserved for loop-wide problems
   (budget breach, runaway behavior) - not for a single noisy source, which
   `constrain` handles without taking the whole loop offline.

## Operational failure ladder

A DIFFERENT axis from the Intervention ladder above: that one escalates on
finding QUALITY (a source works but its results are noisy/drifting). This
one is for the source or tool ITSELF failing (an API errors, `gh auth`
breaks, a git remote goes stale) - a menu a loop's LOOP.md can draw from
when it defines per-source failure handling, not a required declaration.
Implement only the tiers relevant to the sources a given loop actually has;
a loop with no git-backed sources has no resync tier.

Adapted from bradygaster/squad's "Ralph" watch-mode daemon (evaluated
2026-08-22, github.com/bradygaster/squad) - squad itself was skipped
entirely (it runs exclusively through GitHub Copilot, platform-incompatible
here), but this one convention from it was worth taking on its own.

1. **Reset** - retry the failed call once, in-run, before concluding
   anything is actually broken. Cheapest tier; catches transient blips
   (a single dropped connection, a momentary rate-limit) without any
   escalation at all.
2. **Reprobe** - if the retry also fails, check whether the failure
   implicates a shared dependency rather than the specific call (auth,
   network reachability) and report that ROOT CAUSE once, not per-target.
   `daily-triage` already does a narrow version of this: a single
   fleet-wide `gh auth status` check per run (adjustment
   `gitignore-and-auth-drift-check`, applied 2026-08-21) that names auth as
   the likely shared cause instead of letting every dependent check fail
   silently and separately.
3. **Resync** (git-backed sources only) - a read-only `git fetch` to refresh
   remote-tracking refs before declaring a source stale/unreachable, since a
   locally out-of-date clone can look dead when it is not. Weigh this
   against the loop's own L1 boundary before adopting it: fetching refs is
   data-gathering, not a corrective action, but it is still worth a loop
   stating explicitly in its LOOP.md that this tier stays read-only (fetch,
   never pull/merge) if the loop's L1 boundary requires that distinction.
4. **Report-unavailable** - once the above are exhausted (or don't apply),
   surface the failure plainly and stop trying for that source this run.
   `daily-triage`'s existing `distinguish-broken-probe-from-dead-source`
   rule (proposed runs 14-16 / 2026-08-11, applied 2026-08-17) is the
   working precedent for this tier: it distinguishes a source that is
   simply absent (one quiet "unavailable" line) from a multi-target source
   where 100% of targets fail the SAME way (one loud `probe failure:` line,
   never silently absorbed into a clean-looking digest).

A source that keeps landing on tier 4 across multiple runs is a candidate
for a human to `constrain` (Intervention ladder, step 2) - reaching
report-unavailable does not automatically constrain anything; it is a
related but distinct signal that gets surfaced in the run digest for a
human to act on.

## Continuous refinement

1. Per run: one-line critique in the run log; the loop honors the Human
   Decisions section next run.
2. Retrospective (runs_since_retro >= 10): read ALL of runs.jsonl + STATE.md,
   analyze trends, output a numbered refinement proposal (LOOP.md edits,
   thresholds, source add/drop, graduation when the gate is met). Human
   approves; apply via the loop-design skill; append a `retrospective`
   event; reset runs_since_retro.
3. Cross-loop: run critiques reach agent-learn via the existing Stop hook;
   promoted lessons land in domains/loop-design.md, which the loop-design
   skill reads whenever any loop is created or modified.

A loop NEVER edits its own LOOP.md autonomously - refinement is
human-approved at every level.

## Registered loops

| Loop | Level | Trigger | Since |
|---|---|---|---|
| daily-triage | 1 | SessionStart hook (first session of the day) | 2026-07-13 |
| pr-review-watch | 1 | SessionStart hook + in-session background watcher | 2026-09-06 |
