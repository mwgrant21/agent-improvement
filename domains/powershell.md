# PowerShell

Durable PowerShell / PDQ / sysadmin lessons. Seeded 2026-07-12 by migrating the
"Known Issues / Lessons Learned" section out of `~/.claude/rules/codex.md` (which is now
the pattern & script index). New lessons arrive via the agent-learn loop or
ps-script-learner. Reusable CODE patterns stay in codex.md / the `ps-codex` skill.

### Escape curly braces correctly in strings

- In double-quoted strings escape literal `{` / `}` with a backtick. In `-f` format
  strings double them: `{{` / `}}`. Never use `${}` - use `$()` subexpressions.
- Why: unescaped braces are parsed as subexpressions/format tokens and break the string.
- Evidence: migrated from codex.md.
- Added: 2026-07-12 (home-matt)

### Save scripts as UTF-8 without BOM

- Use UTF-8 no BOM. Never copy-paste from Word/browser - smart quotes and em dashes
  silently break scripts.
- Why: a BOM or a smart quote makes the parser fail in ways that are hard to spot.
- Evidence: migrated from codex.md.
- Added: 2026-07-12 (home-matt)

### HKCU under SYSTEM is the wrong hive

- Under SYSTEM (e.g. PDQ Deploy), `HKCU:` points to the SYSTEM account hive, not the
  logged-on user's. Resolve the user's SID and use `HKU:\<SID>` instead.
- Why: registry writes land in the wrong hive and appear to "do nothing" for the user.
- Evidence: migrated from codex.md.
- Added: 2026-07-12 (home-matt)

### Set $ErrorActionPreference = 'Stop' at the top

- Always set `$ErrorActionPreference = 'Stop'` at script top. Never set
  `SilentlyContinue` globally.
- Why: without Stop, non-terminating errors slip past try/catch and the script "succeeds"
  after failing.
- Evidence: migrated from codex.md.
- Added: 2026-07-12 (home-matt)

### Never use Write-Host in logging

- Use `Write-Output` (or `Write-Verbose` for debug). Write-Host bypasses the pipeline and
  breaks PDQ Deploy log capture.
- Why: PDQ captures the pipeline, not the host; Write-Host output is lost from logs.
- Evidence: migrated from codex.md.
- Added: 2026-07-12 (home-matt)

### Put #Requires -RunAsAdministrator first

- Make `#Requires -RunAsAdministrator` the first line of admin scripts so they terminate
  early with a clear error when not elevated.
- Why: fails fast with a readable message instead of a confusing mid-run access error.
- Evidence: migrated from codex.md.
- Added: 2026-07-12 (home-matt)

### schtasks stderr becomes a terminating error under Stop

- schtasks.exe writes warnings (e.g. "time is in the past") to stderr. Piping
  `2>&1 | Out-Null` turns that into error objects, which become terminating under
  `$ErrorActionPreference = 'Stop'`. Fix: use `Register-ScheduledTask` cmdlets for
  reliable error handling, or omit `2>&1` so PowerShell does not capture stderr.
- Why: a benign schtasks warning aborts the whole script.
- Evidence: migrated from codex.md.
- Added: 2026-07-12 (home-matt)

### Use ASCII only in scripts

- No em dashes, box-drawing characters, or smart quotes anywhere in strings or comments -
  they break parsing when a file is re-encoded (e.g. baked into an image). Run
  `LC_ALL=C grep -n '[^[:print:][:space:]]'` before shipping.
- Why: re-encoding mangles non-ASCII bytes and the script fails to parse.
- Evidence: migrated from codex.md.
- Added: 2026-07-12 (home-matt)

### Validate extracted config values before using them in a comparison

- When a regex pulls a field out of frontmatter/config text (e.g. a date string) for
  use in an ordinal or `-ge`/`-le` comparison, validate its shape first and fall back to
  a safe sentinel (e.g. `1970-01-01`) if it doesn't match. Do not trust the raw
  extracted string.
