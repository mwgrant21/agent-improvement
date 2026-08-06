#Requires -Version 5.1
<#
.SYNOPSIS
    Installs the agent-improvement loop machinery onto this machine.

.DESCRIPTION
    The lessons in this repo travel by git. The machinery that FEEDS them -
    the SessionStart/Stop hooks and the agent-learn / loop-design skills -
    lives here too, but Claude Code only discovers skills under
    ~/.claude/skills. This script bridges that gap.

    Run it once on any machine that should participate in the learning loop:

        pwsh -File ~/agent-improvement/bootstrap.ps1

    It is idempotent. Run it again after a git pull to pick up skill changes.

    Hooks are NOT copied - settings.json points directly at
    $env:USERPROFILE\agent-improvement\hooks\, so they update on git pull with
    no install step. Only skills need copying, because of where Claude Code
    looks for them.

.PARAMETER Check
    Report status and exit without writing anything. Same checks, no changes.

.NOTES
    Write-Host is used intentionally for coloured interactive console output.
    This is a one-time setup script, never a PDQ Deploy step.
#>
[CmdletBinding()]
param([switch]$Check)

$ErrorActionPreference = 'Stop'

$store      = Join-Path $env:USERPROFILE 'agent-improvement'
$claudeDir  = Join-Path $env:USERPROFILE '.claude'
$skillsSrc  = Join-Path $store 'skills'
$skillsDst  = Join-Path $claudeDir 'skills'
$hooksDir   = Join-Path $store 'hooks'
$settings   = Join-Path $claudeDir 'settings.json'

$problems = 0
function Say { param($Msg, $Colour = 'Gray') Write-Host $Msg -ForegroundColor $Colour }
function Bad { param($Msg) $script:problems++; Write-Host "  [X] $Msg" -ForegroundColor Red }
function Ok  { param($Msg) Write-Host "  [ok] $Msg" -ForegroundColor Green }

Say ""
Say "agent-improvement bootstrap  (machine: $env:COMPUTERNAME, user: $env:USERNAME)" 'Cyan'
Say "store: $store"
Say ""

# --- 1. store present -------------------------------------------------------
Say "1. Store" 'White'
if (-not (Test-Path $store)) {
    Bad "Store not found at $store. Clone mwgrant21/agent-improvement there first."
    Say ""
    Say "Nothing else can be checked without it." 'Yellow'
    exit 1
}
Ok "present"

# --- 2. hook scripts --------------------------------------------------------
Say ""
Say "2. Hook scripts (referenced directly from settings.json - no install needed)" 'White'
$expected = @('agent-learn-onstart.ps1', 'capture-lesson-buffer.ps1', 'daily-triage-onstart.ps1')
foreach ($h in $expected) {
    $p = Join-Path $hooksDir $h
    if (Test-Path $p) { Ok $h } else { Bad "$h MISSING from $hooksDir" }
}

# --- 3. settings.json wiring ------------------------------------------------
Say ""
Say "3. settings.json wiring" 'White'
if (-not (Test-Path $settings)) {
    Bad "settings.json not found at $settings"
} else {
    $raw = Get-Content $settings -Raw
    foreach ($h in $expected) {
        if ($raw -match [regex]::Escape("agent-improvement/hooks/$h")) {
            Ok "$h is wired to the repo copy"
        } elseif ($raw -match [regex]::Escape($h)) {
            Bad "$h is wired, but NOT to the repo copy - it still points at an untracked path. Re-point it at `$USERPROFILE/agent-improvement/hooks/$h"
        } else {
            Bad "$h is not referenced in settings.json at all - the loop will never fire"
        }
    }
}

# --- 4. skills --------------------------------------------------------------
Say ""
Say "4. Skills (must be copied - Claude Code only discovers ~/.claude/skills)" 'White'
if (-not (Test-Path $skillsSrc)) {
    Bad "No skills/ directory in the store"
} else {
    foreach ($skill in (Get-ChildItem $skillsSrc -Directory)) {
        $dst = Join-Path $skillsDst $skill.Name
        $srcManifest = Join-Path $skill.FullName 'SKILL.md'
        if (-not (Test-Path $srcManifest)) { Bad "$($skill.Name): no SKILL.md, skipped"; continue }

        $needsCopy = $true
        if (Test-Path (Join-Path $dst 'SKILL.md')) {
            $a = (Get-FileHash (Join-Path $dst 'SKILL.md')).Hash
            $b = (Get-FileHash $srcManifest).Hash
            if ($a -eq $b) { $needsCopy = $false }
        }

        if ($Check) {
            if ($needsCopy) { Bad "$($skill.Name): out of date or absent at $dst" }
            else { Ok "$($skill.Name): current" }
            continue
        }

        if ($needsCopy) {
            New-Item -ItemType Directory -Path $skillsDst -Force | Out-Null
            if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
            Copy-Item $skill.FullName -Destination $dst -Recurse -Force
            Ok "$($skill.Name): installed"
        } else {
            Ok "$($skill.Name): already current"
        }
    }
}

# --- 5. machine identity ----------------------------------------------------
Say ""
Say "5. Machine identity (gitignored, per-machine)" 'White'
$localState = Join-Path $store 'local-state.json'
if (Test-Path $localState) {
    $id = (Get-Content $localState -Raw | ConvertFrom-Json).machineId
    Ok "machineId = $id"
} elseif ($Check) {
    Bad "local-state.json absent - agent-learn cannot find this machine's buffer"
} else {
    $id = Read-Host "  No local-state.json. Enter a machineId for this machine (e.g. home-matt, work-it)"
    if ([string]::IsNullOrWhiteSpace($id)) {
        Bad "no machineId given - create local-state.json manually before running agent-learn"
    } else {
        $json = "{`"machineId`":`"$id`",`"lastProcessedSession`":`"`"}"
        [System.IO.File]::WriteAllText($localState, $json, (New-Object System.Text.UTF8Encoding($false)))
        Ok "created local-state.json with machineId = $id"
    }
}

# --- summary ----------------------------------------------------------------
Say ""
if ($problems -eq 0) {
    Say "All checks passed. The learning loop is wired on this machine." 'Green'
    exit 0
} else {
    Say "$problems problem(s) found - see [X] lines above." 'Red'
    Say "This is what a silently-dead loop looks like from the inside. Fix before relying on it." 'Yellow'
    exit 1
}
