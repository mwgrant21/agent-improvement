# App-Dev Lessons

Durable, graded lessons for application development (Electron, Android, web).
Format per `README.md` in this directory.

### Write setup-completion flags only after long first-run work finishes

- When an app does long first-run work (asset extraction, migration, downloads),
  persist the "setup done" flag only after the work fully completes - never before
  or during. An interrupted run then self-heals by re-running on next launch.
- Why: mobile devices interrupt long work routinely (screen doze froze extraction
  mid-way on a Samsung device); a flag written early would strand the app with
  partial assets and no recovery path.
- Evidence: TarotApp Android image extraction 2026-07-14 - extraction froze at
  22/65 files during screen doze, and because the setup flag is only written on
  completion, relaunch resumed and reached 65/65 verified on device.
- Added: 2026-07-14 (home-matt)

### Persisted-state whitelists silently drop new fields unless added explicitly

- Whenever a persistence layer gates saved/rehydrated state through an explicit
  field whitelist, adding a new state field must also add it to that whitelist
  in the same change - otherwise the field is silently dropped or desynced on
  reload, not erred on.
- Why: this is a recurring bug class across projects with a whitelist-based
  persistence layer, not a one-off. TokenMonitor's own `uiConfig.js#sanitize` is
  documented as exactly this shape (new `ui.json` keys must be added to both
  `UI_DEFAULTS` and `sanitize`). A sibling project hit the same shape: `memSeq`
  was left out of the persistence whitelist (unlike `memories`/`selectedMemory`),
  so reloading reset the id counter while keeping the higher-id memories,
  producing duplicate ids on the next creation.
- Evidence: 2026-07-19 session - reviewer caught "memSeq ... isn't in the
  persistence whitelist, so reloading resets the id counter while keeping the
  higher-id memories, causing duplicate ids on the next creation."
- Added: 2026-07-20 (home-matt)

### Fix an Electron sandbox/preload module-format mismatch by fixing the build, not by disabling the sandbox

- When a preload script fails under Electron's sandbox because of an ESM/CJS
  module-format mismatch, fix the build output format (force CJS output for the
  preload bundle) rather than disabling `contextIsolation`/`sandbox` to make the
  error go away.
- Why: disabling the sandbox "fixes" the symptom by removing the security
  boundary; the actual defect is a build-config mismatch that has a real fix.
- Evidence: 2026-07-20 session (aether-os Electron real-terminal Phase 1) - a
  fix subagent was dispatched "forcing CJS output for the preload build (the
  correct fix) rather than disabling Electron's sandbox."
- Added: 2026-07-20 (home-matt)

### `tsc -b` and `--noEmit` conflict in composite/project-reference TypeScript setups

- Never invoke `tsc --build` (`tsc -b`) together with `--noEmit`. In a tsconfig
  using `composite`/project `references`, `tsc -b --noEmit` errors on the config
  itself; plain `tsc -b` is the correct typecheck-and-build command in that
  setup, matching whatever `npm run build` already runs. If a task brief
  specifies the combined flag, fix the brief - do not let an implementer "fix"
  the symptom by ripping out the composite project reference instead.
- Why: an implementer facing the `tsc -b --noEmit` error removed the root
  tsconfig's composite project reference to make the flag combination pass - an
  unplanned, out-of-scope config change that the reviewer had to catch and
  question before approving. The actual fix was simpler: drop `--noEmit` from
  the command, not the project reference from the config.
- Evidence: 2026-07-21 session (aether-os real-Active-Agents plan, Task 1) -
  reviewer flagged "the implementer mentions an unplanned tsconfig change
  ('removed composite project reference') - that's outside the brief's scope";
  orchestrator then corrected all remaining task briefs to "use plain `tsc -b`,
  NOT `tsc -b --noEmit` - this project's composite tsconfig setup errors on
  that flag combination."
- Added: 2026-07-21 (home-matt)

### Verify a bleeding-edge Node API's minimum version before setting the CI matrix

- When a project uses a newer Node core API (e.g. `node:sqlite`), don't assume
  the current LTS or an existing CI matrix entry (e.g. `20.x`) covers it. Check
  the API's actual minimum Node version and set the CI matrix to match (e.g.
  `22.x`/`24.x`), rather than discovering the gap when that matrix leg fails.
- Why: the failure is silent until CI runs - the code works fine locally on a
  newer local Node version, so the mismatch only surfaces as a CI-only failure
  that looks unrelated to the actual cause.