- Why: a malformed value (typo, stray text) can lexicographically compare `>=` a valid
  value and silently suppress the intended branch forever - a fail-open hook becomes a
  fail-closed one with no error or log line to point at it.
- Evidence: daily-triage-onstart.ps1 - `$lastRun` was compared directly against
  `$today` (`yyyy-MM-dd`); a non-date `last_run` value would compare `-ge` true and the
  SessionStart trigger would never fire again. Fixed by validating
  `$lastRun -match '^\d{4}-\d{2}-\d{2}$'` and defaulting to `1970-01-01` otherwise.
- Added: 2026-07-14 (home-matt)

### Gate a rescue/remediation script on what the operation implies, not on an identifier snapshotted earlier

- When a script guards a destructive operation, prefer a guard derived from the
  operation itself (partition size, type GUID, presence of the file being replaced)
  over one that matches an identifier captured at an earlier point in time (volume
  serial, drive letter, saved partition number). Snapshot identifiers go stale
  exactly when the recovery path is needed.
- Why: a stale-identity guard reads as safety but is really a time bomb - it refuses
  to run, or worse targets the wrong object, precisely in the recovery scenario it
  was written for.
- Evidence: 2026-08-04 sessions (EFIPartitionRemediation / BootRescue incident).
  `3-FLIP-ESPTYPE.cmd` gated on volume serial `5408-4987`; reformatting the ESP
  produces a new serial, so the rescue script would have correctly refused to run
  mid-incident on the machine it existed to rescue. Same class: a stale
  `NewESPPartitionNumber` in saved state, and diskpart section labels that were
  correct when written and wrong when used. Fix applied was parameterizing on
  `/part` + `/size` - properties of the partition being operated on.
- Corollary (2026-08-05, work-it): the same staleness applies on the TIME axis
  within a single run. A precondition that can lapse mid-run - a suspended
  security agent, a maintenance window, a lease, a token - must be re-checked
  immediately before EVERY destructive step, not once at script entry. Evidence:
  EFIPartitionRemediation, where the SentinelOne minifilter can re-arm between
  steps; the settled design re-checks the filter before each destructive step
  rather than gating once at the top, because "verified at entry" is a snapshot
  of a value that is free to change while the script is still running.
- Added: 2026-08-05 (work-it)

### A diagnostic script must refuse on an unmet precondition, not plough on emitting errors

- Check the one precondition every section depends on (disk online, service
  running, share reachable) at the top and exit with a clear message naming it.
  Do not let the script run all its sections and emit a wall of
  "cannot find the path specified".
- Why: a diagnostic that fails quietly into noise is worse than one that refuses -
  mid-incident the operator must read a dozen misleading failures to infer the one
  real cause, and may misdiagnose from them.
- Evidence: 2026-08-04 session (EFIPartitionRemediation) - the collection script
  ran through twelve sections producing path errors while disk 0 was simply
  offline; agent noted "a diagnostic tool that fails quietly into noise is worse
  than one that refuses."
- Added: 2026-08-05 (work-it)

### Build a fleet rescue USB from full Windows install media, not a minimal WinPE image

- Standardize rescue/recovery media on full Windows install media matching the
  target build. A stripped Rufus/WinPE image silently lacks common tools and
  storage drivers.
- Why: the missing tool is discovered mid-incident on someone's unbootable laptop,
  which is the worst possible time to find out.
- Evidence: 2026-08-04 session (EFIPartitionRemediation boot incident) - a minimal
  WinPE image lacked expected tools and could not read disk 0; the working
  hypothesis became "switch to install media that ships broader storage drivers,"
  which is a completely different remediation path than the BCD repair being
  attempted.
- Added: 2026-08-05 (work-it)

### `mountvol` reports success on invalid usage, and the Storage provider caches away the letter it just added

