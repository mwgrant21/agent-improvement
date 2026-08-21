# Runs every hook test in this directory and reports one summary.
#
# Each test is executed in its OWN powershell.exe child process, deliberately:
# the tests swap $env:USERPROFILE to point at a synthetic fixture, and a crash
# mid-test would otherwise leave the parent session pointing at a temp directory.
# A child process also guarantees the tests run under Windows PowerShell 5.1 (the
# version the hooks themselves run under via settings.json) even when this runner
# is invoked from pwsh 7, where $null/.Count semantics differ.
#
# Exit 0 = every test passed. Exit 1 = at least one failed, or none were found.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File hooks\tests\run-all.ps1
#   ... run-all.ps1 -Filter onstart      # only tests whose name matches

[CmdletBinding()]
param(
    [string]$Filter = '',
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
# @() at the CALL SITE - a single match comes back as a scalar FileInfo whose
# .Count is $null in PS 5.1, so every count-based guard below would misread it.
$tests = @(Get-ChildItem -Path $here -Filter 'test-*.ps1' -File | Sort-Object Name)
if ($Filter) { $tests = @($tests | Where-Object { $_.Name -like "*$Filter*" }) }

if ($tests.Count -eq 0) {
    Write-Output "No tests matched in $here$(if ($Filter) { " (filter '$Filter')" })."
    exit 1
}

Write-Output "Running $($tests.Count) hook test file(s) from $here"
Write-Output ''

$failed = @()
foreach ($t in $tests) {
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $t.FullName 2>&1
    $code = $LASTEXITCODE
    $text = (@($out) -join "`n")

    if ($code -eq 0) {
        Write-Output "PASS  $($t.Name)"
        if (-not $Quiet) { $text -split "`n" | ForEach-Object { if ($_.Trim()) { Write-Output "      $_" } } }
    }
    else {
        $failed += $t.Name
        Write-Output "FAIL  $($t.Name)  (exit $code)"
        # Always show a failing test's output, even under -Quiet - a silent
        # failure report is the thing this whole suite exists to prevent.
        $text -split "`n" | ForEach-Object { if ($_.Trim()) { Write-Output "      $_" } }
    }
    Write-Output ''
}

$passed = $tests.Count - $failed.Count
Write-Output "----------------------------------------"
if ($failed.Count -eq 0) {
    Write-Output "ALL $($tests.Count) TEST FILE(S) PASSED"
    exit 0
}
Write-Output "$passed passed, $($failed.Count) FAILED: $($failed -join ', ')"
exit 1