- Evidence: 2026-07-28 session (aether-os) - CI matrix included Node `20.x`;
  `node:sqlite` (used throughout collector/electron store) requires Node 22.5+,
  so that leg could never pass. Fixed by changing the matrix to `22.x`/`24.x`;
  confirmed green afterward.
- Added: 2026-07-29 (work-it)

### A stale compiled `.js` file can silently shadow its `.ts` source in dev vs. packaged Electron modes

- When a TS/Electron project has compiled `.js` output sitting alongside its
  `.ts` source, check whether dev mode and the packaged/Electron build path
  resolve the same file. If one path can pick up a stale compiled `.js` while
  the other reads the live `.ts`, edits to the source silently stop taking
  effect in whichever mode reads the stale file - with no error.
- Why: this class of bug is invisible to a single task's review (the source
  edit looks correct in isolation); it only surfaces when dev and packaged
  behavior are compared directly, which is exactly what a final whole-branch
  review does that per-task review does not - see
  [[a-final-whole-branch-review-is-required-after-task-level-reviews]].
- Evidence: 2026-07-27 session (aether-os chat-ipc-correctness branch) - final
  whole-branch review found "a compiled-`.js`-shadowing-source issue" (plus a
  related silent key-parsing divergence between dev and Electron modes) after
  all 7 per-task reviews had already passed clean; both fixed in one wave and
  re-verified.
- Added: 2026-07-29 (work-it)

### A static name-keyed lookup table silently drops namespaced/plugin-scoped variants of the key

- When a lookup table maps subagent/tool identifiers to behavior (e.g. a role or
  voice map keyed by bare name like `code-reviewer`), check whether the real
  dispatch strings can also arrive namespaced (e.g. `pr-review-toolkit:code-reviewer`).
  A table with only the bare name silently falls through to the default/fallback
  entry for every namespaced variant, with no error - add the namespaced forms
  explicitly rather than assuming exact-match coverage.
- Why: this is the same defect class as [[persisted-state-whitelists-silently-drop-new-fields]]
  (a whitelist/lookup gate silently drops unlisted variants instead of erroring) applied
  to a different lookup mechanism - static name-keyed maps, not persistence whitelists.
- Evidence: 2026-08-04 session (aether-os Stage 12 voice packs follow-up) - `ROLE_MAP`
  in `agentVoiceRoles.ts` only had plain names, so `pr-review-toolkit:code-reviewer`
  fell through to the FORGE fallback; validated against real production transcripts
  showing 44 real dispatches for the plugin-scoped form vs. 2 for the unmapped variant.
- Added: 2026-08-04 (home-matt)

### Snapshot a rolling baseline before recording the new value, not after

