# Exercises capture-lesson-buffer.ps1 against a synthetic USERPROFILE so the real
# buffer is never touched. Covers the three resolution paths, the middle one being
# the defect that silently discarded 36 records.

$ErrorActionPreference = 'Stop'
$hook = Join-Path $env:USERPROFILE 'agent-improvement\hooks\capture-lesson-buffer.ps1'

function New-Fixture {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("cap-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path (Join-Path $root 'agent-improvement\candidates') -Force | Out-Null
    $state = '{"machineId":"testbox","lastProcessedSession":""}'
    [System.IO.File]::WriteAllText((Join-Path $root 'agent-improvement\local-state.json'), $state, (New-Object System.Text.UTF8Encoding($false)))
    return $root
}

function New-Transcript {
    param([string]$Root, [string]$ProjectDir, [string]$SessionId, [string]$Text)
    $dir = Join-Path $Root ".claude\projects\$ProjectDir"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $path = Join-Path $dir "$SessionId.jsonl"
    $line = @{ type = 'assistant'; message = @{ content = @(@{ type = 'text'; text = $Text }) } } | ConvertTo-Json -Compress -Depth 6
    [System.IO.File]::WriteAllText($path, "$line`n", (New-Object System.Text.UTF8Encoding($false)))
    return $path
}

function Invoke-Hook {
    param([string]$Root, [hashtable]$Payload)
    $json = $Payload | ConvertTo-Json -Compress
    $prev = $env:USERPROFILE
    $env:USERPROFILE = $Root
    try {
        $json | & powershell -NoProfile -ExecutionPolicy Bypass -File $hook
    } finally {
        $env:USERPROFILE = $prev
    }
    $buf = Join-Path $Root 'agent-improvement\candidates\testbox-buffer.jsonl'
    if (-not (Test-Path $buf)) { return $null }
    # @() at the CALL SITE: with a single record Get-Content returns a scalar
    # string, and $lines[-1] would index the last CHARACTER rather than the last
    # line. This is the array-unroll trap from the environment's own codex.
    $lines = @(Get-Content $buf | Where-Object { $_ })
    if ($lines.Count -eq 0) { return $null }
    return ($lines[$lines.Count - 1] | ConvertFrom-Json)
}

$fail = 0
function Check {
    param([string]$Name, [bool]$Ok, [string]$Detail = '')
    if ($Ok) { Write-Output "  ok   $Name" }
    else { Write-Output "  FAIL $Name $Detail"; $script:fail++ }
}

Write-Output 'capture hook resolution paths:'

# 1. Payload path is correct.
$r1 = New-Fixture
$sid1 = 'aaaaaaaa-1111-2222-3333-444444444444'
$tp1 = New-Transcript -Root $r1 -ProjectDir 'C--Users-IT' -SessionId $sid1 -Text 'payload path works'
$rec1 = Invoke-Hook -Root $r1 -Payload @{ session_id = $sid1; cwd = 'C:\Users\IT'; transcript_path = $tp1 }
Check 'payload path resolves -> summary_source=payload' ($rec1.summary_source -eq 'payload') "(got '$($rec1.summary_source)')"
Check 'summary captured from payload path' ($rec1.summary -eq 'payload path works') "(got '$($rec1.summary)')"

# 2. THE DEFECT: payload names a file that does not exist, but the transcript is
#    on disk under a DIFFERENT project directory. Previously this produced an
#    empty summary and an unusable record.
$r2 = New-Fixture
$sid2 = 'bbbbbbbb-1111-2222-3333-444444444444'
New-Transcript -Root $r2 -ProjectDir 'C--Users-IT-Desktop-NMMToolkit' -SessionId $sid2 -Text 'recovered by session id' | Out-Null
$bogus = Join-Path $r2 ".claude\projects\C--Users-IT\$sid2.jsonl"
$rec2 = Invoke-Hook -Root $r2 -Payload @{ session_id = $sid2; cwd = 'C:\Users\IT\Desktop\NMMToolkit'; transcript_path = $bogus }
Check 'wrong payload path -> falls back to session-id search' ($rec2.summary_source -eq 'session-id-search') "(got '$($rec2.summary_source)')"
Check 'summary recovered despite wrong payload path' ($rec2.summary -eq 'recovered by session id') "(got '$($rec2.summary)')"
Check 'resolved path points at the real project dir' ($rec2.transcript_path -like '*NMMToolkit*') "(got '$($rec2.transcript_path)')"
Check 'original payload path retained for diagnosis' ($rec2.payload_path -eq $bogus)

# 3. No transcript anywhere - must be labelled, not silently empty.
$r3 = New-Fixture
$sid3 = 'cccccccc-1111-2222-3333-444444444444'
$rec3 = Invoke-Hook -Root $r3 -Payload @{ session_id = $sid3; cwd = 'C:\Users\IT'; transcript_path = (Join-Path $r3 'nope.jsonl') }
Check 'no transcript -> summary_source=unavailable' ($rec3.summary_source -eq 'unavailable') "(got '$($rec3.summary_source)')"
Check 'unavailable is distinguishable from an empty summary' ($rec3.summary -eq '' -and $rec3.summary_source -ne 'payload')

# 4. Never throws, always exits 0, even on garbage input.
$r4 = New-Fixture
$prev = $env:USERPROFILE; $env:USERPROFILE = $r4
try { 'not json at all' | & powershell -NoProfile -ExecutionPolicy Bypass -File $hook; $code = $LASTEXITCODE }
finally { $env:USERPROFILE = $prev }
Check 'garbage stdin still exits 0' ($code -eq 0) "(exit $code)"

Write-Output ''
if ($fail -eq 0) { Write-Output 'ALL CHECKS PASSED' } else { Write-Output "$fail CHECK(S) FAILED"; exit 1 }
