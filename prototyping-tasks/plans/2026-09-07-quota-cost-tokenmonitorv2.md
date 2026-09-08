# Quota-Normalized Cost (TokenMonitorV2 half) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make TokenMonitorV2 price work in the subscription quota it actually consumes — a verified pricing table, a `planCostPerPoint` conversion, an empirical tokens-per-point fit driven by a real usage-percentage time series, and a "budget vs quota" readout in the budgets panel.

**Architecture:** Three layers, bottom up. (1) `packages/core` gains the corrected pricing table plus two new pure modules — `quotaCost.ts` (dollars per quota point) and `quotaEfficiency.ts` (the tokens-per-point fit with md2's delta rules). (2) A new **statusline payload feed** — a Claude Code `statusLine` hook script that writes `~/.claude-token-tracker/statusline.json` on every turn, a file watcher in the main process, and an append-only sample store — supplies the usage-percentage time series that the `/usage` scrape never could. (3) `src/shared/quotaState.js` joins plan price + fit + budgets into one render model that `budgets.js` draws. The existing `/usage` scraper is **kept as the no-install fallback** and gains a poll-failure reason enum.

**Tech Stack:** Node 18+, Electron 43.4.1, CommonJS in `src/` and `test/`, TypeScript (ESM source, dual ESM+CJS build via `packages/core/build.mjs`) in `packages/core`, `node:test` + `node:assert/strict` everywhere (no vitest, no jest — vitest is aether-os's runner and must not be introduced here).

**Spec:** `C:\Users\Matt\agent-improvement\prototyping-tasks\quota-normalized-cost-2026-09-07.md`

---

## Decision: statusline reader **and** scraper, not either/or

The spec offers a choice: keep `src/main/usageScraper.js` or port aether-os's statusline-file reader and retire scraping (spec line 38 marks the port "preferred"). **This plan ports the statusline reader AND keeps the scraper.** Reasoning, grounded in the code:

- **The scraper structurally cannot produce a time series.** `src/main/usageScraper.js:22-32` only parses when `/usage` output happens to be sitting in the pty buffer, and `src/main/main.js:178-212` only writes `/usage\r` when the user clicks Sync. Item 1's tokens-per-point fit needs *repeated* `used_percentage` readings across buckets. One snapshot per button press is not that. The statusline hook fires on every turn and carries `rate_limits.seven_day.used_percentage` plus `resets_at` as an epoch number (aether-os `src/shared/statuslinePayload.ts:88-96`) — a strictly better signal than the free-text `resetsAt` string `src/shared/usageParser.js:64` recovers.
- **Retiring the scraper would be a destructive removal on a feature branch.** `usageParser.js` (100 lines, fixture-calibrated against `test/fixtures/usage-pane-real.txt`), `planUsageConfig.js`, `test/usageParser.test.js`, `test/planUsageConfig.test.js`, and the `planUsage` / `planWarnings` inputs to `evaluateAlerts` (`src/main/ipcHandlers.js:126-128`) all work today. Deleting them is not in service of this spec.
- **The scraper is the only source that needs no `~/.claude/settings.json` edit.** TMv2 ships to an IT department (README, "What v2 is for"); a user who declines the statusline install must still get a plan-usage readout. So item 7's reason enum stays worth building — but, per the task framing, it is now a **fallback-path improvement only**, and the plan treats it that way (Task 13, near the end, small).

**Known interaction to verify, not assume:** aether-os installs *itself* as `statusLine` on this machine. `detectInstallStatus` returns `installed-other` for a foreign command and `installStatusline` chains to it rather than clobbering it (aether-os `electron/statuslineInstaller.ts:186-198`). The TMv2 port keeps that chaining verbatim, so installing TMv2's statusline on top of aether's leaves aether's script running and writing its own payload. Task 10 includes an explicit manual verification of exactly that.

---

## Global Constraints

Copied from the spec and the repo; every task's requirements implicitly include this section.

- **"Zero API cost, enforced. Nothing in v2 may make a model call."** (`README.md:22-24`.) Every number renders client-side from local transcript JSONL and the CLI's own output. No `@anthropic-ai/sdk`, no `api.anthropic.com`, no `messages.create(`, no `ANTHROPIC_API_KEY` read.
- **The `noApiCalls` boundary test does not exist in TokenMonitorV2 yet.** Verified: grepping the repo for `noApiCall|messages.create|modelPolicy` returns only prose — `README.md:23-24`, `docs/design/aether-convergence-plan.md:227-228`, `docs/design/2026-08-05-app-move-and-aether-reskin.md:278-280`. The real implementation is aether-os's `src/shared/noApiCalls.test.ts` (vitest). **Task 1 ports it to `node:test` so this constraint is enforced rather than merely stated**, and every later task must keep it green.
- **Model-ID literals:** the ported guard fails the build on any `/claude-[a-z]+-\d/` literal in `src/`, `scripts/` or `packages/core/src/` outside an explicit exception set. Verified today the only hit is `packages/core/src/optimizeRules.ts:51` (`costForEvent({ ...e, model: 'claude-sonnet-4-6' })`, a hypothetical-cost comparison, not a call site). Keep pricing and quota code tier-named, never model-ID-named — the same reason aether-os's `modelPricing.ts:24-26` gives.
- **Test runner is `node:test`.** Root suite: `node --test "test/*.test.js"`; core suite: `npm run build && node --test "test/*.test.js" "test/*.test.cjs"` (`package.json:14`, `packages/core/package.json:34`). Root tests are CommonJS `require`; core tests exist as `.cjs` (against `dist/cjs`) and `.js` ESM (against `dist/esm`). **Do not add vitest.**
- **`packages/core` is pure:** "No `fs`, no Electron, no network, no model calls" (`packages/core/package.json:4`). Anything touching the filesystem belongs in `src/shared/` (CommonJS) or `src/main/`, never in `packages/core`.
- **`packages/core/build.mjs` is a mechanical ESM→CJS transform, not a bundler.** It only rewrites `import {…} from './x.js'`, `import x from 'node:y'`, `export * from './x.js'`, and `export function|const|class NAME`. Any new core module must use only those forms — no default exports, no dynamic `import()`, no `export { a, b }` block carrying a binding's only export.
- **Renderer scripts are classic `<script>`s, not modules.** `budgets.js`, `format.js`, `settingsPanel.js` cannot `require()`. Constants duplicated into the renderer must be pinned by a source-text test, the pattern `test/settingsPalettes.test.js` and `test/budgetAlarmUnification.test.js` already use.
- **Resolved spec decisions, binding:**
  - 7-day window is the basis for dollars and tokens-per-point. The 5-hour window is a **live gauge only** and is never mixed into a dollar figure.
  - Buckets where the account percentage moved but local tokens are zero are **excluded from the fit** and surfaced as an "external usage" indicator.
  - Show **quota points** until 3 buckets carry both signals; only then show dollars.
  - Plan price is stored **beside** the `planUsageConfig.js` snapshot, i.e. in `~/.claude-token-tracker/`.
- **`monthlyUsd / (100 * (28 days / windowMs))`** is the exact `planCostPerPoint` formula (spec line 14; 28-day month = 40320 minutes). For a 7-day window this must equal `monthlyUsd / 400`.
- **The statusline script must never throw, never exit non-zero, and never write to stderr, under any input.** It runs inside the user's live Claude Code session; a bug there degrades their coding session, not just this app. Node builtins only, no imports from `src/`.
- **Every task ends with its own commit.** Conventional-commit prefixes (`feat:`, `fix:`, `test:`, `chore:`) — the repo uses `commit-and-tag-version` (`package.json:24`), so the prefix drives the changelog.

---

## File Structure

**Created**

| Path | Responsibility |
|---|---|
| `test/noApiCalls.test.js` | Zero-API-cost boundary guard, ported to `node:test` |
| `packages/core/src/quotaCost.ts` | `planCostPerPoint`, `QuotaCost` shape, window constants |
| `packages/core/test/quotaCost.test.cjs` | its test |
| `packages/core/src/quotaEfficiency.ts` | `fitTokensPerPoint` — md2's delta rules + external-usage exclusion |
| `packages/core/test/quotaEfficiency.test.cjs` | its test |
| `src/shared/planPriceConfig.js` | monthly plan USD, persisted beside `planUsage.json` |
| `test/planPriceConfig.test.js` | its test |
| `src/shared/statuslinePayload.js` | defensive parser for Claude Code's statusline JSON |
| `test/statuslinePayload.test.js` | its test |
| `scripts/tokenmonitor-statusline.mjs` | the `statusLine` hook: prints a line, persists the payload |
| `test/statuslineScript.test.js` | spawns the script and asserts its contract |
| `src/main/statuslineInstaller.js` | reads/patches `~/.claude/settings.json`, chaining not clobbering |
| `test/statuslineInstaller.test.js` | its test |
| `src/shared/quotaSeriesStore.js` | append-only, capped sample series joining `%` to tokens |
| `test/quotaSeriesStore.test.js` | its test |
| `src/main/statuslineWatcher.js` | polls the payload file, emits snapshots |
| `test/statuslineWatcher.test.js` | its test |
| `src/shared/quotaState.js` | pure: plan price + fit + budgets → the render model |
| `test/quotaState.test.js` | its test |

**Modified**

| Path | Change |
|---|---|
| `packages/core/src/modelPricing.ts:1-40` | replaced wholesale by the verified aether-os table |
| `packages/core/src/index.ts:1-5` | three new `export * from` lines |
| `packages/core/test/modelPricing.test.cjs:1-26` | rewritten against the verified table |
| `test/historyAggregator.test.js:173-187` | `modelSplit` ordering assertions (opus is no longer the top spender) |
| `test/coreContract.test.js:17+` | new core bindings added to the pinned export list |
| `src/shared/usageParser.js:100` | adds `classifySyncFailure` + `SYNC_FAILURE_REASONS` |
| `src/main/usageScraper.js:44-51` | exposes `getBuffer()` |
| `src/main/main.js:178-212` | `plan:sync` returns a reason enum; statusline watcher + series store wiring |
| `src/main/ipcHandlers.js:82-131` | `quota` block on dashboard state; plan-price and statusline IPC |
| `src/preload/preload.js:61-63` | `plan.getPrice/setPrice`, `statusline.*` |
| `src/renderer/index.html:29-77` | plan-price row + statusline install row in the settings popover |
| `src/renderer/dashboard/panels/settingsPanel.js:300-348` | mounts those two rows |
| `src/renderer/dashboard/panels/budgets.js:52-71` | quota rendering + external-usage indicator |
| `src/renderer/styles/tokens.css` | classes for the new rows |

---

### Task 1: Isolated worktree, deps, and the zero-API-cost guard

**Files:**
- Create: `test/noApiCalls.test.js`
- Worktree: `../TokenMonitorV2-quota` on branch `feat/quota-normalized-cost`

**Interfaces:**
- Consumes: nothing.
- Produces: a green baseline suite in the worktree, and a build-failing guard every later task must keep green. No exported symbols.

- [ ] **Step 1: Create the worktree and install**

Run from the main tree `C:\Users\Matt\projects\TokenMonitorV2`:

```bash
git worktree add ../TokenMonitorV2-quota -b feat/quota-normalized-cost
cd ../TokenMonitorV2-quota
npm install
npm run build:core
```

All remaining work happens in `../TokenMonitorV2-quota`. Never edit the main tree.

- [ ] **Step 2: Record the baseline**

Run: `npm test`
Expected: PASS. Write the pass/fail counts down — Task 2 changes pricing, and you need to know which failures it caused versus which were already there.

- [ ] **Step 3: Write the guard test**

Create `test/noApiCalls.test.js`:

```js
// test/noApiCalls.test.js
// The CI guardrail README.md:22-24 promises and docs/design/aether-convergence-plan.md:227
// specifies. Ported from aether-os's src/shared/noApiCalls.test.ts (vitest) to node:test,
// scoped to this repo's roots. Fails the build the moment a paid API call becomes reachable.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const REPO = path.join(__dirname, '..');
const ROOTS = ['src', 'scripts', path.join('packages', 'core', 'src')];
const SKIP_DIR_NAMES = new Set(['node_modules', 'dist', 'release', '.git']);
const SOURCE_EXTENSIONS = ['.ts', '.tsx', '.js', '.cjs', '.mjs'];

function isTestOrDecl(name) {
  return /\.test\.(ts|tsx|js|cjs|mjs)$/.test(name) || name.endsWith('.d.ts');
}

function walk(dir, out) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (SKIP_DIR_NAMES.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (SOURCE_EXTENSIONS.some((ext) => entry.name.endsWith(ext)) && !isTestOrDecl(entry.name)) out.push(full);
  }
}

function allSourceFiles() {
  const out = [];
  for (const root of ROOTS) {
    const abs = path.join(REPO, root);
    if (fs.existsSync(abs)) walk(abs, out);
  }
  return out;
}

function offendersMatching(pattern) {
  const offenders = [];
  for (const file of allSourceFiles()) {
    if (pattern.test(fs.readFileSync(file, 'utf8'))) offenders.push(path.relative(REPO, file));
  }
  return offenders;
}

test('@anthropic-ai/sdk is not a dependency of the app or of packages/core', () => {
  for (const rel of ['package.json', path.join('packages', 'core', 'package.json')]) {
    const pkg = JSON.parse(fs.readFileSync(path.join(REPO, rel), 'utf8'));
    assert.strictEqual((pkg.dependencies || {})['@anthropic-ai/sdk'], undefined, rel + ' dependencies');
    assert.strictEqual((pkg.devDependencies || {})['@anthropic-ai/sdk'], undefined, rel + ' devDependencies');
  }
});

test('no source file imports @anthropic-ai/sdk', () => {
  assert.deepStrictEqual(offendersMatching(/@anthropic-ai\/sdk/), []);
});

test('no source file references api.anthropic.com', () => {
  assert.deepStrictEqual(offendersMatching(/api\.anthropic\.com/), []);
});

test('no source file reads ANTHROPIC_API_KEY', () => {
  assert.deepStrictEqual(offendersMatching(/ANTHROPIC_API_KEY/), []);
});

test('no source file contains a messages.create( call', () => {
  assert.deepStrictEqual(offendersMatching(/messages\.create\s*\(/), []);
});

// Pricing and quota code must name TIERS, never model IDs -- the same discipline
// aether-os's modelPricing.ts:24-26 documents. optimizeRules.ts is the one reviewed
// exception: its literal is a hypothetical "what would Sonnet have cost" comparison,
// not a call site.
const MODEL_ID_SHAPE = /claude-[a-z]+-\d/;
const LITERAL_EXCEPTIONS = new Set([path.normalize('packages/core/src/optimizeRules.ts')]);

test('no Claude model-ID-shaped literal appears outside LITERAL_EXCEPTIONS', () => {
  const offenders = [];
  for (const file of allSourceFiles()) {
    const rel = path.normalize(path.relative(REPO, file));
    if (LITERAL_EXCEPTIONS.has(rel)) continue;
    if (MODEL_ID_SHAPE.test(fs.readFileSync(file, 'utf8'))) offenders.push(rel);
  }
  assert.deepStrictEqual(offenders, []);
});
```

- [ ] **Step 4: Run it and confirm it passes on the untouched tree**

Run: `node --test test/noApiCalls.test.js`
Expected: PASS, 6 tests. If the model-ID test fails naming a file other than `optimizeRules.ts`, do **not** widen `LITERAL_EXCEPTIONS` silently — read the file, and only add it with a comment naming why it is not a call site.

- [ ] **Step 5: Prove the guard actually bites**

Temporarily append to `src/shared/budgetDerive.js`: `// api.anthropic.com`
Run: `node --test test/noApiCalls.test.js`
Expected: FAIL on "no source file references api.anthropic.com", listing `src\shared\budgetDerive.js`.
Then remove the line and re-run. Expected: PASS. A guard you never watched fail is not a verified guard.

- [ ] **Step 6: Commit**

```bash
git add test/noApiCalls.test.js
git commit -m "test: enforce the zero-API-cost boundary README promises"
```

---

### Task 2: Port aether-os's verified pricing table into packages/core

**Files:**
- Modify: `packages/core/src/modelPricing.ts:1-40` (replace whole file)
- Modify: `packages/core/test/modelPricing.test.cjs:1-26` (replace whole file)
- Modify: `test/historyAggregator.test.js:173-187`
- Modify: `test/coreContract.test.js:17+`
- Test: `packages/core/test/modelPricing.test.cjs`

**Interfaces:**
- Consumes: nothing.
- Produces: `PRICING_PER_MILLION_TOKENS` (now with a `fable` tier), `PRICING_VERIFIED_AT: string`, `CACHE_READ_DISCOUNT: number`, `CACHE_WRITE_MULTIPLIER: number`, `pricingTierForModel(modelName: string | null | undefined): 'opus'|'sonnet'|'haiku'|'fable'`, `costBreakdownForEvent(event): { input, output, cacheCreation, cacheRead }`, `costForEvent(event): number`.

**The three discrepancies the spec names, confirmed against the real files:**

| Claim | TMv2 today (`packages/core/src/modelPricing.ts`) | aether-os (`src/shared/modelPricing.ts`) |
|---|---|---|
| opus 15/75 | line 6: `opus: { input: 15, output: 75 }` — the retired Opus 3 rate; overstates every Opus figure **3x** | line 30: `opus: { input: 5, output: 25 }` |
| cache write at 1.0x | line 34: `((inputTokens + cacheCreationInputTokens) / 1e6) * rates.input` — cache creation billed at the plain input rate | line 45: `CACHE_WRITE_MULTIPLIER = 1.25`, applied at line 85 |
| fable falls through to sonnet | lines 19-22: no fable branch, so `pricingTierForModel('claude-fable-5') === 'sonnet'`; TMv2's own test pins that at `packages/core/test/modelPricing.test.cjs:9` | lines 33, 53: `fable: { input: 10, output: 50 }` plus a `fable`/`mythos` branch |

Two further TMv2-only errors the port also fixes, found while confirming the above: haiku is `0.8/4` (line 8) where the verified rate is `1/5`, and there is no `PRICING_VERIFIED_AT` stamp at all.

- [ ] **Step 1: Replace the core test first (it must fail before the source changes)**

Overwrite `packages/core/test/modelPricing.test.cjs` — aether's vitest suite transliterated to `node:test`, keeping every assertion including both regressions:

```js
// packages/core/test/modelPricing.test.cjs
// Ported from aether-os's src/shared/modelPricing.test.ts. Same assertions,
// node:test instead of vitest, against the CJS build output.
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  pricingTierForModel,
  costForEvent,
  costBreakdownForEvent,
  PRICING_VERIFIED_AT,
  PRICING_PER_MILLION_TOKENS,
  CACHE_READ_DISCOUNT,
  CACHE_WRITE_MULTIPLIER,
} = require('../dist/cjs/modelPricing.cjs');

const close = (actual, expected, digits = 5) =>
  assert.ok(Math.abs(actual - expected) < Math.pow(10, -digits), actual + ' !~= ' + expected);

test('PRICING_VERIFIED_AT parses as a date and is not in the future', () => {
  assert.ok(!Number.isNaN(Date.parse(PRICING_VERIFIED_AT)));
  assert.ok(Date.parse(PRICING_VERIFIED_AT) <= Date.now());
});

test('holds the rates verified on PRICING_VERIFIED_AT', () => {
  assert.deepStrictEqual({ ...PRICING_PER_MILLION_TOKENS }, {
    opus: { input: 5, output: 25 },
    sonnet: { input: 3, output: 15 },
    haiku: { input: 1, output: 5 },
    fable: { input: 10, output: 50 },
  });
  assert.strictEqual(CACHE_READ_DISCOUNT, 0.1);
  assert.strictEqual(CACHE_WRITE_MULTIPLIER, 1.25);
});

test('classifies model names into pricing tiers, case-insensitively', () => {
  assert.strictEqual(pricingTierForModel('claude-opus-4-8'), 'opus');
  assert.strictEqual(pricingTierForModel('claude-sonnet-5'), 'sonnet');
  assert.strictEqual(pricingTierForModel('claude-haiku-4-5-20251001'), 'haiku');
  assert.strictEqual(pricingTierForModel('CLAUDE-OPUS-4-8'), 'opus');
  assert.strictEqual(pricingTierForModel(null), 'sonnet');
  assert.strictEqual(pricingTierForModel(''), 'sonnet');
  assert.strictEqual(pricingTierForModel('unknown-model'), 'sonnet');
});

// Regression: these previously fell through to the sonnet default, billing a
// $10 / $50 model at $3 / $15 with no error surfaced anywhere.
test('classifies the fable and mythos families into their own tier', () => {
  assert.strictEqual(pricingTierForModel('claude-fable-5'), 'fable');
  assert.strictEqual(pricingTierForModel('claude-mythos-5'), 'fable');
  assert.strictEqual(pricingTierForModel('Claude-Fable-5'), 'fable');
});

test('computes cost for an event with usage', () => {
  const cost = costForEvent({
    model: 'claude-sonnet-4-6',
    usage: { inputTokens: 1_000_000, outputTokens: 1_000_000, cacheCreationInputTokens: 0, cacheReadInputTokens: 0 },
  });
  assert.strictEqual(Math.round(cost), 18); // 1M in @ $3 + 1M out @ $15
});

test('returns 0 for missing usage and for a null event', () => {
  assert.strictEqual(costForEvent({ model: 'claude-sonnet-4-6', usage: null }), 0);
  assert.strictEqual(costForEvent(null), 0);
});

// Regression: opus was $15/$75 here (the retired Opus 3 rate) and overstated
// every Opus dollar figure this app rendered by 3x.
test('computes correct cost for the opus tier', () => {
  close(costForEvent({
    model: 'claude-opus-4-8',
    usage: { inputTokens: 1_000_000, outputTokens: 1_000_000, cacheCreationInputTokens: 0, cacheReadInputTokens: 0 },
  }), 30); // was 90
});

test('computes correct cost for the haiku tier', () => {
  close(costForEvent({
    model: 'claude-haiku-4-5',
    usage: { inputTokens: 1_000_000, outputTokens: 1_000_000, cacheCreationInputTokens: 0, cacheReadInputTokens: 0 },
  }), 6); // was 4.80
});

test('computes correct cost for the fable tier', () => {
  close(costForEvent({
    model: 'claude-fable-5',
    usage: { inputTokens: 1_000_000, outputTokens: 1_000_000, cacheCreationInputTokens: 0, cacheReadInputTokens: 0 },
  }), 60); // was 18 while fable fell through to sonnet
});

// Regression: cache creation was billed at 1.0x the input rate.
test('prices a cache-write token at 1.25x a plain input token', () => {
  const shape = { outputTokens: 0, cacheReadInputTokens: 0 };
  const asInput = costForEvent({ model: 'claude-sonnet-4-6', usage: { ...shape, inputTokens: 1_000_000, cacheCreationInputTokens: 0 } });
  const asWrite = costForEvent({ model: 'claude-sonnet-4-6', usage: { ...shape, inputTokens: 0, cacheCreationInputTokens: 1_000_000 } });
  assert.ok(asWrite > asInput);
  close(asWrite / asInput, 1.25);
});

test('applies the cache-read discount at 10% of the tier input rate', () => {
  close(costForEvent({
    model: 'claude-opus-4-8',
    usage: { inputTokens: 0, outputTokens: 0, cacheCreationInputTokens: 0, cacheReadInputTokens: 1_000_000 },
  }), 0.5); // 1M * $5 * 0.1
});

test('combines all four token types', () => {
  close(costForEvent({
    model: 'claude-sonnet-4-6',
    usage: { inputTokens: 500_000, outputTokens: 100_000, cacheCreationInputTokens: 200_000, cacheReadInputTokens: 300_000 },
  }), 3.84); // 1.50 + 1.50 + 0.75 + 0.09
});

test('costForEvent equals the sum of costBreakdownForEvent', () => {
  for (const model of ['claude-sonnet-4-6', 'claude-opus-4-8', 'claude-haiku-4-5', 'claude-fable-5']) {
    const event = {
      model,
      usage: { inputTokens: 123_456, outputTokens: 7_890, cacheCreationInputTokens: 45_678, cacheReadInputTokens: 901_234 },
    };
    const b = costBreakdownForEvent(event);
    close(costForEvent(event), b.input + b.output + b.cacheCreation + b.cacheRead, 10);
  }
});
```

- [ ] **Step 2: Run the core suite to verify it fails**

Run: `npm test --workspace @tokenmonitor/core`
Expected: FAIL — `PRICING_VERIFIED_AT` is undefined, the rates table does not match, `pricingTierForModel('claude-fable-5')` returns `'sonnet'`, and the opus/haiku/cache-write costs are wrong.

- [ ] **Step 3: Replace the source file**

Overwrite `packages/core/src/modelPricing.ts` with aether-os's file. The only adaptations are prose: aether's "Ledger's PricingBasisFooter" references are reworded, and the `noApiCalls.test.ts` reference becomes this repo's `test/noApiCalls.test.js`. `as const` on the rates object is kept — tsc emits plain JS and `build.mjs`'s `^export\s+(function|const|class)\s+(\w+)` transform still matches.

```ts
//
// Per-million-token USD pricing for the Claude tiers this app encounters in
// Claude Code transcripts. These are NOT placeholders. They were checked by the
// operator against Anthropic's published pricing on the date stamped below.
// Ported verbatim from aether-os's src/shared/modelPricing.ts (verified
// 2026-08-07); only the prose was adapted. Both repos consume this one package,
// so the table cannot diverge again.
//
// What the verification changed relative to this file's previous placeholder table:
//   opus   $5 / $25   Opus 5, 4.8, 4.7 and 4.6 all share this rate. The old table
//                     carried $15 / $75 -- the retired Opus 3 rate -- and overstated
//                     every Opus dollar figure by 3x.
//   sonnet $3 / $15   Unchanged. Caveat: Sonnet 5 carries an introductory $2 / $10
//                     rate through 2026-08-31. The standard rate is stamped here
//                     deliberately, because it is the durable one.
//   haiku  $1 / $5    Was $0.80 / $4, understating Haiku by ~20%.
//   fable  $10 / $50  New tier, covering the Fable and Mythos families. These
//                     previously fell through to the sonnet default and billed a
//                     $10 / $50 model at $3 / $15 -- a 3.3x undercount, silent.
//
// Deliberately no full model-ID literals below: test/noApiCalls.test.js guards on
// /claude-[a-z]+-\d/, and naming tiers rather than IDs keeps this file out of that
// test's LITERAL_EXCEPTIONS set.
export const PRICING_VERIFIED_AT = '2026-08-07';

export const PRICING_PER_MILLION_TOKENS = {
  opus: { input: 5, output: 25 },
  sonnet: { input: 3, output: 15 },
  haiku: { input: 1, output: 5 },
  fable: { input: 10, output: 50 },
} as const;

// Cache reads are priced at 10% of the tier's input rate. Confirmed at the same
// verification as the table above -- this is the published multiplier, not an
// approximation. Exported so any footer can render the multiplier actually in
// force rather than a hardcoded "10%" that could drift away from it.
export const CACHE_READ_DISCOUNT = 0.1;

// Cache WRITES cost more than a fresh input token, not the same: 1.25x the input
// rate for the 5-minute TTL and 2x for the 1-hour TTL. Claude Code writes
// 5-minute ephemeral entries, and a transcript records no TTL, so 1.25 is the
// only defensible constant here. A workload using 1-hour caching would be
// under-reported by this factor; that is a known limitation, not an oversight.
export const CACHE_WRITE_MULTIPLIER = 1.25;

export type PricingTier = keyof typeof PRICING_PER_MILLION_TOKENS;

export function pricingTierForModel(modelName: string | null | undefined): PricingTier {
  const lower = (modelName || '').toLowerCase();
  if (lower.includes('opus')) return 'opus';
  if (lower.includes('haiku')) return 'haiku';
  if (lower.includes('fable') || lower.includes('mythos')) return 'fable';
  return 'sonnet';
}

export interface CostBreakdown {
  input: number;
  output: number;
  cacheCreation: number;
  cacheRead: number;
}

export interface PricedEvent {
  model?: string | null;
  usage?: {
    inputTokens: number;
    outputTokens: number;
    cacheCreationInputTokens: number;
    cacheReadInputTokens: number;
  } | null;
}

/**
 * The four-way USD split behind costForEvent.
 *
 * costForEvent is defined as the sum of this rather than the two being computed
 * independently and trusted to agree -- duplicate arithmetic over the same two
 * multipliers is exactly the kind of thing that drifts apart silently.
 */
export function costBreakdownForEvent(event: PricedEvent | null | undefined): CostBreakdown {
  if (!event || !event.usage) return { input: 0, output: 0, cacheCreation: 0, cacheRead: 0 };
  const rates = PRICING_PER_MILLION_TOKENS[pricingTierForModel(event.model)];
  return {
    input: (event.usage.inputTokens / 1_000_000) * rates.input,
    output: (event.usage.outputTokens / 1_000_000) * rates.output,
    cacheCreation: (event.usage.cacheCreationInputTokens / 1_000_000) * rates.input * CACHE_WRITE_MULTIPLIER,
    cacheRead: (event.usage.cacheReadInputTokens / 1_000_000) * rates.input * CACHE_READ_DISCOUNT,
  };
}

export function costForEvent(event: PricedEvent | null | undefined): number {
  const b = costBreakdownForEvent(event);
  return b.input + b.output + b.cacheCreation + b.cacheRead;
}
```

- [ ] **Step 4: Run the core suite to verify it passes**

Run: `npm test --workspace @tokenmonitor/core`
Expected: PASS, including the pre-existing `optimizeRules` / `optimizeGrade` / `optimizeActions` / `esm-entry` suites.

- [ ] **Step 5: Pin the new bindings in the root contract test**

`packages/core/src/index.ts:2` already does `export * from './modelPricing.js'`, so the new symbols reach the barrel automatically. Add them to the pinned export list in `test/coreContract.test.js` (the array beginning at line 17) so a future barrel change cannot silently drop them:

```js
  'costForEvent',
  'costBreakdownForEvent',
  'pricingTierForModel',
  'PRICING_VERIFIED_AT',
  'CACHE_READ_DISCOUNT',
  'CACHE_WRITE_MULTIPLIER',
```

- [ ] **Step 6: Run the root suite and repair the one known breakage**

Run: `npm test`
Expected: exactly one failing test — `modelSplit groups by pricing tier within the window, sorted by spend` at `test/historyAggregator.test.js:173`. Its fixture is three output-only events: 1M opus, 1M sonnet, 1M null-model (→ sonnet). Under the old table opus was `$75` and sonnet `$30`, so opus sorted first. Under the verified table opus is `1M * $25 = $25` and the two sonnet-tier events total `2M * $15 = $30`, so **sonnet now sorts first**. The sort under test is unchanged; the rates are.

Replace the assertion block at lines 183-187 with:

```js
  // Under the verified table (opus $5/$25) 1M opus output is $25, while the two
  // sonnet-tier events total 2M output at $15 = $30 -- so sonnet, not opus, is now
  // the top spender for this fixture. The sort under test is unchanged; the rates are.
  assert.strictEqual(split[0].tier, 'sonnet'); // $30 > opus's $25
  assert.strictEqual(split[0].tokens, 2_000_000); // sonnet + unknown-model event
  assert.strictEqual(split[1].tier, 'opus');
  assert.strictEqual(split[1].tokens, 1_000_000);
  assert.strictEqual(Math.round(split[0].spend), 30);
  assert.strictEqual(Math.round(split[1].spend), 25);
```

Delete the stale inline comment `// $75 > sonnet's $30` if it survives the replacement.

- [ ] **Step 7: Re-run both suites**

Run: `npm test`
Expected: PASS, root and core. Any *other* failure means a fixture pins a dollar value this plan did not account for — read it, do not blanket-update it. Verified by grep before this plan was written: the only other pinned dollar assertions are `test/aggregator.test.js:95` (`Math.round(spend) === 18`, sonnet 1M/1M — unaffected by every rate change here) and the `weekOverWeek` ratio tests at `test/historyAggregator.test.js:199,208` (same model on both sides, so the ratio is rate-independent).

- [ ] **Step 8: Commit**

```bash
git add packages/core/src/modelPricing.ts packages/core/test/modelPricing.test.cjs test/coreContract.test.js test/historyAggregator.test.js
git commit -m "fix: port aether-os's verified pricing table into packages/core"
```

---

### Task 3: planCostPerPoint in packages/core

**Files:**
- Create: `packages/core/src/quotaCost.ts`
- Modify: `packages/core/src/index.ts:1-5`
- Modify: `test/coreContract.test.js:17+`
- Test: `packages/core/test/quotaCost.test.cjs`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `MONTH_BASIS_MS: number` (28 days), `SEVEN_DAY_WINDOW_MS: number`, `FIVE_HOUR_WINDOW_MS: number`
  - `type QuotaBasis = 'seven_day' | 'five_hour'`
  - `interface QuotaCost { usdPlan: number; points: number; basis: QuotaBasis; tokensPerPoint: number }`
  - `planCostPerPoint(monthlyUsd: number, windowMs: number): number`
  - `quotaCostForTokens(args: { tokens: number; tokensPerPoint: number; monthlyUsd: number; windowMs: number; basis: QuotaBasis }): QuotaCost | null`

- [ ] **Step 1: Write the failing test**

Create `packages/core/test/quotaCost.test.cjs`:

```js
// packages/core/test/quotaCost.test.cjs
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  planCostPerPoint,
  quotaCostForTokens,
  MONTH_BASIS_MS,
  SEVEN_DAY_WINDOW_MS,
  FIVE_HOUR_WINDOW_MS,
} = require('../dist/cjs/quotaCost.cjs');

const close = (a, b, d = 9) => assert.ok(Math.abs(a - b) < Math.pow(10, -d), a + ' !~= ' + b);

test('the month basis is 28 days, matching the source formula', () => {
  assert.strictEqual(MONTH_BASIS_MS, 28 * 24 * 60 * 60 * 1000);
  assert.strictEqual(MONTH_BASIS_MS / 60000, 40320); // the 40320 minutes the spec names
  assert.strictEqual(SEVEN_DAY_WINDOW_MS, 7 * 24 * 60 * 60 * 1000);
  assert.strictEqual(FIVE_HOUR_WINDOW_MS, 5 * 60 * 60 * 1000);
});

// The identity the spec pins: for the seven-day window, $/point is monthlyUsd / 400.
test('a $200 plan on the seven-day window is $0.50 per quota point', () => {
  close(planCostPerPoint(200, SEVEN_DAY_WINDOW_MS), 0.5);
  close(planCostPerPoint(200, SEVEN_DAY_WINDOW_MS), 200 / 400);
  close(planCostPerPoint(100, SEVEN_DAY_WINDOW_MS), 0.25);
});

test('a shorter window costs proportionally less per point', () => {
  // 28d / 5h = 134.4 windows per month -> 200 / (100 * 134.4)
  close(planCostPerPoint(200, FIVE_HOUR_WINDOW_MS), 200 / (100 * (MONTH_BASIS_MS / FIVE_HOUR_WINDOW_MS)));
  assert.ok(planCostPerPoint(200, FIVE_HOUR_WINDOW_MS) < planCostPerPoint(200, SEVEN_DAY_WINDOW_MS));
});

test('a full window of points costs exactly one window of plan money', () => {
  close(planCostPerPoint(200, SEVEN_DAY_WINDOW_MS) * 100, 200 / 4); // four seven-day windows in 28 days
});

test('non-positive or non-finite inputs yield 0, never NaN or Infinity', () => {
  for (const bad of [0, -1, NaN, Infinity, null, undefined, 'lots']) {
    assert.strictEqual(planCostPerPoint(bad, SEVEN_DAY_WINDOW_MS), 0, 'monthlyUsd=' + bad);
    assert.strictEqual(planCostPerPoint(200, bad), 0, 'windowMs=' + bad);
  }
});

test('quotaCostForTokens converts tokens to points and points to dollars', () => {
  assert.deepStrictEqual(quotaCostForTokens({
    tokens: 5_000_000, tokensPerPoint: 1_000_000, monthlyUsd: 200,
    windowMs: SEVEN_DAY_WINDOW_MS, basis: 'seven_day',
  }), { usdPlan: 2.5, points: 5, basis: 'seven_day', tokensPerPoint: 1_000_000 });
});

test('quotaCostForTokens returns null when the fit is unusable', () => {
  const base = { tokens: 1_000, monthlyUsd: 200, windowMs: SEVEN_DAY_WINDOW_MS, basis: 'seven_day' };
  assert.strictEqual(quotaCostForTokens({ ...base, tokensPerPoint: 0 }), null);
  assert.strictEqual(quotaCostForTokens({ ...base, tokensPerPoint: -5 }), null);
  assert.strictEqual(quotaCostForTokens({ ...base, tokensPerPoint: NaN }), null);
  assert.strictEqual(quotaCostForTokens({ ...base, tokensPerPoint: null }), null);
});

test('quotaCostForTokens reports points even when no plan price is set', () => {
  assert.deepStrictEqual(quotaCostForTokens({
    tokens: 2_000_000, tokensPerPoint: 1_000_000, monthlyUsd: 0,
    windowMs: SEVEN_DAY_WINDOW_MS, basis: 'seven_day',
  }), { usdPlan: 0, points: 2, basis: 'seven_day', tokensPerPoint: 1_000_000 });
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `npm run build --workspace @tokenmonitor/core && node --test packages/core/test/quotaCost.test.cjs`
Expected: FAIL — `Cannot find module '../dist/cjs/quotaCost.cjs'`.

- [ ] **Step 3: Write the implementation**

Create `packages/core/src/quotaCost.ts`:

```ts
//
// Subscription-quota cost: what a Max/Pro plan actually pays for a unit of work,
// as opposed to what the same work would have cost at API rates (modelPricing.ts).
// Both repos consuming this package are subscription-only by policy, so every
// API-rate dollar figure they render is counterfactual. This module is the
// non-counterfactual one.
//
// The conversion spreads the operator's plan price across the provider's own
// reported quota window on a 28-day-month basis (40320 minutes) -- the same basis
// md2's stats_subscription_cost.ts uses, so the two are comparable. For the
// seven-day window this reduces to monthlyUsd / 400.
//

export const MONTH_BASIS_MS = 28 * 24 * 60 * 60 * 1000;
export const SEVEN_DAY_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;
export const FIVE_HOUR_WINDOW_MS = 5 * 60 * 60 * 1000;

// Dollars are only ever quoted on the seven-day basis (resolved decision,
// 2026-09-07). 'five_hour' exists as a live depletion gauge and must never be
// mixed into the same number as a seven-day figure.
export type QuotaBasis = 'seven_day' | 'five_hour';

export interface QuotaCost {
  usdPlan: number;
  points: number;
  basis: QuotaBasis;
  tokensPerPoint: number;
}

function positiveFinite(n: unknown): n is number {
  return typeof n === 'number' && Number.isFinite(n) && n > 0;
}

/**
 * USD per one percentage point of the given quota window.
 *
 * Returns 0 -- never NaN, never Infinity -- for any non-positive or non-finite
 * input, so a missing plan price renders as "no dollar figure" rather than
 * poisoning every downstream sum.
 */
export function planCostPerPoint(monthlyUsd: number, windowMs: number): number {
  if (!positiveFinite(monthlyUsd) || !positiveFinite(windowMs)) return 0;
  const windowsPerMonth = MONTH_BASIS_MS / windowMs;
  return monthlyUsd / (100 * windowsPerMonth);
}

/**
 * Prices a token count in quota points and, when a plan price is known, in the
 * dollars that plan actually pays.
 *
 * Returns null when tokensPerPoint is unusable -- the caller must then show
 * nothing rather than a zero, because "we have no fit yet" and "this cost
 * nothing" are different states and must never render the same way.
 */
export function quotaCostForTokens(args: {
  tokens: number;
  tokensPerPoint: number;
  monthlyUsd: number;
  windowMs: number;
  basis: QuotaBasis;
}): QuotaCost | null {
  const { tokens, tokensPerPoint, monthlyUsd, windowMs, basis } = args;
  if (!positiveFinite(tokensPerPoint)) return null;
  const safeTokens = positiveFinite(tokens) ? tokens : 0;
  const points = safeTokens / tokensPerPoint;
  return {
    usdPlan: points * planCostPerPoint(monthlyUsd, windowMs),
    points,
    basis,
    tokensPerPoint,
  };
}
```

- [ ] **Step 4: Export it from the barrel**

Edit `packages/core/src/index.ts`, adding after line 2:

```ts
export * from './quotaCost.js';
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `npm test --workspace @tokenmonitor/core`
Expected: PASS.

- [ ] **Step 6: Pin the new bindings and run the root suite**

Add `'planCostPerPoint'` and `'quotaCostForTokens'` to the export list in `test/coreContract.test.js`.
Run: `npm test`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add packages/core/src/quotaCost.ts packages/core/src/index.ts packages/core/test/quotaCost.test.cjs test/coreContract.test.js
git commit -m "feat: price work in subscription quota, not counterfactual API dollars"
```

---

### Task 4: The tokens-per-point fit in packages/core

**Files:**
- Create: `packages/core/src/quotaEfficiency.ts`
- Modify: `packages/core/src/index.ts`
- Modify: `test/coreContract.test.js:17+`
- Test: `packages/core/test/quotaEfficiency.test.cjs`

**Interfaces:**
- Consumes: nothing (pure).
- Produces:
  - `MIN_FIT_BUCKETS = 3`
  - `interface QuotaSample { atMs: number; usedPercentage: number; tokens: number }` — `tokens` is a **rolling-window running total**, not a per-bucket delta; the fit takes the deltas itself.
  - `interface QuotaFit { tokensPerPoint: number | null; buckets: number; externalBuckets: number; ready: boolean; resets: number }`
  - `fitTokensPerPoint(samples: QuotaSample[] | null | undefined): QuotaFit`

**The rules encoded here** — md2's three (spec line 15) plus the two resolved decisions (spec lines 60, 63):
1. Negative percentage delta means the window reset — treat the delta as the current percentage, not as a negative.
2. Ignore negative token deltas (the token source is a rolling 7-day total, so old events aging out can make it fall).
3. Both signals must come from the same adjacent pair of samples.
4. **External usage:** account percentage moved but this machine logged no tokens — excluded from the fit, counted separately.
5. **Minimum samples:** fewer than 3 contributing buckets → `ready: false`, so the UI shows points and not dollars.

- [ ] **Step 1: Write the failing test**

Create `packages/core/test/quotaEfficiency.test.cjs`:

```js
// packages/core/test/quotaEfficiency.test.cjs
const test = require('node:test');
const assert = require('node:assert/strict');
const { fitTokensPerPoint, MIN_FIT_BUCKETS } = require('../dist/cjs/quotaEfficiency.cjs');

const s = (atMs, usedPercentage, tokens) => ({ atMs, usedPercentage, tokens });
const close = (a, b, d = 6) => assert.ok(Math.abs(a - b) < Math.pow(10, -d), a + ' !~= ' + b);

test('MIN_FIT_BUCKETS is the resolved three-bucket floor', () => {
  assert.strictEqual(MIN_FIT_BUCKETS, 3);
});

test('fits tokens per point from adjacent-pair deltas', () => {
  const fit = fitTokensPerPoint([
    s(1000, 10, 0),
    s(2000, 12, 2_000_000),  // +2 pts, +2M tokens
    s(3000, 15, 5_000_000),  // +3 pts, +3M tokens
    s(4000, 20, 10_000_000), // +5 pts, +5M tokens
  ]);
  close(fit.tokensPerPoint, 1_000_000);
  assert.strictEqual(fit.buckets, 3);
  assert.strictEqual(fit.externalBuckets, 0);
  assert.strictEqual(fit.ready, true);
});

// Aggregate ratio, not a mean of per-bucket ratios: a bucket carrying more work
// should weigh more, and a mean-of-ratios lets one tiny bucket dominate.
test('the fit is total tokens over total points, not an average of ratios', () => {
  const fit = fitTokensPerPoint([
    s(1000, 0, 0),
    s(2000, 1, 5_000_000),   // 5M/pt over 1 pt
    s(3000, 11, 15_000_000), // 1M/pt over 10 pts
    s(4000, 12, 16_000_000), // 1M/pt over 1 pt
  ]);
  close(fit.tokensPerPoint, 16_000_000 / 12);
  assert.strictEqual(fit.buckets, 3);
});

test('below MIN_FIT_BUCKETS the fit is reported but not ready', () => {
  const fit = fitTokensPerPoint([s(1000, 10, 0), s(2000, 12, 2_000_000), s(3000, 14, 4_000_000)]);
  assert.strictEqual(fit.buckets, 2);
  assert.strictEqual(fit.ready, false);
  close(fit.tokensPerPoint, 1_000_000);
});

test('an empty, single-sample, or non-array input yields a null fit', () => {
  for (const input of [[], [s(1000, 10, 0)], null, undefined, 'nope']) {
    const fit = fitTokensPerPoint(input);
    assert.strictEqual(fit.tokensPerPoint, null);
    assert.strictEqual(fit.buckets, 0);
    assert.strictEqual(fit.ready, false);
  }
});

// Rule 1: on a window reset the percentage drops; the delta is the NEW value,
// not a negative number that would subtract real work out of the fit.
test('a window reset is treated as a delta of the current percentage', () => {
  const fit = fitTokensPerPoint([
    s(1000, 90, 0),
    s(2000, 3, 3_000_000), // reset: +3 pts (not -87), +3M tokens
    s(3000, 5, 5_000_000), // +2 pts, +2M
    s(4000, 9, 9_000_000), // +4 pts, +4M
  ]);
  close(fit.tokensPerPoint, 1_000_000);
  assert.strictEqual(fit.buckets, 3);
  assert.strictEqual(fit.resets, 1);
});

// Rule 2: the token total is a rolling seven-day window, so it can fall when old
// events age out. That is not negative work and must not enter the fit.
test('a negative token delta is dropped, not counted', () => {
  const fit = fitTokensPerPoint([
    s(1000, 10, 9_000_000),
    s(2000, 12, 4_000_000),  // tokens fell: dropped
    s(3000, 14, 6_000_000),  // +2 pts, +2M
    s(4000, 16, 8_000_000),  // +2 pts, +2M
    s(5000, 18, 10_000_000), // +2 pts, +2M
  ]);
  close(fit.tokensPerPoint, 1_000_000);
  assert.strictEqual(fit.buckets, 3);
});

// Resolved decision: percentage moved, local tokens did not -> somebody else on
// the same account did that work. Excluded from the fit, surfaced separately.
test('external-usage buckets are excluded from the fit and counted', () => {
  const fit = fitTokensPerPoint([
    s(1000, 10, 1_000_000),
    s(2000, 20, 1_000_000), // +10 pts, 0 tokens -> external
    s(3000, 22, 3_000_000), // +2 pts, +2M
    s(4000, 24, 5_000_000), // +2 pts, +2M
    s(5000, 26, 7_000_000), // +2 pts, +2M
  ]);
  close(fit.tokensPerPoint, 1_000_000); // the 10-point external bucket did NOT drag it to ~375k
  assert.strictEqual(fit.buckets, 3);
  assert.strictEqual(fit.externalBuckets, 1);
});

test('a bucket where nothing moved is neither a fit sample nor external usage', () => {
  const fit = fitTokensPerPoint([
    s(1000, 10, 1_000_000),
    s(2000, 10, 1_000_000), // idle
    s(3000, 12, 3_000_000),
    s(4000, 14, 5_000_000),
    s(5000, 16, 7_000_000),
  ]);
  assert.strictEqual(fit.buckets, 3);
  assert.strictEqual(fit.externalBuckets, 0);
  close(fit.tokensPerPoint, 1_000_000);
});

test('samples are sorted by time before differencing', () => {
  const ordered = fitTokensPerPoint([s(1000, 10, 0), s(2000, 12, 2_000_000), s(3000, 15, 5_000_000), s(4000, 20, 10_000_000)]);
  const shuffled = fitTokensPerPoint([s(3000, 15, 5_000_000), s(1000, 10, 0), s(4000, 20, 10_000_000), s(2000, 12, 2_000_000)]);
  assert.deepStrictEqual(shuffled, ordered);
});

test('malformed samples are skipped rather than poisoning the fit', () => {
  const fit = fitTokensPerPoint([
    s(1000, 10, 0),
    { atMs: 'soon', usedPercentage: 12, tokens: 2_000_000 },
    s(2000, 12, 2_000_000),
    s(3000, 15, 5_000_000),
    s(4000, 20, 10_000_000),
    null,
  ]);
  close(fit.tokensPerPoint, 1_000_000);
  assert.strictEqual(fit.buckets, 3);
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `npm run build --workspace @tokenmonitor/core && node --test packages/core/test/quotaEfficiency.test.cjs`
Expected: FAIL — `Cannot find module '../dist/cjs/quotaEfficiency.cjs'`.

- [ ] **Step 3: Write the implementation**

Create `packages/core/src/quotaEfficiency.ts`:

```ts
//
// Empirical tokens-per-quota-point, fitted from this machine's own token totals
// joined to the account's reported quota percentage.
//
// This is a CORRELATION, not a causal measurement, and it is honest about two
// specific ways it can be wrong:
//   - The account percentage covers every project and every machine on the
//     account, not just this one. Buckets where the percentage moved but this
//     machine logged no tokens are therefore excluded from the fit entirely and
//     reported as externalBuckets, so the number the UI shows is fitted only on
//     evidence this machine can actually explain.
//   - Below MIN_FIT_BUCKETS contributing buckets the fit is too thin to price
//     anything in dollars. ready:false is the signal to render quota POINTS only.
//

export const MIN_FIT_BUCKETS = 3;

export interface QuotaSample {
  atMs: number;
  /** The account's reported quota usage for the window, 0-100. */
  usedPercentage: number;
  /** Running token total for the same window on THIS machine, not a per-bucket delta. */
  tokens: number;
}

export interface QuotaFit {
  /** Tokens per one percentage point, or null when nothing could be fitted. */
  tokensPerPoint: number | null;
  /** Adjacent-sample pairs that contributed to the fit. */
  buckets: number;
  /** Pairs where the percentage moved but this machine logged no tokens. */
  externalBuckets: number;
  /** True once buckets >= MIN_FIT_BUCKETS: only then may a dollar figure be shown. */
  ready: boolean;
  /** Pairs where the window reset (percentage went down). Diagnostic only. */
  resets: number;
}

function isSample(x: unknown): x is QuotaSample {
  if (typeof x !== 'object' || x === null) return false;
  const s = x as Record<string, unknown>;
  return (
    typeof s.atMs === 'number' && Number.isFinite(s.atMs) &&
    typeof s.usedPercentage === 'number' && Number.isFinite(s.usedPercentage) &&
    typeof s.tokens === 'number' && Number.isFinite(s.tokens)
  );
}

export function fitTokensPerPoint(samples: QuotaSample[] | null | undefined): QuotaFit {
  const empty: QuotaFit = { tokensPerPoint: null, buckets: 0, externalBuckets: 0, ready: false, resets: 0 };
  if (!Array.isArray(samples)) return empty;
  const clean = samples.filter(isSample).sort((a, b) => a.atMs - b.atMs);
  if (clean.length < 2) return empty;

  let tokenTotal = 0;
  let pointTotal = 0;
  let buckets = 0;
  let externalBuckets = 0;
  let resets = 0;

  for (let i = 1; i < clean.length; i++) {
    const prev = clean[i - 1];
    const cur = clean[i];

    // Rule 1: a drop means the window reset. The work done since the reset is
    // the current percentage itself, not a negative delta.
    let pointDelta = cur.usedPercentage - prev.usedPercentage;
    if (pointDelta < 0) {
      resets += 1;
      pointDelta = cur.usedPercentage;
    }
    if (pointDelta <= 0) continue; // idle bucket: no quota moved, nothing to learn

    // Rule 2: the token figure is a rolling-window running total, so it can fall
    // when old events age out of the window. A fall is not negative work.
    const tokenDelta = cur.tokens - prev.tokens;
    if (tokenDelta < 0) continue;

    // Resolved decision: quota moved, this machine did nothing -> another project
    // or another machine on the same account. Excluded from the fit, surfaced.
    if (tokenDelta === 0) {
      externalBuckets += 1;
      continue;
    }

    tokenTotal += tokenDelta;
    pointTotal += pointDelta;
    buckets += 1;
  }

  if (buckets === 0 || pointTotal <= 0) {
    return { tokensPerPoint: null, buckets: 0, externalBuckets, ready: false, resets };
  }

  // Aggregate ratio, deliberately not a mean of per-bucket ratios: a bucket
  // carrying more work should weigh more, and a mean lets one tiny bucket with a
  // rounding-scale percentage delta dominate the whole estimate.
  return {
    tokensPerPoint: tokenTotal / pointTotal,
    buckets,
    externalBuckets,
    ready: buckets >= MIN_FIT_BUCKETS,
    resets,
  };
}
```

- [ ] **Step 4: Export it and run**

Add to `packages/core/src/index.ts`:

```ts
export * from './quotaEfficiency.js';
```

Run: `npm test --workspace @tokenmonitor/core`
Expected: PASS.

- [ ] **Step 5: Pin the bindings and run the root suite**

Add `'fitTokensPerPoint'` and `'MIN_FIT_BUCKETS'` to `test/coreContract.test.js`'s export list.
Run: `npm test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/core/src/quotaEfficiency.ts packages/core/src/index.ts packages/core/test/quotaEfficiency.test.cjs test/coreContract.test.js
git commit -m "feat: fit tokens-per-quota-point from account percentage deltas"
```

---
### Task 5: Plan price, persisted beside the plan-usage snapshot

**Files:**
- Create: `src/shared/planPriceConfig.js`
- Modify: `src/main/ipcHandlers.js` (add two handlers next to `budget:get`/`budget:set`, around line 145)
- Modify: `src/preload/preload.js:61-63` (extend the `plan` namespace)
- Modify: `src/main/main.js:60` (pass the new config path into `registerIpcHandlers`)
- Test: `test/planPriceConfig.test.js`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `DEFAULT_PLAN_PRICE = { monthlyUsd: 0 }` — 0 means "not set", which is distinct from "$0"
  - `PLAN_PRICE_PRESETS: Array<{ label: string, monthlyUsd: number }>`
  - `sanitizePlanPrice(raw): { monthlyUsd: number }`
  - `loadPlanPrice(configPath): Promise<{ monthlyUsd: number }>`
  - `savePlanPrice(configPath, price): Promise<void>`
  - IPC: `plan:getPrice` → `{ monthlyUsd }`, `plan:setPrice` (payload `{ monthlyUsd }`) → `{ monthlyUsd }`, `plan:pricePresets` → the preset array
  - Preload: `window.tokenTracker.plan.getPrice()`, `.setPrice(payload)`, `.pricePresets()`

The file lives at `~/.claude-token-tracker/planPrice.json`, beside `planUsage.json` (the location `src/main/main.js:42` already uses for the snapshot) — the spec's resolved "plan price location" decision.

- [ ] **Step 1: Write the failing test**

Create `test/planPriceConfig.test.js`, following the `test/planUsageConfig.test.js` tmpdir pattern:

```js
// test/planPriceConfig.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const fsp = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const {
  loadPlanPrice, savePlanPrice, sanitizePlanPrice, DEFAULT_PLAN_PRICE, PLAN_PRICE_PRESETS,
} = require('../src/shared/planPriceConfig');

async function tmpPath() {
  const dir = await fsp.mkdtemp(path.join(os.tmpdir(), 'ttprice-'));
  return path.join(dir, 'planPrice.json');
}

test('an unset price is 0, which is not the same as a $0 plan', () => {
  assert.deepStrictEqual(DEFAULT_PLAN_PRICE, { monthlyUsd: 0 });
});

test('round-trips a valid price; a missing file yields the default', async () => {
  const p = await tmpPath();
  assert.deepStrictEqual(await loadPlanPrice(p), { monthlyUsd: 0 });
  await savePlanPrice(p, { monthlyUsd: 200 });
  assert.deepStrictEqual(await loadPlanPrice(p), { monthlyUsd: 200 });
});

test('accepts fractional dollars and rounds to cents', () => {
  assert.deepStrictEqual(sanitizePlanPrice({ monthlyUsd: 19.994 }), { monthlyUsd: 19.99 });
  assert.deepStrictEqual(sanitizePlanPrice({ monthlyUsd: 19.996 }), { monthlyUsd: 20 });
});

test('rejects negative, non-finite, non-numeric and absurd values back to the default', () => {
  for (const bad of [-1, NaN, Infinity, '200', null, undefined, {}]) {
    assert.deepStrictEqual(sanitizePlanPrice({ monthlyUsd: bad }), { monthlyUsd: 0 }, 'monthlyUsd=' + String(bad));
  }
  // A price above the cap is a typo (an extra zero), not a plan. Clamp, don't trust.
  assert.deepStrictEqual(sanitizePlanPrice({ monthlyUsd: 1_000_000 }), { monthlyUsd: 10000 });
  assert.deepStrictEqual(sanitizePlanPrice(null), { monthlyUsd: 0 });
  assert.deepStrictEqual(sanitizePlanPrice('nope'), { monthlyUsd: 0 });
});

test('a corrupt file falls back to the default without clobbering the user file', async () => {
  const p = await tmpPath();
  await fsp.writeFile(p, 'not json', 'utf8');
  assert.deepStrictEqual(await loadPlanPrice(p), { monthlyUsd: 0 });
  assert.strictEqual(await fsp.readFile(p, 'utf8'), 'not json');
});

test('saving creates the parent directory on a fresh install', async () => {
  const dir = await fsp.mkdtemp(path.join(os.tmpdir(), 'ttprice-'));
  const p = path.join(dir, 'nested', 'planPrice.json');
  await savePlanPrice(p, { monthlyUsd: 100 });
  assert.deepStrictEqual(await loadPlanPrice(p), { monthlyUsd: 100 });
});

test('presets are labelled, positive, and ascending', () => {
  assert.ok(PLAN_PRICE_PRESETS.length >= 3);
  let prev = 0;
  for (const preset of PLAN_PRICE_PRESETS) {
    assert.strictEqual(typeof preset.label, 'string');
    assert.ok(preset.label.length > 0);
    assert.ok(preset.monthlyUsd > prev, preset.label + ' should be above ' + prev);
    prev = preset.monthlyUsd;
  }
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test test/planPriceConfig.test.js`
Expected: FAIL — `Cannot find module '../src/shared/planPriceConfig'`.

- [ ] **Step 3: Write the implementation**

Create `src/shared/planPriceConfig.js`:

```js
// src/shared/planPriceConfig.js
// The operator's monthly subscription price, persisted beside the /usage
// snapshot planUsageConfig.js writes (~/.claude-token-tracker/). This is the one
// number that turns quota points into the dollars the plan actually pays --
// everything else in the quota path is measured, this is declared.
//
// 0 means NOT SET, deliberately distinct from a real $0: quotaCost.ts returns a
// 0 $/point for it, and the budgets panel renders points instead of dollars.
const fsp = require('node:fs/promises');
const path = require('node:path');

const DEFAULT_PLAN_PRICE = { monthlyUsd: 0 };

// A price above this is a typo (an extra zero), not a plan. Clamping rather than
// rejecting keeps the user's intent -- they meant a big number -- while stopping a
// six-figure $/point from silently poisoning every figure on the dashboard.
const MAX_MONTHLY_USD = 10000;

// Convenience presets for the settings row. These are conveniences ONLY: the
// stored monthlyUsd is what every calculation uses, and the user can type any
// value. Published plan prices change; nothing here is treated as authoritative.
const PLAN_PRICE_PRESETS = [
  { label: 'Pro', monthlyUsd: 20 },
  { label: 'Max 5x', monthlyUsd: 100 },
  { label: 'Max 20x', monthlyUsd: 200 },
];

function sanitizePlanPrice(raw) {
  if (!raw || typeof raw !== 'object') return { ...DEFAULT_PLAN_PRICE };
  const value = raw.monthlyUsd;
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) return { ...DEFAULT_PLAN_PRICE };
  const clamped = Math.min(value, MAX_MONTHLY_USD);
  return { monthlyUsd: Math.round(clamped * 100) / 100 };
}

async function loadPlanPrice(configPath) {
  try {
    return sanitizePlanPrice(JSON.parse(await fsp.readFile(configPath, 'utf8')));
  } catch {
    // Missing OR malformed: return the default in memory and leave the file
    // alone. Overwriting a file we could not read is how a bug destroys a
    // setting the user actually made -- same discipline as budgetConfig.js:28-32.
    return { ...DEFAULT_PLAN_PRICE };
  }
}

async function savePlanPrice(configPath, price) {
  const clean = sanitizePlanPrice(price);
  await fsp.mkdir(path.dirname(configPath), { recursive: true });
  await fsp.writeFile(configPath, JSON.stringify(clean, null, 2), 'utf8');
}

module.exports = { DEFAULT_PLAN_PRICE, PLAN_PRICE_PRESETS, MAX_MONTHLY_USD, sanitizePlanPrice, loadPlanPrice, savePlanPrice };
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `node --test test/planPriceConfig.test.js`
Expected: PASS, 7 tests.

- [ ] **Step 5: Wire the IPC handlers**

In `src/main/ipcHandlers.js`, add to the top-of-file requires (next to the `budgetConfig` require on line 15):

```js
const { loadPlanPrice, savePlanPrice, PLAN_PRICE_PRESETS } = require('../shared/planPriceConfig');
```

Add `planPriceConfigPath` to the `registerIpcHandlers({ ... })` destructured parameter list, and register the handlers immediately after the `budget:deriveFromMonthly` handler:

```js
  ipcMain.handle('plan:getPrice', () => loadPlanPrice(planPriceConfigPath));
  ipcMain.handle('plan:setPrice', async (_event, payload) => {
    await savePlanPrice(planPriceConfigPath, payload);
    return loadPlanPrice(planPriceConfigPath);
  });
  ipcMain.handle('plan:pricePresets', () => PLAN_PRICE_PRESETS);
```

In `src/main/main.js`, add to the `registerIpcHandlers({ ... })` call that begins at line 62:

```js
    planPriceConfigPath: path.join(os.homedir(), '.claude-token-tracker', 'planPrice.json'),
```

In `src/preload/preload.js`, replace the `plan` namespace (lines 61-63) with:

```js
  plan: {
    sync: () => ipcRenderer.invoke('plan:sync'),
    getPrice: () => ipcRenderer.invoke('plan:getPrice'),
    setPrice: (payload) => ipcRenderer.invoke('plan:setPrice', payload),
    pricePresets: () => ipcRenderer.invoke('plan:pricePresets'),
  },
```

- [ ] **Step 6: Pin the preload surface with a source-text test**

Append to `test/planPriceConfig.test.js`:

```js
const fs = require('node:fs');

test('the preload bridge exposes the plan-price channels the settings row calls', () => {
  const src = fs.readFileSync(path.join(__dirname, '..', 'src', 'preload', 'preload.js'), 'utf8');
  for (const channel of ['plan:getPrice', 'plan:setPrice', 'plan:pricePresets']) {
    assert.ok(src.includes(channel), 'preload.js does not expose ' + channel);
  }
});

test('the main process registers those channels', () => {
  const src = fs.readFileSync(path.join(__dirname, '..', 'src', 'main', 'ipcHandlers.js'), 'utf8');
  for (const channel of ['plan:getPrice', 'plan:setPrice', 'plan:pricePresets']) {
    assert.ok(src.includes("'" + channel + "'"), 'ipcHandlers.js does not handle ' + channel);
  }
  const mainSrc = fs.readFileSync(path.join(__dirname, '..', 'src', 'main', 'main.js'), 'utf8');
  assert.ok(/planPriceConfigPath/.test(mainSrc), 'main.js does not pass planPriceConfigPath');
});
```

- [ ] **Step 7: Run the full suite**

Run: `npm test`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add src/shared/planPriceConfig.js test/planPriceConfig.test.js src/main/ipcHandlers.js src/main/main.js src/preload/preload.js
git commit -m "feat: persist the monthly plan price beside the plan-usage snapshot"
```

---

### Task 6: The plan-price row in the settings popover

**Files:**
- Modify: `src/renderer/index.html` (insert after the `budget-save-row` div, before the divider preceding "Panels" — currently lines 41-45)
- Modify: `src/renderer/dashboard/panels/settingsPanel.js` (add `mountPlanPriceRow`, call it from `mountSettings` at line 300+)
- Modify: `src/renderer/styles/tokens.css`
- Test: `test/planPriceRow.test.js`

**Interfaces:**
- Consumes: `window.tokenTracker.plan.getPrice()`, `.setPrice({ monthlyUsd })`, `.pricePresets()` (Task 5).
- Produces: nothing importable — the row's only contract is the element ids `plan-price-input`, `plan-price-presets`, `plan-price-save`, asserted by the test.

- [ ] **Step 1: Write the failing test**

Create `test/planPriceRow.test.js` (source-text style, matching `test/settingsPalettes.test.js` and `test/budgetAlarmUnification.test.js` — renderer scripts are classic `<script>`s and cannot be required):

```js
// test/planPriceRow.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const read = (...p) => fs.readFileSync(path.join(__dirname, '..', ...p), 'utf8');

test('the settings popover carries the plan-price row markup', () => {
  const html = read('src', 'renderer', 'index.html');
  assert.ok(html.includes('id="plan-price-input"'), 'no plan-price input');
  assert.ok(html.includes('id="plan-price-presets"'), 'no plan-price presets container');
  assert.ok(html.includes('id="plan-price-save"'), 'no plan-price save button');
});

test('settingsPanel.js mounts the plan-price row and persists through the IPC bridge', () => {
  const js = read('src', 'renderer', 'dashboard', 'panels', 'settingsPanel.js');
  assert.ok(/function mountPlanPriceRow/.test(js), 'no mountPlanPriceRow');
  assert.ok(/mountPlanPriceRow\(\)/.test(js), 'mountPlanPriceRow is never called');
  assert.ok(/window\.tokenTracker\.plan\.getPrice\(\)/.test(js), 'never reads the persisted price');
  assert.ok(/window\.tokenTracker\.plan\.setPrice\(/.test(js), 'never writes the price');
});

// The renderer must not carry its own copy of the price rules -- planPriceConfig.js
// sanitizes on the way in, and a second clamp here would drift away from it.
test('settingsPanel.js does not hardcode a price cap or a preset table', () => {
  const js = read('src', 'renderer', 'dashboard', 'panels', 'settingsPanel.js');
  assert.ok(!/10000/.test(js.split('function mountPlanPriceRow')[1] || ''), 'MAX_MONTHLY_USD duplicated in the renderer');
  assert.ok(/plan\.pricePresets\(\)/.test(js), 'presets should come from IPC, not a renderer literal');
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test test/planPriceRow.test.js`
Expected: FAIL — `no plan-price input`.

- [ ] **Step 3: Add the markup**

In `src/renderer/index.html`, insert immediately after the `<div class="budget-save-row">…</div>` block (currently ending at line 44) and before the `<div class="settings-divider"></div>` that precedes "Panels":

```html
        <div class="settings-divider"></div>
        <div class="hero-label mb-2">Plan price (monthly USD)</div>
        <div class="plan-price-row">
          <span class="plan-price-prefix">$</span>
          <input type="number" id="plan-price-input" min="0" step="1" inputmode="decimal" aria-label="Monthly plan price in US dollars">
          <button type="button" id="plan-price-save">Save</button>
        </div>
        <div id="plan-price-presets" class="plan-price-presets"></div>
        <div class="plan-price-hint">Turns quota points into the dollars your plan actually pays. Leave at 0 to show quota points only.</div>
```

- [ ] **Step 4: Add the mount function**

In `src/renderer/dashboard/panels/settingsPanel.js`, add before `mountSettings` (currently line 300):

```js
// Plan price row. The renderer holds NO validation of its own: planPriceConfig.js
// sanitizes and clamps on the way in, and setPrice returns the persisted value,
// so the input is always re-rendered from what was actually stored rather than
// from what was typed. A second copy of the rules here would drift.
function mountPlanPriceRow() {
  const input = document.getElementById('plan-price-input');
  const saveBtn = document.getElementById('plan-price-save');
  const presetBox = document.getElementById('plan-price-presets');
  if (!input || !saveBtn || !presetBox || !window.tokenTracker || !window.tokenTracker.plan) return;

  const show = (price) => { input.value = price && price.monthlyUsd ? String(price.monthlyUsd) : '0'; };

  const persist = async (monthlyUsd) => {
    try {
      show(await window.tokenTracker.plan.setPrice({ monthlyUsd }));
      const state = await window.tokenTracker.dashboard.getState();
      if (window.TT.renderDashboard) window.TT.renderDashboard(state);
    } catch (err) {
      // Persist failed -- re-read so the field can never show a value that was
      // never stored, the same recovery saveAlertsPartial does.
      try { show(await window.tokenTracker.plan.getPrice()); } catch (e) { /* leave as-is */ }
    }
  };

  window.tokenTracker.plan.getPrice().then(show).catch(() => {});

  window.tokenTracker.plan.pricePresets().then((presets) => {
    presetBox.innerHTML = (presets || [])
      .map((p) => `<button type="button" class="plan-price-preset" data-usd="${p.monthlyUsd}">${escapeHtml(p.label)} $${p.monthlyUsd}</button>`)
      .join('');
  }).catch(() => {});

  presetBox.addEventListener('click', (e) => {
    const btn = e.target.closest('.plan-price-preset');
    if (btn) persist(Number(btn.dataset.usd));
  });

  saveBtn.addEventListener('click', () => persist(Number(input.value)));
}
```

Then call it from `mountSettings`, beside the existing `mountAlertsSection()` call:

```js
  mountPlanPriceRow();
```

- [ ] **Step 5: Add the styles**

Append to `src/renderer/styles/tokens.css`:

```css
.plan-price-row { display: flex; align-items: center; gap: 6px; margin-bottom: 6px; }
.plan-price-prefix { color: var(--tx-dim); }
.plan-price-row input { flex: 1; min-width: 0; }
.plan-price-presets { display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 6px; }
.plan-price-hint { color: var(--tx-muted); font-size: 11px; line-height: 1.4; }
```

If `test/inlineStyles.test.js` or `test/contrast.test.js` objects to a token name used here, use the neighbouring names those tests already accept rather than inventing new ones — read the failing assertion, do not add an exception.

- [ ] **Step 6: Run the tests**

Run: `npm test`
Expected: PASS.

- [ ] **Step 7: Verify it in the real app**

Run: `npm start`
Open Settings, type `200`, press Save, close and reopen Settings.
Expected: the field still reads `200`. Then check `~/.claude-token-tracker/planPrice.json` contains `{"monthlyUsd": 200}`. Confidence is not evidence — read the file.

- [ ] **Step 8: Commit**

```bash
git add src/renderer/index.html src/renderer/dashboard/panels/settingsPanel.js src/renderer/styles/tokens.css test/planPriceRow.test.js
git commit -m "feat: enter the monthly plan price from Settings"
```

---

### Task 7: The statusline payload parser

**Files:**
- Create: `src/shared/statuslinePayload.js`
- Test: `test/statuslinePayload.test.js`

**Interfaces:**
- Consumes: nothing.
- Produces: `parseStatuslinePayload(raw, capturedAtMs)` returning
  `{ capturedAtMs, sessionId, modelId, modelDisplayName, fiveHour, sevenDay, contextUsedPercentage, contextWindowSize, contextUsage, totalCostUsd, currentDir, projectDir }`
  or `null` when `raw` is not a non-null, non-array object. Each rate-limit window is `{ usedPercentage, resetsAtMs }` or `null`.

Ported from aether-os `src/shared/statuslinePayload.ts` (188 lines). Adaptations: TypeScript types dropped, CommonJS `module.exports`. The parsing behaviour is unchanged, including the two properties that matter most: `resets_at` is in **seconds** and is converted to milliseconds, and a `current_usage: null` must produce `contextUsage: null` rather than a zeroed object — "no data" and "zero tokens" are different states.

- [ ] **Step 1: Write the failing test**

Create `test/statuslinePayload.test.js`:

```js
// test/statuslinePayload.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const { parseStatuslinePayload } = require('../src/shared/statuslinePayload');

const FULL = {
  session_id: 'sess-1',
  model: { id: 'model-x', display_name: 'Opus 5' },
  rate_limits: {
    five_hour: { used_percentage: 46, resets_at: 1_760_000_000 },
    seven_day: { used_percentage: 18, resets_at: 1_760_400_000 },
  },
  context_window: {
    used_percentage: 33,
    context_window_size: 200000,
    current_usage: { input_tokens: 10, output_tokens: 20, cache_creation_input_tokens: 30, cache_read_input_tokens: 40 },
  },
  cost: { total_cost_usd: 1.23 },
  workspace: { current_dir: 'C:\\repo', project_dir: 'C:\\repo' },
};

test('parses a full payload, converting resets_at from seconds to milliseconds', () => {
  const s = parseStatuslinePayload(FULL, 999);
  assert.strictEqual(s.capturedAtMs, 999);
  assert.strictEqual(s.sessionId, 'sess-1');
  assert.strictEqual(s.modelDisplayName, 'Opus 5');
  assert.deepStrictEqual(s.sevenDay, { usedPercentage: 18, resetsAtMs: 1_760_400_000_000 });
  assert.deepStrictEqual(s.fiveHour, { usedPercentage: 46, resetsAtMs: 1_760_000_000_000 });
  assert.strictEqual(s.contextUsedPercentage, 33);
  assert.strictEqual(s.contextWindowSize, 200000);
  assert.deepStrictEqual(s.contextUsage, { inputTokens: 10, outputTokens: 20, cacheCreationInputTokens: 30, cacheReadInputTokens: 40 });
  assert.strictEqual(s.totalCostUsd, 1.23);
  assert.strictEqual(s.currentDir, 'C:\\repo');
});

test('returns null only for a non-object payload', () => {
  for (const bad of [null, undefined, 'x', 7, []]) assert.strictEqual(parseStatuslinePayload(bad, 1), null);
  assert.notStrictEqual(parseStatuslinePayload({}, 1), null);
});

// Claude Code's payload shape has changed across versions and will change again.
// A parser that hard-fails on one unexpected field takes the whole feature down.
test('every field is independently optional', () => {
  const s = parseStatuslinePayload({}, 5);
  assert.deepStrictEqual(s, {
    capturedAtMs: 5, sessionId: null, modelId: null, modelDisplayName: null,
    fiveHour: null, sevenDay: null, contextUsedPercentage: null,
    contextWindowSize: null, contextUsage: null, totalCostUsd: null,
    currentDir: null, projectDir: null,
  });
});

test('a rate-limit window missing either half is null, not half-filled', () => {
  const noReset = parseStatuslinePayload({ rate_limits: { seven_day: { used_percentage: 18 } } }, 1);
  assert.strictEqual(noReset.sevenDay, null);
  const noPct = parseStatuslinePayload({ rate_limits: { seven_day: { resets_at: 1 } } }, 1);
  assert.strictEqual(noPct.sevenDay, null);
  const nonFinite = parseStatuslinePayload({ rate_limits: { seven_day: { used_percentage: NaN, resets_at: 1 } } }, 1);
  assert.strictEqual(nonFinite.sevenDay, null);
});

// "No data yet" (before the first API call, and right after /compact) must not
// render as "zero tokens used".
test('current_usage: null yields contextUsage: null, not a zeroed object', () => {
  const s = parseStatuslinePayload({ context_window: { used_percentage: 0, current_usage: null } }, 1);
  assert.strictEqual(s.contextUsage, null);
  assert.strictEqual(s.contextUsedPercentage, 0);
});

test('a partial current_usage is rejected wholesale', () => {
  const s = parseStatuslinePayload({ context_window: { current_usage: { input_tokens: 1 } } }, 1);
  assert.strictEqual(s.contextUsage, null);
});

test('never throws on hostile input', () => {
  const hostile = { rate_limits: 'nope', model: 7, context_window: [], cost: null, workspace: { current_dir: 42 } };
  const s = parseStatuslinePayload(hostile, 1);
  assert.strictEqual(s.sevenDay, null);
  assert.strictEqual(s.modelId, null);
  assert.strictEqual(s.currentDir, null);
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test test/statuslinePayload.test.js`
Expected: FAIL — `Cannot find module '../src/shared/statuslinePayload'`.

- [ ] **Step 3: Write the implementation**

Create `src/shared/statuslinePayload.js` — aether-os's parser, CommonJS, types dropped:

```js
// src/shared/statuslinePayload.js
// Defensive parser for Claude Code's statusLine JSON payload. Ported from
// aether-os's src/shared/statuslinePayload.ts; behaviour unchanged, types dropped,
// CommonJS to match the rest of src/shared.
//
// This receives whatever JSON.parse produced and must never throw. It returns null
// only when raw is not a non-null, non-array object. Every individual field is
// independently optional -- a payload with no rate_limits at all still yields a
// valid snapshot with fiveHour: null and sevenDay: null. Claude Code's payload
// shape has changed across versions and will change again; a parser that
// hard-fails on one unexpected field takes the whole feature down.

function parseRateLimitWindow(obj) {
  if (typeof obj !== 'object' || obj === null) return null;
  const usedPercentage = obj.used_percentage;
  const resetsAt = obj.resets_at;
  // Only produce a window when BOTH halves are finite numbers -- a half-filled
  // window would render as a real reading with a nonsense reset time.
  if (typeof usedPercentage === 'number' && Number.isFinite(usedPercentage) &&
      typeof resetsAt === 'number' && Number.isFinite(resetsAt)) {
    return { usedPercentage, resetsAtMs: resetsAt * 1000 }; // payload is in SECONDS
  }
  return null;
}

function parseContextWindowUsage(obj) {
  if (typeof obj !== 'object' || obj === null) return null;
  const { input_tokens, output_tokens, cache_creation_input_tokens, cache_read_input_tokens } = obj;
  if (typeof input_tokens === 'number' && typeof output_tokens === 'number' &&
      typeof cache_creation_input_tokens === 'number' && typeof cache_read_input_tokens === 'number') {
    return {
      inputTokens: input_tokens,
      outputTokens: output_tokens,
      cacheCreationInputTokens: cache_creation_input_tokens,
      cacheReadInputTokens: cache_read_input_tokens,
    };
  }
  return null;
}

function finiteOrNull(v) {
  return typeof v === 'number' && Number.isFinite(v) ? v : null;
}

function stringOrNull(v) {
  return typeof v === 'string' ? v : null;
}

function objectOrNull(v) {
  return typeof v === 'object' && v !== null && !Array.isArray(v) ? v : null;
}

function parseStatuslinePayload(raw, capturedAtMs) {
  const payload = objectOrNull(raw);
  if (!payload) return null;

  const rateLimits = objectOrNull(payload.rate_limits) || {};
  const contextWindow = objectOrNull(payload.context_window) || {};
  const model = objectOrNull(payload.model) || {};
  const cost = objectOrNull(payload.cost) || {};
  const workspace = objectOrNull(payload.workspace) || {};

  // current_usage: null must produce null, NOT a zeroed object -- "no data yet"
  // (before the first API call, and right after /compact) and "zero tokens used"
  // are different states and must never render the same way.
  const currentUsage = contextWindow.current_usage;
  const contextUsage = currentUsage !== null && typeof currentUsage === 'object'
    ? parseContextWindowUsage(currentUsage)
    : null;

  return {
    capturedAtMs,
    sessionId: stringOrNull(payload.session_id),
    modelId: stringOrNull(model.id),
    modelDisplayName: stringOrNull(model.display_name),
    fiveHour: parseRateLimitWindow(rateLimits.five_hour),
    sevenDay: parseRateLimitWindow(rateLimits.seven_day),
    contextUsedPercentage: finiteOrNull(contextWindow.used_percentage),
    contextWindowSize: finiteOrNull(contextWindow.context_window_size),
    contextUsage,
    totalCostUsd: finiteOrNull(cost.total_cost_usd),
    currentDir: stringOrNull(workspace.current_dir),
    projectDir: stringOrNull(workspace.project_dir),
  };
}

module.exports = { parseStatuslinePayload };
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `node --test test/statuslinePayload.test.js`
Expected: PASS, 7 tests.

- [ ] **Step 5: Run the full suite and commit**

Run: `npm test`
Expected: PASS.

```bash
git add src/shared/statuslinePayload.js test/statuslinePayload.test.js
git commit -m "feat: parse Claude Code's statusline payload"
```

---

### Task 8: The statusline hook script

**Files:**
- Create: `scripts/tokenmonitor-statusline.mjs`
- Test: `test/statuslineScript.test.js`

**Interfaces:**
- Consumes: nothing at build time. At runtime it reads Claude Code's payload on stdin.
- Produces: writes `~/.claude-token-tracker/statusline.json` atomically (tmp + rename) with the raw payload plus a `capturedAtMs` stamp; prints one status line to stdout. Task 12's watcher reads that file; Task 9's installer references this script path.

**Hard contract (Global Constraints):** never throws, never exits non-zero, never writes to stderr, under any input. Node builtins only — it is executed by Claude Code from an arbitrary working directory with no relationship to this repo's module resolution, so a relative import from `src/` would fail at runtime in a way no test here would catch.

- [ ] **Step 1: Write the failing test**

Create `test/statuslineScript.test.js`:

```js
// test/statuslineScript.test.js
// Spawns the real script as a child process, exactly the way Claude Code does,
// because its contract IS its process behaviour: exit code, stderr, and stdout.
const test = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fsp = require('node:fs/promises');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const SCRIPT = path.join(__dirname, '..', 'scripts', 'tokenmonitor-statusline.mjs');

function runScript(stdin, { home, args = [] } = {}) {
  return spawnSync(process.execPath, [SCRIPT, ...args], {
    input: stdin,
    encoding: 'utf8',
    env: { ...process.env, USERPROFILE: home, HOME: home },
  });
}

async function tmpHome() {
  return fsp.mkdtemp(path.join(os.tmpdir(), 'ttsl-'));
}

const PAYLOAD = {
  model: { display_name: 'Opus 5' },
  rate_limits: { five_hour: { used_percentage: 46, resets_at: 1 }, seven_day: { used_percentage: 18, resets_at: 2 } },
  context_window: { used_percentage: 33 },
};

test('prints a line, exits 0, and writes nothing to stderr for a good payload', async () => {
  const home = await tmpHome();
  const r = runScript(JSON.stringify(PAYLOAD), { home });
  assert.strictEqual(r.status, 0);
  assert.strictEqual(r.stderr, '');
  assert.match(r.stdout, /Opus 5/);
  assert.match(r.stdout, /5h 46%/);
  assert.match(r.stdout, /7d 18%/);
});

test('persists the raw payload plus a capturedAtMs stamp', async () => {
  const home = await tmpHome();
  const before = Date.now();
  runScript(JSON.stringify(PAYLOAD), { home });
  const target = path.join(home, '.claude-token-tracker', 'statusline.json');
  const saved = JSON.parse(fs.readFileSync(target, 'utf8'));
  assert.deepStrictEqual(saved.rate_limits, PAYLOAD.rate_limits);
  assert.ok(saved.capturedAtMs >= before);
  // The atomic-write temp file must not survive the rename.
  assert.strictEqual(fs.existsSync(target + '.tmp'), false);
});

// The hard contract: this runs inside the user's live coding session.
test('never throws, never exits non-zero, never touches stderr, on any input', async () => {
  const home = await tmpHome();
  for (const input of ['', 'not json', '[]', 'null', '7', '{"rate_limits":"nope"}', '{'.repeat(500)]) {
    const r = runScript(input, { home });
    assert.strictEqual(r.status, 0, 'nonzero exit for input: ' + input.slice(0, 20));
    assert.strictEqual(r.stderr, '', 'stderr for input: ' + input.slice(0, 20));
    assert.ok(r.stdout.trim().length > 0, 'empty stdout for input: ' + input.slice(0, 20));
  }
});

test('an unwritable payload directory still prints a line and exits 0', async () => {
  const home = await tmpHome();
  // Occupy the target directory path with a FILE so mkdirSync must fail.
  await fsp.writeFile(path.join(home, '.claude-token-tracker'), 'blocker', 'utf8');
  const r = runScript(JSON.stringify(PAYLOAD), { home });
  assert.strictEqual(r.status, 0);
  assert.strictEqual(r.stderr, '');
  assert.match(r.stdout, /Opus 5/);
});

test('a chained command takes over the printed line, and capture still happens', async () => {
  const home = await tmpHome();
  const chain = Buffer.from('node -e "process.stdout.write(\'OTHER TOOL\')"', 'utf8').toString('base64');
  const r = runScript(JSON.stringify(PAYLOAD), { home, args: ['--chain', chain] });
  assert.strictEqual(r.status, 0);
  assert.match(r.stdout, /OTHER TOOL/);
  assert.ok(!/Opus 5/.test(r.stdout), 'our own line should not also print');
  // Capture is a side effect and must happen regardless of who prints.
  const saved = JSON.parse(fs.readFileSync(path.join(home, '.claude-token-tracker', 'statusline.json'), 'utf8'));
  assert.deepStrictEqual(saved.rate_limits, PAYLOAD.rate_limits);
});

test('a failing chained command falls back to our own line rather than printing nothing', async () => {
  const home = await tmpHome();
  const chain = Buffer.from('node -e "process.exit(3)"', 'utf8').toString('base64');
  const r = runScript(JSON.stringify(PAYLOAD), { home, args: ['--chain', chain] });
  assert.strictEqual(r.status, 0);
  assert.match(r.stdout, /Opus 5/);
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test test/statuslineScript.test.js`
Expected: FAIL — every test, `Cannot find module .../scripts/tokenmonitor-statusline.mjs`.

- [ ] **Step 3: Write the script**

Create `scripts/tokenmonitor-statusline.mjs`:

```js
#!/usr/bin/env node
// TokenMonitor statusline feed.
//
// Installed as Claude Code's `statusLine` command by src/main/statuslineInstaller.js.
// Claude Code invokes it on every turn with a JSON payload on stdin and prints
// whatever this script writes to stdout as the terminal status line.
//
// HARD REQUIREMENT: this must never throw, never exit non-zero, and never write to
// stderr, under any input whatsoever -- a bug here degrades the user's live coding
// session, not just this app. Every step that can fail is individually guarded so a
// problem in one stage (e.g. the file write) cannot prevent the fallback stdout line
// from being printed.
//
// Node builtins only -- no imports from src/, and no npm dependencies. Claude Code
// executes this from an arbitrary working directory with no relationship to this
// repo's module resolution, so a relative import would fail at runtime in a way no
// test here would catch.
//
// Ported from aether-os's scripts/aether-statusline.mjs. Two adaptations: the
// payload lands in ~/.claude-token-tracker/ (beside planUsage.json), and the line
// carries the SEVEN-day window as well as the five-hour one, because the seven-day
// window is the basis for every dollar figure this app renders.

import { readFileSync, mkdirSync, writeFileSync, renameSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { spawnSync } from 'node:child_process';
import process from 'node:process';

const FALLBACK_LINE = 'Token Tracker';
const MAX_LINE_LENGTH = 60;
const MIDDLE_DOT = '\u00b7';
const CHAIN_TIMEOUT_MS = 5000;

/** Reads all of stdin synchronously. Returns '' on any failure rather than throwing. */
function readStdin() {
  try {
    return readFileSync(0, 'utf8');
  } catch {
    return '';
  }
}

/** Parses stdin text into a plain object, or null on any failure / non-object result. */
function parsePayload(raw) {
  try {
    if (typeof raw !== 'string' || raw.trim().length === 0) return null;
    const parsed = JSON.parse(raw);
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) return null;
    return parsed;
  } catch {
    return null;
  }
}

function safePercentage(value) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return null;
  return Math.max(0, Math.min(100, Math.round(value)));
}

function windowPct(rateLimits, key) {
  if (rateLimits === null || typeof rateLimits !== 'object') return null;
  const window = rateLimits[key];
  if (window === null || typeof window !== 'object') return null;
  return safePercentage(window.used_percentage);
}

/** Builds the human-readable line. Any missing/malformed field is simply omitted. */
function buildStatusLine(payload) {
  try {
    const parts = [];
    const model = payload && typeof payload.model === 'object' ? payload.model : null;
    parts.push((model && typeof model.display_name === 'string' && model.display_name) || 'Claude');

    const rateLimits = payload && typeof payload.rate_limits === 'object' ? payload.rate_limits : null;
    const fiveHourPct = windowPct(rateLimits, 'five_hour');
    if (fiveHourPct !== null) parts.push('5h ' + fiveHourPct + '%');
    const sevenDayPct = windowPct(rateLimits, 'seven_day');
    if (sevenDayPct !== null) parts.push('7d ' + sevenDayPct + '%');

    const contextWindow = payload && typeof payload.context_window === 'object' ? payload.context_window : null;
    const ctxPct = contextWindow ? safePercentage(contextWindow.used_percentage) : null;
    if (ctxPct !== null) parts.push('ctx ' + ctxPct + '%');

    const line = parts.join(' ' + MIDDLE_DOT + ' ');
    if (line.length === 0) return FALLBACK_LINE;
    return line.length > MAX_LINE_LENGTH ? line.slice(0, MAX_LINE_LENGTH) : line;
  } catch {
    return FALLBACK_LINE;
  }
}

/** Atomically persists the payload for the app's file watcher: write .tmp, then
 *  rename over the target. A direct write would let the watcher observe a
 *  truncated file mid-write; rename is atomic on the same filesystem. Any failure
 *  is swallowed -- it must never prevent the stdout line from printing. */
function persistSnapshot(payload) {
  try {
    const dir = join(homedir(), '.claude-token-tracker');
    mkdirSync(dir, { recursive: true });
    const targetPath = join(dir, 'statusline.json');
    const tmpPath = targetPath + '.tmp';
    writeFileSync(tmpPath, JSON.stringify({ ...payload, capturedAtMs: Date.now() }), 'utf8');
    renameSync(tmpPath, targetPath);
  } catch {
    // Intentionally swallowed. The watcher simply won't see an update.
  }
}

/** Decodes the `--chain <base64>` argument the installer embeds when another
 *  statusLine command was already configured. Returns null when absent or
 *  undecodable -- never throws. */
function parseChainArg(argv) {
  const idx = argv.indexOf('--chain');
  if (idx === -1 || idx + 1 >= argv.length) return null;
  try {
    const decoded = Buffer.from(argv[idx + 1], 'base64').toString('utf8');
    return decoded.length > 0 ? decoded : null;
  } catch {
    return null;
  }
}

/** Runs whatever statusLine command was configured before this script was
 *  installed, feeding it the exact stdin Claude Code gave us, and returns its
 *  trimmed stdout -- or null on any failure. Bounded by CHAIN_TIMEOUT_MS so a hung
 *  chained command can never hang the user's statusline render. */
function runChainedCommand(command, rawStdin) {
  try {
    const result = spawnSync(command, { input: rawStdin, shell: true, encoding: 'utf8', timeout: CHAIN_TIMEOUT_MS });
    if (result.error || result.status !== 0) return null;
    const out = typeof result.stdout === 'string' ? result.stdout.trim() : '';
    return out.length > 0 ? out : null;
  } catch {
    return null;
  }
}

function main() {
  const raw = readStdin();
  const payload = parsePayload(raw);

  if (payload === null) {
    process.stdout.write(FALLBACK_LINE + '\n');
    return;
  }

  persistSnapshot(payload);

  const chainCommand = parseChainArg(process.argv.slice(2));
  if (chainCommand) {
    const chainedLine = runChainedCommand(chainCommand, raw);
    if (chainedLine !== null) {
      // Print the chained tool's line verbatim -- our payload capture above
      // already happened as a side effect, invisible to the user's terminal.
      process.stdout.write(chainedLine + '\n');
      return;
    }
    // Chained command failed, timed out, or printed nothing -- fall through to our
    // own line so the statusline never goes blank.
  }

  process.stdout.write(buildStatusLine(payload) + '\n');
}

try {
  main();
} catch {
  // Absolute last resort: something above threw despite every internal guard.
  try {
    process.stdout.write(FALLBACK_LINE + '\n');
  } catch {
    // Nothing further can be done; exit cleanly regardless.
  }
}

// No explicit process.exit(0): on POSIX, process.exit() does not flush pending
// async writes to a piped stdout, and nothing else is left on the event loop after
// main() returns -- so the process exits 0 on its own. An explicit exit here buys
// nothing and is a truncation hazard.
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `node --test test/statuslineScript.test.js`
Expected: PASS, 6 tests.

If the "unwritable payload directory" test does not actually fail the write on your platform, do not delete it — change the blocker to a read-only directory, or `assert` on the file's absence instead. The property under test is that a write failure never reaches stdout or the exit code, and it must be genuinely exercised.

- [ ] **Step 5: Confirm the new script does not trip the zero-API-cost guard**

Run: `node --test test/noApiCalls.test.js`
Expected: PASS. `scripts/` is one of the guard's `ROOTS`, and this script uses `spawnSync` with `shell: true` — legitimate (it runs a *local* command the user already had configured), and none of the guard's five patterns match it. If a later change adds a model-ID literal or an HTTP call here, the guard will say so.

- [ ] **Step 6: Commit**

```bash
git add scripts/tokenmonitor-statusline.mjs test/statuslineScript.test.js
git commit -m "feat: statusline hook that captures the quota payload on every turn"
```

---

### Task 9: The statusline installer

**Files:**
- Create: `src/main/statuslineInstaller.js`
- Test: `test/statuslineInstaller.test.js`

**Interfaces:**
- Consumes: the script path from Task 8 (`scripts/tokenmonitor-statusline.mjs`), passed in as an argument — this module never resolves it itself.
- Produces:
  - `statuslineSettingsPatch(scriptPath, chainCommand?): { statusLine: { type: 'command', command: string } }`
  - `extractChainedCommand(command: string | null): string | null`
  - `detectInstallStatus(settingsJson, scriptPath): { status: 'installed'|'installed-other'|'not-installed'|'unreadable', existingCommand: string | null }`
  - `readInstallState(settingsPath, scriptPath): Promise<{ status, existingCommand, settingsPath, scriptPath }>`
  - `installStatusline(settingsPath, scriptPath): Promise<{ ok, backupPath?, error? }>`
  - `uninstallStatusline(settingsPath, scriptPath): Promise<{ ok, backupPath?, error? }>`

Ported from aether-os `electron/statuslineInstaller.ts` (260 lines). Adaptations: CommonJS, TypeScript types dropped, backup/temp suffixes renamed `.ttbak-`/`.tttmp-`.

**The three properties that make this safe, all carried over unchanged:**
1. **Chain, never clobber.** A foreign `statusLine` command is base64-encoded into a `--chain` argument and keeps rendering. This is what lets TokenMonitor and aether-os coexist on the same machine.
2. **A parse failure aborts.** If `settings.json` exists but cannot be parsed, nothing is written — not a backup, not a merge. Overwriting a config we could not read back is destructive.
3. **Backup then atomic write.** The exact original bytes are copied to a timestamped `.ttbak-` file, and the new content lands via write-tmp-then-rename so the target is never observably partial.

- [ ] **Step 1: Write the failing test**

Create `test/statuslineInstaller.test.js`:

```js
// test/statuslineInstaller.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const fsp = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const {
  statuslineSettingsPatch, extractChainedCommand, detectInstallStatus,
  readInstallState, installStatusline, uninstallStatusline,
} = require('../src/main/statuslineInstaller');

const SCRIPT = 'C:\\repo\\scripts\\tokenmonitor-statusline.mjs';

async function tmpSettings(contents) {
  const dir = await fsp.mkdtemp(path.join(os.tmpdir(), 'ttinst-'));
  const p = path.join(dir, 'settings.json');
  if (contents !== undefined) await fsp.writeFile(p, contents, 'utf8');
  return p;
}

const readJson = async (p) => JSON.parse(await fsp.readFile(p, 'utf8'));

test('the patch quotes the script path so spaces survive shell invocation', () => {
  assert.deepStrictEqual(statuslineSettingsPatch(SCRIPT), {
    statusLine: { type: 'command', command: 'node "' + SCRIPT + '"' },
  });
});

// The chained command is itself an arbitrary shell command that may contain its
// own quotes; nesting those inside settings.json's command string is a quoting
// hazard. Base64 sidesteps it entirely.
test('a chained command is base64-encoded, not embedded as literal text', () => {
  const chain = 'powershell -File "C:\\a b\\x.ps1"';
  const { statusLine } = statuslineSettingsPatch(SCRIPT, chain);
  assert.ok(!statusLine.command.includes('powershell'));
  assert.strictEqual(extractChainedCommand(statusLine.command), chain);
});

test('extractChainedCommand returns null for a foreign or chainless command', () => {
  assert.strictEqual(extractChainedCommand(null), null);
  assert.strictEqual(extractChainedCommand('some-other-tool'), null);
  assert.strictEqual(extractChainedCommand('node "' + SCRIPT + '"'), null);
  assert.strictEqual(extractChainedCommand('node "x" --chain !!!notbase64!!!'), null);
});

test('detectInstallStatus classifies all four states', () => {
  assert.strictEqual(detectInstallStatus({}, SCRIPT).status, 'not-installed');
  assert.strictEqual(detectInstallStatus(null, SCRIPT).status, 'unreadable');
  assert.strictEqual(detectInstallStatus([], SCRIPT).status, 'unreadable');
  assert.strictEqual(detectInstallStatus({ statusLine: { type: 'command', command: 'node "' + SCRIPT + '"' } }, SCRIPT).status, 'installed');
  const other = detectInstallStatus({ statusLine: { type: 'command', command: 'ccusage' } }, SCRIPT);
  assert.strictEqual(other.status, 'installed-other');
  assert.strictEqual(other.existingCommand, 'ccusage');
  // A bare string statusLine, and a shape with no command string at all, are both
  // NOT ours -- they must surface rather than be silently overwritten.
  assert.strictEqual(detectInstallStatus({ statusLine: 'ccusage' }, SCRIPT).status, 'installed-other');
  assert.strictEqual(detectInstallStatus({ statusLine: { type: 'command' } }, SCRIPT).status, 'installed-other');
});

test('readInstallState: missing file is not-installed, unparseable is unreadable', async () => {
  const missing = path.join(await fsp.mkdtemp(path.join(os.tmpdir(), 'ttinst-')), 'settings.json');
  assert.strictEqual((await readInstallState(missing, SCRIPT)).status, 'not-installed');
  assert.strictEqual((await readInstallState(await tmpSettings('{oops'), SCRIPT)).status, 'unreadable');
});

test('installing into a fresh settings.json adds statusLine and nothing else', async () => {
  const p = await tmpSettings();
  const res = await installStatusline(p, SCRIPT);
  assert.strictEqual(res.ok, true);
  assert.strictEqual(res.backupPath, null); // nothing existed to back up
  assert.deepStrictEqual(await readJson(p), statuslineSettingsPatch(SCRIPT));
});

test('installing preserves every other key and backs up the original bytes', async () => {
  const original = JSON.stringify({ model: 'opusplan', permissions: { allow: ['Bash'] } }, null, 2);
  const p = await tmpSettings(original);
  const res = await installStatusline(p, SCRIPT);
  assert.strictEqual(res.ok, true);
  const after = await readJson(p);
  assert.strictEqual(after.model, 'opusplan');
  assert.deepStrictEqual(after.permissions, { allow: ['Bash'] });
  assert.strictEqual(await fsp.readFile(res.backupPath, 'utf8'), original);
});

// This is the property that lets TokenMonitor and aether-os coexist.
test('a foreign statusLine is chained, not clobbered', async () => {
  const p = await tmpSettings(JSON.stringify({ statusLine: { type: 'command', command: 'node "C:\\aether\\aether-statusline.mjs"' } }));
  await installStatusline(p, SCRIPT);
  const after = await readJson(p);
  assert.ok(after.statusLine.command.startsWith('node "' + SCRIPT + '"'));
  assert.strictEqual(extractChainedCommand(after.statusLine.command), 'node "C:\\aether\\aether-statusline.mjs"');
});

test('re-installing carries an existing chain forward instead of dropping it', async () => {
  const p = await tmpSettings(JSON.stringify({ statusLine: { type: 'command', command: 'ccusage' } }));
  await installStatusline(p, SCRIPT);
  await installStatusline(p, SCRIPT);
  const after = await readJson(p);
  assert.strictEqual(extractChainedCommand(after.statusLine.command), 'ccusage');
});

// Overwriting a settings file we could not read back is exactly the "helpful"
// destruction this refuses to do.
test('an unparseable settings.json aborts the install and writes nothing', async () => {
  const p = await tmpSettings('{ not json');
  const res = await installStatusline(p, SCRIPT);
  assert.strictEqual(res.ok, false);
  assert.match(res.error, /could not parse/);
  assert.strictEqual(await fsp.readFile(p, 'utf8'), '{ not json');
});

test('a non-object settings.json is refused', async () => {
  const p = await tmpSettings('[1,2,3]');
  const res = await installStatusline(p, SCRIPT);
  assert.strictEqual(res.ok, false);
  assert.strictEqual(await fsp.readFile(p, 'utf8'), '[1,2,3]');
});

test('uninstalling restores the chained tool rather than deleting statusLine', async () => {
  const p = await tmpSettings(JSON.stringify({ statusLine: { type: 'command', command: 'ccusage' }, model: 'opusplan' }));
  await installStatusline(p, SCRIPT);
  const res = await uninstallStatusline(p, SCRIPT);
  assert.strictEqual(res.ok, true);
  const after = await readJson(p);
  assert.deepStrictEqual(after.statusLine, { type: 'command', command: 'ccusage' });
  assert.strictEqual(after.model, 'opusplan');
});

test('uninstalling with no chain removes statusLine entirely', async () => {
  const p = await tmpSettings(JSON.stringify({ model: 'opusplan' }));
  await installStatusline(p, SCRIPT);
  await uninstallStatusline(p, SCRIPT);
  const after = await readJson(p);
  assert.ok(!('statusLine' in after));
  assert.strictEqual(after.model, 'opusplan');
});

test('uninstalling when nothing is installed is a successful no-op', async () => {
  const p = await tmpSettings(JSON.stringify({ model: 'opusplan' }));
  const res = await uninstallStatusline(p, SCRIPT);
  assert.strictEqual(res.ok, true);
  assert.strictEqual(res.backupPath, null);
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test test/statuslineInstaller.test.js`
Expected: FAIL — `Cannot find module '../src/main/statuslineInstaller'`.

- [ ] **Step 3: Write the implementation**

Create `src/main/statuslineInstaller.js`:

```js
// src/main/statuslineInstaller.js
// Installs scripts/tokenmonitor-statusline.mjs as Claude Code's statusLine command
// by merging one key into ~/.claude/settings.json. Ported from aether-os's
// electron/statuslineInstaller.ts; behaviour unchanged, CommonJS, types dropped,
// backup/temp suffixes renamed.
//
// This module writes to the user's REAL Claude Code config, so three properties
// are non-negotiable and every one of them is tested:
//   1. Chain, never clobber -- a foreign statusLine keeps rendering, which is what
//      lets this app coexist with aether-os's own statusline on one machine.
//   2. A parse failure ABORTS -- nothing is written, not even a backup.
//   3. Backup the exact original bytes, then write atomically (tmp + rename).
const fsp = require('node:fs/promises');
const path = require('node:path');

/**
 * The patch merged into settings.json. `command` invokes the script with `node`,
 * quoted so paths containing spaces (very common on Windows) survive Claude Code's
 * shell invocation.
 *
 * A chained command is base64-encoded into a `--chain` argument rather than
 * embedded as literal text: it is itself an arbitrary shell command that may
 * contain its own quotes, and nesting those inside settings.json's command string
 * would be a quoting hazard. See parseChainArg in the script for the decode side.
 */
function statuslineSettingsPatch(scriptPath, chainCommand) {
  const base = 'node "' + scriptPath + '"';
  const command = chainCommand
    ? base + ' --chain ' + Buffer.from(chainCommand, 'utf8').toString('base64')
    : base;
  return { statusLine: { type: 'command', command } };
}

/** Pulls a previously-chained command back out of one of our own installed
 *  commands, or null if the command isn't ours / carries no chain. */
function extractChainedCommand(command) {
  if (!command) return null;
  const m = /--chain\s+(\S+)/.exec(command);
  if (!m) return null;
  try {
    // Node's base64 decoder is lenient, so round-trip to confirm the argument
    // really was base64 rather than accepting whatever bytes fell out.
    const decoded = Buffer.from(m[1], 'base64').toString('utf8');
    if (decoded.length === 0) return null;
    if (Buffer.from(decoded, 'utf8').toString('base64') !== m[1]) return null;
    return decoded;
  } catch {
    return null;
  }
}

/** Pure classification of an already-parsed settings body. Reads and writes nothing. */
function detectInstallStatus(settingsJson, scriptPath) {
  if (typeof settingsJson !== 'object' || settingsJson === null || Array.isArray(settingsJson)) {
    return { status: 'unreadable', existingCommand: null };
  }
  const statusLine = settingsJson.statusLine;
  if (statusLine === undefined) return { status: 'not-installed', existingCommand: null };

  let existingCommand = null;
  if (typeof statusLine === 'string') existingCommand = statusLine;
  else if (typeof statusLine === 'object' && statusLine !== null && typeof statusLine.command === 'string') {
    existingCommand = statusLine.command;
  }

  if (existingCommand !== null && existingCommand.includes(scriptPath)) {
    return { status: 'installed', existingCommand };
  }
  // The key is present but either doesn't reference our script or has an
  // unrecognized shape -- either way it is NOT ours, so it must surface rather
  // than be silently overwritten.
  return { status: 'installed-other', existingCommand };
}

async function readInstallState(settingsPath, scriptPath) {
  let raw;
  try {
    raw = await fsp.readFile(settingsPath, 'utf8');
  } catch (err) {
    const status = err && err.code === 'ENOENT' ? 'not-installed' : 'unreadable';
    return { status, existingCommand: null, settingsPath, scriptPath };
  }
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return { status: 'unreadable', existingCommand: null, settingsPath, scriptPath };
  }
  const { status, existingCommand } = detectInstallStatus(parsed, scriptPath);
  return { status, existingCommand, settingsPath, scriptPath };
}

/** Reads and parses settings.json, or returns an abort. fileExisted:false means
 *  ENOENT (treat as {}); a parse failure on a file that DOES exist is always an
 *  abort, never a {} fallback. */
async function readExistingSettings(settingsPath) {
  let raw = '';
  try {
    raw = await fsp.readFile(settingsPath, 'utf8');
  } catch (err) {
    if (err && err.code === 'ENOENT') return { ok: true, fileExisted: false, raw: '', parsed: {} };
    return { ok: false, error: (err && err.message) || String(err) };
  }

  // DELIBERATE DEVIATION from optimizeActions.js's byte-preservation discipline:
  // that module treats CLAUDE.md as opaque text and splices a managed block into
  // it. settings.json is JSON, not Markdown -- a text-level insert cannot safely
  // handle nested objects or key reordering. The only correct merge is parse,
  // merge, re-serialize. That can reformat whitespace the user had, but it can
  // never lose data -- and the timestamped backup of the exact original bytes is
  // what makes it acceptable: their prior file is always one rename away.
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (err) {
    // ABORT. We could not read this file, so we must not write anything -- not a
    // backup, not a merge. Proceeding is the "helpful" overwrite that destroys a
    // real config.
    return { ok: false, error: 'could not parse existing settings.json: ' + ((err && err.message) || String(err)) };
  }
  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    return { ok: false, error: 'existing settings.json is not a JSON object; refusing to overwrite' };
  }
  return { ok: true, fileExisted: true, raw, parsed };
}

async function writeBackup(settingsPath, raw) {
  const backupPath = settingsPath + '.ttbak-' + Date.now();
  await fsp.writeFile(backupPath, raw, 'utf8');
  return backupPath;
}

// A crash or ENOSPC mid-write directly to settings.json would leave the user's
// REAL Claude Code config truncated -- the backup only helps once they notice.
// Write-tmp-then-rename means the target is never observably partial.
async function writeSettingsAtomically(settingsPath, content) {
  const tmpPath = settingsPath + '.tttmp-' + Date.now();
  await fsp.writeFile(tmpPath, content, 'utf8');
  await fsp.rename(tmpPath, settingsPath);
}

async function installStatusline(settingsPath, scriptPath) {
  const existing = await readExistingSettings(settingsPath);
  if (!existing.ok) return { ok: false, error: existing.error };
  const { fileExisted, raw, parsed } = existing;

  try {
    const backupPath = fileExisted ? await writeBackup(settingsPath, raw) : null;

    // Chain rather than clobber: a foreign command is preserved as the thing we
    // chain to, and a prior install's own chain is carried forward across a
    // re-install rather than silently dropped.
    const { status, existingCommand } = detectInstallStatus(parsed, scriptPath);
    const chainCommand =
      status === 'installed-other' ? existingCommand
      : status === 'installed' ? extractChainedCommand(existingCommand)
      : null;

    const merged = { ...parsed, ...statuslineSettingsPatch(scriptPath, chainCommand) };
    await fsp.mkdir(path.dirname(settingsPath), { recursive: true });
    await writeSettingsAtomically(settingsPath, JSON.stringify(merged, null, 2));
    return { ok: true, backupPath };
  } catch (err) {
    return { ok: false, error: (err && err.message) || String(err) };
  }
}

async function uninstallStatusline(settingsPath, scriptPath) {
  const existing = await readExistingSettings(settingsPath);
  if (!existing.ok) return { ok: false, error: existing.error };
  const { fileExisted, raw, parsed } = existing;

  if (!fileExisted || !('statusLine' in parsed)) return { ok: true, backupPath: null };

  try {
    const backupPath = await writeBackup(settingsPath, raw);
    const { existingCommand } = detectInstallStatus(parsed, scriptPath);
    const chained = extractChainedCommand(existingCommand);
    if (chained) {
      // Restore the tool we were chained through. Uninstalling this app must not
      // also silently kill whatever statusLine command the user had before it.
      parsed.statusLine = { type: 'command', command: chained };
    } else {
      delete parsed.statusLine;
    }
    await writeSettingsAtomically(settingsPath, JSON.stringify(parsed, null, 2));
    return { ok: true, backupPath };
  } catch (err) {
    return { ok: false, error: (err && err.message) || String(err) };
  }
}

module.exports = {
  statuslineSettingsPatch, extractChainedCommand, detectInstallStatus,
  readInstallState, installStatusline, uninstallStatusline,
};
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `node --test test/statuslineInstaller.test.js`
Expected: PASS, 14 tests.

- [ ] **Step 5: Run the full suite and commit**

Run: `npm test`
Expected: PASS.

```bash
git add src/main/statuslineInstaller.js test/statuslineInstaller.test.js
git commit -m "feat: install the statusline hook without clobbering an existing one"
```

---

### Task 10: Statusline install control in Settings

**Files:**
- Modify: `src/main/ipcHandlers.js` (three handlers, beside the plan-price ones from Task 5)
- Modify: `src/main/main.js` (resolve and pass `statuslineScriptPath` and `claudeSettingsPath`)
- Modify: `src/preload/preload.js` (a `statusline` namespace)
- Modify: `src/renderer/index.html` (a row after the plan-price block from Task 6)
- Modify: `src/renderer/dashboard/panels/settingsPanel.js` (`mountStatuslineRow`, called from `mountSettings`)
- Test: `test/statuslineRow.test.js`

**Interfaces:**
- Consumes: `readInstallState`, `installStatusline`, `uninstallStatusline` (Task 9); the script at `scripts/tokenmonitor-statusline.mjs` (Task 8).
- Produces:
  - IPC: `statusline:getState` → `{ status, existingCommand, settingsPath, scriptPath }`, `statusline:install` → `{ ok, backupPath?, error? }`, `statusline:uninstall` → same shape
  - Preload: `window.tokenTracker.statusline.getState()`, `.install()`, `.uninstall()`
  - Element ids `statusline-status`, `statusline-install-btn`, `statusline-uninstall-btn`

- [ ] **Step 1: Write the failing test**

Create `test/statuslineRow.test.js`:

```js
// test/statuslineRow.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const read = (...p) => fs.readFileSync(path.join(__dirname, '..', ...p), 'utf8');

test('the settings popover carries the statusline install row', () => {
  const html = read('src', 'renderer', 'index.html');
  for (const id of ['statusline-status', 'statusline-install-btn', 'statusline-uninstall-btn']) {
    assert.ok(html.includes('id="' + id + '"'), 'no ' + id);
  }
});

test('the IPC channels are registered and bridged', () => {
  const handlers = read('src', 'main', 'ipcHandlers.js');
  const preload = read('src', 'preload', 'preload.js');
  for (const channel of ['statusline:getState', 'statusline:install', 'statusline:uninstall']) {
    assert.ok(handlers.includes("'" + channel + "'"), 'ipcHandlers.js does not handle ' + channel);
    assert.ok(preload.includes(channel), 'preload.js does not expose ' + channel);
  }
});

// The script path must be resolved from the app's own location, not typed as a
// literal anywhere -- a packaged build's resources path differs from a dev run's.
test('main.js resolves the statusline script path rather than hardcoding it', () => {
  const main = read('src', 'main', 'main.js');
  assert.ok(/statuslineScriptPath/.test(main), 'main.js does not pass statuslineScriptPath');
  assert.ok(/tokenmonitor-statusline\.mjs/.test(main), 'main.js does not name the script file');
  assert.ok(/claudeSettingsPath/.test(main), 'main.js does not pass claudeSettingsPath');
});

test('settingsPanel.js mounts the row and surfaces the installed-other state', () => {
  const js = read('src', 'renderer', 'dashboard', 'panels', 'settingsPanel.js');
  assert.ok(/function mountStatuslineRow/.test(js), 'no mountStatuslineRow');
  assert.ok(/mountStatuslineRow\(\)/.test(js), 'mountStatuslineRow is never called');
  // A user must be told what they are about to chain to before they press Install.
  assert.ok(/installed-other/.test(js), 'the installed-other state is never surfaced');
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test test/statuslineRow.test.js`
Expected: FAIL — `no statusline-status`.

- [ ] **Step 3: Register the IPC handlers**

In `src/main/ipcHandlers.js`, add to the requires:

```js
const { readInstallState, installStatusline, uninstallStatusline } = require('./statuslineInstaller');
```

Add `statuslineScriptPath` and `claudeSettingsPath` to the destructured `registerIpcHandlers({ ... })` parameters, and register beside the plan-price handlers:

```js
  ipcMain.handle('statusline:getState', () => readInstallState(claudeSettingsPath, statuslineScriptPath));
  ipcMain.handle('statusline:install', () => installStatusline(claudeSettingsPath, statuslineScriptPath));
  ipcMain.handle('statusline:uninstall', () => uninstallStatusline(claudeSettingsPath, statuslineScriptPath));
```

- [ ] **Step 4: Resolve the paths in main.js**

In `src/main/main.js`, add near the `UI_CONFIG_PATH` constant (line 21):

```js
// Resolved from this file's own location, never a literal: a packaged build's
// resources directory is not the dev tree, and the installer writes this exact
// string into the user's settings.json -- a wrong path there is a silently dead
// statusline, not a visible error.
const STATUSLINE_SCRIPT_PATH = path.join(__dirname, '..', '..', 'scripts', 'tokenmonitor-statusline.mjs');
const CLAUDE_SETTINGS_PATH = path.join(os.homedir(), '.claude', 'settings.json');
```

and pass both into the `registerIpcHandlers({ ... })` call:

```js
    statuslineScriptPath: STATUSLINE_SCRIPT_PATH,
    claudeSettingsPath: CLAUDE_SETTINGS_PATH,
```

- [ ] **Step 5: Extend the preload bridge**

In `src/preload/preload.js`, add beside the `plan` namespace:

```js
  statusline: {
    getState: () => ipcRenderer.invoke('statusline:getState'),
    install: () => ipcRenderer.invoke('statusline:install'),
    uninstall: () => ipcRenderer.invoke('statusline:uninstall'),
  },
```

- [ ] **Step 6: Add the markup**

In `src/renderer/index.html`, immediately after the `plan-price-hint` div added in Task 6:

```html
        <div class="settings-divider"></div>
        <div class="hero-label mb-2">Live quota feed</div>
        <div id="statusline-status" class="statusline-status"></div>
        <div class="statusline-actions">
          <button type="button" id="statusline-install-btn">Install</button>
          <button type="button" id="statusline-uninstall-btn">Remove</button>
        </div>
        <div class="plan-price-hint">Adds a status line to Claude Code that records your quota percentage on every turn. Your existing status line, if any, keeps working.</div>
```

- [ ] **Step 7: Add the mount function**

In `src/renderer/dashboard/panels/settingsPanel.js`, beside `mountPlanPriceRow`:

```js
// Live quota feed row. The four install states each read differently on purpose:
// 'installed-other' must NAME the command it is about to chain to, because the
// user is agreeing to have their existing status line wrapped, and 'unreadable'
// must say the file could not be parsed rather than offering an Install that the
// installer will refuse anyway.
function statuslineStatusText(state) {
  if (!state) return 'unknown';
  if (state.status === 'installed') return 'Installed - quota is being recorded on every turn.';
  if (state.status === 'installed-other') return 'Another status line is configured (' + state.existingCommand + '). Installing will keep it running, chained.';
  if (state.status === 'unreadable') return 'Could not read ' + state.settingsPath + ' - fix or remove that file before installing.';
  return 'Not installed - the quota series has no live source.';
}

function mountStatuslineRow() {
  const statusEl = document.getElementById('statusline-status');
  const installBtn = document.getElementById('statusline-install-btn');
  const removeBtn = document.getElementById('statusline-uninstall-btn');
  if (!statusEl || !installBtn || !removeBtn || !window.tokenTracker || !window.tokenTracker.statusline) return;

  const refresh = async () => {
    try {
      const state = await window.tokenTracker.statusline.getState();
      statusEl.textContent = statuslineStatusText(state);
      installBtn.disabled = state.status === 'installed' || state.status === 'unreadable';
      removeBtn.disabled = state.status === 'not-installed' || state.status === 'unreadable';
    } catch (err) {
      statusEl.textContent = 'unknown';
    }
  };

  const run = async (fn) => {
    installBtn.disabled = true;
    removeBtn.disabled = true;
    let res;
    try {
      res = await fn();
    } catch (err) {
      res = { ok: false, error: String(err) };
    }
    // Report the failure verbatim. A settings.json write that refused itself is
    // exactly the thing the user needs the real reason for.
    if (!res || !res.ok) statusEl.textContent = 'Failed: ' + ((res && res.error) || 'unknown error');
    else await refresh();
    if (res && res.ok && res.backupPath) statusEl.textContent += ' (backup: ' + res.backupPath + ')';
  };

  installBtn.addEventListener('click', () => run(() => window.tokenTracker.statusline.install()));
  removeBtn.addEventListener('click', () => run(() => window.tokenTracker.statusline.uninstall()));
  refresh();
}
```

Call it from `mountSettings`, beside `mountPlanPriceRow()`:

```js
  mountStatuslineRow();
```

Append to `src/renderer/styles/tokens.css`:

```css
.statusline-status { color: var(--tx-muted); font-size: 11px; line-height: 1.4; margin-bottom: 6px; }
.statusline-actions { display: flex; gap: 6px; margin-bottom: 6px; }
```

- [ ] **Step 8: Run the tests**

Run: `npm test`
Expected: PASS.

- [ ] **Step 9: Verify the coexistence claim against the real machine**

This is the interaction the Decision section flagged, and it must be observed rather than assumed.

1. `cat ~/.claude/settings.json` — record the current `statusLine` value. On this machine it is expected to be aether-os's script (`node "…\aether-os\scripts\aether-statusline.mjs"`). **Copy the file somewhere safe before proceeding.**
2. `npm start`, open Settings. Expected: the row reads "Another status line is configured (…)" and names aether's command.
3. Press Install. Expected: `ok`, and a `settings.json.ttbak-…` backup path is shown.
4. `cat ~/.claude/settings.json` — expected: `node "…\TokenMonitorV2-quota\scripts\tokenmonitor-statusline.mjs" --chain <base64>`, and every other key unchanged.
5. Open a **new** Claude Code session and run one turn. Expected: the status line still shows **aether's** output (ours chains to it and prints its line verbatim), AND both `~/.claude-token-tracker/statusline.json` and `~/.aether-os/statusline.json` have fresh `capturedAtMs`/mtimes.
6. Press Remove in Settings. Expected: `settings.json`'s `statusLine` is restored to aether's original command exactly.

Record the actual observed result for each step. If step 5 does not show both files updating, **stop and report** — the coexistence assumption is the load-bearing one for this whole feature branch, and a plan step is not a substitute for the observation.

- [ ] **Step 10: Commit**

```bash
git add src/main/ipcHandlers.js src/main/main.js src/preload/preload.js src/renderer/index.html src/renderer/dashboard/panels/settingsPanel.js src/renderer/styles/tokens.css test/statuslineRow.test.js
git commit -m "feat: install and remove the live quota feed from Settings"
```

---
### Task 11: The persisted quota sample series

**Files:**
- Create: `src/shared/quotaSeriesStore.js`
- Test: `test/quotaSeriesStore.test.js`

**Interfaces:**
- Consumes: `QuotaSample` shape from Task 4 (`{ atMs, usedPercentage, tokens }`).
- Produces:
  - `MAX_SAMPLES = 400`, `MIN_SAMPLE_GAP_MS = 5 * 60 * 1000`
  - `appendSample(samples, sample): QuotaSample[]` — pure; returns a new array, dropping the sample if it arrives within `MIN_SAMPLE_GAP_MS` of the newest one, and trimming to `MAX_SAMPLES`
  - `sanitizeSeries(raw): QuotaSample[]`
  - `loadQuotaSeries(configPath): Promise<QuotaSample[]>`
  - `saveQuotaSeries(configPath, samples): Promise<void>`

**Why the store exists:** the statusline payload file holds only the **latest** reading. `fitTokensPerPoint` needs a history. This module is that history: an append-only, time-capped ring of `(percentage, running token total)` pairs at `~/.claude-token-tracker/quotaSeries.json`.

**Why the 5-minute gap:** the statusline hook fires on **every turn**. Sampling all of them would fill the ring with adjacent pairs whose percentage delta is 0 or a rounding artefact — thousands of idle buckets and a handful of useful ones. A 5-minute floor gives buckets big enough for the reported integer percentage to actually move.

- [ ] **Step 1: Write the failing test**

Create `test/quotaSeriesStore.test.js`:

```js
// test/quotaSeriesStore.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const fsp = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const {
  appendSample, sanitizeSeries, loadQuotaSeries, saveQuotaSeries,
  MAX_SAMPLES, MIN_SAMPLE_GAP_MS,
} = require('../src/shared/quotaSeriesStore');

const s = (atMs, usedPercentage, tokens) => ({ atMs, usedPercentage, tokens });
const GAP = MIN_SAMPLE_GAP_MS;

async function tmpPath() {
  const dir = await fsp.mkdtemp(path.join(os.tmpdir(), 'ttseries-'));
  return path.join(dir, 'quotaSeries.json');
}

test('the sample gap is five minutes and the ring holds 400', () => {
  assert.strictEqual(MIN_SAMPLE_GAP_MS, 5 * 60 * 1000);
  assert.strictEqual(MAX_SAMPLES, 400);
});

test('appends to an empty series', () => {
  assert.deepStrictEqual(appendSample([], s(1000, 10, 5)), [s(1000, 10, 5)]);
  assert.deepStrictEqual(appendSample(null, s(1000, 10, 5)), [s(1000, 10, 5)]);
});

// The statusline hook fires on EVERY turn. Without this floor the ring fills with
// adjacent pairs whose percentage delta is 0 -- thousands of idle buckets.
test('a sample inside the gap is dropped, not appended', () => {
  const base = [s(0, 10, 0)];
  assert.deepStrictEqual(appendSample(base, s(GAP - 1, 12, 500)), base);
  assert.strictEqual(appendSample(base, s(GAP, 12, 500)).length, 2);
});

test('appendSample never mutates its input', () => {
  const base = [s(0, 10, 0)];
  const copy = JSON.parse(JSON.stringify(base));
  appendSample(base, s(GAP, 12, 500));
  assert.deepStrictEqual(base, copy);
});

test('the ring trims from the front at MAX_SAMPLES', () => {
  let series = [];
  for (let i = 0; i <= MAX_SAMPLES + 20; i++) series = appendSample(series, s(i * GAP, i % 100, i * 1000));
  assert.strictEqual(series.length, MAX_SAMPLES);
  assert.strictEqual(series[series.length - 1].atMs, (MAX_SAMPLES + 20) * GAP);
  assert.strictEqual(series[0].atMs, 21 * GAP); // oldest 21 dropped
});

test('an out-of-order sample is still gap-checked against the newest, not the last-pushed', () => {
  const series = [s(0, 10, 0), s(10 * GAP, 20, 100)];
  assert.deepStrictEqual(appendSample(series, s(3 * GAP, 15, 50)), series);
});

test('a malformed sample is refused outright', () => {
  const base = [s(0, 10, 0)];
  for (const bad of [null, undefined, {}, s('x', 10, 0), s(GAP, NaN, 0), s(GAP, 10, 'lots')]) {
    assert.deepStrictEqual(appendSample(base, bad), base);
  }
});

test('sanitizeSeries drops junk entries and sorts by time', () => {
  const cleaned = sanitizeSeries([s(2000, 12, 5), 'nope', null, s(1000, 10, 0), { atMs: 3000 }]);
  assert.deepStrictEqual(cleaned, [s(1000, 10, 0), s(2000, 12, 5)]);
  assert.deepStrictEqual(sanitizeSeries('not an array'), []);
  assert.deepStrictEqual(sanitizeSeries(null), []);
});

test('round-trips through disk; a missing or corrupt file yields an empty series', async () => {
  const p = await tmpPath();
  assert.deepStrictEqual(await loadQuotaSeries(p), []);
  await saveQuotaSeries(p, [s(1000, 10, 0), s(2000, 12, 5)]);
  assert.deepStrictEqual(await loadQuotaSeries(p), [s(1000, 10, 0), s(2000, 12, 5)]);
  await fsp.writeFile(p, 'not json', 'utf8');
  assert.deepStrictEqual(await loadQuotaSeries(p), []);
});

test('saving creates the parent directory and caps what it writes', async () => {
  const dir = await fsp.mkdtemp(path.join(os.tmpdir(), 'ttseries-'));
  const p = path.join(dir, 'nested', 'quotaSeries.json');
  const tooMany = [];
  for (let i = 0; i < MAX_SAMPLES + 50; i++) tooMany.push(s(i * GAP, i % 100, i));
  await saveQuotaSeries(p, tooMany);
  assert.strictEqual((await loadQuotaSeries(p)).length, MAX_SAMPLES);
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test test/quotaSeriesStore.test.js`
Expected: FAIL — `Cannot find module '../src/shared/quotaSeriesStore'`.

- [ ] **Step 3: Write the implementation**

Create `src/shared/quotaSeriesStore.js`:

```js
// src/shared/quotaSeriesStore.js
// The history behind the tokens-per-point fit.
//
// The statusline payload file holds only the LATEST reading; fitTokensPerPoint
// needs adjacent pairs across time. This is that history: an append-only,
// time-capped ring of (account quota percentage, this machine's running seven-day
// token total) pairs at ~/.claude-token-tracker/quotaSeries.json.
//
// MIN_SAMPLE_GAP_MS exists because the statusline hook fires on EVERY turn.
// Sampling all of them would fill the ring with adjacent pairs whose percentage
// delta is 0 or an integer-rounding artefact -- thousands of idle buckets and a
// handful of useful ones. Five minutes is long enough for the reported integer
// percentage to actually move.
const fsp = require('node:fs/promises');
const path = require('node:path');

const MAX_SAMPLES = 400;
const MIN_SAMPLE_GAP_MS = 5 * 60 * 1000;

function isSample(x) {
  return (
    x !== null && typeof x === 'object' &&
    typeof x.atMs === 'number' && Number.isFinite(x.atMs) &&
    typeof x.usedPercentage === 'number' && Number.isFinite(x.usedPercentage) &&
    typeof x.tokens === 'number' && Number.isFinite(x.tokens)
  );
}

function pick(x) {
  return { atMs: x.atMs, usedPercentage: x.usedPercentage, tokens: x.tokens };
}

function sanitizeSeries(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.filter(isSample).map(pick).sort((a, b) => a.atMs - b.atMs).slice(-MAX_SAMPLES);
}

/**
 * Pure append. Returns a NEW array; never mutates the input.
 *
 * The gap is measured against the newest sample by time, not the last element
 * pushed, so an out-of-order arrival (a clock adjustment, a replayed payload)
 * cannot slip past the floor.
 */
function appendSample(samples, sample) {
  const series = sanitizeSeries(samples);
  if (!isSample(sample)) return series;
  const newest = series.length ? series[series.length - 1].atMs : -Infinity;
  if (sample.atMs - newest < MIN_SAMPLE_GAP_MS) return series;
  return series.concat([pick(sample)]).slice(-MAX_SAMPLES);
}

async function loadQuotaSeries(configPath) {
  try {
    return sanitizeSeries(JSON.parse(await fsp.readFile(configPath, 'utf8')));
  } catch {
    // Missing or malformed: an empty series is the honest answer, and the file is
    // left alone rather than overwritten -- the same discipline budgetConfig.js
    // applies at lines 28-32.
    return [];
  }
}

async function saveQuotaSeries(configPath, samples) {
  const clean = sanitizeSeries(samples);
  await fsp.mkdir(path.dirname(configPath), { recursive: true });
  await fsp.writeFile(configPath, JSON.stringify(clean), 'utf8');
}

module.exports = { MAX_SAMPLES, MIN_SAMPLE_GAP_MS, isSample, sanitizeSeries, appendSample, loadQuotaSeries, saveQuotaSeries };
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `node --test test/quotaSeriesStore.test.js`
Expected: PASS, 10 tests.

- [ ] **Step 5: Run the full suite and commit**

Run: `npm test`
Expected: PASS.

```bash
git add src/shared/quotaSeriesStore.js test/quotaSeriesStore.test.js
git commit -m "feat: persist the quota percentage series behind the fit"
```

---

### Task 12: The statusline watcher, wired into the main process

**Files:**
- Create: `src/main/statuslineWatcher.js`
- Modify: `src/main/main.js` (start the watcher in `app.whenReady`, stop it on quit; feed the series store)
- Modify: `src/main/ipcHandlers.js` (accept `getQuotaSeries` and `getStatuslineSnapshot`)
- Test: `test/statuslineWatcher.test.js`

**Interfaces:**
- Consumes: `parseStatuslinePayload` (Task 7), `appendSample`/`loadQuotaSeries`/`saveQuotaSeries` (Task 11), `historyAggregator.getTotals(7d)` (`src/shared/aggregator.js:84`).
- Produces:
  - `WATCH_INTERVAL_MS = 10000`
  - `readSnapshot(payloadPath): StatuslineSnapshot | null`
  - `startStatuslineWatcher(payloadPath, onSnapshot): () => void` — reads once immediately, then polls; the returned function unsubscribes.
  - In `main.js`: module-level `quotaSeries` array and `getQuotaSeries()` / `getStatuslineSnapshot()` accessors passed into `registerIpcHandlers`.

**Why `fs.watchFile`, not `fs.watch`:** on Windows `fs.watch` does not reliably report the atomic write-then-rename pattern the script uses. A 10-second poll is plenty for bars that change over minutes-to-hours, and the sample floor is 5 minutes anyway.

**Why `capturedAtMs` never falls back to `Date.now()`:** it comes from the payload's own stamp, else the file's `mtimeMs`. Using the read time would make every read look artificially fresh and defeat staleness detection.

- [ ] **Step 1: Write the failing test**

Create `test/statuslineWatcher.test.js`:

```js
// test/statuslineWatcher.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const fsp = require('node:fs/promises');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { readSnapshot, startStatuslineWatcher, WATCH_INTERVAL_MS } = require('../src/main/statuslineWatcher');

async function tmpPayload(body) {
  const dir = await fsp.mkdtemp(path.join(os.tmpdir(), 'ttwatch-'));
  const p = path.join(dir, 'statusline.json');
  if (body !== undefined) await fsp.writeFile(p, body, 'utf8');
  return p;
}

const PAYLOAD = {
  rate_limits: { seven_day: { used_percentage: 18, resets_at: 1_760_400_000 } },
  capturedAtMs: 1_700_000_000_000,
};

test('the poll interval is ten seconds', () => {
  assert.strictEqual(WATCH_INTERVAL_MS, 10000);
});

test('readSnapshot parses a good payload and uses its own capturedAtMs', async () => {
  const snap = readSnapshot(await tmpPayload(JSON.stringify(PAYLOAD)));
  assert.strictEqual(snap.capturedAtMs, 1_700_000_000_000);
  assert.deepStrictEqual(snap.sevenDay, { usedPercentage: 18, resetsAtMs: 1_760_400_000_000 });
});

// Using the READ time would make every read look artificially fresh and defeat
// staleness detection entirely.
test('readSnapshot falls back to the file mtime, never to now, when the stamp is missing', async () => {
  const p = await tmpPayload(JSON.stringify({ rate_limits: { seven_day: { used_percentage: 5, resets_at: 1 } } }));
  const snap = readSnapshot(p);
  assert.strictEqual(snap.capturedAtMs, fs.statSync(p).mtimeMs);
});

test('readSnapshot returns null for a missing, unparseable, or non-object file', async () => {
  const dir = await fsp.mkdtemp(path.join(os.tmpdir(), 'ttwatch-'));
  assert.strictEqual(readSnapshot(path.join(dir, 'nope.json')), null);
  assert.strictEqual(readSnapshot(await tmpPayload('{ partial')), null);
  assert.strictEqual(readSnapshot(await tmpPayload('[]')), null);
});

test('the watcher emits a payload that existed before it started', async () => {
  const p = await tmpPayload(JSON.stringify(PAYLOAD));
  const seen = [];
  const stop = startStatuslineWatcher(p, (s) => seen.push(s));
  stop();
  assert.strictEqual(seen.length, 1);
  assert.strictEqual(seen[0].sevenDay.usedPercentage, 18);
});

test('the watcher emits nothing when the file is absent, and stop() is safe to call', async () => {
  const dir = await fsp.mkdtemp(path.join(os.tmpdir(), 'ttwatch-'));
  const seen = [];
  const stop = startStatuslineWatcher(path.join(dir, 'nope.json'), (s) => seen.push(s));
  assert.deepStrictEqual(seen, []);
  stop();
  stop(); // idempotent: quit paths call this more than once
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test test/statuslineWatcher.test.js`
Expected: FAIL — `Cannot find module '../src/main/statuslineWatcher'`.

- [ ] **Step 3: Write the implementation**

Create `src/main/statuslineWatcher.js`:

```js
// src/main/statuslineWatcher.js
// Watches the payload file scripts/tokenmonitor-statusline.mjs writes. Ported from
// aether-os's electron/statuslineWatcher.ts; behaviour unchanged, CommonJS.
//
// fs.watchFile POLLS rather than relying on OS filesystem-change events. fs.watch
// is explicitly avoided: on Windows it does not reliably report the atomic
// write-then-renameSync pattern the script uses. A ~10s poll is plenty for bars
// that change over minutes-to-hours -- and quotaSeriesStore's own sample floor is
// five minutes, so a faster poll would buy nothing.
const { readFileSync, statSync, watchFile, unwatchFile } = require('node:fs');
const { parseStatuslinePayload } = require('../shared/statuslinePayload');

const WATCH_INTERVAL_MS = 10000;

/**
 * Reads and parses the payload file. Never throws: a missing file, a read racing
 * the writer's rename, or malformed JSON all resolve to null, which callers must
 * treat as a silent no-op -- the last good snapshot stays.
 *
 * capturedAtMs comes from the payload's own stamp when the writer set one, else
 * the file's mtimeMs. NEVER Date.now(): that would make every read look
 * artificially fresh and defeat the staleness detection built on this field.
 */
function readSnapshot(payloadPath) {
  try {
    const stat = statSync(payloadPath);
    const parsed = JSON.parse(readFileSync(payloadPath, 'utf8'));
    const raw = parsed && typeof parsed === 'object' ? parsed.capturedAtMs : undefined;
    const capturedAtMs = typeof raw === 'number' && Number.isFinite(raw) ? raw : stat.mtimeMs;
    return parseStatuslinePayload(parsed, capturedAtMs);
  } catch {
    return null;
  }
}

/**
 * Starts watching payloadPath. Reads once immediately (so a payload written before
 * the app launched is picked up right away) and then polls. Returns an
 * unsubscribe function that must be called on app quit; calling it twice is safe.
 */
function startStatuslineWatcher(payloadPath, onSnapshot) {
  const checkAndEmit = () => {
    const snapshot = readSnapshot(payloadPath);
    if (snapshot !== null) onSnapshot(snapshot);
  };

  checkAndEmit();

  const listener = () => checkAndEmit();
  watchFile(payloadPath, { interval: WATCH_INTERVAL_MS, persistent: false }, listener);

  let stopped = false;
  return () => {
    if (stopped) return;
    stopped = true;
    unwatchFile(payloadPath, listener);
  };
}

module.exports = { WATCH_INTERVAL_MS, readSnapshot, startStatuslineWatcher };
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `node --test test/statuslineWatcher.test.js`
Expected: PASS, 6 tests.

- [ ] **Step 5: Wire it into main.js**

In `src/main/main.js`, add to the requires (beside `createUsageScraper` on line 17):

```js
const { startStatuslineWatcher } = require('./statuslineWatcher');
const { appendSample, loadQuotaSeries, saveQuotaSeries } = require('../shared/quotaSeriesStore');
```

Add beside the `usageScraper` declaration (line 42):

```js
const STATUSLINE_PAYLOAD_PATH = path.join(os.homedir(), '.claude-token-tracker', 'statusline.json');
const QUOTA_SERIES_PATH = path.join(os.homedir(), '.claude-token-tracker', 'quotaSeries.json');
const SEVEN_DAY_MS = 7 * 24 * 60 * 60 * 1000;
let quotaSeries = [];
let latestStatuslineSnapshot = null;
let stopStatuslineWatcher = null;
```

Inside `app.whenReady().then(async () => { ... })`, immediately after the existing `await usageScraper.load()` line (line 60):

```js
  quotaSeries = await loadQuotaSeries(QUOTA_SERIES_PATH).catch(() => []);
  stopStatuslineWatcher = startStatuslineWatcher(STATUSLINE_PAYLOAD_PATH, (snapshot) => {
    latestStatuslineSnapshot = snapshot;
    // Only the SEVEN-day window feeds the series: it is the basis for every
    // dollar figure (resolved decision, 2026-09-07). The five-hour window is a
    // live gauge and is never mixed into the fit.
    if (!snapshot.sevenDay) return;
    const totals = historyAggregator.getTotals(SEVEN_DAY_MS);
    const next = appendSample(quotaSeries, {
      atMs: snapshot.capturedAtMs,
      usedPercentage: snapshot.sevenDay.usedPercentage,
      tokens: totals.inputTokens + totals.outputTokens,
    });
    // appendSample enforces the five-minute floor, so an identical array back
    // means the sample was dropped -- do not spend a disk write on it.
    if (next === quotaSeries || next.length === quotaSeries.length) {
      quotaSeries = next;
      return;
    }
    quotaSeries = next;
    saveQuotaSeries(QUOTA_SERIES_PATH, quotaSeries).catch(() => {});
  });
```

Pass the accessors into `registerIpcHandlers({ ... })`:

```js
    getQuotaSeries: () => quotaSeries,
    getStatuslineSnapshot: () => latestStatuslineSnapshot,
```

And stop the watcher on quit — add beside the existing `flushWithDeadline` quit handling:

```js
app.on('will-quit', () => {
  if (stopStatuslineWatcher) stopStatuslineWatcher();
});
```

In `src/main/ipcHandlers.js`, add `getQuotaSeries` and `getStatuslineSnapshot` to **both** the `buildDashboardState({ ... })` destructured parameters and the `registerIpcHandlers({ ... })` ones, and forward them at both `buildDashboardState` call sites (the `dashboard:getState` handler and the returned `getState`). Task 14 consumes them; this task only plumbs them through.

- [ ] **Step 6: Confirm the plumbing with a source-text test**

Append to `test/statuslineWatcher.test.js`:

```js
test('main.js starts the watcher, feeds the series, and stops it on quit', () => {
  const src = fs.readFileSync(path.join(__dirname, '..', 'src', 'main', 'main.js'), 'utf8');
  assert.ok(/startStatuslineWatcher\(/.test(src), 'main.js never starts the watcher');
  assert.ok(/appendSample\(/.test(src), 'main.js never feeds the series store');
  assert.ok(/saveQuotaSeries\(/.test(src), 'main.js never persists the series');
  assert.ok(/will-quit[\s\S]{0,200}stopStatuslineWatcher/.test(src), 'main.js never stops the watcher on quit');
  // Only the seven-day window feeds the fit -- the five-hour window is a live gauge.
  assert.ok(/snapshot\.sevenDay/.test(src), 'main.js does not read the seven-day window');
  assert.ok(!/snapshot\.fiveHour[\s\S]{0,80}appendSample/.test(src), 'the five-hour window must never feed the fit');
});

test('ipcHandlers.js forwards the quota series and statusline snapshot', () => {
  const src = fs.readFileSync(path.join(__dirname, '..', 'src', 'main', 'ipcHandlers.js'), 'utf8');
  assert.ok(/getQuotaSeries/.test(src));
  assert.ok(/getStatuslineSnapshot/.test(src));
});
```

- [ ] **Step 7: Run the full suite**

Run: `npm test`
Expected: PASS.

- [ ] **Step 8: Verify against the real feed**

Run `npm start`, then run at least one Claude Code turn in a terminal (the embedded one is fine) with the statusline installed from Task 10.
Check: `cat ~/.claude-token-tracker/statusline.json` has a fresh `capturedAtMs`, and after five minutes and a second turn, `cat ~/.claude-token-tracker/quotaSeries.json` holds **two** samples with different `atMs`. One sample is not evidence the append path works; two is.

- [ ] **Step 9: Commit**

```bash
git add src/main/statuslineWatcher.js test/statuslineWatcher.test.js src/main/main.js src/main/ipcHandlers.js
git commit -m "feat: record a quota sample from every statusline payload"
```

---

### Task 13: Poll-failure reason enum for the /usage scrape (spec item 7)

**Files:**
- Modify: `src/shared/usageParser.js:100` (add `classifySyncFailure` and `SYNC_FAILURE_REASONS`)
- Modify: `src/main/usageScraper.js:44-51` (expose `getBuffer()`)
- Modify: `src/main/main.js:178-212` (`plan:sync` returns the reason)
- Modify: `src/renderer/dashboard/panels/budgets.js:71-85` (show the reason, not just "last sync failed")
- Test: `test/syncFailureReason.test.js`

**Scope note:** with the statusline feed installed (Tasks 7-12), the `/usage` scrape is no longer the quota-series source — it is the **fallback** for a user who has not installed the statusline. This task therefore improves a fallback path, which is why it is small and sits here rather than earlier.

**Interfaces:**
- Consumes: the scraper's ANSI-stripped buffer.
- Produces:
  - `SYNC_FAILURE_REASONS = ['no-terminal', 'trust-prompt', 'login', 'onboarding', 'timeout', 'unknown']`
  - `classifySyncFailure(bufferText): { reason: string, message: string }`
  - `plan:sync` now resolves to `{ ok: false, reason, error }` (the existing `error` string is kept so nothing downstream that reads it breaks).

**Honest limitation, carry it into the code comment:** `test/fixtures/` contains `usage-pane-real.txt` and nothing else — there is **no captured fixture for the trust-folder, login or onboarding screens**. The patterns below are a starting set derived from the wording of those screens, not from a recorded capture in this repo. `unknown` is the safe fall-through and preserves today's behaviour exactly. **Step 6 requires capturing at least one real screen before this is called done.**

- [ ] **Step 1: Write the failing test**

Create `test/syncFailureReason.test.js`:

```js
// test/syncFailureReason.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { classifySyncFailure, SYNC_FAILURE_REASONS } = require('../src/shared/usageParser');

test('the reason set is closed and includes the three screens item 7 names', () => {
  assert.deepStrictEqual(SYNC_FAILURE_REASONS, ['no-terminal', 'trust-prompt', 'login', 'onboarding', 'timeout', 'unknown']);
});

test('every classification returns a reason from the set and a non-empty message', () => {
  for (const text of ['', 'Do you trust the files in this folder?', 'random terminal noise', null, undefined, 12]) {
    const r = classifySyncFailure(text);
    assert.ok(SYNC_FAILURE_REASONS.includes(r.reason), 'unknown reason: ' + r.reason);
    assert.ok(typeof r.message === 'string' && r.message.length > 0);
  }
});

test('recognises the trust-folder prompt', () => {
  assert.strictEqual(classifySyncFailure('Do you trust the files in this folder?\n1. Yes, proceed').reason, 'trust-prompt');
  assert.strictEqual(classifySyncFailure('DO YOU TRUST THE FILES IN THIS FOLDER').reason, 'trust-prompt');
});

test('recognises a login screen', () => {
  assert.strictEqual(classifySyncFailure('Select login method\n1. Claude account with subscription').reason, 'login');
  assert.strictEqual(classifySyncFailure('Please run /login to authenticate').reason, 'login');
});

test('recognises the first-run onboarding screens', () => {
  assert.strictEqual(classifySyncFailure('Choose the text style that looks best').reason, 'onboarding');
  assert.strictEqual(classifySyncFailure("Let's get started.").reason, 'onboarding');
});

// The fall-through must preserve today's behaviour exactly: the bare message
// main.js:211 already returns.
test('unrecognised output falls through to unknown with the original message', () => {
  const r = classifySyncFailure('a wall of unrelated build output');
  assert.strictEqual(r.reason, 'unknown');
  assert.strictEqual(r.message, 'could not read /usage');
});

// A more specific screen must win over a looser one when both strings appear in
// the same buffer -- otherwise a scrollback mentioning /login misclassifies a
// live trust prompt.
test('the trust prompt outranks an incidental login mention', () => {
  assert.strictEqual(classifySyncFailure('run /login later\nDo you trust the files in this folder?').reason, 'trust-prompt');
});

test('the scraper exposes its buffer so main.js can classify a failure', () => {
  const { createUsageScraper } = require('../src/main/usageScraper');
  const scraper = createUsageScraper({ configPath: path.join(__dirname, 'fixtures', 'nonexistent.json') });
  assert.strictEqual(typeof scraper.getBuffer, 'function');
  scraper.ingest('Do you trust the files in this folder?');
  assert.match(scraper.getBuffer(), /trust the files/);
});

test('plan:sync returns a reason alongside the legacy error string', () => {
  const src = fs.readFileSync(path.join(__dirname, '..', 'src', 'main', 'main.js'), 'utf8');
  assert.ok(/classifySyncFailure\(/.test(src), 'main.js never classifies the failure');
  assert.ok(/reason: 'no-terminal'/.test(src), 'the no-terminal early return has no reason');
  // The legacy `error` field must survive -- budgets.js and any future consumer
  // read it, and dropping it would be a silent contract break.
  assert.ok(/error:/.test(src));
});

test('budgets.js surfaces the reason rather than only "last sync failed"', () => {
  const src = fs.readFileSync(path.join(__dirname, '..', 'src', 'renderer', 'dashboard', 'panels', 'budgets.js'), 'utf8');
  assert.ok(/syncMessage/.test(src), 'budgets.js does not carry the failure message through');
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test test/syncFailureReason.test.js`
Expected: FAIL — `classifySyncFailure is not a function`.

- [ ] **Step 3: Add the classifier**

Append to `src/shared/usageParser.js`, before the `module.exports` line:

```js
// Poll-failure reasons for plan:sync. Replaces the bare "could not read /usage",
// which was true but useless -- the three screens below are the actual reasons a
// /usage poll comes back empty, and each has a different fix.
//
// CALIBRATION LIMIT, stated rather than hidden: unlike parseUsagePane, these
// patterns are NOT calibrated against a captured fixture -- test/fixtures/ holds
// only usage-pane-real.txt. They are derived from the wording of those screens.
// 'unknown' is the safe fall-through and returns exactly the message this code
// path returned before, so a miss costs nothing beyond the old behaviour.
// Ordered most-specific-first: a live trust prompt must win over a scrollback
// that merely mentions /login.
const SYNC_FAILURE_REASONS = ['no-terminal', 'trust-prompt', 'login', 'onboarding', 'timeout', 'unknown'];

const SYNC_FAILURE_PATTERNS = [
  { reason: 'trust-prompt', re: /do you trust the files in this folder/i,
    message: 'Claude Code is asking whether to trust this folder - answer it in the terminal, then Sync again' },
  { reason: 'onboarding', re: /choose the text style|let's get started|lets get started/i,
    message: 'Claude Code is still on its first-run setup screens - finish them, then Sync again' },
  { reason: 'login', re: /select login method|\/login|log in with your claude account/i,
    message: 'Claude Code is not logged in - run /login in the terminal, then Sync again' },
];

// classifySyncFailure(bufferText) -> { reason, message }
function classifySyncFailure(text) {
  const t = typeof text === 'string' ? text : '';
  for (const pattern of SYNC_FAILURE_PATTERNS) {
    if (pattern.re.test(t)) return { reason: pattern.reason, message: pattern.message };
  }
  return { reason: 'unknown', message: 'could not read /usage' };
}
```

and extend the export:

```js
module.exports = { parseUsagePane, parseLimitWarnings, classifySyncFailure, SYNC_FAILURE_REASONS };
```

- [ ] **Step 4: Expose the buffer from the scraper**

In `src/main/usageScraper.js`, add before the `return` at line 51:

```js
  // main.js's plan:sync classifies a failed poll from this buffer. Read-only
  // access on purpose: nothing outside ingest() may touch it.
  function getBuffer() {
    return buffer;
  }
```

and change the return to:

```js
  return { ingest, getSnapshot, getWarnings, getBuffer, load };
```

- [ ] **Step 5: Return the reason from plan:sync**

In `src/main/main.js`, add `classifySyncFailure` to the `usageParser` requires (add the require if the file does not already import from it):

```js
const { classifySyncFailure } = require('../shared/usageParser');
```

Change the `no terminal` early return (line 179) to:

```js
  if (!activePty) return { ok: false, reason: 'no-terminal', error: 'no terminal' };
```

and replace the final `return { ok: false, error: 'could not read /usage' };` (line 211) with:

```js
  // Nothing parseable arrived within the deadline. The buffer usually says WHY --
  // a trust prompt, a login screen, or first-run onboarding sitting where the
  // /usage pane should be. 'unknown' preserves the old message exactly.
  const { reason, message } = classifySyncFailure(usageScraper.getBuffer());
  return { ok: false, reason, error: message };
```

- [ ] **Step 6: Surface it in the panel**

In `src/renderer/dashboard/panels/budgets.js`, replace the module-level `let syncState = 'idle';` (line 3) with:

```js
  let syncState = 'idle'; // idle | syncing | failed
  let syncMessage = '';   // the reason behind a 'failed' state, from plan:sync
```

Replace both occurrences of the failed-state suffix — currently `' · last sync failed'` at lines 38 and 47 — with:

```js
${syncState === 'failed' ? ' · ' + escapeHtml(syncMessage || 'last sync failed') : ''}
```

and in the click handler (lines 76-84) record it:

```js
        try {
          const res = await window.tokenTracker.plan.sync();
          syncState = res && res.ok ? 'idle' : 'failed';
          syncMessage = res && res.error ? res.error : '';
        } catch (err) {
          syncState = 'failed';
          syncMessage = '';
        }
```

- [ ] **Step 7: Run the tests**

Run: `npm test`
Expected: PASS. `test/usageParser.test.js` and `test/budgetAlarmUnification.test.js` must both still pass untouched — the latter asserts `planBar`'s `const warn = p >= 78;` survives, and nothing here touches it.

- [ ] **Step 8: Capture at least one real screen before calling this done**

The patterns are uncalibrated. Do this, and record the result:

1. `npm start`, open the embedded terminal in a directory Claude Code has never seen, and start `claude`. When the trust prompt appears, click Sync.
2. Expected: the plan-usage hint reads "Claude Code is asking whether to trust this folder…". If it reads "could not read /usage" instead, the pattern is wrong — **copy the actual on-screen text into `test/fixtures/trust-prompt.txt`, add a test asserting `classifySyncFailure` against that fixture, and fix the regex.** Do not adjust the test to match the miss.
3. If a login or onboarding screen cannot be reproduced without disrupting the machine's real Claude Code state, say so in the commit body rather than claiming those two were verified. Two of three verified is a real result; three of three claimed is not.

- [ ] **Step 9: Commit**

```bash
git add src/shared/usageParser.js src/main/usageScraper.js src/main/main.js src/renderer/dashboard/panels/budgets.js test/syncFailureReason.test.js
git commit -m "feat: name the reason a /usage poll failed instead of 'could not read'"
```

---

### Task 14: The quota render model

**Files:**
- Create: `src/shared/quotaState.js`
- Modify: `src/main/ipcHandlers.js` (build the `quota` block in `buildDashboardState`, after `budgetVsQuota` at line 82-88)
- Test: `test/quotaState.test.js`

**Interfaces:**
- Consumes: `fitTokensPerPoint`, `quotaCostForTokens`, `planCostPerPoint`, `SEVEN_DAY_WINDOW_MS`, `MIN_FIT_BUCKETS` (Tasks 3-4); the quota series (Task 11); the statusline snapshot (Task 12); `loadPlanPrice` (Task 5).
- Produces:
  - `buildQuotaState({ samples, monthlyUsd, weekTokens, snapshot }): QuotaState`
  - `QuotaState = { mode: 'unavailable'|'points'|'dollars', tokensPerPoint, buckets, externalBuckets, points, usdPlan, usdPerPoint, monthlyUsd, sevenDayPct, fiveHourPct, capturedAtMs, hint }`
  - Dashboard state gains a `quota` key alongside `budgetVsQuota`.

**The three-state rule, straight from the resolved decisions:**
- `unavailable` — no fit at all (`tokensPerPoint === null`). Render neither points nor dollars.
- `points` — a fit exists but fewer than `MIN_FIT_BUCKETS` buckets carry both signals, **or** no plan price is set. Render quota points only.
- `dollars` — `fit.ready` **and** a positive plan price. Render dollars.

- [ ] **Step 1: Write the failing test**

Create `test/quotaState.test.js`:

```js
// test/quotaState.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const { buildQuotaState } = require('../src/shared/quotaState');

const s = (atMs, usedPercentage, tokens) => ({ atMs, usedPercentage, tokens });
// Four samples -> three contributing buckets at exactly 1M tokens per point.
const READY = [s(1, 10, 0), s(2, 12, 2_000_000), s(3, 15, 5_000_000), s(4, 20, 10_000_000)];
const THIN = [s(1, 10, 0), s(2, 12, 2_000_000), s(3, 14, 4_000_000)]; // two buckets
const SNAP = { capturedAtMs: 777, sevenDay: { usedPercentage: 20, resetsAtMs: 9 }, fiveHour: { usedPercentage: 46, resetsAtMs: 8 } };

test('no samples at all -> unavailable, and no numbers are invented', () => {
  const q = buildQuotaState({ samples: [], monthlyUsd: 200, weekTokens: 5_000_000, snapshot: null });
  assert.strictEqual(q.mode, 'unavailable');
  assert.strictEqual(q.tokensPerPoint, null);
  assert.strictEqual(q.points, null);
  assert.strictEqual(q.usdPlan, null);
  assert.ok(q.hint.length > 0);
});

// Resolved decision: show quota points until 3 buckets carry both signals.
test('a thin fit shows points, never dollars, even with a plan price set', () => {
  const q = buildQuotaState({ samples: THIN, monthlyUsd: 200, weekTokens: 5_000_000, snapshot: SNAP });
  assert.strictEqual(q.mode, 'points');
  assert.strictEqual(q.buckets, 2);
  assert.strictEqual(q.points, 5); // 5M / 1M per point
  assert.strictEqual(q.usdPlan, null);
  assert.match(q.hint, /3 samples|more samples|1 more/i);
});

test('a ready fit with no plan price still shows points only', () => {
  const q = buildQuotaState({ samples: READY, monthlyUsd: 0, weekTokens: 5_000_000, snapshot: SNAP });
  assert.strictEqual(q.mode, 'points');
  assert.strictEqual(q.usdPlan, null);
  assert.match(q.hint, /plan price/i);
});

test('a ready fit with a plan price shows dollars on the seven-day basis', () => {
  const q = buildQuotaState({ samples: READY, monthlyUsd: 200, weekTokens: 5_000_000, snapshot: SNAP });
  assert.strictEqual(q.mode, 'dollars');
  assert.strictEqual(q.buckets, 3);
  assert.strictEqual(q.tokensPerPoint, 1_000_000);
  assert.strictEqual(q.points, 5);
  assert.strictEqual(q.usdPerPoint, 0.5); // 200 / 400
  assert.strictEqual(q.usdPlan, 2.5);
  assert.strictEqual(q.monthlyUsd, 200);
});

// Resolved decision: external usage is surfaced, never folded into the fit.
test('external-usage buckets are reported alongside the fit', () => {
  const withExternal = [s(1, 10, 1_000_000), s(2, 30, 1_000_000)].concat(
    [s(3, 32, 3_000_000), s(4, 34, 5_000_000), s(5, 36, 7_000_000)]
  );
  const q = buildQuotaState({ samples: withExternal, monthlyUsd: 200, weekTokens: 5_000_000, snapshot: SNAP });
  assert.strictEqual(q.externalBuckets, 1);
  assert.strictEqual(q.tokensPerPoint, 1_000_000); // the 20-point external bucket did not drag it down
  assert.strictEqual(q.mode, 'dollars');
});

// The five-hour window is a live gauge only and must never reach a dollar figure.
test('the snapshot gauges pass through, and only the seven-day basis prices anything', () => {
  const q = buildQuotaState({ samples: READY, monthlyUsd: 200, weekTokens: 5_000_000, snapshot: SNAP });
  assert.strictEqual(q.sevenDayPct, 20);
  assert.strictEqual(q.fiveHourPct, 46);
  assert.strictEqual(q.capturedAtMs, 777);
  assert.strictEqual(q.usdPerPoint, 0.5); // the seven-day rate, not 200/13440
});

test('a missing snapshot leaves the gauges null rather than zero', () => {
  const q = buildQuotaState({ samples: READY, monthlyUsd: 200, weekTokens: 5_000_000, snapshot: null });
  assert.strictEqual(q.sevenDayPct, null);
  assert.strictEqual(q.fiveHourPct, null);
  assert.strictEqual(q.capturedAtMs, null);
  assert.strictEqual(q.mode, 'dollars'); // the fit does not need a live snapshot
});

test('hostile inputs produce unavailable rather than NaN', () => {
  for (const args of [{}, { samples: 'x', monthlyUsd: 'y', weekTokens: 'z', snapshot: 'w' }, null]) {
    const q = buildQuotaState(args);
    assert.strictEqual(q.mode, 'unavailable');
    assert.strictEqual(q.points, null);
    assert.strictEqual(q.usdPlan, null);
  }
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test test/quotaState.test.js`
Expected: FAIL — `Cannot find module '../src/shared/quotaState'`.

- [ ] **Step 3: Write the implementation**

Create `src/shared/quotaState.js`:

```js
// src/shared/quotaState.js
// Joins the three quota inputs -- the fitted tokens-per-point, the declared plan
// price, and this week's token total -- into the one shape budgets.js renders.
//
// The mode field encodes both resolved decisions from the spec, in one place so
// the renderer never re-decides them:
//   'unavailable' -- no fit at all. Show neither points nor dollars.
//   'points'      -- a fit exists but fewer than MIN_FIT_BUCKETS buckets carry both
//                    signals, OR no plan price is set. Show quota points.
//   'dollars'     -- fit.ready AND a positive plan price. Show dollars.
const { fitTokensPerPoint, quotaCostForTokens, planCostPerPoint, SEVEN_DAY_WINDOW_MS, MIN_FIT_BUCKETS } = require('@tokenmonitor/core');

const round2 = (n) => Math.round(n * 100) / 100;

function buildQuotaState(args) {
  const a = args && typeof args === 'object' ? args : {};
  const samples = Array.isArray(a.samples) ? a.samples : [];
  const monthlyUsd = typeof a.monthlyUsd === 'number' && Number.isFinite(a.monthlyUsd) && a.monthlyUsd > 0 ? a.monthlyUsd : 0;
  const weekTokens = typeof a.weekTokens === 'number' && Number.isFinite(a.weekTokens) && a.weekTokens > 0 ? a.weekTokens : 0;
  const snapshot = a.snapshot && typeof a.snapshot === 'object' ? a.snapshot : null;

  const fit = fitTokensPerPoint(samples);
  const gauges = {
    sevenDayPct: snapshot && snapshot.sevenDay ? snapshot.sevenDay.usedPercentage : null,
    fiveHourPct: snapshot && snapshot.fiveHour ? snapshot.fiveHour.usedPercentage : null,
    capturedAtMs: snapshot && typeof snapshot.capturedAtMs === 'number' ? snapshot.capturedAtMs : null,
  };

  const base = {
    ...gauges,
    tokensPerPoint: fit.tokensPerPoint,
    buckets: fit.buckets,
    externalBuckets: fit.externalBuckets,
    monthlyUsd,
    points: null,
    usdPlan: null,
    usdPerPoint: null,
  };

  if (fit.tokensPerPoint === null) {
    return {
      ...base,
      mode: 'unavailable',
      hint: 'No quota samples yet - install the live quota feed in Settings, then keep working.',
    };
  }

  // basis is always seven_day: dollars are only ever quoted on that window
  // (resolved decision). The five-hour gauge passes through untouched above.
  const cost = quotaCostForTokens({
    tokens: weekTokens,
    tokensPerPoint: fit.tokensPerPoint,
    monthlyUsd,
    windowMs: SEVEN_DAY_WINDOW_MS,
    basis: 'seven_day',
  });
  const points = cost ? round2(cost.points) : null;

  if (!fit.ready) {
    const needed = MIN_FIT_BUCKETS - fit.buckets;
    return {
      ...base,
      mode: 'points',
      points,
      hint: needed + ' more sample' + (needed === 1 ? '' : 's') + ' before this can be priced in dollars.',
    };
  }

  if (monthlyUsd <= 0) {
    return { ...base, mode: 'points', points, hint: 'Set your monthly plan price in Settings to see this in dollars.' };
  }

  return {
    ...base,
    mode: 'dollars',
    points,
    usdPerPoint: round2(planCostPerPoint(monthlyUsd, SEVEN_DAY_WINDOW_MS)),
    usdPlan: round2(cost.usdPlan),
    hint: '',
  };
}

module.exports = { buildQuotaState };
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `node --test test/quotaState.test.js`
Expected: PASS, 8 tests.

- [ ] **Step 5: Wire it into the dashboard state**

In `src/main/ipcHandlers.js`, add to the requires:

```js
const { buildQuotaState } = require('../shared/quotaState');
const { loadPlanPrice } = require('../shared/planPriceConfig');
```

`planPriceConfigPath`, `getQuotaSeries` and `getStatuslineSnapshot` are already in `registerIpcHandlers`'s parameters (Tasks 5 and 12) — add all three to `buildDashboardState`'s destructured parameters and to both of its call sites.

Inside `buildDashboardState`, immediately after the `budgetVsQuota` object (line 88):

```js
  // Quota cost sits beside budgetVsQuota deliberately: they are the two halves of
  // the same panel, and the seven-day token total below is the SAME number the
  // week budget row uses, so the two readings can never disagree.
  const planPrice = await loadPlanPrice(planPriceConfigPath);
  const quota = buildQuotaState({
    samples: typeof getQuotaSeries === 'function' ? getQuotaSeries() : [],
    monthlyUsd: planPrice.monthlyUsd,
    weekTokens: budgetVsQuota.week.used,
    snapshot: typeof getStatuslineSnapshot === 'function' ? getStatuslineSnapshot() : null,
  });
```

and add `quota,` to the returned object, next to `budgetVsQuota,` (line 112).

- [ ] **Step 6: Pin the wiring**

Append to `test/quotaState.test.js`:

```js
const fs = require('node:fs');
const path = require('node:path');

test('buildDashboardState exposes quota beside budgetVsQuota', () => {
  const src = fs.readFileSync(path.join(__dirname, '..', 'src', 'main', 'ipcHandlers.js'), 'utf8');
  assert.ok(/buildQuotaState\(/.test(src), 'ipcHandlers.js never builds the quota state');
  assert.ok(/\n\s*quota,/.test(src), 'quota is not on the returned dashboard state');
  // The week budget row and the quota figure must read the same token total.
  assert.ok(/weekTokens:\s*budgetVsQuota\.week\.used/.test(src), 'quota uses a different week total than the budget row');
});
```

- [ ] **Step 7: Run the full suite**

Run: `npm test`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add src/shared/quotaState.js test/quotaState.test.js src/main/ipcHandlers.js
git commit -m "feat: build the budget-vs-quota render model"
```

---

### Task 15: Render budget vs quota in the budgets panel

**Files:**
- Modify: `src/renderer/dashboard/panels/budgets.js:52-71` (a quota section above the existing rows)
- Modify: `src/renderer/styles/tokens.css`
- Test: `test/budgetsQuotaMarkup.test.js`

**Interfaces:**
- Consumes: `state.quota` (Task 14) and the existing `state.budgetVsQuota` / `state.alerts` / `state.planUsage`.
- Produces: no exports. The panel keeps its `window.TT.budgetsPanel = { render, tierFor }` surface unchanged.

**A naming trap to avoid:** `budgets.js:71` already renders a heading literally reading `Budget vs. quota` over the four **token-budget** rows, and `state.budgetVsQuota` is the existing token-budget object. The spec's "budget vs quota" means something different — plan quota against the token budget. Do **not** rename `state.budgetVsQuota` or reuse its heading; add a distinct `Plan quota` section and leave the existing heading alone so `test/budgetAlarmUnification.test.js` and the four budget rows keep working exactly as they do.

- [ ] **Step 1: Write the failing test**

Create `test/budgetsQuotaMarkup.test.js`:

```js
// test/budgetsQuotaMarkup.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const src = () => fs.readFileSync(path.join(__dirname, '..', 'src', 'renderer', 'dashboard', 'panels', 'budgets.js'), 'utf8');

test('the panel renders a quota section driven by state.quota', () => {
  const js = src();
  assert.ok(/function quotaSection/.test(js), 'no quotaSection');
  assert.ok(/quotaSection\(state\)/.test(js), 'quotaSection is never rendered');
  assert.ok(/state\.quota/.test(js), 'the panel never reads state.quota');
});

// The renderer must not re-decide points-vs-dollars: quotaState.js owns that,
// and a second copy of the rule here would drift away from the resolved decision.
test('the renderer switches on quota.mode and never recomputes the threshold', () => {
  const js = src();
  assert.ok(/quota\.mode/.test(js), 'the panel does not switch on quota.mode');
  assert.ok(!/MIN_FIT_BUCKETS|buckets\s*[<>]=?\s*3/.test(js), 'the three-bucket rule is duplicated in the renderer');
  assert.ok(!/\/\s*400\b/.test(js), 'the $/point formula is duplicated in the renderer');
});

// Resolved decision: external usage is an indicator, not a silent exclusion.
test('external usage is surfaced when there is any', () => {
  const js = src();
  assert.ok(/externalBuckets/.test(js), 'externalBuckets is never rendered');
  assert.ok(/external/i.test(js), 'no external-usage label');
});

// The existing four token-budget rows and their heading must be untouched.
test('the pre-existing budget rows and heading survive', () => {
  const js = src();
  assert.ok(/Budget vs\. quota/.test(js), 'the existing token-budget heading was removed or renamed');
  assert.ok(/state\.budgetVsQuota\[period\]/.test(js), 'the token-budget row loop was changed');
  assert.ok(/tierFor\(state, period\)/.test(js), 'the row loop no longer drives its colour from state.alerts');
  assert.ok(/const warn = p >= 78;/.test(js), "planBar's own amber check was disturbed");
});

test('no inline colour styles - colours come from CSS classes', () => {
  assert.ok(!/style="color:/.test(src()), 'found an inline color style - move it to a CSS class');
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test test/budgetsQuotaMarkup.test.js`
Expected: FAIL — `no quotaSection`.

- [ ] **Step 3: Add the quota section**

In `src/renderer/dashboard/panels/budgets.js`, add `quotaSection` immediately after `planSection` (which ends at line 50):

```js
  // Plan quota: what this week's work costs against the SUBSCRIPTION, as opposed
  // to the counterfactual API dollars every other figure in this app shows.
  //
  // The points-vs-dollars decision is NOT made here -- quotaState.js's `mode`
  // owns it, because it encodes a resolved product decision (three buckets before
  // dollars) that must not exist in two places. This function only draws.
  function quotaSection(state) {
    const q = state.quota;
    if (!q) return '';

    const external = q.externalBuckets > 0
      ? `<div class="quota-external">${q.externalBuckets} bucket${q.externalBuckets === 1 ? '' : 's'} of usage from elsewhere on this account - excluded from the estimate</div>`
      : '';

    if (q.mode === 'unavailable') {
      return `
      <div class="hero-label">Plan quota</div>
      <div class="quota-hint">${escapeHtml(q.hint)}</div>
      ${external}
      <div class="plan-divider"></div>`;
    }

    // One rate string, built once and used by both remaining branches, so the
    // "tokens per point / N samples" wording can never differ between them.
    const fitText = `${formatTokens(Math.round(q.tokensPerPoint))} tokens per quota point · ${q.buckets} sample${q.buckets === 1 ? '' : 's'}`;

    if (q.mode === 'points') {
      return `
      <div class="hero-label">Plan quota</div>
      <div class="quota-headline">${q.points} <span class="quota-unit">quota points this week</span></div>
      <div class="quota-rate">${fitText}</div>
      <div class="quota-hint">${escapeHtml(q.hint)}</div>
      ${external}
      <div class="plan-divider"></div>`;
    }

    return `
      <div class="hero-label">Plan quota</div>
      <div class="quota-headline">${formatMoney(q.usdPlan)} <span class="quota-unit">of your $${q.monthlyUsd}/mo plan, this week</span></div>
      <div class="quota-rate">${q.points} points at ${formatMoney(q.usdPerPoint)} per point · ${fitText}</div>
      ${external}
      <div class="plan-divider"></div>`;
  }
```

Then change the `el.innerHTML` assignment (line 71) from:

```js
    el.innerHTML = `${planSection(state)}<div class="hero-label">Budget vs. quota</div>${rows}`;
```

to:

```js
    el.innerHTML = `${planSection(state)}${quotaSection(state)}<div class="hero-label">Budget vs. quota</div>${rows}`;
```

Leave everything else in `render` — the row loop, `tierFor`, `fillClass`, `planBar` — exactly as it is.

- [ ] **Step 4: Add the styles**

Append to `src/renderer/styles/tokens.css`:

```css
.quota-headline { font-family: var(--font-display, inherit); font-size: 20px; line-height: 1.2; margin: 2px 0 4px; }
.quota-unit { font-size: 11px; color: var(--tx-muted); }
.quota-rate { font-size: 11px; color: var(--tx-muted); margin-bottom: 4px; }
.quota-hint { font-size: 11px; color: var(--tx-muted); line-height: 1.4; margin-bottom: 4px; }
.quota-external { font-size: 11px; color: var(--warn); line-height: 1.4; margin-bottom: 4px; }
```

If `test/contrast.test.js` or `test/inlineStyles.test.js` rejects a variable name here, read the failing assertion and use the token those tests already accept — do not add an exception for this panel.

- [ ] **Step 5: Run the tests**

Run: `npm test`
Expected: PASS — including `test/budgetAlarmUnification.test.js` and `test/heroTilesMarkup.test.js` untouched.

- [ ] **Step 6: Verify in the real app**

Run: `npm start`.
- With no `quotaSeries.json`: expected "Plan quota — No quota samples yet…". Confirm no `NaN`, no `$0.00`, and no empty headline.
- With a hand-written `~/.claude-token-tracker/quotaSeries.json` containing exactly the four `READY` samples from `test/quotaState.test.js` and a plan price of 200: expected a dollar headline with a `$0.50 per point` rate line. Delete the hand-written file afterwards so the real feed is not polluted with fabricated samples.
- Screenshot both states.

- [ ] **Step 7: Commit**

```bash
git add src/renderer/dashboard/panels/budgets.js src/renderer/styles/tokens.css test/budgetsQuotaMarkup.test.js
git commit -m "feat: show what this week cost against the plan, not against API rates"
```

- [ ] **Step 8: Full-suite green and branch summary**

Run: `npm test`
Expected: PASS, root and core, with `test/noApiCalls.test.js` still green.

Then run `git log --oneline main..HEAD` and confirm 15 commits, one per task.

---

## Self-Review

Run against the spec with fresh eyes after writing the plan.

**1. Spec coverage.** Every in-scope item maps to a task:

| Spec item | Task(s) | Note |
|---|---|---|
| Side finding — pricing-table port | Task 2 | All three named discrepancies confirmed against real line numbers; two further errors (haiku 0.8/4, no verification stamp) found and fixed by the same port |
| Item 1 — `planCostPerPoint` in `packages/core` | Task 3 | Test pins the `monthlyUsd / 400` identity the spec states |
| Item 1 — plan USD beside the `planUsageConfig.js` snapshot | Tasks 5, 6 | `~/.claude-token-tracker/planPrice.json` |
| Item 1 — "budget vs quota" in the budgets panel | Tasks 14, 15 | Distinct `Plan quota` section; the pre-existing `Budget vs. quota` heading over the token rows is deliberately untouched |
| Item 1 — tokens-per-point series | Tasks 4, 7-12 | Statusline feed supplies the percentage series; `quotaSeriesStore` supplies the history; `fitTokensPerPoint` does the fit |
| Item 7 — poll-failure reason enum | Task 13 | Downgraded to a fallback-path improvement, as the decision requires |
| Preferred option — statusline reader port | Tasks 7-12 | Chosen, with the scraper kept; decision and reasoning stated at the top |
| Resolved: 7-day basis for dollars, 5-hour a live gauge | Tasks 3, 12, 14 | `basis: 'seven_day'` is the only value that reaches a dollar; Task 12's test asserts the five-hour window never feeds the fit |
| Resolved: external-usage exclusion + indicator | Tasks 4, 14, 15 | Excluded in `fitTokensPerPoint`, counted in `QuotaFit.externalBuckets`, rendered in `quotaSection` |
| Resolved: points until 3 buckets, then dollars | Tasks 4, 14, 15 | `MIN_FIT_BUCKETS`, `fit.ready`, `quota.mode`; a renderer test forbids duplicating the rule |
| Resolved: isolated worktree on a feature branch | Task 1 | |
| Global: zero API cost, `noApiCalls` boundary | Task 1 | The guard did not exist; Task 1 creates it and Step 5 proves it bites |

Out of scope by the task framing and untouched here: aether-os items 1-6 of the spec, and md2's per-card boards / worktree UI / remote control.

**2. Placeholder scan.** No `TBD`, no "implement later", no "add appropriate error handling", no "similar to Task N". Every code step carries the actual code. Two steps deliberately require *observation* rather than prescribing an outcome — Task 10 Step 9 (statusline coexistence with aether-os) and Task 13 Step 8 (capturing a real trust-prompt screen). Both name exactly what to run, what to expect, and what to do if the expectation is wrong, including "do not adjust the test to match the miss." That is a verification instruction, not a placeholder.

**3. Type consistency.** Checked across tasks:
- `QuotaSample` is `{ atMs, usedPercentage, tokens }` in Task 4 (core), Task 11 (store), and Task 12 (the append call in `main.js`) — same three field names throughout.
- `QuotaFit` fields `tokensPerPoint / buckets / externalBuckets / ready / resets` are produced in Task 4 and consumed by name in Task 14; `ready` is read only there, and only `mode` crosses into Task 15.
- `fitTokensPerPoint` is called from `quotaState.js` (Task 14) as `fitTokensPerPoint(samples)` — the single-argument signature Task 4 defines.
- `quotaCostForTokens` takes one options object in Task 3 and is called with exactly those five keys in Task 14.
- `planCostPerPoint(monthlyUsd, windowMs)` is positional in Task 3 and called positionally in Task 14.
- The statusline snapshot's `sevenDay.usedPercentage` / `fiveHour.usedPercentage` / `capturedAtMs` come from Task 7's parser and are read under those exact names in Tasks 12 and 14.
- `plan:sync`'s result gains `reason` while keeping `error` (Task 13) — `budgets.js` reads `res.error`, which Task 13 preserves rather than renames.
- Installer exports in Task 9 match the three names Task 10's IPC handlers require.
- `MIN_FIT_BUCKETS` is defined once (Task 4) and referenced from `quotaState.js` only; Task 15's test actively forbids a second copy in the renderer.

**Fixed inline during review:**
- Task 15 initially reused the existing `Budget vs. quota` heading. That heading already labels the four **token-budget** rows and `state.budgetVsQuota` is the token-budget object — reusing either would have collided with `test/budgetAlarmUnification.test.js` and made two different things share one name. The quota block is now a separate `Plan quota` section, and Task 15's test asserts the old heading and row loop survive intact.
- Task 12's `appendSample` call originally wrote to disk on every statusline payload. Since `appendSample` enforces a five-minute floor and returns an unchanged series when the sample is dropped, that would have been a disk write per turn for nothing; the wiring now writes only when the series actually grew.
- Task 15's dollars branch originally rebuilt the rate line by string-replacing the `<div>` wrapper off the points branch's markup — a fragile way to share one sentence. It now builds a single `fitText` string used by both branches, so the wording can never differ between them.
- Task 9's `extractChainedCommand` originally used aether's plain `Buffer.from(x, 'base64')` decode. Node's base64 decoder is lenient and would return junk for a non-base64 `--chain` argument, so the port adds a round-trip check — and the test asserts `null` for `!!!notbase64!!!`.

**Known gap, stated rather than hidden:** Task 13's trust-prompt / login / onboarding regexes are the one part of this plan not grounded in a real captured artifact — `test/fixtures/` contains only `usage-pane-real.txt`. `unknown` falls through to today's exact message, so a miss costs nothing, and Task 13 Step 8 requires capturing at least one real screen before the task is called done.
