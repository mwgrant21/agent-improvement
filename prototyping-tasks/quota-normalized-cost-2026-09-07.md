# Prototyping task: quota-normalized cost (price what the subscription actually pays)

**Source evaluation:** evaluate-repo run against github.com/jan-bogaerts/md2, 2026-09-07.
**Verdict on md2 itself:** steal specific ideas only (confidence 8/10). md2 is a feature-card board with cost stats bolted on; aether-os and TokenMonitorV2 already out-measure it on token capture, cache-bucket fidelity, and pricing tables. The one thing it does that neither of ours does: it prices work in **subscription quota**, not in API dollars the user never pays. AGPL-3.0 is a footnote here (personal, never-sold tools; ideas port freely, no code vendoring).

## The gap

Both of our apps compute cost at API rates (aether `src/shared/ledgerMath.ts` + `modelPricing.ts`; TMv2 `packages/core/src/modelPricing.ts`). Both are subscription-only by policy (aether `codexSubscriptionPolicy`, TMv2 "zero API cost, enforced"). So every dollar figure we show is counterfactual: it is what the work *would* have cost on the API, not what Matt's Max/Pro plan is actually consuming. TMv2's `src/shared/budgetDerive.js` asks for a monthly *token* budget, never a plan price. `grep -ri "tokensPer\|perPercent"` across both repos: zero hits.

md2's model (`app/src/services/stats/stats_subscription_cost.ts`, ~10 lines; described in its `docs/concepts/usage-and-cost.md`):

1. Operator enters the monthly plan price per agent profile (e.g. $200 Max).
2. Convert to dollars per quota percentage point for the provider's reported window:
   `usdPerPoint = monthlyUsd / (100 * (40320 / windowMinutes))` using a 28-day month (40320 min). For the 7-day window that is `monthlyUsd / 400`.
3. Correlate the project's per-bucket token deltas with the account's per-bucket `used_percentage` deltas to get an empirical tokens-per-point rate. Rules: ignore negative deltas (corrections), on reset treat delta as the current %.
4. Price each conversation/card/action as `tokens / tokensPerPoint * usdPerPoint`.

It is honest about its own limits: correlation not causation, and account usage includes other projects on the same account.

## Fit evidence (why now, not speculative)

- aether-os audit 2026-09-06 (memory `aether-os-audit-2026-09-06-remaining`) still lists "wrong pricing math" as open. The right fix for a subscription-only app is a cost type that is not API pricing at all, not a fourth correction to the API table.
- aether already captures the input: `electron/statuslineWatcher.ts` / `src/shared/statuslinePayload.ts` read the statusline hook's `rate_limits` (five-hour and seven-day), and `src/shared/depletion.ts` already consumes `usedPercentage` for time-to-exhaustion. The percentage series exists; nothing joins it to tokens.
- TMv2 v2.0.0-alpha.1 already has a plan-usage snapshot (`src/shared/planUsageConfig.js`) and a budgets panel (`src/renderer/dashboard/panels/budgets.js`); a plan price is one field away.
- Directly serves the user's stated goal: "genuinely improve our model" of cost, and "have agents be more efficient" (a tokens-per-quota-point series makes Claude-vs-Codex efficiency measurable per engine with no rate table).

## Minimal prototype scope

Vertical slice, aether-os first (it already has the % series), TMv2 second.

**aether-os**
1. `src/shared/ledgerMath.ts`: add a third, structurally distinct cost type beside the existing exact/estimated shapes, e.g. `QuotaCost { usdPlan: number; points: number; basis: 'seven_day' | 'five_hour'; tokensPerPoint: number }`. Pure function `planCostPerPoint(monthlyUsd, windowMs)`; unit tests next to `ledgerMath.test.ts`.
2. `src/shared/quotaEfficiency.ts` (new): derive `tokensPerPoint` per time bucket from collector token events joined to statusline `usedPercentage` snapshots. Encode md2's three rules (positive deltas only, reset handling, same-bucket alignment). Tests with synthetic series including a reset.
3. Ledger: price each dispatch in quota dollars alongside the API estimate. Show both; label the API figure as counterfactual.
4. Setting: monthly plan USD per provider (Claude now; Codex once `account/rateLimits/read` lands, see item 3 below).