- Two traps when scripting ESP/volume work with `mountvol`:
  1. `mountvol` invoked with a missing or malformed drive-letter argument exits
     **0**. `$LASTEXITCODE -eq 0` is therefore not evidence the mount happened -
     verify by testing the path itself (`Test-Path "$Letter\EFI"`), not the exit code.
  2. The Storage provider caches volume state, so `Get-Volume` / `Get-Partition`
     can report no drive letter for a volume `mountvol` just lettered. Re-query
     through the filesystem or force a provider refresh instead of trusting the
     first read back.
- Why: together these produce the worst failure shape - the script believes the
  mount succeeded (exit 0), then the verification step believes it failed (stale
  cache), so the true state is invisible from either signal alone.
- Evidence: 2026-08-06 session (EFI-wt-migration, Task 3 review) - both traps had
  already caused real failures on this box and the task review was aimed
  specifically at them.
- Added: 2026-08-06 (work-it)

### `ConvertFrom-Json` is case-insensitive and rejects keys that differ only in case

- PS 5.1's `ConvertFrom-Json` builds a case-INSENSITIVE dictionary, so a JSON
  file containing two keys differing only in case throws
  `DuplicateKeysInJsonString` and NOTHING in the file parses. JavaScript is
  case-sensitive and reads the same file fine. When a JSON file is owned by a
  JS/Node tool, parse it with Node, not PowerShell - match the semantics of
  whatever writes it.
- Why: the failure is total and misleading. It looks like file corruption rather
  than a dialect difference, and it blocks the whole document over two keys that
  the owning application considers distinct and valid.
- Evidence: 2026-08-12, snapshotting `~/.claude.json`. It held
  `C:/Users/IT/.claude`, `C:/users/it/.claude`, and `C:/Users/it/.claude` -
  three keys for one Windows directory, created by launching `claude` from
  differently-cased shells. `ConvertFrom-Json` refused the entire 63KB file;
  Node parsed it without complaint. The snapshot scripts were rewritten in Node
  for that reason, and a dedupe script later collapsed the variants.
- Added: 2026-08-12 (work-it)

### An Intune-delivered policy is absent from the GPO registry path - read PolicyManager, not Policies

- A setting delivered by Intune/MDM does NOT appear under
  `HKLM:\SOFTWARE\Policies\Microsoft\<Area>` (the GPO location). It lands under
  `HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\<Area>`, and it lands there
  as a CSP triplet - `<Name>_ProviderSet`, `<Name>_WinningProvider`,
  `<Name>_ADMXInstanceData` - with NO plain `<Name>` value to read. A script that
  probes the GPO path, or that probes PolicyManager for the bare ADMX value name,
  gets "absent" on a machine where the policy is demonstrably active and enforcing.
  Concrete instance: BitLocker's `FixedDrivesRequireEncryption` exists only as
  `FixedDrivesRequireEncryption_ProviderSet=1` (alongside `RequireDeviceEncryption=1`)
  under `PolicyManager\current\device\BitLocker`; the GPO path
  `Policies\Microsoft\FVE` was present with 19 other values and no
  `FDVDenyWriteAccess` at all.
- Why: the negative result is indistinguishable from a genuinely unmanaged machine, so
  a detector built on the GPO path reports every affected unit as clear. Worse, the
  wrong path is the intuitive one - the ADMX setting and the CSP share a name, which
  makes "same value, different hive" a very easy assumption to write down as fact.
- Also: the defect shipped behind a doc comment asserting the CSP "lands on that same
  value", "confirmed against Microsoft Learn, not assumed." A comment claiming
  verification is not evidence of verification; only a capture from a machine in the
  affected state settles it. Related: [[inspect-the-artifact-itself-not-proxies]].
- Evidence: 2026-09-01 session (EFIPartitionRemediation, work-it) - `Invoke-EFIPreScan.ps1`
  read PolicyManager and correctly identified the confirmed SARAHC_L3 cause on
  2026-08-28, while `Invoke-EFIDiagnostic.ps1` checked the two FVE paths, found both
  empty on a healthy laptop, and concluded the policy "isn't here". The archived
  SARAHC_L3 prescan capture, taken while the machine was blocked, contradicted the
  comment directly.
- Added: 2026-09-02 (work-it)
