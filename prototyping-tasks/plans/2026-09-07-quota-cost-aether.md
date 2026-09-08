# Quota-Normalized Cost (aether-os half) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Price aether-os's work in the subscription quota it actually consumes — dollars per rate-limit percentage point, derived from an empirical tokens-per-point fit — instead of only the counterfactual API-rate estimate the Ledger shows today.

**Architecture:** Three new pure modules in `src/shared/` (`quotaEfficiency.ts`, `waitClock.ts`, plus additions to `ledgerMath.ts`) do all the arithmetic and are unit-tested in isolation. `electron/main.ts` owns the two impure edges: a ring buffer of statusline seven-day percentage samples fed by the existing `startStatuslineWatcher` callback, and the `TranscriptEvent[]` it already scans each 60s tick for Optimize/Ledger. It pushes a derived `QuotaEfficiency` snapshot over a new `quota:efficiency` IPC channel — only derived numbers cross, per `docs/privacy-and-data.md`. Separately, `electron/crossEngine/providers/codexAppServer.ts` gains a thread-free `account/rateLimits/read` probe and a fix for Codex's nested token buckets.

**Tech Stack:** TypeScript (strict), React 18, Electron 43.4.1, Vitest 2.1.8 (jsdom default, `// @vitest-environment node` pragma for stdio tests), no new dependencies.

**Spec:** `C:\Users\Matt\agent-improvement\prototyping-tasks\quota-normalized-cost-2026-09-07.md`

---

## Global Constraints

