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
