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
