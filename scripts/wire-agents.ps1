# wire-agents.ps1
# Inserts a "Prior lessons (read before you start)" directive into the PowerShell /
# sysadmin-facing it-fleet agents so they READ the shared lesson store before working.
# Idempotent (skips files already wired) and UTF-8-no-BOM safe. Run on each machine.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File wire-agents.ps1

$ErrorActionPreference = 'Stop'

$block = @'
## Prior lessons (read before you start)

Before doing task work, read `~/agent-improvement/LESSONS.md` (the shared, cross-machine
lesson index). For any listed domain relevant to this task (e.g. `powershell`), read
`~/agent-improvement/domains/<domain>.md` and apply its lessons - hard-won gotchas and
corrected mistakes from prior work on both machines. If the repo is absent on this
machine, continue without it; do not fail.
'@

$files = @('powershell-guru.md','pdq-script-preparer.md','windows-azure-sysadmin.md','cve-remediation-builder.md','security-code-reviewer.md','ps-code-reviewer.md')
$dir = Join-Path $env:USERPROFILE '.claude\agents\it-fleet'
$enc = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path $dir)) { Write-Output "it-fleet agents dir not found: $dir - nothing to wire."; exit 0 }

foreach ($f in $files) {
    $path = Join-Path $dir $f
    if (-not (Test-Path $path)) { Write-Output "$f : not present, skipped"; continue }
    $raw = Get-Content -Path $path -Raw
    if ($raw -match 'Prior lessons \(read before you start\)') { Write-Output "$f : already wired, skipped"; continue }
    $lines = Get-Content -Path $path
    $idx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^## ') { $idx = $i; break } }
    if ($idx -lt 1) { Write-Output "$f : no usable '## ' heading, skipped"; continue }
    $blockLines = $block -split "`r?`n"
    $new = @()
    $new += $lines[0..($idx - 1)]
    $new += $blockLines
    $new += ''
    $new += $lines[$idx..($lines.Count - 1)]
    [System.IO.File]::WriteAllLines($path, $new, $enc)
    Write-Output "$f : wired (inserted before '$($lines[$idx])')"
}
