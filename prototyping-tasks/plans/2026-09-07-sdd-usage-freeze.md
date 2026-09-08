# SDD Usage Freeze Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a `sdd-tracking` requirement closes, stamp an immutable token-usage summary into its one-line `.sdd/STATE.md` `## Completed` entry, so "what did this feature cost" is answered by reading the file instead of recomputing it later.

**Architecture:** Add a `**Started:**` timestamp to the REQ section at creation time (Phase 1), so a close-time window has a start bound. Add a new read-only helper script, `Get-SddUsage.ps1`, that scans this machine's local Claude Code session transcripts (`~/.claude/projects/<slug>/*.jsonl`), sums the `usage` block on every assistant message whose `gitBranch` matches the REQ's branch and whose `timestamp` falls inside `[Started, now]`, and prints one compact YAML flow-mapping line. Phase 3 (close) runs that script before deleting the REQ section, then appends its output to the collapsed `## Completed` line. Quota-points fields are stamped `null` — no quota-to-token conversion exists yet (that's item 1/2 of the source spec, a separate aether-os/TokenMonitorV2 effort); the shape leaves room for it.

**Tech Stack:** PowerShell 5.1 (matches every existing script in this skill — `New-SddRequirement.ps1`, `Get-SddStatus.ps1`, `Update-SddTask.ps1`, `Test-MachineGates.ps1` are all `.ps1`, none has a PS7+ dependency). No new external dependencies — `ConvertFrom-Json` and `Get-ChildItem -Recurse` are both PS5.1-native.

**Spec:** `C:\Users\Matt\agent-improvement\prototyping-tasks\quota-normalized-cost-2026-09-07.md`, companion item 6 only ("Freeze usage totals at REQ close").

## Global Constraints

- PowerShell 5.1 compatible — no `??`, no ternary `?:`, no null-conditional `?.` (per `C:\Users\Matt\.claude\rules\powershell.md`).
- `Write-Output` only, never `Write-Host` (breaks pipeline capture in this environment's other tooling).
- Every new/edited `.ps1` file saved as **UTF-8 without BOM**; use `Set-Content -Encoding UTF8NoBOM -NoNewline` for file writes, exactly like the three existing scripts in this directory.
- `$ErrorActionPreference = 'Stop'` at the top of every script, wrapped in one top-level `try/catch` that prints `"ERROR: $($_.Exception.Message)"` via `Write-Output` and exits non-zero — matches the existing house style in this skill's scripts.
- Straight ASCII quotes only (`"`, `'`) — never smart quotes or em dashes in script content.
- Literal `{`/`}` inside a double-quoted string must be backtick-escaped, or (preferred here) avoid the problem by building the output line with single-quoted string concatenation instead of interpolation.
- Do not modify `Get-SddStatus.ps1`, `Update-SddTask.ps1`, or `Test-MachineGates.ps1` — none of their regexes depend on field order inside a REQ section, and this plan's `**Started:**` addition sits between two fields none of them anchor against (verified in Task 1's regression check).
- This is a plan for **new/edited files inside `C:\Users\Matt\.claude\skills\sdd-tracking\`** (the skill itself was read-only research for this planning pass — do not touch it while planning; the plan below is what an executor changes).
- Data source is local session transcripts only (`~/.claude/projects/*/​*.jsonl`) — no dependency on the aether-os usage collector (a separate session is actively editing that repo) and no dependency on any not-yet-built quota-to-dollars conversion.
- Known, accepted limitation (documented in Task 2, not solved by this plan): transcripts are per-machine. A REQ worked from both home and work machines before the store's home&lt;-&gt;work sync catches up will under-count until both machines' `~/.claude/projects` trees are available at close time. This mirrors md2's own admitted limit ("account usage includes other projects on the same account") — call it out, don't silently hide it.

---

### Task 1: Stamp a `Started` timestamp when a REQ is created

**Files:**
- Modify: `C:\Users\Matt\.claude\skills\sdd-tracking\scripts\New-SddRequirement.ps1:65` (the `$reqSection` assignment)
- Modify: `C:\Users\Matt\.claude\skills\sdd-tracking\SKILL.md:43-61` (the "State file" fenced format block)

**Interfaces:**
- Consumes: nothing new — same `$nextId`, `$Title`, `$branchName`, `$criteriaLines` locals already in scope at that line.
- Produces: every new REQ section now contains a `- **Started:** <UTC ISO-8601 timestamp>` line between `**Branch:**` and `**Acceptance criteria:**`. Task 2's `Get-SddUsage.ps1` reads this field by name (regex `\*\*Started:\*\*\s*(\S+)`) when given `-ReqId` without an explicit `-StartTime`.

- [ ] **Step 1: Edit `New-SddRequirement.ps1` to stamp the timestamp**

Change line 65 from:

```powershell
    $reqSection = "`n## REQ-${nextId}: $Title`n- **Status:** in-progress`n- **Branch:** $branchName`n- **Acceptance criteria:**`n$criteriaLines- **Tasks:**`n"
```

to:

```powershell
    $startedStamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $reqSection = "`n## REQ-${nextId}: $Title`n- **Status:** in-progress`n- **Branch:** $branchName`n- **Started:** $startedStamp`n- **Acceptance criteria:**`n$criteriaLines- **Tasks:**`n"
```

- [ ] **Step 2: Update the State file format block in `SKILL.md`**

Change (lines 43-61):

```markdown
## REQ-<N>: <title>
- **Status:** in-progress | blocked | ready-for-review | merged
- **Branch:** <branch-name>
- **Acceptance criteria:**
  1. <criterion>
  2. <criterion>
- **Tasks:**
  - [ ] TASK-<N>.1: <description>
  - [x] TASK-<N>.2: <description>

## Completed
- REQ-<M>: <title> (merged <date>)
```

to:

```markdown
## REQ-<N>: <title>
- **Status:** in-progress | blocked | ready-for-review | merged
- **Branch:** <branch-name>
- **Started:** <UTC ISO-8601 timestamp, stamped by New-SddRequirement.ps1>
- **Acceptance criteria:**
  1. <criterion>
  2. <criterion>
- **Tasks:**
  - [ ] TASK-<N>.1: <description>
  - [x] TASK-<N>.2: <description>

## Completed
- REQ-<M>: <title> (merged <date>) - usage: { input: <N>, output: <N>, cache_creation: <N>, cache_read: <N>, total: <N>, sessions: <N>, quota_points: null, quota_basis: null }
```

- [ ] **Step 3: Regression-safe verification in a scratch git repo**

Run in Bash (do not run this against any real project repo):

```bash
mkdir -p /c/Users/Matt/AppData/Local/Temp/claude/C--Users-Matt/1126a512-febb-47e0-9dcf-bfc3e945e989/scratchpad/sdd-task1-repo
cd /c/Users/Matt/AppData/Local/Temp/claude/C--Users-Matt/1126a512-febb-47e0-9dcf-bfc3e945e989/scratchpad/sdd-task1-repo
git init -q
git commit -q --allow-empty -m "init"
```

Then in PowerShell, from that same directory:

```powershell
& "C:\Users\Matt\.claude\skills\sdd-tracking\scripts\New-SddRequirement.ps1" -Title "Test Started Stamp" -Criteria "It has a Started field"
Get-Content .sdd\STATE.md -Raw
```

Expected: output includes a line matching `- **Started:** \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z` positioned between the `**Branch:**` line and `**Acceptance criteria:**`.

- [ ] **Step 4: Regression check — existing scripts still parse the file**

Still in that scratch repo:

```powershell
& "C:\Users\Matt\.claude\skills\sdd-tracking\scripts\Get-SddStatus.ps1" -ReqId 1
```

Expected: prints `REQ-1: Test Started Stamp`, `Status: in-progress`, a `Branch:` line, `Tasks: 0/0 complete`, and the `Acceptance criteria:` list with "It has a Started field" — i.e. unaffected by the new field. If this fails, `Get-SddStatus.ps1` needs no code change (its regexes don't anchor on adjacency), so a failure here means the Step 1 edit broke the file's structure, not that Get-SddStatus.ps1 needs touching.

- [ ] **Step 5: Clean up the scratch repo**

```bash
rm -rf /c/Users/Matt/AppData/Local/Temp/claude/C--Users-Matt/1126a512-febb-47e0-9dcf-bfc3e945e989/scratchpad/sdd-task1-repo
```

- [ ] **Step 6: Commit**

```bash
cd ~/.claude
git add "C:\Users\Matt\.claude\skills\sdd-tracking\scripts\New-SddRequirement.ps1" "C:\Users\Matt\.claude\skills\sdd-tracking\SKILL.md"
git commit -m "sdd-tracking: stamp Started timestamp on REQ creation"
```

(Only if `~/.claude/skills` is itself a git-tracked location on this machine — if it is not under version control, skip this step and note the file changes were made directly.)

---

### Task 2: `Get-SddUsage.ps1` — compute frozen usage totals from local session transcripts

**Files:**
- Create: `C:\Users\Matt\.claude\skills\sdd-tracking\scripts\Get-SddUsage.ps1`

**Interfaces:**
- Consumes: `.sdd/STATE.md`'s `**Branch:**` and `**Started:**` fields (added in Task 1) when called with `-ReqId` and no explicit `-Branch`/`-StartTime`. Also consumes the Claude Code transcript JSONL format directly: each line is a JSON object with top-level `gitBranch` (string), `timestamp` (ISO-8601 UTC string), `sessionId` (string), and (for assistant messages only) `message.usage` with `input_tokens`, `output_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens` (all integers, any of which may be absent/zero).
- Produces: exactly one line on stdout, format:
  `usage: { input: <int>, output: <int>, cache_creation: <int>, cache_read: <int>, total: <int>, sessions: <int>, quota_points: null, quota_basis: null }`
  Task 3 pastes this line, appended after `(merged <date>)`, into the `## Completed` entry.

- [ ] **Step 1: Write the script**

Create `C:\Users\Matt\.claude\skills\sdd-tracking\scripts\Get-SddUsage.ps1`:

```powershell
<#
.SYNOPSIS
    Computes frozen usage totals (tokens, session count) for a REQ from local
    Claude Code session transcripts (~/.claude/projects/<slug>/*.jsonl),
    filtered by git branch and a start/end time window. Prints a single
    compact YAML flow-mapping line ready to append to the REQ's one-line
    entry under .sdd/STATE.md's "## Completed" section.
.NOTES
    PowerShell 5.1 compatible. Read-only: never writes to STATE.md itself -
    sdd-tracking's Phase 3 (close) pastes the printed line by hand.

    Known limitation: transcripts are per-machine. A REQ worked from more
    than one machine will under-count here unless every machine's
    ~/.claude/projects tree is reachable at close time (e.g. via
    -TranscriptsRoot pointed at a merged copy). This mirrors md2's own
    admitted limit that account-level usage includes other work on the
    same account - this script has the analogous per-machine version of
    that gap.
#>
param(
    [int]$ReqId,
    [string]$Branch,
    [Nullable[datetime]]$StartTime,
    [Nullable[datetime]]$EndTime,
    [string]$RepoNameFilter,
    [string]$TranscriptsRoot = (Join-Path $env:USERPROFILE ".claude\projects")
)

$ErrorActionPreference = 'Stop'

try {
    if (-not $EndTime) {
        $EndTime = Get-Date
    }

    if ($ReqId -and ((-not $Branch) -or (-not $StartTime))) {
        $repoRoot = (git rev-parse --show-toplevel 2>$null)
        if (-not $repoRoot) {
            Write-Output "ERROR: not inside a git repository, and -Branch/-StartTime were not both supplied."
            exit 1
        }
        $repoRoot = $repoRoot.Trim()
        $statePath = Join-Path (Join-Path $repoRoot ".sdd") "STATE.md"
        if (-not (Test-Path $statePath)) {
            Write-Output "ERROR: no .sdd/STATE.md found at $statePath"
            exit 1
        }
        $content = Get-Content -Path $statePath -Raw
        $reqPattern = "(?ms)^## REQ-$($ReqId):.*?\r?\n(.*?)(?=^## |\z)"
        $reqMatch = [regex]::Match($content, $reqPattern)
        if (-not $reqMatch.Success) {
            Write-Output "ERROR: REQ-$ReqId not found in $statePath"
            exit 1
        }
        $body = $reqMatch.Groups[1].Value

        if (-not $Branch) {
            $branchMatch = [regex]::Match($body, '\*\*Branch:\*\*\s*(\S+)')
            if ($branchMatch.Success) {
                $Branch = $branchMatch.Groups[1].Value
            }
        }
        if (-not $StartTime) {
            $startedMatch = [regex]::Match($body, '\*\*Started:\*\*\s*(\S+)')
            if ($startedMatch.Success) {
                $StartTime = [datetime]::Parse($startedMatch.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
            }
        }
        if (-not $RepoNameFilter) {
            $RepoNameFilter = Split-Path $repoRoot -Leaf
        }
    }

    if (-not $Branch) {
        Write-Output "ERROR: -Branch is required (directly, or resolvable from -ReqId's .sdd/STATE.md 'Branch' field)."
        exit 1
    }
    if (-not $StartTime) {
        Write-Output "ERROR: -StartTime is required (directly, or resolvable from -ReqId's .sdd/STATE.md 'Started' field - REQs created before this field existed have none)."
        exit 1
    }

    if (-not (Test-Path $TranscriptsRoot)) {
        Write-Output "ERROR: transcripts root not found: $TranscriptsRoot"
        exit 1
    }

    # Normalize both bounds to UTC. .NET DateTime comparison compares ticks and
    # ignores Kind, so a Local-kind Get-Date or a PowerShell [datetime] cast
    # (which converts "...Z" to Local) must not be compared against the
    # Utc-kind values RoundtripKind produces for transcript timestamps.
    $StartTime = ([datetime]$StartTime).ToUniversalTime()
    $EndTime = ([datetime]$EndTime).ToUniversalTime()

    $totalInput = [int64]0
    $totalOutput = [int64]0
    $totalCacheCreation = [int64]0
    $totalCacheRead = [int64]0
    $sessionIds = @{}

    $jsonlFiles = Get-ChildItem -Path $TranscriptsRoot -Filter "*.jsonl" -Recurse -File
    foreach ($file in $jsonlFiles) {
        if ($RepoNameFilter -and ($file.DirectoryName -notlike "*$RepoNameFilter*")) {
            continue
        }
        $lines = Get-Content -Path $file.FullName
        foreach ($line in $lines) {
            if ($line -notlike '*"usage"*') {
                continue
            }
            $entry = $null
            try {
                $entry = $line | ConvertFrom-Json
            }
            catch {
                continue
            }
            if (-not $entry) { continue }
            if ($entry.gitBranch -ne $Branch) { continue }
            if (-not $entry.timestamp) { continue }

            $ts = $null
            try {
                $ts = [datetime]::Parse($entry.timestamp, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
            }
            catch {
                continue
            }
            $ts = $ts.ToUniversalTime()
            if ($ts -lt $StartTime -or $ts -gt $EndTime) { continue }

            $usage = $entry.message.usage
            if (-not $usage) { continue }

            if ($usage.input_tokens) { $totalInput += [int64]$usage.input_tokens }
            if ($usage.output_tokens) { $totalOutput += [int64]$usage.output_tokens }
            if ($usage.cache_creation_input_tokens) { $totalCacheCreation += [int64]$usage.cache_creation_input_tokens }
            if ($usage.cache_read_input_tokens) { $totalCacheRead += [int64]$usage.cache_read_input_tokens }
            if ($entry.sessionId) { $sessionIds[$entry.sessionId] = $true }
        }
    }

    $grandTotal = $totalInput + $totalOutput + $totalCacheCreation + $totalCacheRead
    $sessionCount = $sessionIds.Count

    $line = 'usage: { input: ' + $totalInput + ', output: ' + $totalOutput + ', cache_creation: ' + $totalCacheCreation + ', cache_read: ' + $totalCacheRead + ', total: ' + $grandTotal + ', sessions: ' + $sessionCount + ', quota_points: null, quota_basis: null }'
    Write-Output $line
}
catch {
    Write-Output "ERROR: $($_.Exception.Message)"
    exit 1
}
```

- [ ] **Step 2: Save it as UTF-8 without BOM**

If the file was created with a plain text-editor write, verify encoding:

```powershell
$bytes = [System.IO.File]::ReadAllBytes("C:\Users\Matt\.claude\skills\sdd-tracking\scripts\Get-SddUsage.ps1")
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Output "BOM DETECTED - re-save without BOM"
} else {
    Write-Output "OK: no BOM"
}
```

Expected: `OK: no BOM`.

- [ ] **Step 3: Build a synthetic JSONL fixture in the scratchpad**

```powershell
$fixtureDir = "C:\Users\Matt\AppData\Local\Temp\claude\C--Users-Matt\1126a512-febb-47e0-9dcf-bfc3e945e989\scratchpad\sdd-usage-fixture\proj-fake-repo"
New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null

$lines = @(
    '{"gitBranch":"req-9-usage-freeze","timestamp":"2026-09-07T10:00:00.000Z","sessionId":"sess-a","message":{"role":"assistant","usage":{"input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":10,"cache_read_input_tokens":5}}}',
    '{"gitBranch":"req-9-usage-freeze","timestamp":"2026-09-07T11:00:00.000Z","sessionId":"sess-a","message":{"role":"assistant","usage":{"input_tokens":200,"output_tokens":75,"cache_creation_input_tokens":0,"cache_read_input_tokens":20}}}',
    '{"gitBranch":"req-9-usage-freeze","timestamp":"2026-09-07T12:00:00.000Z","sessionId":"sess-b","message":{"role":"assistant","usage":{"input_tokens":300,"output_tokens":125,"cache_creation_input_tokens":15,"cache_read_input_tokens":0}}}',
    '{"gitBranch":"some-other-branch","timestamp":"2026-09-07T10:30:00.000Z","sessionId":"sess-c","message":{"role":"assistant","usage":{"input_tokens":9999,"output_tokens":9999,"cache_creation_input_tokens":9999,"cache_read_input_tokens":9999}}}',
    '{"gitBranch":"req-9-usage-freeze","timestamp":"2026-09-06T09:00:00.000Z","sessionId":"sess-d","message":{"role":"assistant","usage":{"input_tokens":5000,"output_tokens":5000,"cache_creation_input_tokens":5000,"cache_read_input_tokens":5000}}}',
    '{"gitBranch":"req-9-usage-freeze","timestamp":"2026-09-07T10:15:00.000Z","sessionId":"sess-e","message":{"role":"user","content":"no usage block on user messages"}}',
    'not even json, should be skipped without crashing but matches the "usage" substring check below on purpose: "usage"'
)
Set-Content -Path (Join-Path $fixtureDir "fake-session.jsonl") -Value $lines -Encoding UTF8NoBOM
```

Hand-computed expected totals for lines that should count (both `sess-a` lines and the `sess-b` line — matching branch, timestamps inside `2026-09-07T09:00:00Z` .. `2026-09-07T13:00:00Z`, and have a real `usage` block on an assistant message):
- input: 100 + 200 + 300 = 600
- output: 50 + 75 + 125 = 250
- cache_creation: 10 + 0 + 15 = 25
- cache_read: 5 + 20 + 0 = 25
- total: 900
- sessions: 2 (`sess-a`, `sess-b`)

Excluded and why: `sess-c` (wrong branch), `sess-d` (right branch, timestamp a day before the window), the user-role line (no `message.usage`), the malformed JSON line (fails `ConvertFrom-Json`, caught and skipped).

- [ ] **Step 4: Run the script against the fixture**

```powershell
& "C:\Users\Matt\.claude\skills\sdd-tracking\scripts\Get-SddUsage.ps1" `
    -Branch "req-9-usage-freeze" `
    -StartTime ([datetime]"2026-09-07T09:00:00Z") `
    -EndTime ([datetime]"2026-09-07T13:00:00Z") `
    -TranscriptsRoot "C:\Users\Matt\AppData\Local\Temp\claude\C--Users-Matt\1126a512-febb-47e0-9dcf-bfc3e945e989\scratchpad\sdd-usage-fixture"
```

Expected exact output:

```
usage: { input: 600, output: 250, cache_creation: 25, cache_read: 25, total: 900, sessions: 2, quota_points: null, quota_basis: null }
```

- [ ] **Step 5: Clean up the fixture**

```powershell
Remove-Item -Recurse -Force "C:\Users\Matt\AppData\Local\Temp\claude\C--Users-Matt\1126a512-febb-47e0-9dcf-bfc3e945e989\scratchpad\sdd-usage-fixture"
```

- [ ] **Step 6: Commit**

```bash
cd ~/.claude
git add "C:\Users\Matt\.claude\skills\sdd-tracking\scripts\Get-SddUsage.ps1"
git commit -m "sdd-tracking: add Get-SddUsage.ps1 to freeze token totals from session transcripts"
```

(Skip if `~/.claude/skills` is not itself under version control on this machine — note the file was added directly instead.)

---

### Task 3: Wire the usage freeze into Phase 3 (close a requirement)

**Files:**
- Modify: `C:\Users\Matt\.claude\skills\sdd-tracking\SKILL.md:79-81` (Phase 3 section)

**Interfaces:**
- Consumes: `Get-SddUsage.ps1`'s single-line stdout (Task 2) and `New-SddRequirement.ps1`'s `**Started:**` field (Task 1).
- Produces: the documented close procedure other sessions/agents follow — no new code interface, this task only changes the skill's own instructions.

- [ ] **Step 1: Rewrite the Phase 3 section**

Change (lines 79-81):

```markdown
## Phase 3: Close a requirement

When a REQ's PR merges: Edit `.sdd/STATE.md` — remove its full `## REQ-N` section and add one line under `## Completed`: `- REQ-N: <title> (merged <date>)`.
```

to:

```markdown
## Phase 3: Close a requirement

When a REQ's PR merges, in this order (the usage freeze needs the REQ's `**Branch:**` and `**Started:**` fields, which the next step deletes):

1. Run `scripts/Get-SddUsage.ps1 -ReqId <N>` from the repo root. It reads `**Branch:**` and `**Started:**` from the still-open REQ-N section, scans this machine's `~/.claude/projects/*/*.jsonl` session transcripts for that branch between `Started` and now, and prints one line: `usage: { input: <N>, output: <N>, cache_creation: <N>, cache_read: <N>, total: <N>, sessions: <N>, quota_points: null, quota_basis: null }`.
   - REQs created before the `**Started:**` field existed have no start bound — `Get-SddUsage.ps1` errors asking for an explicit `-StartTime`; if none is known, use the REQ's branch creation date (`git log --format=%aI <branch> | tail -1` gives the first commit's timestamp as a reasonable proxy) or omit the usage suffix entirely rather than inventing a number.
   - This total is per-machine (see the script's `.NOTES`) — if the REQ was worked from more than one machine, say so when reporting the frozen total rather than presenting a partial sum as complete.
2. Edit `.sdd/STATE.md` — remove the full `## REQ-N` section and add one line under `## Completed`: `- REQ-N: <title> (merged <date>) - <the usage line from step 1>`.

The frozen line is never recomputed after this point — that is the point of freezing it. If token pricing or the quota-points conversion (see companion aether-os/TokenMonitorV2 work) becomes available later, a future REQ's close can fill in `quota_points`/`quota_basis`; do not retroactively edit an already-closed REQ's line for that.
```

- [ ] **Step 2: End-to-end manual walkthrough**

Reuse the fixture-building approach from Task 2 to prove the full documented flow reads naturally start to finish (this step exercises the *procedure*, not new code — `Get-SddUsage.ps1` itself was already unit-tested in Task 2):

```powershell
$repoDir = "C:\Users\Matt\AppData\Local\Temp\claude\C--Users-Matt\1126a512-febb-47e0-9dcf-bfc3e945e989\scratchpad\sdd-task3-repo"
New-Item -ItemType Directory -Path $repoDir -Force | Out-Null
Push-Location $repoDir
git init -q
git commit -q --allow-empty -m "init"

& "C:\Users\Matt\.claude\skills\sdd-tracking\scripts\New-SddRequirement.ps1" -Title "Usage Freeze Walkthrough" -Criteria "Demonstrates the close flow"

# Simulate the fixture step 3 from Task 2, but with the real branch name New-SddRequirement.ps1 just created:
$state = Get-Content .sdd\STATE.md -Raw
$branchName = [regex]::Match($state, '\*\*Branch:\*\*\s*(\S+)').Groups[1].Value
$startedStamp = [regex]::Match($state, '\*\*Started:\*\*\s*(\S+)').Groups[1].Value
Write-Output "Branch: $branchName"
Write-Output "Started: $startedStamp"

$fixtureDir = Join-Path $repoDir "fixture\proj-walkthrough"
New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null
$fixtureLine = '{"gitBranch":"' + $branchName + '","timestamp":"' + $startedStamp.TrimEnd('Z') + '.500Z","sessionId":"sess-walkthrough","message":{"role":"assistant","usage":{"input_tokens":42,"output_tokens":17,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'
Set-Content -Path (Join-Path $fixtureDir "walkthrough.jsonl") -Value @($fixtureLine) -Encoding UTF8NoBOM

$usageLine = & "C:\Users\Matt\.claude\skills\sdd-tracking\scripts\Get-SddUsage.ps1" -ReqId 1 -TranscriptsRoot (Join-Path $repoDir "fixture") -RepoNameFilter "proj-walkthrough"
Write-Output $usageLine
Pop-Location
```

Expected: `$usageLine` equals `usage: { input: 42, output: 17, cache_creation: 0, cache_read: 0, total: 59, sessions: 1, quota_points: null, quota_basis: null }` (the fixture's one message falls exactly one second after `Started`, inside the `[Started, now]` window).

- [ ] **Step 3: Hand-apply the documented close edit and confirm the file stays well-formed**

Still with `$repoDir`, `$usageLine` in scope:

```powershell
$statePath = Join-Path $repoDir ".sdd\STATE.md"
$content = Get-Content -Path $statePath -Raw
$content = $content -replace '(?ms)^## REQ-1:.*?(?=^## Completed)', ''
$content = $content -replace '(?m)^## Completed', "## Completed`n- REQ-1: Usage Freeze Walkthrough (merged 2026-09-07) - $usageLine"
Set-Content -Path $statePath -Value $content -Encoding UTF8NoBOM -NoNewline
Get-Content -Path $statePath -Raw

& "C:\Users\Matt\.claude\skills\sdd-tracking\scripts\Get-SddStatus.ps1" -ReqId 1
```

Expected: the printed `STATE.md` shows no `## REQ-1` section anymore, and one line under `## Completed` containing both `(merged 2026-09-07)` and the full `usage: { ... }` block. `Get-SddStatus.ps1 -ReqId 1` prints `ERROR: REQ-1 not found in ...` (exit 0, per its fail-quiet design) — expected, since the REQ is now closed and collapsed.

- [ ] **Step 4: Clean up**

```powershell
Remove-Item -Recurse -Force "C:\Users\Matt\AppData\Local\Temp\claude\C--Users-Matt\1126a512-febb-47e0-9dcf-bfc3e945e989\scratchpad\sdd-task3-repo"
```

- [ ] **Step 5: Commit**

```bash
cd ~/.claude
git add "C:\Users\Matt\.claude\skills\sdd-tracking\SKILL.md"
git commit -m "sdd-tracking: wire Get-SddUsage.ps1 into the Phase 3 close procedure"
```

(Skip if `~/.claude/skills` is not itself under version control on this machine — note the file was edited directly instead.)

---

## Notes for whoever executes this plan

- Nothing in this plan touches `acceptance-criteria-reviewer` or `Test-MachineGates.ps1` — the usage line is informational, never a gating acceptance criterion, and is not itself `[check: ...]`-taggable (it's a summary of the past, not a pass/fail condition).
- `quota_points`/`quota_basis` stay `null` until the aether-os/TokenMonitorV2 companion work (spec items 1-5) lands a `tokensPerPoint` conversion. When that lands, extend `Get-SddUsage.ps1` with an optional `-TokensPerPoint`/`-QuotaBasis` pair of parameters rather than hardcoding a rate — do not guess at that conversion here.
- If `~/.claude/skills` turns out not to be a git repository on this machine, every "Commit" step above is a no-op to skip, not a blocker — say so rather than forcing a `git init` on a shared skills directory.
