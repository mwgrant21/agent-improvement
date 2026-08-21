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

### When catching filesystem read errors, only swallow ENOENT - propagate everything else instead of silently undercounting

- A `try { readdir/readFile } catch { treat as empty/zero }` pattern should only
  catch the specific case the fallback is meant for (path legitimately doesn't
  exist yet - `ENOENT`). Any other error (permissions, I/O failure, corrupt
  data) must propagate as a real error, not get folded into the same "treat as
  empty" branch - that turns a real failure into a silent undercount with no
  error signal.
- Why: the two failure modes look identical from the caller's side (both
  produce a lower-than-expected count) but have opposite correct handling -
  one is expected and recoverable, the other is a bug that needs surfacing.
- Evidence: 2026-08-08 session (aether-os PR #14) - fix verified and pushed:
  "non-ENOENT subagent-directory read errors now propagate instead of
  silently undercounting," 1006/1006 tests passing afterward.
- Added: 2026-08-10 (home-matt)

### Suppress shell profile/rc loading when a pty/subprocess is used to control environment variables

- When code spawns a shell inside a pty (or any subprocess) specifically to
  control or strip environment variables, pass the shell's no-profile flag
  (`-NoProfile` for PowerShell, `--norc --noprofile` for bash, `-f` for zsh).
  Without it, the user's own `~/.bashrc`/`$PROFILE`/etc. can silently
  re-export a variable that the calling code just stripped, defeating the
  intended env control with no error.
- Why: the leak is invisible from the calling code's perspective - it set the
  environment correctly before spawning: the re-export happens entirely
  inside the shell's own startup sequence, outside the parent process's view.
- Evidence: 2026-08-09 session (aether-os `fix/pty-shell-profile-leak`,
  merged as PR #18) - fix applied `-NoProfile` (PowerShell), `--norc
  --noprofile` (bash), and `-f` (zsh) "so `~/.bashrc`/`$PROFILE` can't
  silently re-export a var that was just stripped from the pty's
  environment"; 991/991 tests passing on master afterward.
- Added: 2026-08-10 (home-matt)

### When you fix a rule on one code path, apply and TEST it on the sibling/nested path in the same pass

- Scanners, ingesters and walkers usually have a top-level loop and a nested
  (child/subagent/recursive) loop. A rule added to one is routinely absent from
  the other, and the miss is invisible: the feature demonstrably works, just on
  half the corpus. Enumerate every loop that handles the same entity before
  calling such a fix done, and assert the new behaviour on the nested path
  specifically - a pre-existing test that covers a NEIGHBOURING behaviour on
  that path reads as coverage of the path and is why these gaps survive.
- Why: the failure is silent and quantitatively large, not a crash. Totals stay
  plausible while a majority of the input is skipped, so no error surfaces to
  prompt the check.
- Evidence: 2026-08-10 Aether-OS - the nested `subagents/*.jsonl` loop ingested
  tool calls and anomalies but never called `ingestUsageEvent`. Fix off vs on
  over the real `~/.claude/projects` corpus: 12,514 -> 26,420 usage events and
  15.3M -> 21.5M tokens, i.e. 53% of events and 28.6% of tokens (6.15M) were
  invisible; the scan tracks 373 nested files against 58 top-level ones. The
  existing nested-subagent test asserted tool calls only, which is exactly why
  the gap survived (commit `278e76b`, issue #25). Three defects that day had
  this identical shape, including `collector-go` having no `subagents/` handling
  at all and a missing `tool_calls.source_file_rel` write (#29, #32).
- See also [[two-implementations-of-one-contract-need-a-parity-harness]] - the harness that turns this
  class from "found by running the app" into a red test.
- Added: 2026-08-11 (work-it)

### A guard that stops a bad state RECURRING heals nothing already in it - migrations must read the physical schema, not the recorded version

- Two fixes are needed whenever a bug has been writing bad persistent state:
  stop it happening again, AND converge machines already broken. Shipping only
  the guard leaves the exact population the fix most needed to reach still
  crashing. Concretely for schema migrations: drive column migrations off the
  columns physically present (`pragma_table_info` / `addColumnIfMissing`), never
  off a recorded version integer, so a database that is version-ahead, stamped
  backwards, or partly migrated converges instead of throwing.
- Why: a version-gated block (`if (currentVersion < 5) ALTER TABLE ... ADD
  COLUMN`) re-runs against a column that already exists and throws `duplicate
  column name`, and an unguarded throw at startup means the user cannot rescue
  the machine by upgrading either. Verifying the fix on a FRESH database says
  nothing - the round trip runs clean there by construction.
- Evidence: 2026-08-10 Aether-OS - #31's guard stopped `collector-go` stamping
  the version downwards, but a database physically at v6/v7 recorded as 4 (the
  state the pre-#31 Go collector left behind) still crashed both collectors at
  `index.ts:49`. Caught by a Codex P1 review on PR #35 after the crash had been
  demonstrated and not noticed. Fixed in `b08ae74` and proven end to end -
  migrate to v7, stamp back to 4, migrate again - with a regression test in both
  collectors watched failing first on the real error.
- Added: 2026-08-11 (work-it)

### Centralizing a setting is not centralizing its guarantee

- When moving a setting into a shared helper so callers "no longer have to
  remember it", check whether the setting's EFFECT is also centralized. If the
  value still only takes effect when each caller does something else as well,
  the helper has moved the code without moving the invariant - and the comment
  claiming otherwise makes it harder to spot, not easier.
- Why: a setting that reads as centrally guaranteed but is conditionally
  effective fails exactly when a second caller appears. The first caller usually
  works by coincidence, so the defect ships green and stays invisible until
  someone adds the caller that does not know the extra step.
- Evidence: 2026-08-12 Aether-OS issue #41. `schema.OpenDatabase` set
  `PRAGMA busy_timeout = 5000` via `db.Exec` after `sql.Open`, commented "set
  here rather than left to each caller to remember". True of the pragma, false
  of the guarantee: a PRAGMA binds to the connection that ran it, and
  `database/sql` hands later queries any pooled connection. Holding four
  connections open reported `5000, 0, 0, 0`. Production was unexposed only
  because the single caller also set `SetMaxOpenConns(1)` for an unrelated
  reason. Fixed by moving it into the DSN, where the driver applies it per
  connection regardless of caller.
- See also [[a-static-name-keyed-lookup-table-silently-drops]].
- Added: 2026-08-12 (work-it)

### A restrictive shell Job Object can break Chromium's sandboxed subprocess creation, masquerading as a GPU/driver crash

- When an Electron app's GPU process crashes on startup (e.g.
  `STATUS_BREAKPOINT`/"GPU process isn't usable") and every GPU-flag
  workaround (disable-hardware-acceleration, in-process-gpu,
  disable-gpu-sandbox, disable-gpu-compositing) either fails to fix it or
  "fixes" the crash while breaking rendering entirely, suspect the sandboxed
  subprocess creation path itself rather than the GPU/driver. A restrictive
  shell Job Object (e.g. one applied by a CLI runner or terminal wrapper) can
  block Chromium's sandbox from spawning subprocesses, which presents
  identically to a GPU/driver fault. Diagnose with `--no-sandbox` before
  cycling further GPU flags.
- Why: multiple sessions independently chased this as a wedged GPU/WDDM
  session state or a hybrid-AMD-driver mismatch - both plausible-looking
  explanations that cost several diagnostic passes (cache clears, driver
  inventory, reboot recommendation) before the real cause (sandboxed
  subprocess creation blocked by the invoking shell's Job Object) was found
  and verified end to end via the actual launch command, not a manual
  electron.exe invocation.
- Evidence: 2026-08-11 sessions (tarot/TokenMonitor, home-matt) - four
  GPU-flag combinations tried and ruled out one at a time; root cause
  identified as the restrictive shell Job Object breaking Chromium's
  sandboxed subprocess creation; fix verified via `npm run electron`
  launching clean; `GPU-CRASH-NOTES.md` updated to prevent the stale WDDM
  theory from misleading a future session.
- Added: 2026-08-12 (home-matt)

### Before deep local diagnosis of an Electron GPU-process crash, check the Electron version against recent releases/issues

- When an Electron app crashes with the `STATUS_BREAKPOINT`/`exit_code=-2147483645`
  "GPU process isn't usable" signature (or any crash-shaped symptom in a
  fast-moving dependency), do a cheap external check FIRST, before multi-session
  local diagnosis: (1) compare the app's pinned Electron version against a
  working sibling app on the same machine if one exists, (2) search the
  Electron GitHub issue tracker for the exact error string, and (3) check
  whether a newer patch release exists and what its changelog says. Only after
  that comes up empty should local hypotheses (GPU driver, WDDM state, shell
  Job Object, sandbox flags) get multi-session investigation time.
- Why: this exact symptom has now had two DIFFERENT confirmed root causes on
  this machine in the same month - a restrictive shell Job Object breaking
  sandboxed subprocess creation (2026-08-12, see above), and an orphaned
  AppContainer SID in the user profile's ACL breaking sandbox token
  construction (2026-08-19, below). Neither is a GPU/driver problem despite
  the error text; both are the kind of thing a GitHub issue search surfaces in
  minutes because other users hit the identical string. A reboot (tried and
  ruled out 2026-08-19) or a driver reinstall would not have fixed either one -
  cheap external triage would have pointed at the real mechanism immediately
  instead of after a full local diagnostic pass.
- Evidence: 2026-08-19 session (TokenMonitorV2 reskin-phases-3-4, home-matt) -
  root-caused by diffing a working app's Electron version (35.7.5) against the
  failing one (43.3.0) on identical hardware, confirmed with a single-variable
  swap test, then bisected the actual break point (35.7.5 good, 36.0.0+ bad)
  across 5 version installs before a web search surfaced
  github.com/electron/electron/issues/51761 - the real cause (orphaned
  `S-1-15-2-*` AppContainer SID from a stale sandbox registration, inherited
  into `C:\Users\<user>`'s ACL, breaking `CHECK(InitializeICU())` in the
  sandboxed child process before any GPU code runs). Fixing the ACL (`icacls
  ... /remove:g`) let the app run clean on the latest Electron (43.4.1,
  released the same day) with zero version downgrade needed - the bisection
  work was real but unnecessary, and would have been skippable entirely with
  an issue-tracker search up front.
- Added: 2026-08-19 (home-matt)