**TokenMonitorV2**
5. Same `planCostPerPoint` in `packages/core`; plan USD stored beside the `planUsageConfig.js` snapshot; render "budget vs quota" in `budgets.js`. Depends on TMv2 having a % series: either keep the `/usage` scraper (`src/main/usageScraper.js`) or port aether's statusline-file reader and retire scraping (preferred; see companion ideas).

**Out of scope for the prototype:** per-card boards, worktree UI, remote control, any md2 code.

## Companion steal-ideas from the same evaluation (Comparable, could enhance ours; IN SCOPE)

Originally listed as opportunistic. On 2026-09-07 the user set a standing rule ("always evolve": take every enhancement, not only genuine gaps, unless there is a hard reason not to), so items 2-7 below are part of this doc's build scope alongside item 1. Each is a one-function change with a named landing spot. Suggested build order: 4 (guard, cheapest, protects the broker ledger) -> 3 (Codex rate limits, unblocks the Codex half of item 1) -> 1 + 2 (the gap) -> 5 -> 6 -> 7 (TMv2 side, together with the pricing-table port below).

| # | Idea | Landing spot | Payoff |
|---|---|---|---|
| 2 | Tokens-per-quota-point series (this doc's step 2, but useful standalone as an efficiency view) | aether `src/shared/quotaEfficiency.ts` | measures per-engine efficiency without pricing |
| 3 | Codex `account/rateLimits/read` via `codex app-server --stdio` without opening a thread | aether `electron/crossEngine/providers/codexAppServer.ts` (`readAccountRateLimits()`), feed `depletion.ts` | fills the Codex half of the quota bar (~60 lines; today it exists only in comments) |
| 4 | Codex token buckets are nested (cached within input, reasoning within output): subtract before summing | aether `readUsage` in `codexAppServer.ts` + a `providerConformance.ts` case; document on `TurnUsage` in `contract.ts` | prevents cache double-count before the broker ledger sums anything |
| 5 | Measured duration pauses while waiting on the user (permission / ask events), never `end - start` | aether `liveAgentTracker.ts` clock; `durationBaseline.ts` medians | kills false "slow run" anomaly narrations |
| 6 | Freeze usage totals at REQ close (immutable per-release summary) | `sdd-tracking`: stamp tokens / quota points into `.sdd/STATE.md` on close | "what did this feature cost" without recompute |
| 7 | Poll-failure reason enum for the `/usage` scrape (trust prompt, login, onboarding screens) | TMv2 `main.js` `plan:sync` | replaces bare "could not read /usage"; or retire scraping via aether's statusline reader |

**Side finding, not from md2:** TMv2 `packages/core/src/modelPricing.ts` still carries the placeholder table aether corrected on 2026-08-07 (opus 15/75, cache write at 1.0x, fable falls through to sonnet). Port aether's `src/shared/modelPricing.ts` and its tests as-is. Same author, no design work needed.

## Open questions (resolved 2026-09-07 via port-gap)

- **Cost window:** 7-day basis for $/point and tokens-per-point; 5-hour stays a live depletion gauge only; never mixed in one number. (User decision.)
- **External usage:** buckets where account % moved but this machine logged zero tokens are excluded from the fit and surfaced as an "external usage" indicator. (User decision.)
- **Isolation:** build in a separate git worktree per repo on a feature branch; another session is active in aether-os on #58-#60. (User decision.)
- **Plan price location:** aether's existing user-settings store, beside the statusline settings; TMv2 beside `planUsageConfig.js`. (Assumption, low stakes.)
- **Minimum samples:** show quota points only until 3 buckets carry both signals, then show dollars. (Assumption, low stakes.)

## Status

Plan only, not started. User confirmed on 2026-09-07 that the full scope (item 1 plus companions 2-7 and the TMv2 pricing-table port) should be built. Next step: `port-gap` on this doc; expect a hand-off to `superpowers:writing-plans` since the scope spans two repos and eight items.
