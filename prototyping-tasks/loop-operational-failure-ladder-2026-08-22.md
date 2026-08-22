# Prototyping task: operational-failure escalation ladder for loop-design

**Source evaluation:** evaluate-repo run against github.com/bradygaster/squad, 2026-08-22.
**Verdict on squad itself:** skip entirely, confidence 9/10 — it runs exclusively through GitHub Copilot as its agent execution engine (`copilot --agent squad`), which makes it platform-incompatible with this Claude-only setup regardless of feature quality. Its one idea worth taking is a design pattern from its "Ralph" watch-mode daemon, not the tool itself.

## Gap: no documented convention for a SOURCE/PROBE failing, as distinct from a finding

**What's missing today:** `loops/README.md`'s existing **Intervention ladder** (Escalate → Constrain → Stop) is explicitly about *finding quality* — a noisy or drifting source's *results* need narrowing. It has no answer for a different failure class: the source itself stops working (an API call errors, `gh auth` breaks, a git remote goes stale) as opposed to the source working but producing bad findings. Right now each loop would have to invent its own ad hoc handling for this the first time it hits it.

**Fit evidence (why now, not speculative):** This already happened. `daily-triage`'s Adjustment ledger records `distinguish-broken-probe-from-dead-source` (first proposed 2026-08-11, landed 2026-08-17) — a hand-rolled, narrow rule distinguishing "a source that's dead/absent" from "a multi-target source where 100% of targets fail the same way," built specifically because the loop had no general convention to fall back on. That's the exact problem class squad's Ralph mode has a documented, generalized answer for. `daily-triage` is currently the only registered loop, but the `loop-design` skill exists precisely so the *next* loop doesn't have to rediscover this from scratch.

**What squad's Ralph mode does that's worth taking (idea only, not the dependency):** a 4-tier operational-failure ladder before giving up on a probe within a single run: (1) reset/retry once, (2) reprobe the dependency the failure implicates (e.g. auth), (3) if the source is a git-backed one, try syncing it before declaring it stale, (4) if all else fails, back off (in squad's case a timed pause; here, more likely "mark this source unavailable for this run and report it plainly" rather than blocking the whole loop).

## Minimal prototype scope

- Add a new **Operational failure ladder** section to `~/agent-improvement/loops/README.md`, placed near the existing **Intervention ladder** section, explicit about the axis distinction: Intervention ladder = finding severity/noise; Operational failure ladder = the source/tool itself misbehaving.
- Keep it a **menu, not a mandate**: a loop implements only the tiers relevant to the sources it actually has (e.g. a loop with no git-backed sources has no "sync" tier). Do not make this a new required declaration in `loop-design/SKILL.md`'s creation checklist — that would force every future loop to justify tiers it doesn't need. Instead, reference it from the skill as available guidance for any loop's LOOP.md when it defines per-source failure handling.
- Reframe (don't rewrite) `daily-triage`'s existing `distinguish-broken-probe-from-dead-source` rule as the first real instance of tier 1/2 of this ladder, so the convention has a working precedent documented alongside it rather than being purely theoretical.
- Explicitly scope out: squad's actual timed-pause/backoff duration mechanics (`--overnight-start`/`--overnight-end`) — no current loop is continuous-poll (daily-triage runs once a day), so a real pause/backoff scheduler is speculative until a continuous-poll loop actually exists.

## Open questions

- Should the ladder's tiers be named generically (reset / reprobe / resync / report-unavailable) so they map cleanly onto non-git, non-API sources too, or is it acceptable for the doc to describe them with git/API examples and trust each loop to adapt?
- Does hitting the final tier (report-unavailable) count toward the Intervention ladder's existing `constrained_scopes` mechanism (a source that keeps failing operationally becomes a candidate for a human to `constrain`), or is it a fully separate, unrelated signal that just gets surfaced in the run digest?
- Is `daily-triage`'s existing rule specific enough to serve as the worked example, or does it need a slightly more general restatement to avoid the doc reading as "this is just what daily-triage already does" rather than a convention for loops in general?

## Status

**BUILT 2026-08-22**, same session, via the `port-gap` skill. Scaffolded directly — no `writing-plans` handoff needed, since all three open questions resolved to low-stakes naming/integration calls, not shape-changing design decisions.

- `~/agent-improvement/loops/README.md` — new `## Operational failure ladder` section added between the existing Intervention ladder and Continuous refinement sections, with the required axis-distinction framing (finding quality vs. source/tool failure) and explicit menu-not-mandate framing per the scope's constraint.
- `~/.claude/skills/loop-design/SKILL.md` — added a pointer in "Before designing" (step 4) to the new ladder as available guidance, NOT a required declaration, per the scope's explicit instruction not to add it to the creation checklist.

**Open questions, resolved as assumptions (all low-stakes, none shape-changing):**
1. *Generic tier names vs. git/API-specific description?* Went generic (Reset / Reprobe / Resync / Report-unavailable) with concrete examples under each, satisfying both concerns at once.
2. *Does report-unavailable auto-feed `constrained_scopes`?* No — kept as a related-but-distinct signal surfaced in the run digest; a human still has to act to `constrain`, consistent with the Intervention ladder's existing "human-added/removed entry, not something the loop sets on itself" rule.
3. *Is daily-triage's rule specific enough as the worked example?* Used it for tier 4 (report-unavailable) as originally proposed, but also found and cited a SECOND existing daily-triage precedent for tier 2 (reprobe) that wasn't in the original plan doc: the `gitignore-and-auth-drift-check` adjustment (applied 2026-08-21) already does a single fleet-wide `gh auth status` reprobe instead of letting every dependent check fail separately — a more accurate mapping than treating the broken-probe rule as covering both tiers 1-2 as originally drafted.

**Correction from the original plan doc:** the plan's "reframe `distinguish-broken-probe-from-dead-source` as tier 1/2" claim was too generous on inspection — that rule is a CLASSIFICATION/reporting rule (tier 4: report clearly, once), not a retry mechanism (it doesn't actually reset or reprobe). The final doc maps it to tier 4 only, and separately cites `gitignore-and-auth-drift-check` for tier 2. Tier 1 (Reset) and tier 3 (Resync) have no existing precedent in this store yet — documented as available tiers, not retrofitted onto daily-triage, since daily-triage's L1/once-daily/read-only shape doesn't obviously need either yet.

**Verification performed:** read back both edited files in full after writing; confirmed the new README section doesn't duplicate or contradict the existing Intervention ladder section, and that the SKILL.md addition doesn't add a new required-declaration checklist item (would have violated the scope's explicit constraint).

**Not built** (explicitly out of scope per this doc): squad's actual timed-pause/backoff scheduling mechanics — no current loop is continuous-poll, so this stays speculative until one exists.