- **Repo:** `C:\Users\Matt\projects\aether-os`. All work happens in the git worktree created in Task 1 (`C:\Users\Matt\projects\aether-os-quota`, branch `feat/quota-normalized-cost`, based on `master`). Never edit the main checkout — another session is on `fix/hooks-shape-refusal` there.
- **HARD RULE — do not touch anything under `collector/`.** Another session is editing it right now (issues #58-#60). Nothing in this plan needs a collector read: every input comes from `electron/statuslineWatcher.ts` (already wired into `main.ts`) and from the `TranscriptEvent[]` that `scanAllProjects` already returns in `main.ts`. `collector/` is also excluded from the root vitest run (`vite.config.ts:14`) and has its own CI job, so a change there would not even be verified by this plan's commands.
- **Spec decisions, binding (spec lines 59-63):**
  - Cost basis is the **7-day** window. The 5-hour window stays a live depletion gauge only. Never mix them in one number.
  - Buckets where the account percentage moved but this machine logged zero tokens are **excluded from the fit** and surfaced as an "external usage" indicator.
  - Plan price lives in the **existing user-settings store** (`state.cfg`, persisted by `src/state/persistence.ts:65`), beside the statusline settings in `SettingsView.tsx`.
  - Show **quota points only** until **3** buckets carry both signals; only then show dollars.
- **`planCostPerPoint(monthlyUsd, windowMs) = monthlyUsd / (100 * (28 days / windowMs))`** — 28-day month, exactly as the spec states (line 14). For the 7-day window this is `monthlyUsd / 400`.
- **The new cost type is structurally distinct.** `src/shared/ledgerMath.ts:16-54` states the rule explicitly: `ExactCost` and `EstimatedCost` share no supertype and no field names, so the compiler rejects rendering one where another belongs. `QuotaCost` must obey the same rule — its money field is `usdPlan`, colliding with neither `usd` nor `usdApprox`. Do **not** overload `estimateDispatchCost`.
- **Test runner:** `npx vitest run` (npm script `test`). Default environment is jsdom (`vite.config.ts:10`). Any test that drives a `PassThrough`-backed child-process fake **must** carry `// @vitest-environment node` as its first line — jsdom's patched timers stop `'data'` events firing and the test hangs (see `electron/crossEngine/providers/providers.test.ts:1-6`).
- **Typecheck:** `npm run typecheck:electron` covers `electron/` and is **not** covered by `npm run build`. Run both. Every task's verification runs the full suite plus this.
- **CI lanes (controller-corrected 2026-09-07):** `.github/workflows/ci.yml` has four jobs: `test-and-build`, `collector`, and `go-collector` on `ubuntu-latest`, plus a blocking `windows-build` job on `windows-latest` (line 112; shipped in PR #46, it builds Electron and verifies artifacts and native modules). Tests run on the Ubuntu lanes; the Windows lane must keep building, so nothing in this plan may add a native dependency or a build step that only works on Linux.
- **node-pty fact:** `CLAUDE.md:222-224` — MSVC is installed on this box, but `node-pty` deliberately keeps using **prebuilds**. `npm ci` in a fresh worktree runs `postinstall` (`install-electron && node scripts/grant-appcontainer-acl.js`); do not add `--build-from-source`.
- **`src/state/persistence.test.ts` is a coverage gate.** Adding a key to `AetherState` fails that test unless the key is either added to the `savePersisted` whitelist or given a reasoned entry in `PERSISTENCE_EXCLUSIONS`. Task 8 does the latter.
- **No new npm dependencies.** `src/shared/noApiCalls.test.ts` also forbids any new `claude-[a-z]+-\d`-shaped literal outside its exceptions set — no task here adds one.
- Commit after every task. Commit messages end with:
  ```
  Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
  ```

---

## File Structure

**Created**
| File | Responsibility |
|---|---|
| `src/shared/quotaEfficiency.ts` | Pure: join token samples to quota-percentage samples per time bucket, produce `tokensPerPoint` + per-bucket outcomes. |
| `src/shared/quotaEfficiency.test.ts` | Its tests, including a window reset and an external-usage bucket. |
| `src/shared/waitClock.ts` | Pure: record "waiting on the user" intervals, subtract their overlap from a wall-clock span. |
| `src/shared/waitClock.test.ts` | Its tests. |
| `electron/crossEngine/providers/codexRateLimits.ts` | Pure: defensive parser for `account/rateLimits/read`'s response. |
| `electron/crossEngine/providers/codexRateLimits.test.ts` | Its tests. |
| `src/state/useQuotaSync.ts` | Renderer sync hook for the `quota:efficiency` channel. |
| `src/components/settings/PlanPriceCard.tsx` | Settings card for the monthly plan price. |
| `src/components/settings/PlanPriceCard.test.tsx` | Its test. |
| `src/components/ledger/QuotaCostCard.tsx` | Ledger card: 7-day points consumed, plan dollars, tokens/point, external-usage indicator. |
| `src/components/ledger/QuotaCostCard.test.tsx` | Its test. |

**Modified**
| File | Change |
|---|---|
| `electron/crossEngine/providers/contract.ts` | `TurnUsage` gains `reasoningOutputTokens`; the nesting rule is documented on the type. |
| `electron/crossEngine/providers/codexAppServer.ts` | `readUsage` de-nests Codex's buckets; new `readAccountRateLimits()`. |
| `electron/crossEngine/providers/claudeHeadlessCli.ts` | `readUsage` returns the new field (Claude's buckets are already disjoint). |
| `electron/crossEngine/providers/providerConformance.ts` | New case: usage buckets are present and non-negative. |
| `electron/crossEngine/providers/providers.test.ts` | Fakes and expectations updated for the four-field usage; new rate-limit tests. |
| `src/shared/depletion.ts` | `deriveDepletion`'s parameter widened to a structural subset so a Codex readout can feed it. |
| `src/shared/ledgerMath.ts` | `QuotaCost`, `planCostPerPoint`, `quotaCostForTokens`, window constants. |
| `src/shared/ledgerMath.test.ts` | Tests for the above. |
| `electron/main.ts` | Quota sample buffers, `quota:efficiency` push/pull, wait-clock wiring. |
| `electron/main.narration.test.ts` | Pins the new narration call shape. |
| `electron/preload.ts`, `src/aetherElectron.d.ts` | `quota` namespace. |
| `src/state/types.ts`, `initialState.ts`, `reducer.ts`, `persistence.ts` | `quotaEfficiency` state + `cfg.planMonthlyUsd`. |
| `src/App.tsx` | Mounts `QuotaSync`. |
| `src/components/settings/SettingsView.tsx` | Mounts `PlanPriceCard`. |
| `src/components/ledger/LedgerView.tsx` | Mounts `QuotaCostCard`, passes quota inputs to the dispatch table. |
| `src/components/ledger/DispatchCostTable.tsx` | Quota column; API column relabelled counterfactual. |
| `src/components/ledger/format.ts` | `planUsd`, `points`, `QUOTA_BASIS_TOOLTIP`. |

---

### Task 1: Isolated worktree with a green baseline

**Files:**
- Create: `C:\Users\Matt\projects\aether-os-quota` (git worktree, branch `feat/quota-normalized-cost`)
- Modify: none
- Test: the existing suite

**Interfaces:**
- Consumes: nothing.
- Produces: a worktree at `C:/Users/Matt/projects/aether-os-quota` on branch `feat/quota-normalized-cost`, with `node_modules` installed and a recorded baseline test count. Every later task runs its commands from this directory.

- [ ] **Step 1: Create the worktree off `master`**

```bash
cd /c/Users/Matt/projects/aether-os
git worktree add ../aether-os-quota -b feat/quota-normalized-cost master
```

Base is `master` (`a3cbed1`), **not** the checked-out `fix/hooks-shape-refusal` — that branch carries the other session's in-flight `collector/src/hookInstaller.ts` edit. The worktree is placed as a **sibling** of the repo, not under `.worktrees/`, so the root vitest run in the main checkout cannot collect this branch's tests (`vite.config.ts:37-40` only excludes `**/.worktrees/**` and `**/.claude/worktrees/**`).

- [ ] **Step 2: Install dependencies**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npm ci
```

Expected: install completes and `postinstall` (`install-electron && node scripts/grant-appcontainer-acl.js`) runs without error. `node-pty` uses its prebuild; do not force a source build.

- [ ] **Step 3: Record the green baseline**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run 2>&1 | tail -20
npm run typecheck:electron
npm run build
```

Expected: all three succeed. Write the test-file and test counts from the vitest summary line into the task notes — every later task compares against them, so a pre-existing failure is never mistaken for one this plan introduced.

- [ ] **Step 4: Commit the branch point**

Nothing to commit yet (the worktree adds no tracked files). Confirm a clean tree instead:

```bash
cd /c/Users/Matt/projects/aether-os-quota
git status --short
```

Expected: empty output.

---

### Task 2: Codex token buckets are nested — de-nest before anything sums them (spec item 4)

**Files:**
- Modify: `electron/crossEngine/providers/contract.ts:90-100`
- Modify: `electron/crossEngine/providers/codexAppServer.ts:100-112`
- Modify: `electron/crossEngine/providers/claudeHeadlessCli.ts:122-131`
- Modify: `electron/crossEngine/providers/providerConformance.ts:144-154`
- Test: `electron/crossEngine/providers/providers.test.ts` (lines 162, 331, 367, 459, 500, 816)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `TurnUsage = { inputTokens: number | null; outputTokens: number | null; cachedInputTokens: number | null; reasoningOutputTokens: number | null }` with **disjoint** buckets, and `EMPTY_USAGE` carrying all four as `null`. No later task in this plan reads `TurnUsage` — this is a standalone correctness fix that protects the broker ledger before it starts summing.

The bug: Codex's `ThreadTokenUsage.last` reports `inputTokens` **including** `cachedInputTokens`, and `outputTokens` **including** `reasoningOutputTokens` (Codex's own `TokenUsage::non_cached_input()` subtracts the cache bucket for exactly this reason). `codexAppServer.ts:108-110` copies all three straight through, so anything that adds `inputTokens + cachedInputTokens` double-counts the cache. Claude's `claude -p` result usage is already disjoint (`input_tokens` excludes `cache_read_input_tokens`, per Anthropic API semantics) and reports no separate reasoning bucket, so its adapter only gains an explicit `null`.

- [ ] **Step 1: Write the failing tests**

In `electron/crossEngine/providers/providers.test.ts`, change the app-server fake's token usage at line ~162 so the nesting is unambiguous, then add a new assertion. Replace the `push('thread/tokenUsage/updated', ...)` call inside `appServerFake()` with:

```ts
        push('thread/tokenUsage/updated', {
          threadId,
          turnId: 'turn-1',
          // Deliberately NESTED, the way the real server reports it:
          // inputTokens (100) INCLUDES cachedInputTokens (80), and
          // outputTokens (50) INCLUDES reasoningOutputTokens (30).
          tokenUsage: {
            last: { inputTokens: 100, outputTokens: 50, cachedInputTokens: 80, reasoningOutputTokens: 30 },
          },
        });
```

Replace the existing assertion at line ~367 (`expect(result.usage).toEqual({ inputTokens: 11, outputTokens: 22, cachedInputTokens: 33 })`) inside the `it('reports provider-supplied token usage rather than nulls', ...)` case with:

```ts
    expect(result.usage).toEqual({
      inputTokens: 20,             // 100 reported - 80 cached
      outputTokens: 20,            // 50 reported - 30 reasoning
      cachedInputTokens: 80,
      reasoningOutputTokens: 30,
    });
```

Add a new case immediately after it, in the same `describe('CodexAppServerAdapter', ...)` block:

```ts
  it('never reports a negative bucket when the server claims more cache than input', async () => {
    const fake = makeStdioFake((req, push) => {
      if (req.method === 'initialize') return { userAgent: 'x' };
      if (req.method === 'thread/start') return { thread: { id: 'thread-1' } };
      if (req.method === 'turn/start') {
        const threadId = (req.params as { threadId: string }).threadId;
        push('thread/tokenUsage/updated', {
          threadId,
          turnId: 't',
          tokenUsage: { last: { inputTokens: 5, outputTokens: 5, cachedInputTokens: 9, reasoningOutputTokens: 9 } },
        });
        push('turn/completed', { threadId, turn: { id: 't', status: 'completed' } });
        return { turn: { id: 't', status: 'inProgress' } };
      }
      return {};
    });
    const adapter = new CodexAppServerAdapter(() => fake.child);
    await adapter.connect();
    const sessionId = await adapter.newSession({ cwd: 'C:/tmp/snapshot' });
    const result = await adapter.sendTurn({ sessionId, text: 'go' }, () => {});
    expect(result.usage.inputTokens).toBe(0);
    expect(result.usage.outputTokens).toBe(0);
    await adapter.dispose();
  });
```

Update the two existing four-field-blind expectations. At line ~331 (`LegacyCodexAcpAdapter`):

```ts
    expect(result.usage).toEqual({
      inputTokens: null, outputTokens: null, cachedInputTokens: null, reasoningOutputTokens: null,
    });
```

At line ~816 (`ClaudeHeadlessCliAdapter`):

```ts
    expect(result.usage).toEqual({
      inputTokens: 5, outputTokens: 7, cachedInputTokens: 9, reasoningOutputTokens: null,
    });
```

Add the new conformance case in `electron/crossEngine/providers/providerConformance.ts`, replacing the body of `it('reports a usage shape with the three token fields present', ...)` (line 144) with:

```ts
    it('reports four disjoint, non-negative token buckets', async () => {
      const adapter = await target.create();
      if (!adapter.capabilities().usageReporting) return;
      await adapter.connect();
      const sessionId = await adapter.newSession({ cwd: process.cwd() });
      const result = await adapter.sendTurn({ sessionId, text: 'hello' }, () => {});
      // The buckets are DISJOINT by contract (see TurnUsage in contract.ts):
      // a provider that reports nested buckets must subtract before reporting.
      // A negative value is the signature of that subtraction done without a
      // floor -- the one failure mode the de-nesting itself can introduce.
      for (const key of ['inputTokens', 'outputTokens', 'cachedInputTokens', 'reasoningOutputTokens'] as const) {
        expect(result.usage).toHaveProperty(key);
        const value = result.usage[key];
        expect(value === null || (Number.isFinite(value) && value >= 0)).toBe(true);
      }
      await adapter.dispose();
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run electron/crossEngine/providers/providers.test.ts
```

Expected: FAIL. The nested-usage case reports `{ inputTokens: 100, outputTokens: 50, cachedInputTokens: 80 }` (no subtraction, missing field); the legacy and Claude cases fail on the missing `reasoningOutputTokens` key.

- [ ] **Step 3: Widen the contract**

In `electron/crossEngine/providers/contract.ts`, replace lines 90-100 with:

```ts
/**
 * Per-turn token usage, in FOUR DISJOINT buckets.
 *
 * Disjoint is the load-bearing word, and it is a contract every adapter owes
 * rather than a property the wire format supplies. Codex's app-server reports
 * them NESTED -- `ThreadTokenUsage.last.inputTokens` includes
 * `cachedInputTokens`, and `outputTokens` includes `reasoningOutputTokens`
 * (Codex's own `TokenUsage::non_cached_input()` subtracts the cache bucket for
 * exactly this reason). Copying those straight through means any consumer that
 * sums the buckets -- the broker ledger being the one that will -- counts every
 * cached token twice and every reasoning token twice, silently, with no
 * anomaly to notice.
 *
 * So the adapter subtracts, and this type states the post-subtraction meaning:
 *   inputTokens   FRESH input only. EXCLUDES cachedInputTokens.
 *   outputTokens  VISIBLE output only. EXCLUDES reasoningOutputTokens.
 * Which makes `inputTokens + outputTokens + cachedInputTokens +
 * reasoningOutputTokens` a correct grand total, and makes it correct for every
 * provider rather than for whichever one the caller happened to have in mind.
 *
 * Claude's `claude -p` result usage is already disjoint (`input_tokens`
 * excludes `cache_read_input_tokens`) and reports no separate reasoning
 * bucket, so its adapter subtracts nothing and reports
 * `reasoningOutputTokens: null`.
 *
 * `null` means NOT REPORTED, and is deliberately different from 0. An adapter
 * with usageReporting: false reports four nulls rather than four zeros.
 */
export interface TurnUsage {
  inputTokens: number | null;
  outputTokens: number | null;
  cachedInputTokens: number | null;
  reasoningOutputTokens: number | null;
}

export const EMPTY_USAGE: TurnUsage = Object.freeze({
  inputTokens: null,
  outputTokens: null,
  cachedInputTokens: null,
  reasoningOutputTokens: null,
});
```

- [ ] **Step 4: De-nest in the Codex adapter**

In `electron/crossEngine/providers/codexAppServer.ts`, replace `readUsage` (lines 100-112) with:

```ts
/** Reads a ThreadTokenUsage's `last` breakdown defensively, DE-NESTING it.
 *  Field casing is not asserted -- both camelCase and snake_case are accepted
 *  so a serde rename in a future codex build degrades to nulls rather than
 *  throwing.
 *
 *  The subtraction is floored at zero. A server that reports more cache than
 *  input (a rounding artifact, or a bucket definition drifting in a future
 *  build) must not turn into a negative token count that then subtracts real
 *  spend from a ledger total -- clamping loses a little accuracy in a case
 *  that should not happen; a negative loses correctness in a case that then
 *  propagates. */
function readUsage(raw: unknown): TurnUsage {
  const last = (raw as { last?: Record<string, unknown> } | undefined)?.last;
  if (!last) return EMPTY_USAGE;
  const num = (v: unknown) => (typeof v === 'number' ? v : null);

  const reportedInput = num(last.inputTokens ?? last.input_tokens);
  const reportedOutput = num(last.outputTokens ?? last.output_tokens);
  const cachedInputTokens = num(last.cachedInputTokens ?? last.cached_input_tokens);
  const reasoningOutputTokens = num(last.reasoningOutputTokens ?? last.reasoning_output_tokens);

  const denest = (total: number | null, nested: number | null): number | null =>
    total === null ? null : Math.max(0, total - (nested ?? 0));

  return {
    inputTokens: denest(reportedInput, cachedInputTokens),
    outputTokens: denest(reportedOutput, reasoningOutputTokens),
    cachedInputTokens,
    reasoningOutputTokens,
  };
}
```

- [ ] **Step 5: Report the explicit null in the Claude adapter**

In `electron/crossEngine/providers/claudeHeadlessCli.ts`, replace `readUsage`'s return object (lines 126-130) with:

```ts
  return {
    // Already disjoint on this wire format: the Anthropic result's
    // `input_tokens` excludes `cache_read_input_tokens`, so nothing is
    // subtracted here. Reasoning tokens are not broken out separately on this
    // surface at all, which is `null` (not reported), never 0.
    inputTokens: num(u.input_tokens),
    outputTokens: num(u.output_tokens),
    cachedInputTokens: num(u.cache_read_input_tokens),
    reasoningOutputTokens: null,
  };
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run electron/crossEngine/providers/providers.test.ts
npx vitest run
npm run typecheck:electron
```

Expected: PASS on all three. Total test count is the Task 1 baseline plus one (the new negative-bucket case); the conformance case was renamed, not added, so its four instances (fake, legacy, app-server, claude) keep their count.

- [ ] **Step 7: Commit**

```bash
cd /c/Users/Matt/projects/aether-os-quota
git add electron/crossEngine/providers/contract.ts electron/crossEngine/providers/codexAppServer.ts electron/crossEngine/providers/claudeHeadlessCli.ts electron/crossEngine/providers/providerConformance.ts electron/crossEngine/providers/providers.test.ts
git commit -m "$(cat <<'EOF'
fix(crossEngine): de-nest Codex token buckets before any consumer sums them

Codex reports inputTokens including cachedInputTokens and outputTokens
including reasoningOutputTokens. Subtract at the adapter, document the
disjointness on TurnUsage, and add a conformance case that fails on a
negative bucket.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: A defensive parser for `account/rateLimits/read` (spec item 3, pure half)

**Files:**
- Create: `electron/crossEngine/providers/codexRateLimits.ts`
- Create: `electron/crossEngine/providers/codexRateLimits.test.ts`
- Modify: `src/shared/depletion.ts:41-45`

**Interfaces:**
- Consumes: `RateLimitWindow` from `src/shared/statuslinePayload.ts:1-4` (`{ usedPercentage: number; resetsAtMs: number }`).
- Produces:
  - `interface RateLimitWindowReadout { usedPercentage: number; windowMinutes: number | null; resetsAtMs: number | null }`
  - `interface AccountRateLimits { capturedAtMs: number; primary: RateLimitWindowReadout | null; secondary: RateLimitWindowReadout | null }`
  - `function parseAccountRateLimits(raw: unknown, capturedAtMs: number): AccountRateLimits`
  - `function asDepletionInput(limits: AccountRateLimits): DepletionInput`
  - `type DepletionInput = Pick<StatuslineSnapshot, 'capturedAtMs' | 'fiveHour'>` exported from `src/shared/depletion.ts`, and `deriveDepletion`'s first parameter widened to `DepletionInput | null`.
- Task 4 consumes `parseAccountRateLimits` and `AccountRateLimits`.

`grep -rn "rateLimits" ` across the repo finds only a **comment** (`electron/crossEngine/providers/contract.ts:18`, which lists `account/rateLimits/read` among the app-server's methods) and the unrelated `rate_limits` key in `src/shared/statuslinePayload.ts:94`. There are no vendored bindings and no generated types for this method anywhere, so the shape below is defined from the spec ("request has no params, response includes rate limit windows with used percentage and reset time") and parsed defensively in both casings — the same posture `readUsage` and `parseStatuslinePayload` already take.

- [ ] **Step 1: Write the failing test**

Create `electron/crossEngine/providers/codexRateLimits.test.ts`:

```ts
import { describe, it, expect } from 'vitest';
import { parseAccountRateLimits, asDepletionInput } from './codexRateLimits';

const AT = Date.UTC(2026, 8, 7, 12, 0, 0);

describe('parseAccountRateLimits', () => {
  it('reads snake_case windows with an epoch-seconds reset', () => {
    const parsed = parseAccountRateLimits(
      {
        rate_limits: {
          primary: { used_percent: 42.5, window_minutes: 300, resets_at: AT / 1000 + 600 },
          secondary: { used_percent: 7, window_minutes: 10080, resets_at: AT / 1000 + 86400 },
        },
      },
      AT,
    );
    expect(parsed.primary).toEqual({ usedPercentage: 42.5, windowMinutes: 300, resetsAtMs: AT + 600_000 });
    expect(parsed.secondary).toEqual({ usedPercentage: 7, windowMinutes: 10080, resetsAtMs: AT + 86_400_000 });
    expect(parsed.capturedAtMs).toBe(AT);
  });

  it('reads camelCase windows at the top level, with no rateLimits envelope', () => {
    const parsed = parseAccountRateLimits(
      { primary: { usedPercent: 10, windowMinutes: 300, resetsInSeconds: 60 } },
      AT,
    );
    expect(parsed.primary).toEqual({ usedPercentage: 10, windowMinutes: 300, resetsAtMs: AT + 60_000 });
    expect(parsed.secondary).toBeNull();
  });

  it('accepts an ISO reset timestamp', () => {
    const parsed = parseAccountRateLimits(
      { primary: { usedPercentage: 1, resetsAt: '2026-09-07T13:00:00.000Z' } },
      AT,
    );
    expect(parsed.primary?.resetsAtMs).toBe(Date.UTC(2026, 8, 7, 13, 0, 0));
    expect(parsed.primary?.windowMinutes).toBeNull();
  });

  it('returns nulls rather than throwing on junk, an absent response, or a non-numeric percentage', () => {
    for (const raw of [null, undefined, 42, 'nope', [], { primary: { used_percent: 'lots' } }]) {
      const parsed = parseAccountRateLimits(raw, AT);
      expect(parsed.primary).toBeNull();
      expect(parsed.secondary).toBeNull();
      expect(parsed.capturedAtMs).toBe(AT);
    }
  });

  it('keeps a window whose reset time is unreadable, because the percentage is still usable', () => {
    const parsed = parseAccountRateLimits({ primary: { used_percent: 55, resets_at: 'never' } }, AT);
    expect(parsed.primary).toEqual({ usedPercentage: 55, windowMinutes: null, resetsAtMs: null });
  });
});

describe('asDepletionInput', () => {
  it('maps the primary window onto the shape deriveDepletion consumes', () => {
    const parsed = parseAccountRateLimits(
      { primary: { used_percent: 40, window_minutes: 300, resets_at: AT / 1000 + 1800 } },
      AT,
    );
    expect(asDepletionInput(parsed)).toEqual({
      capturedAtMs: AT,
      fiveHour: { usedPercentage: 40, resetsAtMs: AT + 1_800_000 },
    });
  });

  it('yields a null window when the primary reset time is unknown, since a projection needs one', () => {
    const parsed = parseAccountRateLimits({ primary: { used_percent: 40 } }, AT);
    expect(asDepletionInput(parsed).fiveHour).toBeNull();
  });
});
```

Add one case to the existing `src/shared/depletion.test.ts` proving the widened parameter accepts the narrower shape:

```ts
  it('accepts a bare DepletionInput, not only a full StatuslineSnapshot', () => {
    const now = Date.UTC(2026, 8, 7, 12, 0, 0);
    const readout = deriveDepletion(
      { capturedAtMs: now, fiveHour: { usedPercentage: 50, resetsAtMs: now + 2 * 60 * 60 * 1000 } },
      now - 2 * 60 * 60 * 1000,
      now,
    );
    expect(readout.source).toBe('statusline');
    expect(readout.usedPercentage).toBe(50);
    expect(readout.msUntilDepleted).toBe(2 * 60 * 60 * 1000);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run electron/crossEngine/providers/codexRateLimits.test.ts src/shared/depletion.test.ts
```

Expected: FAIL — `Failed to resolve import "./codexRateLimits"`, and a TS error on the depletion case (`fiveHour`/`capturedAtMs` object is not assignable to `StatuslineSnapshot`).

- [ ] **Step 3: Widen `deriveDepletion`'s parameter**

In `src/shared/depletion.ts`, insert after the import on line 1 and change the signature on lines 41-45:

```ts
import type { StatuslineSnapshot } from './statuslinePayload';

/**
 * The only two fields deriveDepletion actually reads. Named and taken
 * structurally so a source that is NOT the Claude statusline -- Codex's
 * `account/rateLimits/read`, via codexRateLimits.ts's asDepletionInput --
 * can feed the same projection without either faking the other ten fields of
 * a StatuslineSnapshot or getting a parallel copy of this arithmetic.
 * StatuslineSnapshot still satisfies it, so every existing caller is
 * unchanged.
 */
export type DepletionInput = Pick<StatuslineSnapshot, 'capturedAtMs' | 'fiveHour'>;
```

```ts
export function deriveDepletion(
  snapshot: DepletionInput | null,
  windowStartMs: number | null,
  nowMs: number,
): DepletionReadout {
```

- [ ] **Step 4: Write the parser**

Create `electron/crossEngine/providers/codexRateLimits.ts`:

```ts
// Parser for `account/rateLimits/read` on `codex app-server`.
//
// Unlike every other method this directory speaks, there are no generated
// bindings for this one in the repo: `grep -rn "rateLimits"` finds only the
// method-list comment in contract.ts. The shape below is therefore taken from
// the prototyping spec ("request has no params, response includes rate limit
// windows with used percentage and reset time") and parsed the way readUsage
// and parseStatuslinePayload already are -- accept both casings, accept every
// plausible spelling of the reset time, and degrade a field this parser cannot
// read to null rather than discarding the whole readout or throwing.
//
// A percentage with no reset time is still worth keeping: "58% of the weekly
// window is gone" is the number the quota view needs; the reset time only
// feeds the countdown.
import type { RateLimitWindow } from '../../../src/shared/statuslinePayload';
import type { DepletionInput } from '../../../src/shared/depletion';

export interface RateLimitWindowReadout {
  /** 0-100. */
  usedPercentage: number;
  /** The window's length as the server describes it (300 = the 5-hour window,
   *  10080 = the 7-day one). null when absent -- never inferred. */
  windowMinutes: number | null;
  /** Epoch MILLISECONDS, converted from whichever form the server sent. */
  resetsAtMs: number | null;
}

export interface AccountRateLimits {
  capturedAtMs: number;
  /** The shorter, faster-moving window (the 5-hour one on a ChatGPT plan). */
  primary: RateLimitWindowReadout | null;
  /** The longer window (the weekly one). */
  secondary: RateLimitWindowReadout | null;
}

function num(v: unknown): number | null {
  return typeof v === 'number' && Number.isFinite(v) ? v : null;
}

/** Epoch ms from an epoch-SECONDS number, an ISO string, or a relative
 *  seconds-from-now offset -- in that order of preference. */
function readResetMs(w: Record<string, unknown>, capturedAtMs: number): number | null {
  const absolute = w.resetsAt ?? w.resets_at;
  const seconds = num(absolute);
  if (seconds !== null) return seconds * 1000;
  if (typeof absolute === 'string') {
    const parsed = Date.parse(absolute);
    if (!Number.isNaN(parsed)) return parsed;
  }
  const relative = num(w.resetsInSeconds ?? w.resets_in_seconds);
  if (relative !== null) return capturedAtMs + relative * 1000;
  return null;
}

function readWindow(raw: unknown, capturedAtMs: number): RateLimitWindowReadout | null {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return null;
  const w = raw as Record<string, unknown>;
  const usedPercentage = num(w.usedPercent ?? w.used_percent ?? w.usedPercentage ?? w.used_percentage);
  if (usedPercentage === null) return null;
  return {
    usedPercentage,
    windowMinutes: num(w.windowMinutes ?? w.window_minutes),
    resetsAtMs: readResetMs(w, capturedAtMs),
  };
}

/** Never throws. Anything unreadable becomes a null window. */
export function parseAccountRateLimits(raw: unknown, capturedAtMs: number): AccountRateLimits {
  const empty: AccountRateLimits = { capturedAtMs, primary: null, secondary: null };
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return empty;
  const outer = raw as Record<string, unknown>;
  // The windows may arrive wrapped (`{ rateLimits: { primary, secondary } }`)
  // or bare. Both are accepted rather than guessed at.
  const wrapped = outer.rateLimits ?? outer.rate_limits;
  const source =
    typeof wrapped === 'object' && wrapped !== null && !Array.isArray(wrapped)
      ? (wrapped as Record<string, unknown>)
      : outer;
  return {
    capturedAtMs,
    primary: readWindow(source.primary, capturedAtMs),
    secondary: readWindow(source.secondary, capturedAtMs),
  };
}

/** The primary window in the shape `deriveDepletion` consumes.
 *
 *  A window with no reset time yields null: every projection in
 *  depletion.ts is anchored to `resetsAtMs` (it derives the window start from
 *  it when the caller supplies none), so handing it a fabricated reset would
 *  produce a confident, wrong countdown rather than an honest "no data". */
export function asDepletionInput(limits: AccountRateLimits): DepletionInput {
  return { capturedAtMs: limits.capturedAtMs, fiveHour: toRateLimitWindow(limits.primary) };
}

export function toRateLimitWindow(readout: RateLimitWindowReadout | null): RateLimitWindow | null {
  if (readout === null || readout.resetsAtMs === null) return null;
  return { usedPercentage: readout.usedPercentage, resetsAtMs: readout.resetsAtMs };
}
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run electron/crossEngine/providers/codexRateLimits.test.ts src/shared/depletion.test.ts
npx vitest run
npm run typecheck:electron
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /c/Users/Matt/projects/aether-os-quota
git add electron/crossEngine/providers/codexRateLimits.ts electron/crossEngine/providers/codexRateLimits.test.ts src/shared/depletion.ts src/shared/depletion.test.ts
git commit -m "$(cat <<'EOF'
feat(crossEngine): defensive parser for codex account/rateLimits/read

No bindings for this method exist in the repo, so the shape is taken from
the spec and parsed in both casings. Widen deriveDepletion's parameter to
the structural subset it reads so a Codex readout can feed it.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `readAccountRateLimits()` on the app-server adapter, without opening a thread (spec item 3, transport half)

**Files:**
- Modify: `electron/crossEngine/providers/codexAppServer.ts` (add a method after `health()`, which ends at line 536)
- Test: `electron/crossEngine/providers/providers.test.ts` (new cases in `describe('CodexAppServerAdapter', ...)`)

**Interfaces:**
- Consumes: `parseAccountRateLimits`, `AccountRateLimits` from Task 3.
- Produces: `CodexAppServerAdapter.readAccountRateLimits(nowMs?: number): Promise<AccountRateLimits>`. Not added to the `ProviderAdapter` interface — this is Codex-specific, and widening the provider-neutral contract for a method one provider has is exactly the fake-a-feature-you-lack pattern `providerConformance.ts:9-13` exists to prevent.

The point of the task is the negative: the probe must reach the account surface **without** `thread/start`. A thread costs a Codex-side session and, on a read-only adapter, buys nothing.

- [ ] **Step 1: Write the failing tests**

Add to `electron/crossEngine/providers/providers.test.ts`, inside `describe('CodexAppServerAdapter', ...)`:

```ts
  it('reads account rate limits without opening a thread', async () => {
    const at = Date.UTC(2026, 8, 7, 12, 0, 0);
    const fake = makeStdioFake((req) => {
      if (req.method === 'initialize') return { userAgent: 'codex-app-server/0.153.2' };
      if (req.method === 'account/rateLimits/read') {
        return {
          rate_limits: {
            primary: { used_percent: 12, window_minutes: 300, resets_at: at / 1000 + 900 },
            secondary: { used_percent: 63.5, window_minutes: 10080, resets_at: at / 1000 + 200_000 },
          },
        };
      }
      return {};
    });
    const adapter = new CodexAppServerAdapter(() => fake.child);
    await adapter.connect();

    const limits = await adapter.readAccountRateLimits(at);

    expect(limits.primary).toEqual({ usedPercentage: 12, windowMinutes: 300, resetsAtMs: at + 900_000 });
    expect(limits.secondary?.usedPercentage).toBe(63.5);
    // The whole point: no session was spent to read this.
    expect(fake.received.some((r) => r.method === 'thread/start')).toBe(false);
    expect(fake.received.some((r) => r.method === 'turn/start')).toBe(false);
    await adapter.dispose();
  });

  it('sends an explicit empty params object on account/rateLimits/read', async () => {
    const fake = makeStdioFake((req) => (req.method === 'initialize' ? { userAgent: 'x' } : {}));
    const adapter = new CodexAppServerAdapter(() => fake.child);
    await adapter.connect();
    await adapter.readAccountRateLimits(0);
    // Same reason account/read sends {} rather than omitting params (see the
    // comment in health()): the server rejects the call when the params key is
    // absent entirely, and that rejection is easy to swallow into a null readout.
    const sent = fake.received.find((r) => r.method === 'account/rateLimits/read');
    expect(sent?.params).toEqual({});
    await adapter.dispose();
  });

  it('rejects readAccountRateLimits before connect() with NOT_CONNECTED', async () => {
    const fake = makeStdioFake(() => ({}));
    const adapter = new CodexAppServerAdapter(() => fake.child);
    let caught: unknown;
    try {
      await adapter.readAccountRateLimits(0);
    } catch (err) {
      caught = err;
    }
    expect(caught).toBeInstanceOf(ProviderError);
    expect((caught as ProviderError).code).toBe('NOT_CONNECTED');
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run electron/crossEngine/providers/providers.test.ts -t "rate limits"
```

Expected: FAIL — `adapter.readAccountRateLimits is not a function`.

- [ ] **Step 3: Add the method**

In `electron/crossEngine/providers/codexAppServer.ts`, add the import alongside the existing ones near line 39:

```ts
import { parseAccountRateLimits, type AccountRateLimits } from './codexRateLimits';
```

and insert this method immediately after `health()` (i.e. after line 536, before `async newSession`):

```ts
  /**
   * The account's rate-limit windows, read WITHOUT opening a thread.
   *
   * `account/rateLimits/read` sits on the same account surface as
   * `account/read` -- it needs `initialize` and nothing else. Routing it
   * through `thread/start` would spend a Codex session per poll to read two
   * percentages, and a read-only thread cannot make the answer any more
   * accurate. The test above asserts the absence of thread/start and
   * turn/start, because "we didn't open a thread" is the kind of property
   * that quietly stops being true.
   *
   * Deliberately NOT on the ProviderAdapter interface: only the app-server
   * exposes this. Widening the provider-neutral contract for a method one
   * provider has is exactly what providerConformance.ts's capability-gated
   * design exists to avoid.
   *
   * `nowMs` is a parameter rather than a `Date.now()` call so the parse is
   * deterministic under test -- a relative `resets_in_seconds` is anchored to
   * it.
   *
   * Unlike health(), this does NOT swallow transport failures into a
   * neutral-looking value: an empty readout and an unreachable server are
   * different facts, and a caller that renders "0% used" for the second one
   * would be worse than one that renders nothing.
   */
  async readAccountRateLimits(nowMs: number = Date.now()): Promise<AccountRateLimits> {
    this.require();
    const res = await this.call('account/rateLimits/read', {});
    return parseAccountRateLimits(res, nowMs);
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run electron/crossEngine/providers/providers.test.ts
npx vitest run
npm run typecheck:electron
```

Expected: PASS, three tests added to the baseline.

- [ ] **Step 5: Optional live confirmation (opt-in, spends no tokens)**

```bash
cd /c/Users/Matt/projects/aether-os-quota
AETHER_LIVE_PROVIDER_SMOKE=1 npx vitest run electron/crossEngine/providers/providers.live.test.ts
```

This gate is documented at `providers.live.test.ts:17-21` as spending **no** model tokens (handshake and read-only account probes only). It is not required for the task to pass — record the result either way, since it is the only check that the real server's field names match the parser.

- [ ] **Step 6: Commit**

```bash
cd /c/Users/Matt/projects/aether-os-quota
git add electron/crossEngine/providers/codexAppServer.ts electron/crossEngine/providers/providers.test.ts
git commit -m "$(cat <<'EOF'
feat(crossEngine): readAccountRateLimits() via app-server, no thread opened

Tests assert the absence of thread/start and turn/start, since that is the
property most likely to regress silently.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `QuotaCost` — the third cost type (spec item 1)

**Files:**
- Modify: `src/shared/ledgerMath.ts` (insert after `EstimatedCost`, line 54)
- Test: `src/shared/ledgerMath.test.ts`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `type QuotaBasis = 'seven_day' | 'five_hour'`
  - `const QUOTA_MONTH_MS: number` (28 days)
  - `const QUOTA_WINDOW_MS: Record<QuotaBasis, number>`
  - `interface QuotaCost { usdPlan: number | null; points: number; basis: QuotaBasis; tokensPerPoint: number }`
  - `function planCostPerPoint(monthlyUsd: number, windowMs: number): number`
  - `function quotaCostForTokens(tokens: number, tokensPerPoint: number, monthlyUsd: number | null, basis?: QuotaBasis): QuotaCost`
- Tasks 10 and 11 consume `QuotaCost`, `quotaCostForTokens`, and `planCostPerPoint`.

- [ ] **Step 1: Write the failing tests**

Add to `src/shared/ledgerMath.test.ts`. Extend the existing import block at the top with `planCostPerPoint`, `quotaCostForTokens`, `QUOTA_WINDOW_MS`, then append:

```ts
describe('planCostPerPoint', () => {
  it('prices a $200 plan at $0.50 per point on the seven-day window', () => {
    // 28-day month / 7-day window = 4 windows; 4 * 100 points = 400 points.
    expect(planCostPerPoint(200, QUOTA_WINDOW_MS.seven_day)).toBeCloseTo(0.5, 10);
  });

  it('prices the same plan far lower per point on the five-hour window', () => {
    // 40320 minutes / 300 = 134.4 windows; 13440 points.
    expect(planCostPerPoint(200, QUOTA_WINDOW_MS.five_hour)).toBeCloseTo(200 / 13440, 10);
  });

  it('returns 0 rather than Infinity or NaN for a zero, negative, or absent input', () => {
    expect(planCostPerPoint(0, QUOTA_WINDOW_MS.seven_day)).toBe(0);
    expect(planCostPerPoint(-200, QUOTA_WINDOW_MS.seven_day)).toBe(0);
    expect(planCostPerPoint(200, 0)).toBe(0);
    expect(planCostPerPoint(Number.NaN, QUOTA_WINDOW_MS.seven_day)).toBe(0);
  });
});

describe('quotaCostForTokens', () => {
  it('converts tokens to points and points to plan dollars', () => {
    // 500k tokens at 100k tokens/point = 5 points; 5 points at $0.50 = $2.50.
    const cost = quotaCostForTokens(500_000, 100_000, 200);
    expect(cost.points).toBeCloseTo(5, 10);
    expect(cost.usdPlan).toBeCloseTo(2.5, 10);
    expect(cost.basis).toBe('seven_day');
    expect(cost.tokensPerPoint).toBe(100_000);
  });

  it('reports points with usdPlan null when no plan price is configured', () => {
    const cost = quotaCostForTokens(500_000, 100_000, null);
    expect(cost.points).toBeCloseTo(5, 10);
    expect(cost.usdPlan).toBeNull();
  });

  it('reports zero points, not Infinity, when the fit has produced no rate yet', () => {
    const cost = quotaCostForTokens(500_000, 0, 200);
    expect(cost.points).toBe(0);
    expect(cost.usdPlan).toBe(0);
  });

  it('treats a missing or negative token count as zero', () => {
    expect(quotaCostForTokens(-5, 100_000, 200).points).toBe(0);
    expect(quotaCostForTokens(Number.NaN, 100_000, 200).points).toBe(0);
  });

  it('is structurally distinct from the other two cost types', () => {
    const quota = quotaCostForTokens(1000, 100, 200);
    const estimate = estimateDispatchCost({
      toolUseId: 't', subagentType: 'a', description: '', startedAt: '', prompt: '', model: null,
      tokens: 1000, toolUses: 0, durationMs: 0,
    });
    // No shared money field name: a renderer cannot read one where the other
    // belongs and still compile. This is the same invariant ExactCost and
    // EstimatedCost already hold (see ledgerMath.ts's header comment).
    expect(Object.keys(quota)).not.toContain('usd');
    expect(Object.keys(quota)).not.toContain('usdApprox');
    expect(Object.keys(estimate)).not.toContain('usdPlan');
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run src/shared/ledgerMath.test.ts
```

Expected: FAIL — `planCostPerPoint is not exported by src/shared/ledgerMath.ts`.

- [ ] **Step 3: Add the third cost type**

In `src/shared/ledgerMath.ts`, insert immediately after `EstimatedCost` (after line 54) and before the `// Tier 1 -- exact` divider:

```ts
/**
 * A cost expressed in the SUBSCRIPTION QUOTA the work actually consumed,
 * rather than in the API rates this account never pays.
 *
 * This is a third structurally distinct cost type, not a variant of the other
 * two, and for the same reason they are distinct from each other: the money
 * field is `usdPlan`, which collides with neither `usd` nor `usdApprox`, so a
 * renderer cannot accidentally show a plan-amortized figure where an exact or
 * an API-rate one belongs. The distinction matters more here than anywhere
 * else in this file -- ExactCost and EstimatedCost differ in PRECISION, but
 * QuotaCost differs in what is being measured. An operator on a Max plan pays
 * the same $200 whether these dispatches ran or not; the honest question is
 * what share of the month's quota they took, and that is what `points` is.
 *
 * `usdPlan` is `number | null`, and null is a real state with two causes, both
 * of which must render as points-only rather than as $0.00:
 *   - no monthly plan price has been entered in Settings, or
 *   - the tokens-per-point fit has not yet cleared MIN_FIT_BUCKETS
 *     (quotaEfficiency.ts), so there is no defensible rate to multiply by.
 *
 * `tokensPerPoint` is carried on the value rather than left at the call site,
 * for the same reason EstimatedCost carries its `tier` -- a renderer showing
 * the figure can name the empirical rate it came from, and two figures built
 * from different fits can be told apart.
 */
export interface QuotaCost {
  usdPlan: number | null;
  /** Rate-limit percentage points, on the window named by `basis`. */
  points: number;
  basis: QuotaBasis;
  tokensPerPoint: number;
}

export type QuotaBasis = 'seven_day' | 'five_hour';

/**
 * A fixed 28-day month, matching the basis the $/point formula is defined on
 * (spec: `monthlyUsd / (100 * (40320 / windowMinutes))`).
 *
 * Fixed rather than calendar deliberately: a calendar month makes $/point
 * swing 11% between February and March for a plan whose price never changed,
 * so a week-over-week efficiency comparison would move for a reason that has
 * nothing to do with efficiency.
 */
export const QUOTA_MONTH_MS = 28 * 24 * 60 * 60 * 1000;

export const QUOTA_WINDOW_MS: Record<QuotaBasis, number> = {
  seven_day: 7 * 24 * 60 * 60 * 1000,
  five_hour: 5 * 60 * 60 * 1000,
};

/**
 * Dollars per rate-limit percentage point.
 *
 * A plan buys 100 points per window, and a 28-day month contains
 * `QUOTA_MONTH_MS / windowMs` windows -- so the month buys
 * `100 * windowsPerMonth` points, and each is worth that fraction of the
 * price. On the 7-day window this is simply `monthlyUsd / 400`.
 *
 * Returns 0 (never Infinity or NaN) for a non-positive or non-finite input:
 * this feeds a currency display, and one bad settings value must not turn
 * every figure on the Ledger into "$NaN".
 */
export function planCostPerPoint(monthlyUsd: number, windowMs: number): number {
  if (!Number.isFinite(monthlyUsd) || monthlyUsd <= 0) return 0;
  if (!Number.isFinite(windowMs) || windowMs <= 0) return 0;
  const windowsPerMonth = QUOTA_MONTH_MS / windowMs;
  return monthlyUsd / (100 * windowsPerMonth);
}

/**
 * Prices a token count in quota.
 *
 * `basis` defaults to 'seven_day' and every caller in this app leaves it
 * there: the 7-day window is the cost basis (spec, "Open questions
 * (resolved)"), and the 5-hour window stays a live depletion gauge that is
 * never mixed into a cost figure. The parameter exists so a future five-hour
 * cost figure has to be written deliberately rather than by defaulting into
 * one.
 */
export function quotaCostForTokens(
  tokens: number,
  tokensPerPoint: number,
  monthlyUsd: number | null,
  basis: QuotaBasis = 'seven_day',
): QuotaCost {
  const safeTokens = Number.isFinite(tokens) && tokens > 0 ? tokens : 0;
  const safeRate = Number.isFinite(tokensPerPoint) && tokensPerPoint > 0 ? tokensPerPoint : 0;
  const points = safeRate > 0 ? safeTokens / safeRate : 0;
  const usdPlan =
    monthlyUsd !== null && Number.isFinite(monthlyUsd) && monthlyUsd > 0
      ? points * planCostPerPoint(monthlyUsd, QUOTA_WINDOW_MS[basis])
      : null;
  return { usdPlan, points, basis, tokensPerPoint: safeRate };
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run src/shared/ledgerMath.test.ts
npx vitest run
npm run typecheck:electron
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /c/Users/Matt/projects/aether-os-quota
git add src/shared/ledgerMath.ts src/shared/ledgerMath.test.ts
git commit -m "$(cat <<'EOF'
feat(ledger): QuotaCost, a third structurally distinct cost type

planCostPerPoint amortizes a monthly plan price over the rate-limit points
the window buys. usdPlan collides with neither usd nor usdApprox, so the
compiler still rejects rendering one cost type where another belongs.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: `quotaEfficiency.ts` — the tokens-per-point series (spec item 2)

**Files:**
- Create: `src/shared/quotaEfficiency.ts`
- Create: `src/shared/quotaEfficiency.test.ts`

**Interfaces:**
- Consumes: `TranscriptEvent` from `electron/transcriptParser` (type-only, the same import `ledgerMath.ts:1` uses).
- Produces:
  - `interface QuotaSample { atMs: number; usedPercentage: number }`
  - `interface TokenSample { atMs: number; tokens: number }`
  - `type BucketOutcome = 'fitted' | 'external-usage' | 'no-quota-movement' | 'no-prior-sample'`
  - `interface QuotaBucket { startMs: number; points: number; tokens: number; outcome: BucketOutcome }`
  - `interface QuotaEfficiency { basis: 'seven_day'; tokenBasis: 'input-output-cachewrite'; bucketMs: number; windowMs: number; computedAtMs: number; tokensPerPoint: number | null; fittedBuckets: number; externalUsageBuckets: number; fittedTokens: number; fittedPoints: number; observedTokens: number; buckets: QuotaBucket[] }`
  - `function deriveQuotaEfficiency(quotaSamples: QuotaSample[], tokenSamples: TokenSample[], opts: { nowMs: number; bucketMs?: number; windowMs?: number }): QuotaEfficiency`
  - `function tokenSamplesFromEvents(events: TranscriptEvent[]): TokenSample[]`
  - `const MIN_FIT_BUCKETS = 3`, `const DEFAULT_BUCKET_MS`, `const SEVEN_DAY_MS`
- Task 7 calls `deriveQuotaEfficiency` and `tokenSamplesFromEvents`; Tasks 8, 10 and 11 consume `QuotaEfficiency` and `MIN_FIT_BUCKETS`.

- [ ] **Step 1: Write the failing test**

Create `src/shared/quotaEfficiency.test.ts`:

```ts
import { describe, it, expect } from 'vitest';
import type { TranscriptEvent } from '../../electron/transcriptParser';
import {
  deriveQuotaEfficiency,
  tokenSamplesFromEvents,
  MIN_FIT_BUCKETS,
  DEFAULT_BUCKET_MS,
  type QuotaSample,
  type TokenSample,
} from './quotaEfficiency';

const H = DEFAULT_BUCKET_MS; // one hour
const T0 = Date.UTC(2026, 8, 1, 0, 0, 0); // an exact bucket boundary
const NOW = T0 + 24 * H;

/** A quota reading `n` buckets in, offset into the bucket so the "closing
 *  reading wins" rule is actually exercised rather than assumed. */
function q(bucket: number, usedPercentage: number, offsetMs = H - 1): QuotaSample {
  return { atMs: T0 + bucket * H + offsetMs, usedPercentage };
}
function t(bucket: number, tokens: number): TokenSample {
  return { atMs: T0 + bucket * H + 100, tokens };
}

describe('deriveQuotaEfficiency', () => {
  it('fits tokens per point from positive percentage deltas', () => {
    const result = deriveQuotaEfficiency(
      [q(0, 10), q(1, 12), q(2, 14), q(3, 18)],
      [t(1, 200_000), t(2, 200_000), t(3, 800_000)],
      { nowMs: NOW },
    );
    // Deltas: bucket1 +2, bucket2 +2, bucket3 +4 = 8 points for 1,200,000
    // tokens => 150,000 tokens per point.
    expect(result.fittedBuckets).toBe(3);
    expect(result.fittedPoints).toBeCloseTo(8, 10);
    expect(result.fittedTokens).toBe(1_200_000);
    expect(result.tokensPerPoint).toBeCloseTo(150_000, 6);
    expect(result.basis).toBe('seven_day');
  });

  it('treats a percentage DROP as a window reset and uses the current level as the delta', () => {
    const result = deriveQuotaEfficiency(
      [q(0, 90), q(1, 3), q(2, 5), q(3, 7)],
      [t(1, 300_000), t(2, 200_000), t(3, 200_000)],
      { nowMs: NOW },
    );
    // bucket1 dropped 90 -> 3: the window rolled over, so everything showing
    // (3 points) was consumed inside bucket1 -- never -87.
    const reset = result.buckets.find((b) => b.startMs === T0 + H);
    expect(reset?.points).toBeCloseTo(3, 10);
    expect(reset?.outcome).toBe('fitted');
    expect(result.fittedPoints).toBeCloseTo(3 + 2 + 2, 10);
  });

  it('excludes a bucket where the account moved but this machine logged nothing, and counts it', () => {
    const result = deriveQuotaEfficiency(
      [q(0, 10), q(1, 12), q(2, 20), q(3, 22), q(4, 24)],
      [t(1, 200_000), t(3, 200_000), t(4, 200_000)],
      { nowMs: NOW },
    );
    const external = result.buckets.find((b) => b.startMs === T0 + 2 * H);
    expect(external?.outcome).toBe('external-usage');
    expect(external?.points).toBeCloseTo(8, 10);
    expect(result.externalUsageBuckets).toBe(1);
    // The 8 external points are NOT in the fit: 3 buckets, 2 points each,
    // 600,000 tokens => 100,000 tokens per point.
    expect(result.fittedBuckets).toBe(3);
    expect(result.fittedPoints).toBeCloseTo(6, 10);
    expect(result.tokensPerPoint).toBeCloseTo(100_000, 6);
  });

  it('records a bucket with tokens but no percentage movement as no-quota-movement', () => {
    const result = deriveQuotaEfficiency(
      [q(0, 10), q(1, 10)],
      [t(1, 500_000)],
      { nowMs: NOW },
    );
    expect(result.buckets.find((b) => b.startMs === T0 + H)?.outcome).toBe('no-quota-movement');
    expect(result.fittedBuckets).toBe(0);
  });

  it('withholds tokensPerPoint until MIN_FIT_BUCKETS buckets carry both signals', () => {
    const two = deriveQuotaEfficiency(
      [q(0, 10), q(1, 12), q(2, 14)],
      [t(1, 200_000), t(2, 200_000)],
      { nowMs: NOW },
    );
    expect(MIN_FIT_BUCKETS).toBe(3);
    expect(two.fittedBuckets).toBe(2);
    expect(two.tokensPerPoint).toBeNull();
    // The points are still real and still reported -- only the rate is withheld.
    expect(two.fittedPoints).toBeCloseTo(4, 10);
  });

  it('uses each bucket CLOSING reading, so points consumed inside a bucket are not dropped', () => {
    const result = deriveQuotaEfficiency(
      [q(0, 10, 0), q(1, 11, 0), q(1, 20, H - 1), q(2, 22, H - 1), q(3, 24, H - 1)],
      [t(1, 1_000_000), t(2, 200_000), t(3, 200_000)],
      { nowMs: NOW },
    );
    // bucket1 closes at 20, not 11: its delta is 10, not 1.
    expect(result.buckets.find((b) => b.startMs === T0 + H)?.points).toBeCloseTo(10, 10);
  });

  it('ignores samples outside the window and never returns a rate from an empty series', () => {
    const stale = deriveQuotaEfficiency(
      [{ atMs: NOW - 30 * 24 * H, usedPercentage: 10 }, { atMs: NOW - 29 * 24 * H, usedPercentage: 40 }],
      [{ atMs: NOW - 29 * 24 * H, tokens: 500_000 }],
      { nowMs: NOW },
    );
    expect(stale.buckets).toEqual([]);
    expect(stale.tokensPerPoint).toBeNull();

    const empty = deriveQuotaEfficiency([], [], { nowMs: NOW });
    expect(empty.tokensPerPoint).toBeNull();
    expect(empty.fittedBuckets).toBe(0);
    expect(empty.observedTokens).toBe(0);
  });

  it('discards non-finite samples rather than poisoning the fit with NaN', () => {
    const result = deriveQuotaEfficiency(
      [q(0, 10), { atMs: Number.NaN, usedPercentage: 50 }, q(1, 12), q(2, 14), q(3, 16)],
      [t(1, 200_000), { atMs: T0 + 2 * H, tokens: Number.NaN }, t(2, 200_000), t(3, 200_000)],
      { nowMs: NOW },
    );
    expect(Number.isFinite(result.tokensPerPoint as number)).toBe(true);
    expect(result.fittedBuckets).toBe(3);
  });
});

describe('tokenSamplesFromEvents', () => {
  function ev(atMs: number, input: number, output: number, cacheCreation: number, cacheRead: number): TranscriptEvent {
    return {
      kind: 'assistant',
      sessionId: 's',
      timestamp: new Date(atMs),
      cwd: null,
      model: null,
      usage: {
        inputTokens: input,
        outputTokens: output,
        cacheCreationInputTokens: cacheCreation,
        cacheReadInputTokens: cacheRead,
      },
      toolUses: [],
      toolResults: [],
      isHumanPrompt: false,
      humanText: null,
      originKind: null,
    } as TranscriptEvent;
  }

  it('sums input, output and cache WRITES, excluding cache reads', () => {
    expect(tokenSamplesFromEvents([ev(T0, 100, 50, 25, 9_000)])).toEqual([{ atMs: T0, tokens: 175 }]);
  });

  it('skips events with no usage, no timestamp, or a non-assistant kind', () => {
    const noUsage = { ...ev(T0, 1, 1, 1, 1), usage: null } as TranscriptEvent;
    const noTime = { ...ev(T0, 1, 1, 1, 1), timestamp: null } as TranscriptEvent;
    const user = { ...ev(T0, 1, 1, 1, 1), kind: 'user' } as TranscriptEvent;
    expect(tokenSamplesFromEvents([noUsage, noTime, user])).toEqual([]);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run src/shared/quotaEfficiency.test.ts
```

Expected: FAIL — `Failed to resolve import "./quotaEfficiency"`.

- [ ] **Step 3: Write the module**

Create `src/shared/quotaEfficiency.ts`:

```ts
import type { TranscriptEvent } from '../../electron/transcriptParser';

// ---------------------------------------------------------------------------
// Tokens per quota point -- an empirical fit, not a rate table
// ---------------------------------------------------------------------------
//
// Nothing published says how many tokens move a rate-limit percentage point.
// The only way to know is to watch: bucket this machine's token consumption
// and the account's reported percentage over the same intervals, and divide.
//
// That makes this correlation, not causation, and the type says so by carrying
// every bucket's outcome rather than only the fitted total. The two ways this
// can be wrong are both visible in the output:
//   - The account is shared with work this machine never saw (another machine,
//     another project). Those buckets are identified, excluded, and COUNTED --
//     see 'external-usage' below.
//   - The fit is too thin to mean anything. Below MIN_FIT_BUCKETS the rate is
//     withheld entirely (null) rather than published with a caveat, because a
//     caveat next to a number does not stop the number from being read.

export const SEVEN_DAY_MS = 7 * 24 * 60 * 60 * 1000;

/** One hour. Short enough that a burst of work and the percentage move it
 *  caused land together; long enough that the statusline's ~10s poll
 *  (statuslineWatcher.ts's WATCH_INTERVAL_MS) reliably supplies at least one
 *  reading per bucket while the app is running. */
export const DEFAULT_BUCKET_MS = 60 * 60 * 1000;

/** Buckets carrying BOTH signals required before a rate is published.
 *  Three is the spec's resolved minimum: below it, show points only. */
export const MIN_FIT_BUCKETS = 3;

export interface QuotaSample {
  atMs: number;
  /** 0-100, from the statusline payload's seven_day window. */
  usedPercentage: number;
}

export interface TokenSample {
  atMs: number;
  tokens: number;
}

export type BucketOutcome =
  /** Both signals present and positive -- this bucket is in the fit. */
  | 'fitted'
  /** The account moved; this machine logged nothing. Excluded, and counted. */
  | 'external-usage'
  /** The percentage did not move. Says nothing about tokens per point. */
  | 'no-quota-movement'
  /** The first bucket in the series: a level with nothing to difference against. */
  | 'no-prior-sample';

export interface QuotaBucket {
  /** Bucket start, floored to bucketMs. */
  startMs: number;
  /** Percentage points consumed in this bucket. Never negative. */
  points: number;
  /** Tokens this machine logged in this bucket. */
  tokens: number;
  outcome: BucketOutcome;
}

export interface QuotaEfficiency {
  /** The cost basis, fixed by the spec. The five-hour window is a live
   *  depletion gauge and is deliberately never fitted here. */
  basis: 'seven_day';
  /** What `tokens` counts. Named on the value so a consumer pricing a
   *  dispatch can see it is comparing like with like -- see the note on
   *  tokenSamplesFromEvents. */
  tokenBasis: 'input-output-cachewrite';
  bucketMs: number;
  windowMs: number;
  computedAtMs: number;
  /** null until MIN_FIT_BUCKETS buckets carry both signals. */
  tokensPerPoint: number | null;
  fittedBuckets: number;
  externalUsageBuckets: number;
  fittedTokens: number;
  fittedPoints: number;
  /** Tokens across EVERY bucket in the window, fitted or not. This is what the
   *  window actually cost in tokens; fittedTokens is only the subset the rate
   *  was derived from. */
  observedTokens: number;
  buckets: QuotaBucket[];
}

/**
 * The token count a quota fit should use.
 *
 * Cache READS are excluded. They are the largest token category in a long
 * Claude Code session by an order of magnitude and are priced at a tenth of an
 * input token (modelPricing.ts's CACHE_READ_DISCOUNT); including them would
 * make tokens-per-point a measure of how much context gets re-read rather than
 * of how much work was done, and two sessions doing identical work would fit
 * wildly different rates purely from cache behaviour.
 *
 * Cache WRITES are included: they are billed above a fresh input token
 * (CACHE_WRITE_MULTIPLIER, 1.25x) and represent real new content.
 *
 * Stated plainly, because it bounds what the per-dispatch quota figure means:
 * the per-dispatch scalar this rate is later applied to comes from
 * `<subagent_tokens>`, whose own basis Claude Code does not document -- see the
 * DISPATCH_OUTPUT_SHARE comment in ledgerMath.ts, which reasons it behaves like
 * generated tokens. So a per-dispatch quota figure inherits that uncertainty on
 * top of this one. The window-level figure (observedTokens against the
 * statusline's own percentage) does not, and is the more trustworthy of the two.
 */
export function tokenSamplesFromEvents(events: TranscriptEvent[]): TokenSample[] {
  const samples: TokenSample[] = [];
  for (const e of events) {
    if (e.kind !== 'assistant' || !e.usage || !e.timestamp) continue;
    const atMs = e.timestamp.getTime();
    if (Number.isNaN(atMs)) continue;
    samples.push({
      atMs,
      tokens: e.usage.inputTokens + e.usage.outputTokens + e.usage.cacheCreationInputTokens,
    });
  }
  return samples;
}

export function deriveQuotaEfficiency(
  quotaSamples: QuotaSample[],
  tokenSamples: TokenSample[],
  opts: { nowMs: number; bucketMs?: number; windowMs?: number },
): QuotaEfficiency {
  const bucketMs = opts.bucketMs ?? DEFAULT_BUCKET_MS;
  const windowMs = opts.windowMs ?? SEVEN_DAY_MS;
  const since = opts.nowMs - windowMs;
  const bucketOf = (atMs: number) => Math.floor(atMs / bucketMs) * bucketMs;
  const inWindow = (atMs: number) => Number.isFinite(atMs) && atMs >= since && atMs <= opts.nowMs;

  // Each bucket's CLOSING reading. Closing rather than opening: the next
  // bucket's delta is measured against where this one ended, and using the
  // opening level would silently drop everything consumed inside the bucket.
  const closing = new Map<number, { atMs: number; usedPercentage: number }>();
  for (const s of quotaSamples) {
    if (!inWindow(s.atMs) || !Number.isFinite(s.usedPercentage)) continue;
    const key = bucketOf(s.atMs);
    const prev = closing.get(key);
    if (prev === undefined || s.atMs >= prev.atMs) {
      closing.set(key, { atMs: s.atMs, usedPercentage: s.usedPercentage });
    }
  }

  const tokensByBucket = new Map<number, number>();
  for (const t of tokenSamples) {
    if (!inWindow(t.atMs) || !Number.isFinite(t.tokens)) continue;
    const key = bucketOf(t.atMs);
    tokensByBucket.set(key, (tokensByBucket.get(key) ?? 0) + t.tokens);
  }

  const buckets: QuotaBucket[] = [];
  let previousPct: number | null = null;
  let fittedBuckets = 0;
  let externalUsageBuckets = 0;
  let fittedTokens = 0;
  let fittedPoints = 0;
  let observedTokens = 0;

  // Same-bucket alignment: only buckets with a percentage reading are
  // considered at all. Tokens logged in a bucket the statusline never reported
  // have nothing to be divided by, and carrying them into a neighbouring
  // bucket's delta would attribute them to a percentage move they did not
  // cause.
  for (const startMs of [...closing.keys()].sort((a, b) => a - b)) {
    const pct = closing.get(startMs)!.usedPercentage;
    const tokens = tokensByBucket.get(startMs) ?? 0;
    observedTokens += tokens;

    if (previousPct === null) {
      buckets.push({ startMs, points: 0, tokens, outcome: 'no-prior-sample' });
      previousPct = pct;
      continue;
    }

    // A DROP means the window rolled over, so everything now showing was
    // consumed inside this bucket -- never a negative delta. A negative would
    // subtract real consumption from the fit and inflate tokensPerPoint.
    const points = pct < previousPct ? pct : pct - previousPct;
    previousPct = pct;

    if (points <= 0) {
      buckets.push({ startMs, points: 0, tokens, outcome: 'no-quota-movement' });
      continue;
    }

    if (tokens <= 0) {
      // The account moved and this machine logged nothing: another machine, or
      // another project on the same account. Fitting it would attribute
      // someone else's consumption to zero local tokens and drag the rate
      // toward zero, making every local figure look cheaper than it is.
      externalUsageBuckets += 1;
      buckets.push({ startMs, points, tokens: 0, outcome: 'external-usage' });
      continue;
    }

    fittedBuckets += 1;
    fittedTokens += tokens;
    fittedPoints += points;
    buckets.push({ startMs, points, tokens, outcome: 'fitted' });
  }

  return {
    basis: 'seven_day',
    tokenBasis: 'input-output-cachewrite',
    bucketMs,
    windowMs,
    computedAtMs: opts.nowMs,
    tokensPerPoint: fittedBuckets >= MIN_FIT_BUCKETS && fittedPoints > 0 ? fittedTokens / fittedPoints : null,
    fittedBuckets,
    externalUsageBuckets,
    fittedTokens,
    fittedPoints,
    observedTokens,
    buckets,
  };
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run src/shared/quotaEfficiency.test.ts
npx vitest run
npm run typecheck:electron
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /c/Users/Matt/projects/aether-os-quota
git add src/shared/quotaEfficiency.ts src/shared/quotaEfficiency.test.ts
git commit -m "$(cat <<'EOF'
feat(shared): quotaEfficiency -- empirical tokens per quota point

Joins token events to statusline seven-day percentage snapshots per hourly
bucket. Positive deltas only, a drop is a reset, same-bucket alignment, and
buckets where the account moved with zero local tokens are excluded from
the fit and counted as external usage.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Main-process wiring — sample buffers and the `quota:efficiency` channel

**Files:**
- Modify: `electron/main.ts` (imports ~line 30; a new module-level buffer block; `scanAndPushUsage` at ~line 445; the statusline watcher callback at ~line 639; a new `ipcMain.handle` beside `ledger:snapshot:current` at line 1102)
- Test: `electron/main.narration.test.ts` is touched in Task 13; this task is verified by typecheck plus the existing suite.

**Interfaces:**
- Consumes: `deriveQuotaEfficiency`, `tokenSamplesFromEvents`, `type QuotaEfficiency`, `SEVEN_DAY_MS` (Task 6).
- Produces: IPC channel `quota:efficiency` (push, payload `QuotaEfficiency | null`) and `quota:efficiency:current` (invoke, returns `QuotaEfficiency | null`). Task 8 consumes both.

The two inputs both already exist in main and neither requires a collector read:
- The percentage series arrives via `startStatuslineWatcher`'s callback (`main.ts:639-642`), which already receives every parsed `StatuslineSnapshot`.
- The token series comes from `optimizeEvents` — the `TranscriptEvent[]` `scanAndPushUsage` already scans and already feeds `buildLedgerSnapshot` (`main.ts:445`). No second scan.

- [ ] **Step 1: Add the imports**

In `electron/main.ts`, beside the existing `import { buildLedgerSnapshot, ... }` on line 30:

```ts
import {
  deriveQuotaEfficiency,
  tokenSamplesFromEvents,
  SEVEN_DAY_MS,
  type QuotaEfficiency,
} from '../src/shared/quotaEfficiency';
```

- [ ] **Step 2: Add the sample buffer and cache**

Add near the other module-level caches in `electron/main.ts` (the block containing `cachedLedgerSnapshot` / `cachedStatuslineSnapshot`):

```ts
/**
 * Seven-day rate-limit percentage readings, oldest first.
 *
 * In memory only, and deliberately: this is a live series whose whole value is
 * being current. A persisted copy rehydrated after a restart would date from
 * a window that has since reset, which is the same dishonesty
 * persistence.ts's `statusline` exclusion already refuses.
 *
 * The statusline writes roughly every render and the watcher polls every 10s
 * (statuslineWatcher.ts's WATCH_INTERVAL_MS), so a full 7 days of continuous
 * running is ~60k readings. The cap keeps that bounded at a size the hourly
 * bucketing cannot even use -- two readings per hour would be plenty; the
 * headroom just means a burst never evicts the far end of the window.
 */
const MAX_QUOTA_SAMPLES = 4000;
const quotaSamples: { atMs: number; usedPercentage: number }[] = [];
let cachedQuotaEfficiency: QuotaEfficiency | null = null;

function recordQuotaSample(atMs: number, usedPercentage: number): void {
  // The watcher re-emits the same payload whenever the file is touched
  // without changing. Deduping on the capture timestamp keeps a stalled
  // statusline from filling the buffer with copies of one reading and
  // evicting the history the fit needs.
  const last = quotaSamples[quotaSamples.length - 1];
  if (last && last.atMs >= atMs) return;
  quotaSamples.push({ atMs, usedPercentage });
  if (quotaSamples.length > MAX_QUOTA_SAMPLES) quotaSamples.shift();
}
```

- [ ] **Step 3: Feed the buffer from the statusline watcher**

Replace the watcher callback at `electron/main.ts:639-642` with:

```ts
  stopStatuslineWatcher = startStatuslineWatcher(statuslinePayloadPath, (snapshot) => {
    cachedStatuslineSnapshot = snapshot;
    // The seven-day window is the quota cost basis (the five-hour one stays a
    // live depletion gauge and is never fitted). A payload without it -- an
    // older Claude Code, or a session before the first rate-limit report --
    // simply contributes no sample.
    if (snapshot.sevenDay) recordQuotaSample(snapshot.capturedAtMs, snapshot.sevenDay.usedPercentage);
    sendToWindow('statusline:snapshot', snapshot);
  });
```

- [ ] **Step 4: Derive and push the snapshot**

In `scanAndPushUsage`, immediately after `sendToWindow('ledger:snapshot', cachedLedgerSnapshot);` (line 450):

```ts
  // Quota efficiency rides the SAME optimizeEvents scan as the Ledger -- no
  // third pass over the transcripts -- and joins it to the percentage series
  // the statusline watcher has been accumulating. Only the derived numbers
  // cross the IPC boundary; no transcript content does.
  cachedQuotaEfficiency = deriveQuotaEfficiency(quotaSamples, tokenSamplesFromEvents(optimizeEvents), {
    nowMs: Date.now(),
    windowMs: SEVEN_DAY_MS,
  });
  sendToWindow('quota:efficiency', cachedQuotaEfficiency);
```

- [ ] **Step 5: Add the pull handler**

Beside `ipcMain.handle('ledger:snapshot:current', ...)` at `electron/main.ts:1102`:

```ts
// Same startup race the ledger and statusline channels solve this way: the
// 60s scan can finish before the renderer's listener exists.
ipcMain.handle('quota:efficiency:current', () => cachedQuotaEfficiency);
```

- [ ] **Step 6: Verify**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npm run typecheck:electron
npx vitest run
npm run electron:build
```

Expected: all pass, test count unchanged from Task 6.

- [ ] **Step 7: Commit**

```bash
cd /c/Users/Matt/projects/aether-os-quota
git add electron/main.ts
git commit -m "$(cat <<'EOF'
feat(main): derive and push quota efficiency over a new IPC channel

Accumulates seven-day percentage readings from the existing statusline
watcher and joins them to the TranscriptEvent[] the usage scan already
produces. No second scan, no collector read, derived numbers only.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Renderer wiring — preload, store, sync hook

**Files:**
- Modify: `electron/preload.ts` (new namespace after the `ledger` block, line 132-142)
- Modify: `src/aetherElectron.d.ts` (imports at top; new namespace after the `ledger` block, lines 66-69)
- Modify: `src/state/types.ts` (`AetherState`, after `ledger` on line 242)
- Modify: `src/state/initialState.ts`
- Modify: `src/state/reducer.ts` (Action union ~line 39; a case beside `SET_LEDGER` at line 254)
- Modify: `src/state/persistence.ts` (`PERSISTENCE_EXCLUSIONS`)
- Create: `src/state/useQuotaSync.ts`
- Modify: `src/App.tsx`
- Test: `src/state/persistence.test.ts` (its existing coverage test does the work)

**Interfaces:**
- Consumes: `QuotaEfficiency` (Task 6), the `quota:efficiency` / `quota:efficiency:current` channels (Task 7).
- Produces: `state.quotaEfficiency: QuotaEfficiency | null`, action `{ type: 'SET_QUOTA_EFFICIENCY'; quota: QuotaEfficiency | null }`, hook `useQuotaSync()`. Tasks 10 and 11 read `state.quotaEfficiency`.

- [ ] **Step 1: Run the coverage test to see it fail after the state field is added**

Add the state field first so the guard fires. In `src/state/types.ts`, add the import alongside the other shared-type imports at the top:

```ts
import type { QuotaEfficiency } from '../shared/quotaEfficiency';
```

and add to `AetherState`, immediately after `ledger: LedgerSnapshot | null;` (line 242):

```ts
  quotaEfficiency: QuotaEfficiency | null;
```

In `src/state/initialState.ts`, add beside the other null snapshot fields:

```ts
  quotaEfficiency: null,
```

Then:

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run src/state/persistence.test.ts
```

Expected: FAIL, naming `quotaEfficiency` as a key that is neither persisted nor excluded.

- [ ] **Step 2: Exclude it from persistence, with a reason**

In `src/state/persistence.ts`, add to `PERSISTENCE_EXCLUSIONS` beside the `ledger` entry:

```ts
  quotaEfficiency: 'a fit over a ROLLING seven-day rate-limit window, recomputed in main every scan from a percentage series that only exists in memory; a rehydrated value would price today\'s dispatches against a window that has since reset -- the same reason `statusline` and `ledger` are excluded',
```

Re-run:

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run src/state/persistence.test.ts
```

Expected: PASS.

- [ ] **Step 3: Add the reducer action**

In `src/state/reducer.ts`, add to the `Action` union beside the other snapshot setters (near line 39):

```ts
  | { type: 'SET_QUOTA_EFFICIENCY'; quota: QuotaEfficiency | null }
```

and to the imports on line 1 add `QuotaEfficiency`:

```ts
import type { QuotaEfficiency } from '../shared/quotaEfficiency';
```

Add the case immediately after `case 'SET_LEDGER':` (line 254-255):

```ts
    case 'SET_QUOTA_EFFICIENCY':
      return { ...state, quotaEfficiency: action.quota };
```

- [ ] **Step 4: Expose the channel in preload and its type declaration**

In `electron/preload.ts`, add the import beside the `LedgerSnapshot` one on line 7:

```ts
import type { QuotaEfficiency } from '../src/shared/quotaEfficiency';
```

and the namespace immediately after the `ledger` block (after line 142):

```ts
  quota: {
    onEfficiency: (callback: (snapshot: QuotaEfficiency | null) => void) => {
      const listener = (_event: Electron.IpcRendererEvent, snapshot: QuotaEfficiency | null) => callback(snapshot);
      ipcRenderer.on('quota:efficiency', listener);
      return () => ipcRenderer.removeListener('quota:efficiency', listener);
    },
    // Same startup race the ledger channel solves this way.
    current: (): Promise<QuotaEfficiency | null> => ipcRenderer.invoke('quota:efficiency:current'),
  },
```

In `src/aetherElectron.d.ts`, add the import beside the `LedgerSnapshot` one on line 10:

```ts
import type { QuotaEfficiency } from './shared/quotaEfficiency';
```

and the declaration immediately after the `ledger` block (after line 69):

```ts
      quota: {
        onEfficiency: (callback: (snapshot: QuotaEfficiency | null) => void) => () => void;
        current: () => Promise<QuotaEfficiency | null>;
      };
```

- [ ] **Step 5: Add the sync hook**

Create `src/state/useQuotaSync.ts`, mirroring `useLedgerSync.ts` exactly (same startup race, same fix):

```ts
import { useEffect } from 'react';
import { useAetherStore } from './store';

export function useQuotaSync() {
  const { dispatch } = useAetherStore();

  useEffect(() => {
    const quota = window.aetherElectron?.quota;
    if (!quota) return;

    // Pull whatever main already has before subscribing. The scan that
    // produces the first snapshot can finish before this listener is
    // registered, and the interval is 60s -- same race, same fix, as the
    // ledger and statusline channels.
    let cancelled = false;
    quota
      .current()
      .then((snapshot) => {
        // A live push may already have landed while this promise was in
        // flight; that value is newer, so don't overwrite it.
        if (!cancelled && snapshot) dispatch({ type: 'SET_QUOTA_EFFICIENCY', quota: snapshot });
      })
      .catch(() => {
        // An older main process without the pull channel: the push still works.
      });

    const unsubscribe = quota.onEfficiency((snapshot) => {
      cancelled = true;
      dispatch({ type: 'SET_QUOTA_EFFICIENCY', quota: snapshot });
    });

    return () => {
      cancelled = true;
      unsubscribe();
    };
  }, [dispatch]);
}
```

- [ ] **Step 6: Mount it**

In `src/App.tsx`, add the import beside `useLedgerSync` (line 15):

```ts
import { useQuotaSync } from './state/useQuotaSync';
```

add the wrapper component beside `LedgerSync` (line 106-109):

```tsx
function QuotaSync() {
  useQuotaSync();
  return null;
}
```

and mount it beside `<LedgerSync />` (line 47):

```tsx
        <QuotaSync />
```

- [ ] **Step 7: Verify**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run
npm run typecheck:electron
npm run build
```

Expected: PASS on all three.

- [ ] **Step 8: Commit**

```bash
cd /c/Users/Matt/projects/aether-os-quota
git add electron/preload.ts src/aetherElectron.d.ts src/state/types.ts src/state/initialState.ts src/state/reducer.ts src/state/persistence.ts src/state/useQuotaSync.ts src/App.tsx
git commit -m "$(cat <<'EOF'
feat(state): carry the quota-efficiency snapshot into the renderer

New quota IPC namespace, SET_QUOTA_EFFICIENCY action, useQuotaSync hook.
Excluded from persistence -- a rehydrated fit would price today's work
against a window that has since reset.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: The monthly plan price setting

**Files:**
- Modify: `src/state/types.ts` (`Cfg`, after `narrationVerbosity` on line 179)
- Modify: `src/state/initialState.ts` (`cfg` block, lines 20-45)
- Create: `src/components/settings/PlanPriceCard.tsx`
- Create: `src/components/settings/PlanPriceCard.test.tsx`
- Modify: `src/components/settings/SettingsView.tsx`

**Interfaces:**
- Consumes: `UPDATE_CFG` (`src/state/reducer.ts:145`), which already merges a `Partial<Cfg>`.
- Produces: `Cfg.planMonthlyUsd: number | null`. Tasks 10 and 11 read `state.cfg.planMonthlyUsd`.

`Cfg` is already inside the persisted slice (`persistence.ts:65`), so this lands in the existing user-settings store with no new plumbing — exactly what the spec's resolved decision asks for. The card sits beside `StatuslineCard` in `SettingsView`, since the statusline feed is where the percentage series it prices comes from.

Only a Claude-side price is added. A Codex price field would be config that lies about being wired: `readAccountRateLimits` (Task 4) is not yet consumed by any renderer surface, so nothing would spend it. Add it in the same place when the Codex quota gauge lands.

- [ ] **Step 1: Write the failing test**

Create `src/components/settings/PlanPriceCard.test.tsx`:

```tsx
import { afterEach, describe, expect, it } from 'vitest';
import { cleanup, render, screen, fireEvent } from '@testing-library/react';
import { PlanPriceCard } from './PlanPriceCard';
import { AetherStoreProvider } from '../../state/store';

afterEach(cleanup);

function renderCard() {
  return render(
    <AetherStoreProvider>
      <PlanPriceCard />
    </AetherStoreProvider>,
  );
}

describe('PlanPriceCard', () => {
  it('starts with no price set and says what that costs the operator', () => {
    renderCard();
    expect(screen.getByLabelText('Monthly plan price in USD')).toHaveValue(null);
    expect(screen.getByText(/quota points only/i)).toBeTruthy();
  });

  it('stores a typed price on the config', () => {
    renderCard();
    const input = screen.getByLabelText('Monthly plan price in USD');
    fireEvent.change(input, { target: { value: '200' } });
    expect(screen.getByText('$0.50')).toBeTruthy(); // $200 / 400 points
  });

  it('clears back to null on an empty field rather than storing 0', () => {
    renderCard();
    const input = screen.getByLabelText('Monthly plan price in USD');
    fireEvent.change(input, { target: { value: '200' } });
    fireEvent.change(input, { target: { value: '' } });
    // 0 would render "$0.00 per point", which reads as a free plan. Null
    // reads as "not configured", which is the truth.
    expect(screen.getByText(/quota points only/i)).toBeTruthy();
  });

  it('rejects a negative price rather than storing a negative rate', () => {
    renderCard();
    fireEvent.change(screen.getByLabelText('Monthly plan price in USD'), { target: { value: '-50' } });
    expect(screen.getByText(/quota points only/i)).toBeTruthy();
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run src/components/settings/PlanPriceCard.test.tsx
```

Expected: FAIL — `Failed to resolve import "./PlanPriceCard"`.

- [ ] **Step 3: Add the config field**

In `src/state/types.ts`, add to `Cfg` after `narrationVerbosity: NarrationVerbosity;` (line 179):

```ts
  /**
   * The monthly subscription price in USD, or null when the operator has not
   * entered one.
   *
   * null and 0 are different answers and must stay different: null means "no
   * price configured, show quota points only", while 0 would mean "this plan
   * is free", which would render every dispatch at $0.00 and read as though
   * the work cost nothing. The input in PlanPriceCard therefore clears to
   * null rather than coercing an empty field to 0.
   */
  planMonthlyUsd: number | null;
```

In `src/state/initialState.ts`, add to the `cfg` object:

```ts
    planMonthlyUsd: null,
```

- [ ] **Step 4: Write the card**

Create `src/components/settings/PlanPriceCard.tsx`:

```tsx
import type { CSSProperties } from 'react';
import { fonts, type ColorPalette } from '../../styles/tokens';
import { useColors } from '../shared/useColors';
import { useAetherStore } from '../../state/store';
import { planCostPerPoint, QUOTA_WINDOW_MS } from '../../shared/ledgerMath';

export function PlanPriceCard() {
  const colors = useColors();
  const { state, dispatch } = useAetherStore();
  const price = state.cfg.planMonthlyUsd;

  function onChange(raw: string): void {
    const trimmed = raw.trim();
    const parsed = Number(trimmed);
    // Empty, unparsable, or non-positive all clear to null. Storing 0 would
    // render "$0.00" everywhere, which reads as a free plan rather than as an
    // unconfigured one.
    const next = trimmed !== '' && Number.isFinite(parsed) && parsed > 0 ? parsed : null;
    dispatch({ type: 'UPDATE_CFG', patch: { planMonthlyUsd: next } });
  }

  const perPoint = price === null ? null : planCostPerPoint(price, QUOTA_WINDOW_MS.seven_day);

  return (
    <div style={cardStyle(colors)}>
      <div style={titleStyle(colors)}>PLAN PRICE</div>

      <div style={rowStyle}>
        <label style={labelStyle(colors)} htmlFor="plan-monthly-usd">
          MONTHLY USD
        </label>
        <input
          id="plan-monthly-usd"
          aria-label="Monthly plan price in USD"
          type="number"
          min={0}
          step={1}
          value={price ?? ''}
          onChange={(e) => onChange(e.target.value)}
          style={inputStyle(colors)}
        />
      </div>

      <div style={rowStyle}>
        <div style={labelStyle(colors)}>PER QUOTA POINT (7D)</div>
        <div style={valueStyle(colors)}>{perPoint === null ? '—' : `$${perPoint.toFixed(2)}`}</div>
      </div>

      <p style={hintStyle(colors)}>
        {price === null
          ? 'Not set — the Ledger shows quota points only. Enter what this subscription costs per month and it will price work in the quota it actually consumes, instead of only in API rates this account never pays.'
          : 'A plan buys 100 rate-limit points per 7-day window, and a 28-day month holds four of them — so this price divides by 400. The Ledger amortizes each dispatch over that rate.'}
      </p>
    </div>
  );
}

function cardStyle(colors: ColorPalette): CSSProperties {
  return {
    padding: 15,
    borderRadius: 14,
    border: `1px solid ${colors.panelBorder}`,
    background: colors.panelGradient,
    display: 'flex',
    flexDirection: 'column',
    minHeight: 0,
    flexShrink: 0,
  };
}
function titleStyle(colors: ColorPalette): CSSProperties {
  return { flex: 'none', font: `600 12px/1 ${fonts.ui}`, letterSpacing: 3, color: colors.textSecondary };
}
const rowStyle: CSSProperties = {
  marginTop: 12,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  gap: 12,
};
function labelStyle(colors: ColorPalette): CSSProperties {
  return { font: `600 10px/1 ${fonts.ui}`, letterSpacing: 2, color: colors.textMuted, flexShrink: 0 };
}
function valueStyle(colors: ColorPalette): CSSProperties {
  return { font: `600 11px/1 ${fonts.mono}`, color: colors.textSecondary, textAlign: 'right' };
}
function inputStyle(colors: ColorPalette): CSSProperties {
  return {
    width: 110,
    padding: '4px 8px',
    borderRadius: 6,
    border: `1px solid ${colors.panelBorder}`,
    background: 'transparent',
    color: colors.textSecondary,
    font: `600 12px/1.2 ${fonts.mono}`,
    textAlign: 'right',
  };
}
function hintStyle(colors: ColorPalette): CSSProperties {
  return { marginTop: 12, font: `500 11px/1.4 ${fonts.ui}`, color: colors.textMuted };
}
```

- [ ] **Step 5: Mount it beside the statusline card**

In `src/components/settings/SettingsView.tsx`, add the import beside `StatuslineCard` (line 7):

```ts
import { PlanPriceCard } from './PlanPriceCard';
```

and render it immediately after `<StatuslineCard />` (line 20):

```tsx
        <PlanPriceCard />
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run src/components/settings/PlanPriceCard.test.tsx
npx vitest run
npm run build
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd /c/Users/Matt/projects/aether-os-quota
git add src/state/types.ts src/state/initialState.ts src/components/settings/PlanPriceCard.tsx src/components/settings/PlanPriceCard.test.tsx src/components/settings/SettingsView.tsx
git commit -m "$(cat <<'EOF'
feat(settings): monthly plan price, stored in the existing cfg slice

Beside the statusline card, since that feed supplies the percentage series
this price is amortized over. Clears to null rather than 0 -- 0 would render
as a free plan.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: The Ledger's quota card

**Files:**
- Create: `src/components/ledger/QuotaCostCard.tsx`
- Create: `src/components/ledger/QuotaCostCard.test.tsx`
- Modify: `src/components/ledger/format.ts`
- Modify: `src/components/ledger/LedgerView.tsx`

**Interfaces:**
- Consumes: `state.quotaEfficiency` (Task 8), `state.statusline` (existing), `state.cfg.planMonthlyUsd` (Task 9), `planCostPerPoint` / `QUOTA_WINDOW_MS` (Task 5), `MIN_FIT_BUCKETS` (Task 6).
- Produces: `format.ts` gains `planUsd(value: number): string` and `points(value: number): string` and `QUOTA_BASIS_TOOLTIP: string`. Task 11 uses all three.

The window-level figure deliberately does **not** go through the fit: the statusline reports the seven-day percentage directly, so "58 points consumed = $29" needs only the price. The fit is what Task 11 needs, to attribute that consumption to individual dispatches.

- [ ] **Step 1: Write the failing test**

Create `src/components/ledger/QuotaCostCard.test.tsx`:

```tsx
import { afterEach, describe, expect, it } from 'vitest';
import { cleanup, render, screen } from '@testing-library/react';
import { QuotaCostCard } from './QuotaCostCard';
import type { QuotaEfficiency } from '../../shared/quotaEfficiency';
import type { StatuslineSnapshot } from '../../shared/statuslinePayload';

afterEach(cleanup);

const NOW = Date.UTC(2026, 8, 7, 12, 0, 0);

function statusline(sevenDayPct: number): StatuslineSnapshot {
  return {
    capturedAtMs: NOW,
    sessionId: null, modelId: null, modelDisplayName: null,
    fiveHour: null,
    sevenDay: { usedPercentage: sevenDayPct, resetsAtMs: NOW + 86_400_000 },
    contextUsedPercentage: null, contextWindowSize: null, contextUsage: null,
    totalCostUsd: null, currentDir: null, projectDir: null,
  };
}

function efficiency(over: Partial<QuotaEfficiency> = {}): QuotaEfficiency {
  return {
    basis: 'seven_day',
    tokenBasis: 'input-output-cachewrite',
    bucketMs: 3_600_000,
    windowMs: 7 * 24 * 3_600_000,
    computedAtMs: NOW,
    tokensPerPoint: 150_000,
    fittedBuckets: 5,
    externalUsageBuckets: 0,
    fittedTokens: 750_000,
    fittedPoints: 5,
    observedTokens: 900_000,
    buckets: [],
    ...over,
  };
}

describe('QuotaCostCard', () => {
  it('prices the seven-day window from the live percentage and the plan price', () => {
    render(<QuotaCostCard quota={efficiency()} statusline={statusline(58)} planMonthlyUsd={200} />);
    expect(screen.getByText('58.0 pts')).toBeTruthy();
    expect(screen.getByText('$29.00')).toBeTruthy(); // 58 * ($200 / 400)
  });

  it('shows points with no dollar figure when no plan price is configured', () => {
    render(<QuotaCostCard quota={efficiency()} statusline={statusline(58)} planMonthlyUsd={null} />);
    expect(screen.getByText('58.0 pts')).toBeTruthy();
    expect(screen.queryByText(/^\$/)).toBeNull();
    expect(screen.getByText(/set a monthly plan price/i)).toBeTruthy();
  });

  it('reports the fit as still forming below the minimum bucket count', () => {
    render(
      <QuotaCostCard
        quota={efficiency({ tokensPerPoint: null, fittedBuckets: 2, fittedTokens: 0, fittedPoints: 0 })}
        statusline={statusline(58)}
        planMonthlyUsd={200}
      />,
    );
    expect(screen.getByText(/2 of 3/)).toBeTruthy();
    // The window figure does NOT depend on the fit -- it comes straight from
    // the statusline percentage -- so it is still shown.
    expect(screen.getByText('$29.00')).toBeTruthy();
  });

  it('surfaces external usage as an indicator rather than hiding it', () => {
    render(
      <QuotaCostCard quota={efficiency({ externalUsageBuckets: 4 })} statusline={statusline(58)} planMonthlyUsd={200} />,
    );
    expect(screen.getByText(/4 hours/i)).toBeTruthy();
    expect(screen.getByText(/other machines or projects/i)).toBeTruthy();
  });

  it('renders an honest empty state with no statusline feed at all', () => {
    render(<QuotaCostCard quota={null} statusline={null} planMonthlyUsd={200} />);
    expect(screen.getByText(/no seven-day rate-limit data/i)).toBeTruthy();
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run src/components/ledger/QuotaCostCard.test.tsx
```

Expected: FAIL — `Failed to resolve import "./QuotaCostCard"`.

- [ ] **Step 3: Add the formatters**

Append to `src/components/ledger/format.ts`:

```ts
/**
 * A plan-amortized dollar figure. No tilde, and deliberately so: unlike
 * approxUsd this is not a guess at what something cost -- it is an exact
 * division of a price the operator entered. What it is NOT is a marginal
 * cost: this money was spent whether the work ran or not, which is what the
 * card's own copy says rather than what a punctuation mark could.
 */
export function planUsd(value: number): string {
  return `$${value.toFixed(2)}`;
}

/** Rate-limit percentage points, at the precision the statusline reports. */
export function points(value: number): string {
  return `${value.toFixed(1)} pts`;
}

export const QUOTA_BASIS_TOOLTIP =
  'share of the 7-day rate-limit window this consumed, priced by amortizing the monthly plan across the 400 points a 28-day month buys; tokens-per-point is fitted from observed percentage movement, so it is correlation, not a published rate';
```

- [ ] **Step 4: Write the card**

Create `src/components/ledger/QuotaCostCard.tsx`:

```tsx
import type { CSSProperties } from 'react';
import { fonts, type ColorPalette } from '../../styles/tokens';
import { useColors } from '../shared/useColors';
import { planCostPerPoint, QUOTA_WINDOW_MS } from '../../shared/ledgerMath';
import { MIN_FIT_BUCKETS, type QuotaEfficiency } from '../../shared/quotaEfficiency';
import type { StatuslineSnapshot } from '../../shared/statuslinePayload';
import { planUsd, points as fmtPoints, tokens as fmtTokens, QUOTA_BASIS_TOOLTIP } from './format';

/**
 * What the subscription actually paid for this window.
 *
 * The window-level figure deliberately does NOT go through the tokens-per-point
 * fit: the statusline reports the seven-day percentage directly, so points
 * consumed is a measurement, not an inference, and only the price is needed to
 * value it. The fit exists to ATTRIBUTE that consumption to individual
 * dispatches (DispatchCostTable), which is a strictly harder claim -- and this
 * card reports the fit's state so the operator can see how much weight the
 * per-dispatch column deserves.
 */
export function QuotaCostCard({
  quota,
  statusline,
  planMonthlyUsd,
}: {
  quota: QuotaEfficiency | null;
  statusline: StatuslineSnapshot | null;
  planMonthlyUsd: number | null;
}) {
  const colors = useColors();
  const sevenDay = statusline?.sevenDay ?? null;

  if (sevenDay === null) {
    return (
      <div style={cardStyle(colors)}>
        <div style={titleStyle(colors)} title={QUOTA_BASIS_TOOLTIP}>QUOTA COST · 7 DAY</div>
        <div style={emptyStyle(colors)}>
          No seven-day rate-limit data. Install the statusline hook from Settings — the percentage
          series this prices comes from it.
        </div>
      </div>
    );
  }

  const usedPoints = sevenDay.usedPercentage;
  const perPoint = planMonthlyUsd === null ? null : planCostPerPoint(planMonthlyUsd, QUOTA_WINDOW_MS.seven_day);

  return (
    <div style={cardStyle(colors)}>
      <div style={titleStyle(colors)} title={QUOTA_BASIS_TOOLTIP}>QUOTA COST · 7 DAY</div>

      <div style={rowStyle}>
        <div style={labelStyle(colors)}>CONSUMED</div>
        <div style={valueStyle(colors)}>{fmtPoints(usedPoints)}</div>
      </div>

      {perPoint !== null && (
        <div style={rowStyle}>
          <div style={labelStyle(colors)}>PLAN VALUE</div>
          <div style={valueStyle(colors)}>{planUsd(usedPoints * perPoint)}</div>
        </div>
      )}

      <div style={rowStyle}>
        <div style={labelStyle(colors)}>TOKENS / POINT</div>
        <div style={valueStyle(colors)}>
          {quota?.tokensPerPoint != null
            ? fmtTokens(Math.round(quota.tokensPerPoint))
            : `fit forming — ${quota?.fittedBuckets ?? 0} of ${MIN_FIT_BUCKETS} hours`}
        </div>
      </div>

      <div style={rowStyle}>
        <div style={labelStyle(colors)}>OBSERVED HERE</div>
        <div style={valueStyle(colors)}>{fmtTokens(quota?.observedTokens ?? 0)}</div>
      </div>

      {quota != null && quota.externalUsageBuckets > 0 && (
        <p style={hintStyle(colors)}>
          External usage: {quota.externalUsageBuckets} hours where the account&apos;s quota moved but this
          machine logged no tokens — other machines or projects on the same account. Those hours are
          excluded from the tokens-per-point fit.
        </p>
      )}

      {planMonthlyUsd === null && (
        <p style={hintStyle(colors)}>
          Set a monthly plan price in Settings to see this window&apos;s consumption in dollars.
        </p>
      )}

      <p style={hintStyle(colors)}>
        This is what the subscription bought, not marginal spend — the plan costs the same whether
        this work ran or not. Tokens per point is fitted from observed percentage movement, so it is
        correlation, not a published rate.
      </p>
    </div>
  );
}

function cardStyle(colors: ColorPalette): CSSProperties {
  return {
    padding: 15,
    borderRadius: 14,
    border: `1px solid ${colors.panelBorder}`,
    background: colors.panelGradient,
    display: 'flex',
    flexDirection: 'column',
    minHeight: 0,
    flexShrink: 0,
  };
}
function titleStyle(colors: ColorPalette): CSSProperties {
  return { flex: 'none', font: `600 12px/1 ${fonts.ui}`, letterSpacing: 3, color: colors.textSecondary };
}
const rowStyle: CSSProperties = {
  marginTop: 10,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  gap: 12,
};
function labelStyle(colors: ColorPalette): CSSProperties {
  return { font: `600 10px/1 ${fonts.ui}`, letterSpacing: 2, color: colors.textMuted, flexShrink: 0 };
}
function valueStyle(colors: ColorPalette): CSSProperties {
  return { font: `600 11px/1 ${fonts.mono}`, color: colors.textSecondary, textAlign: 'right' };
}
function emptyStyle(colors: ColorPalette): CSSProperties {
  return { marginTop: 12, font: `500 11px/1.4 ${fonts.ui}`, color: colors.textMuted };
}
function hintStyle(colors: ColorPalette): CSSProperties {
  return { marginTop: 12, font: `500 11px/1.4 ${fonts.ui}`, color: colors.textMuted };
}
```

- [ ] **Step 5: Mount it in the Ledger**

In `src/components/ledger/LedgerView.tsx`, add the import beside `CacheImpactCard` (line 17):

```ts
import { QuotaCostCard } from './QuotaCostCard';
```

Render it inside the populated branch of the view, immediately after `<CacheImpactCard ... />`:

```tsx
      <QuotaCostCard
        quota={state.quotaEfficiency}
        statusline={state.statusline}
        planMonthlyUsd={state.cfg.planMonthlyUsd}
      />
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run src/components/ledger/
npx vitest run
npm run build
```

Expected: PASS. `LedgerView.test.tsx` may need its store fixture extended with `quotaEfficiency: null` and `cfg.planMonthlyUsd: null` if it builds state literally rather than spreading `initialState` — check and fix if so.

- [ ] **Step 7: Commit**

```bash
cd /c/Users/Matt/projects/aether-os-quota
git add src/components/ledger/QuotaCostCard.tsx src/components/ledger/QuotaCostCard.test.tsx src/components/ledger/format.ts src/components/ledger/LedgerView.tsx
git commit -m "$(cat <<'EOF'
feat(ledger): quota cost card for the seven-day window

Points consumed comes straight from the statusline percentage, so it is a
measurement rather than a fit. Surfaces the fit's state and external-usage
hours instead of quietly folding them in.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: Per-dispatch quota column, and the API figure labelled counterfactual

**Files:**
- Modify: `src/components/ledger/DispatchCostTable.tsx`
- Modify: `src/components/ledger/DispatchCostTable.test.tsx`
- Modify: `src/components/ledger/LedgerView.tsx` (`buildDispatchRows`, lines 168-212; the `<DispatchCostTable>` call site)

**Interfaces:**
- Consumes: `quotaCostForTokens`, `type QuotaCost` (Task 5), `state.quotaEfficiency` / `state.cfg.planMonthlyUsd` (Tasks 8-9), `planUsd` / `points` / `QUOTA_BASIS_TOOLTIP` (Task 10).
- Produces: `DispatchCostRow` gains `quota: QuotaCost`; `buildDispatchRows` gains a third parameter `quotaInputs: { tokensPerPoint: number | null; planMonthlyUsd: number | null }`.

This is the spec's item-1 step 3: "price each dispatch in quota dollars alongside the API estimate. Show both; label the API figure as counterfactual."

- [ ] **Step 1: Write the failing test**

Add to `src/components/ledger/DispatchCostTable.test.tsx`:

```tsx
  it('shows a quota figure alongside the API estimate', () => {
    render(<DispatchCostTable rows={[row({
      estimate: { usdApprox: 1.5, basis: 'blended-tier-rate', tokens: 300_000, tier: 'sonnet', tierSource: 'observed' },
      quota: { usdPlan: 1, points: 2, basis: 'seven_day', tokensPerPoint: 150_000 },
    })]} />);
    expect(screen.getByText('$1.00')).toBeTruthy();   // quota, no tilde
    expect(screen.getByText('~$1.50')).toBeTruthy();  // API estimate, tilde retained
  });

  it('falls back to points when no plan price makes a dollar figure possible', () => {
    render(<DispatchCostTable rows={[row({
      quota: { usdPlan: null, points: 2, basis: 'seven_day', tokensPerPoint: 150_000 },
    })]} />);
    expect(screen.getByText('2.0 pts')).toBeTruthy();
  });

  it('shows an em dash, not a zero, when the fit has produced no rate yet', () => {
    render(<DispatchCostTable rows={[row({
      quota: { usdPlan: null, points: 0, basis: 'seven_day', tokensPerPoint: 0 },
    })]} />);
    // 0 points would read as "this dispatch consumed no quota", which is false
    // -- it consumed an unknown amount.
    expect(screen.getByText('—')).toBeTruthy();
  });

  it('labels the API column as counterfactual, not as spend', () => {
    render(<DispatchCostTable rows={[row()]} />);
    expect(screen.getByText(/API RATE \(NOT PAID\)/i)).toBeTruthy();
  });
```

Add a `row()` helper alongside the file's existing fixtures if one is not already present (check the file first and reuse its existing builder if there is one):

```tsx
function row(over: Partial<DispatchCostRow> = {}): DispatchCostRow {
  return {
    toolUseId: 'tu-1',
    startedAt: '2026-09-07T10:00:00.000Z',
    endedAt: '2026-09-07T10:05:00.000Z',
    description: 'a dispatch',
    subagentType: 'general-purpose',
    durationMs: 300_000,
    toolUses: 4,
    estimate: { usdApprox: 1.5, basis: 'blended-tier-rate', tokens: 300_000, tier: 'sonnet', tierSource: 'observed' },
    quota: { usdPlan: 1, points: 2, basis: 'seven_day', tokensPerPoint: 150_000 },
    exitState: null,
    retries: null,
    ...over,
  };
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run src/components/ledger/DispatchCostTable.test.tsx
```

Expected: FAIL — `quota` is not a property of `DispatchCostRow`.

- [ ] **Step 3: Extend the row type and the table**

In `src/components/ledger/DispatchCostTable.tsx`, add to the imports:

```ts
import type { EstimatedCost, QuotaCost } from '../../shared/ledgerMath';
import { approxUsd, planUsd, points as fmtPoints, tokens as fmtTokens, duration as fmtDuration, ESTIMATE_BASIS_TOOLTIP, QUOTA_BASIS_TOOLTIP } from './format';
```

Add to `DispatchCostRow` (after `estimate`, line 25):

```ts
  /**
   * What this dispatch took out of the subscription quota.
   *
   * Rendered ALONGSIDE `estimate`, never instead of it -- they answer
   * different questions ("what share of the plan did this take" vs "what would
   * this have cost on the API"), and the second is a counterfactual this
   * account never pays. The column header says so.
   */
  quota: QuotaCost;
```

Add a formatter beside the component:

```ts
/**
 * The quota cell.
 *
 * Three states, all distinct on purpose:
 *   dollars  -- a plan price is set and the fit has a rate.
 *   points   -- the fit has a rate but no price is configured.
 *   em dash  -- no rate yet. NOT "0.0 pts": zero would read as "this dispatch
 *               consumed no quota", when the truth is that the amount is not
 *               yet knowable. This is the same null-versus-zero distinction
 *               RollupBuckets makes in ledgerMath.ts.
 */
function quotaCell(quota: QuotaCost): string {
  if (quota.tokensPerPoint <= 0) return '—';
  if (quota.usdPlan !== null) return planUsd(quota.usdPlan);
  return fmtPoints(quota.points);
}
```

In the table's header row, rename the estimate column and add the quota column before it. Locate the header cell currently labelled for the estimate and replace it with:

```tsx
          <div style={headerCellStyle(colors)} title={QUOTA_BASIS_TOOLTIP}>QUOTA</div>
          <div style={headerCellStyle(colors)} title={ESTIMATE_BASIS_TOOLTIP}>API RATE (NOT PAID)</div>
```

and in the body row, before the existing `approxUsd(r.estimate.usdApprox)` cell:

```tsx
          <div style={cellStyle(colors)} title={QUOTA_BASIS_TOOLTIP}>{quotaCell(r.quota)}</div>
```

Leave the existing sort on `estimate.usdApprox` alone: the API estimate is the only figure available for every row regardless of fit state, so sorting on quota would reorder the table whenever the fit crossed `MIN_FIT_BUCKETS`.

- [ ] **Step 4: Build the quota figure in `buildDispatchRows`**

In `src/components/ledger/LedgerView.tsx`, add to the imports on line 5-11:

```ts
  quotaCostForTokens,
```

Change `buildDispatchRows`'s signature (line 168) to take the quota inputs, and add the field to the returned row:

```ts
export function buildDispatchRows(
  state: {
    recentCompletedDispatches: { toolUseId: string; subagentType: string; description: string; startedAt: string; prompt: string; model: string | null }[];
    dispatchUsage: Record<string, { tokens: number; toolUses: number; durationMs: number }>;
    diagnostics: { dispatches: { toolUseId: string; exitState: string | null; retries: number | null }[] } | null;
  },
  quotaInputs: { tokensPerPoint: number | null; planMonthlyUsd: number | null },
): DispatchCostRow[] {
```

and inside the returned object, beside `estimate`:

```ts
      // tokensPerPoint null (fit still forming) becomes 0 here, which
      // quotaCostForTokens turns into 0 points and quotaCell renders as an em
      // dash -- "not yet knowable", never "free".
      quota: quotaCostForTokens(
        completed.tokens,
        quotaInputs.tokensPerPoint ?? 0,
        quotaInputs.planMonthlyUsd,
      ),
```

Update the single call site at the top of `LedgerView` (line 35):

```ts
  const rows = buildDispatchRows(state, {
    tokensPerPoint: state.quotaEfficiency?.tokensPerPoint ?? null,
    planMonthlyUsd: state.cfg.planMonthlyUsd,
  });
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run src/components/ledger/
npx vitest run
npm run build
```

Expected: PASS. `LedgerView.test.tsx` calls `buildDispatchRows` directly in at least one case — add the new second argument (`{ tokensPerPoint: null, planMonthlyUsd: null }`) there.

- [ ] **Step 6: Commit**

```bash
cd /c/Users/Matt/projects/aether-os-quota
git add src/components/ledger/DispatchCostTable.tsx src/components/ledger/DispatchCostTable.test.tsx src/components/ledger/LedgerView.tsx src/components/ledger/LedgerView.test.tsx
git commit -m "$(cat <<'EOF'
feat(ledger): per-dispatch quota column; API column labelled not-paid

Shows both figures. The quota cell falls back to points with no plan price
and to an em dash with no fit -- zero would read as "consumed no quota".

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: `waitClock.ts` — measured duration pauses while waiting on the user (spec item 5, pure half)

**Files:**
- Create: `src/shared/waitClock.ts`
- Create: `src/shared/waitClock.test.ts`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `interface WaitClock { intervals: { startMs: number; endMs: number | null }[]; open: Map<string, number> }`
  - `function createWaitClock(): WaitClock`
  - `function beginWait(clock: WaitClock, id: string, atMs: number): void`
  - `function endWait(clock: WaitClock, id: string, atMs: number): void`
  - `function waitMsWithin(clock: WaitClock, spanStartMs: number, spanEndMs: number, nowMs: number): number`
  - `function activeDurationMs(clock: WaitClock, startedAtMs: number, wallDurationMs: number, nowMs: number): number`
  - `const MAX_RETAINED_WAITS = 200`
- Task 13 calls `createWaitClock`, `beginWait`, `endWait`, `activeDurationMs`.

- [ ] **Step 1: Write the failing test**

Create `src/shared/waitClock.test.ts`:

```ts
import { describe, it, expect } from 'vitest';
import {
  createWaitClock,
  beginWait,
  endWait,
  waitMsWithin,
  activeDurationMs,
  MAX_RETAINED_WAITS,
} from './waitClock';

const T = 1_000_000;

describe('waitMsWithin', () => {
  it('is zero with no waits recorded', () => {
    expect(waitMsWithin(createWaitClock(), T, T + 10_000, T + 10_000)).toBe(0);
  });

  it('counts a wait fully inside the span', () => {
    const clock = createWaitClock();
    beginWait(clock, 'a', T + 2_000);
    endWait(clock, 'a', T + 5_000);
    expect(waitMsWithin(clock, T, T + 10_000, T + 10_000)).toBe(3_000);
  });

  it('counts only the overlapping portion of a wait that starts before the span', () => {
    const clock = createWaitClock();
    beginWait(clock, 'a', T - 4_000);
    endWait(clock, 'a', T + 1_000);
    expect(waitMsWithin(clock, T, T + 10_000, T + 10_000)).toBe(1_000);
  });

  it('ignores a wait entirely outside the span', () => {
    const clock = createWaitClock();
    beginWait(clock, 'a', T + 20_000);
    endWait(clock, 'a', T + 25_000);
    expect(waitMsWithin(clock, T, T + 10_000, T + 30_000)).toBe(0);
  });

  it('treats a still-open wait as running up to now', () => {
    const clock = createWaitClock();
    beginWait(clock, 'a', T + 3_000);
    expect(waitMsWithin(clock, T, T + 10_000, T + 8_000)).toBe(5_000);
  });

  it('merges overlapping waits rather than double-counting the overlap', () => {
    const clock = createWaitClock();
    beginWait(clock, 'a', T + 1_000);
    beginWait(clock, 'b', T + 2_000);
    endWait(clock, 'a', T + 4_000);
    endWait(clock, 'b', T + 5_000);
    // Union is [T+1000, T+5000] = 4000ms, not 3000 + 3000.
    expect(waitMsWithin(clock, T, T + 10_000, T + 10_000)).toBe(4_000);
  });

  it('ignores a duplicate begin and an end for an id that was never begun', () => {
    const clock = createWaitClock();
    beginWait(clock, 'a', T + 1_000);
    beginWait(clock, 'a', T + 2_000); // duplicate -- must not restart the clock
    endWait(clock, 'ghost', T + 3_000); // never begun -- must be a no-op
    endWait(clock, 'a', T + 4_000);
    expect(waitMsWithin(clock, T, T + 10_000, T + 10_000)).toBe(3_000);
  });
});

describe('activeDurationMs', () => {
  it('subtracts the user wait from the wall-clock duration', () => {
    const clock = createWaitClock();
    beginWait(clock, 'a', T + 10_000);
    endWait(clock, 'a', T + 40_000);
    // A 60s wall clock containing a 30s approval prompt is 30s of real work.
    expect(activeDurationMs(clock, T, 60_000, T + 60_000)).toBe(30_000);
  });

  it('returns the wall duration untouched when nothing was waiting', () => {
    expect(activeDurationMs(createWaitClock(), T, 60_000, T + 60_000)).toBe(60_000);
  });

  it('never returns a negative duration', () => {
    const clock = createWaitClock();
    beginWait(clock, 'a', T - 100_000);
    endWait(clock, 'a', T + 100_000);
    expect(activeDurationMs(clock, T, 5_000, T + 5_000)).toBe(0);
  });

  it('passes a non-finite or negative wall duration straight through as zero', () => {
    const clock = createWaitClock();
    expect(activeDurationMs(clock, T, Number.NaN, T)).toBe(0);
    expect(activeDurationMs(clock, T, -5, T)).toBe(0);
  });
});

describe('retention', () => {
  it('bounds closed intervals without ever discarding an open one', () => {
    const clock = createWaitClock();
    beginWait(clock, 'open', T);
    for (let i = 0; i < MAX_RETAINED_WAITS + 50; i += 1) {
      beginWait(clock, `w${i}`, T + i * 10);
      endWait(clock, `w${i}`, T + i * 10 + 1);
    }
    expect(clock.intervals.length).toBeLessThanOrEqual(MAX_RETAINED_WAITS + 1);
    expect(clock.intervals.some((iv) => iv.endMs === null)).toBe(true);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run src/shared/waitClock.test.ts
```

Expected: FAIL — `Failed to resolve import "./waitClock"`.

- [ ] **Step 3: Write the module**

Create `src/shared/waitClock.ts`:

```ts
// ---------------------------------------------------------------------------
// Measured duration excludes time spent waiting on the human
// ---------------------------------------------------------------------------
//
// A dispatch's reported `<duration_ms>` is wall clock: start to finish,
// including every second the run sat blocked on an approval prompt nobody was
// at the keyboard for. Feeding that into a "slower than usual for this task
// kind" comparison (electron/durationBaseline.ts's medians, consumed by
// narrationGenerator.ts) produces confident, false anomaly narrations whose
// actual cause is that the operator went to lunch mid-run.
//
// So the app records WHEN it was blocking on the user -- a permission prompt,
// a post-tool flag review -- and subtracts the overlap. What is left is time
// the agent was actually working.
//
// Pure and clock-injected throughout: `nowMs` is always a parameter, never a
// Date.now() call, so the tests are deterministic and the module can live in
// src/shared/ alongside the rest of the arithmetic.

export interface WaitInterval {
  startMs: number;
  /** null while the wait is still open. */
  endMs: number | null;
}

export interface WaitClock {
  /** Append-ordered. May contain overlaps; waitMsWithin merges before summing. */
  intervals: WaitInterval[];
  /** Open waits by request id, so an out-of-order or duplicate close is safe. */
  open: Map<string, number>;
}

/** Bound on retained CLOSED intervals. A long session answering hundreds of
 *  prompts must not grow this without limit, but an open interval is never
 *  evicted -- dropping one would silently stop the subtraction for a wait that
 *  is still happening. */
export const MAX_RETAINED_WAITS = 200;

export function createWaitClock(): WaitClock {
  return { intervals: [], open: new Map() };
}

/** Opens a wait. A duplicate id is IGNORED rather than restarting the clock:
 *  main.ts's resolver map can fire a cleanup and a response for the same
 *  request, and restarting would under-count the wait. */
export function beginWait(clock: WaitClock, id: string, atMs: number): void {
  if (!Number.isFinite(atMs) || clock.open.has(id)) return;
  const interval: WaitInterval = { startMs: atMs, endMs: null };
  clock.open.set(id, clock.intervals.length);
  clock.intervals.push(interval);
}

/** Closes a wait. An unknown id is a no-op -- a response arriving after a
 *  timeout cleanup already closed the interval is normal, not an error. */
export function endWait(clock: WaitClock, id: string, atMs: number): void {
  const index = clock.open.get(id);
  if (index === undefined) return;
  clock.open.delete(id);
  const interval = clock.intervals[index];
  if (interval && interval.endMs === null && Number.isFinite(atMs)) {
    interval.endMs = Math.max(interval.startMs, atMs);
  }
  prune(clock);
}

/** Drops the oldest CLOSED intervals once the cap is exceeded. Indices in
 *  `open` are re-based, since dropping from the front shifts them. */
function prune(clock: WaitClock): void {
  const closed = clock.intervals.filter((iv) => iv.endMs !== null).length;
  if (closed <= MAX_RETAINED_WAITS) return;
  let toDrop = closed - MAX_RETAINED_WAITS;
  const kept: WaitInterval[] = [];
  for (const interval of clock.intervals) {
    if (toDrop > 0 && interval.endMs !== null) {
      toDrop -= 1;
      continue;
    }
    kept.push(interval);
  }
  const rebased = new Map<string, number>();
  for (const [id, index] of clock.open) {
    const moved = kept.indexOf(clock.intervals[index]);
    if (moved !== -1) rebased.set(id, moved);
  }
  clock.intervals = kept;
  clock.open = rebased;
}

/**
 * Milliseconds inside [spanStartMs, spanEndMs] during which the app was
 * blocked on the user.
 *
 * Intervals are merged before summing. Two prompts can overlap (a permission
 * request and a post-tool flag review are separate resolver maps in main.ts),
 * and adding their durations would subtract more than the wall clock contains
 * -- producing a negative "active" duration, which is a worse lie than the one
 * this module exists to fix.
 *
 * A still-open wait counts up to `nowMs`.
 */
export function waitMsWithin(
  clock: WaitClock,
  spanStartMs: number,
  spanEndMs: number,
  nowMs: number,
): number {
  if (!Number.isFinite(spanStartMs) || !Number.isFinite(spanEndMs) || spanEndMs <= spanStartMs) return 0;

  const clipped: [number, number][] = [];
  for (const interval of clock.intervals) {
    const start = Math.max(interval.startMs, spanStartMs);
    const end = Math.min(interval.endMs ?? nowMs, spanEndMs);
    if (end > start) clipped.push([start, end]);
  }
  if (clipped.length === 0) return 0;

  clipped.sort((a, b) => a[0] - b[0]);
  let total = 0;
  let [currentStart, currentEnd] = clipped[0];
  for (let i = 1; i < clipped.length; i += 1) {
    const [start, end] = clipped[i];
    if (start <= currentEnd) {
      currentEnd = Math.max(currentEnd, end);
    } else {
      total += currentEnd - currentStart;
      currentStart = start;
      currentEnd = end;
    }
  }
  return total + (currentEnd - currentStart);
}

/**
 * The portion of a wall-clock duration during which the agent was actually
 * working. Clamped at zero: a wait recorded around a span it does not really
 * belong to must degrade to "no measurable work time", never to a negative
 * that would then drag a median below zero.
 */
export function activeDurationMs(
  clock: WaitClock,
  startedAtMs: number,
  wallDurationMs: number,
  nowMs: number,
): number {
  if (!Number.isFinite(wallDurationMs) || wallDurationMs <= 0) return 0;
  if (!Number.isFinite(startedAtMs)) return wallDurationMs;
  const waited = waitMsWithin(clock, startedAtMs, startedAtMs + wallDurationMs, nowMs);
  return Math.max(0, wallDurationMs - waited);
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run src/shared/waitClock.test.ts
npx vitest run
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /c/Users/Matt/projects/aether-os-quota
git add src/shared/waitClock.ts src/shared/waitClock.test.ts
git commit -m "$(cat <<'EOF'
feat(shared): waitClock -- subtract user-wait time from a measured duration

Overlapping waits are merged before summing, so two concurrent prompts can
never subtract more than the wall clock contains.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
)"
```

---

### Task 13: Wire the wait clock into main's prompts and duration baseline (spec item 5, wiring half)

**Files:**
- Modify: `electron/main.ts` (imports; a module-level clock; `onPermissionRequest` at lines 648-667; `onPostToolUse` at lines 669-693; the completed-dispatch narration loop at lines 585-594)
- Modify: `electron/main.narration.test.ts`

**Interfaces:**
- Consumes: `createWaitClock`, `beginWait`, `endWait`, `activeDurationMs` (Task 12).
- Produces: nothing consumed by later tasks — this is the plan's last change.

The two places the app blocks on a human are already explicit in `main.ts`: `onPermissionRequest` (line 648) creates a `requestId`, pushes `permission:request` to the renderer, and awaits a promise resolved by the `permission:respond` IPC handler (line 1022); `onPostToolUse` (line 669) does the same with `postToolFlag:request` / `postToolFlag:respond`. Both already have a unique id to key the interval on, and both are `async`, so `try { return await ... } finally { ... }` closes the interval on every exit path — response, timeout cleanup (`scheduleResolverCleanup`), or throw.

- [ ] **Step 1: Write the failing test**

Replace `electron/main.narration.test.ts` with:

```ts
import { describe, it, expect } from 'vitest';
import { formatNarration } from './narrationGenerator';
import { createWaitClock, beginWait, endWait, activeDurationMs } from '../src/shared/waitClock';

// These tests exist to pin the exact call shapes main.ts's tick loop uses, so
// a future edit to either signature is caught here before it silently breaks
// the wiring.
describe('main.ts narration wiring shape', () => {
  it('formatNarration accepts a completed-dispatch-shaped object and a nullable median, returning {narration, severity} or null', () => {
    const result = formatNarration({ subagentType: 'code-reviewer', durationMs: 1200 }, null);
    const shapeOk = result === null || (typeof result.narration === 'string' && typeof result.severity === 'number');
    expect(shapeOk).toBe(true);
  });

  it('activeDurationMs takes the shape main.ts feeds it and removes an approval pause from the duration', () => {
    const clock = createWaitClock();
    const startedAtMs = new Date('2026-09-07T10:00:00.000Z').getTime();
    // A permission prompt answered 30s later, inside a 60s dispatch.
    beginWait(clock, 'req-1', startedAtMs + 10_000);
    endWait(clock, 'req-1', startedAtMs + 40_000);

    const measured = activeDurationMs(clock, startedAtMs, 60_000, startedAtMs + 60_000);

    expect(measured).toBe(30_000);
    // And the narration path accepts the corrected figure unchanged.
    const result = formatNarration({ subagentType: 'code-reviewer', durationMs: measured }, null);
    const shapeOk = result === null || (typeof result.narration === 'string' && typeof result.severity === 'number');
    expect(shapeOk).toBe(true);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run electron/main.narration.test.ts
```

Expected: FAIL only if Task 12 was skipped. If Task 12 is done this test passes immediately — that is fine and expected; it is a wiring-shape pin, and the behavioural change it guards lands in Steps 3-5. Confirm it is green before continuing so a later failure is unambiguous.

- [ ] **Step 3: Add the clock to main**

In `electron/main.ts`, add the import beside the other `src/shared` imports:

```ts
import { createWaitClock, beginWait, endWait, activeDurationMs } from '../src/shared/waitClock';
```

and the module-level instance beside `narrationDurationBaseline`:

```ts
/**
 * When this app was blocked on the operator.
 *
 * Process-lifetime, in memory, not persisted -- it only ever answers questions
 * about spans inside this run, and a rehydrated interval from a previous run
 * could only ever subtract time from a dispatch it has nothing to do with.
 */
const userWaitClock = createWaitClock();
```

- [ ] **Step 4: Open and close the interval around each prompt**

In `onPermissionRequest` (line 648), replace the tail of the handler — from `sendToWindow('permission:request', ...)` through `return decision;` — with:

```ts
      // The clock opens the moment the prompt reaches the renderer and closes
      // however this resolves: an answer, scheduleResolverCleanup's timeout,
      // or a throw. `finally` covers all three; a `.then` would miss two.
      beginWait(userWaitClock, requestId, Date.now());
      sendToWindow('permission:request', { requestId, toolName: req.toolName, toolInput: req.toolInput, risk, editableField });
      try {
        return await decision;
      } finally {
        endWait(userWaitClock, requestId, Date.now());
      }
```

In `onPostToolUse` (line 669), replace the tail from `sendToWindow('postToolFlag:request', ...)` through `return decision;` with:

```ts
      beginWait(userWaitClock, requestId, Date.now());
      sendToWindow('postToolFlag:request', {
        requestId,
        toolUseId: req.toolUseId,
        toolName: req.toolName,
        anomalyKind: tripped.kind,
        detail: tripped.detail,
      });
      try {
        return await decision;
      } finally {
        endWait(userWaitClock, requestId, Date.now());
      }
```

Both handlers are already declared `async`, so `await` inside them needs no signature change.

- [ ] **Step 5: Feed the corrected duration to the baseline**

Replace the completed-dispatch loop body at `electron/main.ts:585-594` with:

```ts
    for (const c of result.completed) {
      // `<duration_ms>` is WALL CLOCK and includes every second this run sat
      // blocked on an approval prompt. Comparing that against a median of
      // other wall-clock runs manufactures "slow run" anomalies whose real
      // cause is that nobody was at the keyboard. Subtract the overlap first,
      // and record the corrected figure -- recording the wall figure would
      // poison every later comparison with the same inflation.
      const startedMs = new Date(c.startedAt).getTime();
      const measuredMs = activeDurationMs(userWaitClock, startedMs, c.durationMs, Date.now());
      // Snapshot the baseline BEFORE recording this run -- a run must never
      // be compared against a baseline it has already contributed to.
      const medianMsAtEval = getMedianMs(narrationDurationBaseline, c.subagentType);
      const narrated = formatNarration({ subagentType: c.subagentType, durationMs: measuredMs }, medianMsAtEval);
      recordDuration(narrationDurationBaseline, c.subagentType, measuredMs);
      if (narrated) {
        sendToWindow('agents:narration', { toolUseId: c.toolUseId, narration: narrated.narration, severity: narrated.severity });
      }
    }
```

`activeDurationMs` already returns `wallDurationMs` unchanged when `startedAtMs` is not finite, so a dispatch with an unparsable `startedAt` (`liveAgentsMath.ts:18-22` falls back to the epoch, which parses fine) degrades to today's behaviour rather than to zero.

- [ ] **Step 6: Verify**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run electron/main.narration.test.ts
npx vitest run
npm run typecheck:electron
npm run build
npm run electron:build
```

Expected: PASS on all five.

- [ ] **Step 7: Commit**

```bash
cd /c/Users/Matt/projects/aether-os-quota
git add electron/main.ts electron/main.narration.test.ts
git commit -m "$(cat <<'EOF'
fix(main): duration baseline stops counting time spent waiting on the user

Permission prompts and post-tool flag reviews now open and close a wait
interval; completed dispatches are narrated and recorded on the corrected
duration, killing false "slow run" narrations.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
)"
```

---

## Final verification

- [ ] **Full suite, both typechecks, both builds, from the worktree**

```bash
cd /c/Users/Matt/projects/aether-os-quota
npx vitest run
npm run typecheck:electron
npm run build
npm run electron:build
```

Expected: all green. Test count = Task 1 baseline + 1 (Task 2) + 8 (Task 3) + 3 (Task 4) + 9 (Task 5) + 10 (Task 6) + 4 (Task 9) + 5 (Task 10) + 4 (Task 11) + 13 (Task 12) + 1 (Task 13).

- [ ] **Confirm nothing under `collector/` was touched**

```bash
cd /c/Users/Matt/projects/aether-os-quota
git diff --name-only master...HEAD | grep '^collector/' && echo "VIOLATION" || echo "clean"
```

Expected: `clean`.

- [ ] **Manual smoke (optional, needs the real app)**

`npm run electron:dev`, open the Ledger tab. With no plan price set, the quota card shows points and the dispatch table's quota column shows points or an em dash. Set a price in Settings; both switch to dollars. The API column reads `API RATE (NOT PAID)`.

---

## Self-Review

**1. Spec coverage** (aether-os items only; items 6, 7 and the TMv2 pricing-table port are out of scope by instruction)

| Spec item | Task(s) | Notes |
|---|---|---|
| 1 — `QuotaCost` + `planCostPerPoint`, tests beside `ledgerMath.test.ts` | 5 | Structurally distinct (`usdPlan`), asserted by a test. |
| 1 step 3 — price each dispatch in quota dollars alongside the API estimate; label the API figure counterfactual | 11 | Column header `API RATE (NOT PAID)`. |
| 1 step 4 — setting: monthly plan USD | 9 | In `state.cfg`, beside `StatuslineCard`. Claude only; Codex price deferred with a stated reason. |
| 2 — `src/shared/quotaEfficiency.ts`, md2's three rules, tests including a reset | 6 | Positive deltas only, reset ⇒ delta = current %, same-bucket alignment; a reset test and an external-usage test. |
| 3 — Codex `account/rateLimits/read` without opening a thread; feed `depletion.ts` | 3, 4 | Parser + adapter method; test asserts no `thread/start`. `asDepletionInput` + the widened `DepletionInput` are the seam into `depletion.ts`. |
| 4 — nested Codex token buckets; conformance case; document on `TurnUsage` | 2 | De-nested with a zero floor; conformance case fails on a negative bucket. |
| 5 — duration pauses while waiting on the user | 12, 13 | `waitClock.ts` + wiring into both prompt paths and `durationBaseline`. |
| Resolved: 7-day basis, 5-hour stays a gauge | 5, 6 | `QUOTA_WINDOW_MS`, `basis: 'seven_day'` fixed on `QuotaEfficiency`; the `basis` parameter defaults to seven-day and is documented as never defaulted into five-hour. |
| Resolved: external usage excluded and surfaced | 6, 10 | `'external-usage'` outcome, `externalUsageBuckets` count, rendered as an indicator. |
| Resolved: plan price in the existing user-settings store | 9 | `Cfg`, already in `persistence.ts`'s whitelist. |
| Resolved: points until 3 buckets, then dollars | 6, 10, 11 | `MIN_FIT_BUCKETS = 3`; `tokensPerPoint` is null below it and the quota cell falls back to points, then to an em dash. |

**Gap found and closed during review:** item 3's stated payoff is "fills the Codex half of the quota bar", which needs a renderer surface for the Codex readout. Nothing in this plan renders one — `readAccountRateLimits` is exercised only by tests. Rather than pad the plan with a Codex quota tile the spec did not scope, Task 3 makes the seam explicit (`asDepletionInput` returns exactly what `deriveDepletion` consumes, and `deriveDepletion`'s parameter is widened to accept it), and Task 9 documents why no Codex plan-price field is added yet. This is the one spec point not fully grounded in a rendered surface; it is called out in the hand-off summary rather than hidden.

**2. Placeholder scan:** no "TBD", no "implement later", no "similar to Task N", no "add appropriate error handling". Every code step carries the literal code. Two steps say "check the file first" (Task 10 Step 6 on `LedgerView.test.tsx`'s fixture, Task 11 Step 1 on an existing `row()` builder) — both are conditional fixes to existing test files whose exact current contents the executor will have open, with the required change stated exactly.

**3. Type consistency:**
- `QuotaEfficiency.tokensPerPoint: number | null` — produced in Task 6, read as `?? null` in Task 11 and as `!= null` in Task 10. Consistent.
- `QuotaCost.usdPlan: number | null` — produced in Task 5, consumed in Task 11's `quotaCell`. Consistent.
- `quotaCostForTokens(tokens, tokensPerPoint, monthlyUsd, basis?)` — Task 11 passes three positional arguments and relies on the `'seven_day'` default. Matches the Task 5 signature.
- `planCostPerPoint(monthlyUsd, windowMs)` + `QUOTA_WINDOW_MS.seven_day` — same names in Tasks 5, 9, 10.
- `MIN_FIT_BUCKETS` — exported in Task 6, imported in Task 10. Same name.
- `deriveQuotaEfficiency(quotaSamples, tokenSamples, opts)` — Task 6's signature; Task 7 calls it with `{ nowMs, windowMs }` and omits `bucketMs`, which is optional. Consistent.
- `TokenSample` / `QuotaSample` — Task 7's inline buffer type `{ atMs: number; usedPercentage: number }[]` is structurally identical to `QuotaSample[]`. Assignable.
- `DepletionInput` — declared in `depletion.ts` (Task 3), imported by `codexRateLimits.ts` (Task 3). Single definition, no duplicate.
- `TurnUsage` — four fields after Task 2; every fake, adapter and assertion updated in the same task, so no task between 2 and 13 sees a three-field version.
- `waitClock`'s `activeDurationMs(clock, startedAtMs, wallDurationMs, nowMs)` — same argument order in Task 12's tests, Task 13's wiring, and Task 13's shape test.
- `beginWait` / `endWait` take `(clock, id, atMs)` everywhere.
- IPC channel names: `quota:efficiency` (push) and `quota:efficiency:current` (invoke) — identical strings in Task 7 (main) and Task 8 (preload).
- Action type `SET_QUOTA_EFFICIENCY` with payload key `quota` — same in the union, the case, and both dispatch sites in `useQuotaSync`.