- When computing a metric relative to a rolling baseline (e.g. "is this duration
  slower than the median for this type"), read/snapshot the baseline BEFORE
  updating it with the current observation, then record the observation after.
  Recording first and comparing second makes every observation partially compare
  against itself, skewing the metric toward "normal" no matter how anomalous the
  real value is.
- Why: self-comparison silently defeats the purpose of the baseline - the bug
  produces no error, just quietly wrong severity/anomaly output.
- Evidence: 2026-08-04 session (aether-os Stage 12 severity wiring) - `durationBaseline.ts`
  implementation required getting `getMedianMs` before `recordDuration` in the same
  tick to avoid the current sample skewing its own comparison.
- Added: 2026-08-04 (home-matt)

### Extend a well-tested data pipeline with an optional out-param and render-time lookups, not by changing its return type or coupling arrival order

- Two techniques for adding new derived data to code that other tests/consumers
  already depend on: (1) when a function's return type is exercised by many
  existing tests, add the new data via an additional optional parameter (an
  out-array the caller passes in) rather than changing the return type -
  existing callers and tests are untouched by construction. (2) when multiple
  independent consumers need to react to the new data as it arrives on its own
  timeline, have each consumer look the data up by key at its own render/use
  time (e.g. `state.newField[key]`) rather than threading it through at
  creation time - this avoids ordering dependencies between independently
  arriving data pipelines.
- Why: preserves existing tests and callers untouched while adding new
  capture logic; the render-time lookup pattern lets independent consumers
  each pick up the new data with no coordination code between their arrival
  order and the base pipeline.
- Evidence: aether-os Phase 3 Slice 7 (real dispatch token/tool-use/duration
  tracking), 2026-07-24 - `applyLinesToOpenDispatches` gained an optional
  third `completedOut?` parameter instead of a new return shape, preserving
  12 pre-existing tests; Memory/Chat/Analytics consumers each look up
  `state.dispatchUsage[toolUseId]` at their own render/prompt-build time
  rather than at creation time.
- Added: 2026-07-24 (home-matt)

### Before treating an Electron "blank/white screen" as a code regression, check whether the build output is actually complete

- When a packaged/dev Electron app loads to a blank or white window, check that
  every expected subdirectory of the build output (e.g. `out/main/`,
  `out/preload/`, `out/renderer/`) actually exists and is populated - not just
  that the build command exited 0 or that the folder exists at all. A build
  interrupted partway through (killed process, prior crashed session) can leave
  `main`/`preload` present while `renderer` (the actual HTML/JS/CSS the window
  loads) is entirely missing, which presents identically to a real loading bug.
- Why: a partial build directory from an earlier interrupted run looks like a
  normal, if stale, build output at a glance - the missing-subdirectory case
  only surfaces by explicitly listing what's inside, not by assuming a build
  that "ran before" is complete.
- Evidence: 2026-07-30 session (aether-os) - white-screen bug diagnosed as
  "not a code defect - a stale/incomplete local `out/` build was missing
  `out/renderer/` entirely," likely "from an earlier interrupted build before
  this session"; a full rebuild populated `index.html`/JS/CSS/fonts and the
  full e2e suite (4/4, including previously-timing-out terminal/dashboard
  tests) passed afterward.
- A fresh clone is the cheap way to rule this class out entirely: it carries no
  `out/` history, so whatever launches is provably built from the commit under
  test rather than from something an earlier run left on disk. Prefer live-testing
  a throwaway clone over the working copy when the question is "does this commit
  work," not "does my working tree work."
- Added: 2026-08-03 (work-it)

### A fallback that fires only when the data source is UNAVAILABLE will serve stale data forever

- When a read path prefers a cache/store and falls back to a live computation,
  make the fallback condition include STALENESS, not just unavailability. A
  guard of the shape `if (store.read() === null) rescan()` fires for an
  unopenable DB or an outdated schema - and never for a store that opens fine,
  matches the schema, and stopped being written to weeks ago. Check the newest
  row's timestamp, not just that rows came back, and surface "this data source is
  dead" rather than rendering its emptiness as a real zero.
- Why: a dead-but-readable source is the common failure, and it produces a
  plausible number instead of an error. A dashboard that reports "you used
  nothing this month" is indistinguishable from a correct one until it is
  compared against another view derived from the live path - which is how this
  was caught, not by any test.
- Evidence: 2026-08-10 live-test session (Aether-OS v0.2.0) - `scanAndPushUsage()`
  in `electron/main.ts:337` fell back to a full transcript scan only when
  `readUsageEventsSince` returned `null`. `~/.aether-os/collector.db` opened fine
  at schema v4 with 8,728 rows, but its newest row was 2026-07-30 - the collector
  had been dead 11 days. It returned 5,324 stale non-null rows, the fallback
  never fired, and every dashboard usage tile rendered `0` while the Ledger -
  derived from an unconditional fresh scan in the same pass - read $889.44. Filed
  as issue #19.
- Added: 2026-08-10 (work-it)

### Never sum cache-read tokens into a context-window figure, and clamp any derived percentage

- Claude usage records report `cacheReadInputTokens` as the whole accumulated
  context re-counted on every turn. Summing all four token fields of the latest
  turn therefore measures cumulative reads, not occupancy - it produces figures
  far larger than the window itself. Context-window utilization is input +
  output (+ cache-creation), never cache reads. Independently, clamp any
  percentage rendered from a computed ratio: an unclamped bar is what turns a
  units bug into a visibly absurd number instead of a quietly wrong one.
- Why: this trap recurs within the same codebase - one token-math function gets
  fixed for it and a later one reintroduces it, because the field sits alongside
  the legitimate ones in the same record and summing "all tokens" looks correct.
  Treat any new token-math site as suspect by default and check which fields it
  sums. Watch for a second symptom nearby: two views disagreeing on the window
  denominator.
- Evidence: 2026-08-10 live-test session (Aether-OS v0.2.0) - the footer CONTEXT
  WINDOW card rendered **663% USED** (828,967 / 128,000) because
  `computeContextWindow` summed all four fields including `cacheReadInputTokens`
  - the exact trap `usageTokens()` had already been fixed for once per the repo's
  own PROGRESS.md. The Dashboard tile and the footer card also disagreed on the
  denominator (200.0K vs 128,000). Filed as issue #20.
- Added: 2026-08-10 (work-it)
