# Exercises agent-learn-onstart.ps1 against a synthetic USERPROFILE so the real
# buffer is never touched.
#
# The behaviour under test is the CAPTURE DEGRADED report. A record whose capture
# failed still lands in the buffer with every field populated except the summary,
# so a bare pending count reports a healthy-looking number over records that carry
# nothing to grade. On 2026-08-21 Claude Code 2.1.238 stopped writing the session
# transcript during the session (transcript_path null, no <session-id>.jsonl), and
# two promote passes ran against "93 pending" and "14 pending" sessions whose
# recent records were empty - because nothing distinguished usable from unusable.

$ErrorActionPreference = 'Stop'
$hook = Join-Path $env:USERPROFILE 'agent-improvement\hooks\agent-learn-onstart.ps1'

function New-Fixture {
    param([string[]]$BufferLines)
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("onstart-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path (Join-Path $root 'agent-improvement\candidates') -Force | Out-Null
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Join-Path $root 'agent-improvement\local-state.json'),
        '{"machineId":"testbox","lastProcessedSession":""}', $enc)
    if ($null -ne $BufferLines) {
        [System.IO.File]::WriteAllText((Join-Path $root 'agent-improvement\candidates\testbox-buffer.jsonl'),
            (($BufferLines -join "`n") + "`n"), $enc)
    }
    return $root
}

function Invoke-Hook {
    param([string]$Root)
    $prev = $env:USERPROFILE
    $env:USERPROFILE = $Root
    try {
        $out = '{"session_id":"s","cwd":"C:\\Users\\IT","source":"startup"}' |
            & powershell -NoProfile -ExecutionPolicy Bypass -File $hook
    } finally {
        $env:USERPROFILE = $prev
    }
    # @() at the CALL SITE - a single output line comes back as a scalar string.
    $text = (@($out) -join "`n").Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return '' }
    try { return ($text | ConvertFrom-Json).hookSpecificOutput.additionalContext }
    catch { return $text }
}

$fail = 0
function Check {
    param([string]$Name, [bool]$Ok, [string]$Detail = '')
    if ($Ok) { Write-Output "  ok   $Name" }
    else { Write-Output "  FAIL $Name $Detail"; $script:fail++ }
}

$GOOD    = '{"session_id":"a","summary_source":"payload","summary":"a real summary"}'
$BAD     = '{"session_id":"b","summary_source":"unavailable","summary":""}'
$EMPTY   = '{"session_id":"c","summary":""}'
$GARBAGE = 'not json at all'

Write-Output 'agent-learn onstart capture reporting:'

# 1. THE REGRESSION: unusable records must be reported, not folded into the count.
$ctx1 = Invoke-Hook -Root (New-Fixture -BufferLines @($GOOD, $BAD))
Check 'mixed buffer still reports the total pending count' ($ctx1 -match '2 candidate session\(s\) pending')
Check 'mixed buffer reports CAPTURE DEGRADED' ($ctx1 -match 'CAPTURE DEGRADED') "(got: $($ctx1 -replace '\s+',' '))"
Check 'degraded line names the unusable/total split' ($ctx1 -match '1 of 2 record\(s\) have NO usable summary')

# 2. An empty summary counts as unusable even without summary_source.
$ctx2 = Invoke-Hook -Root (New-Fixture -BufferLines @($GOOD, $EMPTY))
Check 'empty summary without summary_source counts as unusable' ($ctx2 -match '1 of 2 record\(s\) have NO usable summary')

# 3. A malformed line counts as unusable rather than crashing the count.
$ctx3 = Invoke-Hook -Root (New-Fixture -BufferLines @($GOOD, $BAD, $GARBAGE))
Check 'malformed line counts as unusable' ($ctx3 -match '2 of 3 record\(s\) have NO usable summary')

# 4. A fully healthy buffer must NOT cry wolf - the warning is only for real degradation.
$ctx4 = Invoke-Hook -Root (New-Fixture -BufferLines @($GOOD))
Check 'healthy buffer still reports pending' ($ctx4 -match '1 candidate session\(s\) pending')
Check 'healthy buffer does NOT report CAPTURE DEGRADED' ($ctx4 -notmatch 'CAPTURE DEGRADED') "(got: $($ctx4 -replace '\s+',' '))"

# 5. Every record unusable - the case that must never read as "nothing to learn".
$ctx5 = Invoke-Hook -Root (New-Fixture -BufferLines @($BAD, $BAD))
Check 'all-unusable buffer reports 2 of 2' ($ctx5 -match '2 of 2 record\(s\) have NO usable summary')

# 6. Empty buffer stays silent - no pending line, no warning.
$ctx6 = Invoke-Hook -Root (New-Fixture -BufferLines @())
Check 'empty buffer emits no pending line' ($ctx6 -notmatch 'candidate session\(s\) pending')
Check 'empty buffer emits no CAPTURE DEGRADED' ($ctx6 -notmatch 'CAPTURE DEGRADED')

# 7. Never throws, always exits 0 - a learning hook must not disrupt a session.
$r7 = New-Fixture -BufferLines @($GARBAGE)
$prev = $env:USERPROFILE; $env:USERPROFILE = $r7
try { '' | & powershell -NoProfile -ExecutionPolicy Bypass -File $hook | Out-Null; $code = $LASTEXITCODE }
finally { $env:USERPROFILE = $prev }
Check 'garbage buffer + empty stdin still exits 0' ($code -eq 0) "(exit $code)"

Write-Output ''
if ($fail -eq 0) { Write-Output 'ALL CHECKS PASSED' } else { Write-Output "$fail CHECK(S) FAILED"; exit 1 }
