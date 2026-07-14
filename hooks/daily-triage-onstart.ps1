# daily-triage-onstart.ps1
# EVENT: SessionStart
# If the daily-triage loop has not run today (STATE.md last_run < today) and is
# not paused, emit additionalContext instructing the session to execute the run
# protocol in ~/agent-improvement/loops/daily-triage/LOOP.md.
#
# Never throws; always exits 0. Fails open (missing store/state -> silent).

$ErrorActionPreference = 'Stop'
try {
    try { [void][Console]::In.ReadToEnd() } catch {}

    $statePath = Join-Path $env:USERPROFILE 'agent-improvement\loops\daily-triage\STATE.md'
    if (-not (Test-Path $statePath)) { exit 0 }

    $state = Get-Content $statePath -Raw

    $paused = [regex]::Match($state, '(?m)^paused:\s*(\S+)').Groups[1].Value
    if ($paused -eq 'true') { exit 0 }

    $lastRun = [regex]::Match($state, '(?m)^last_run:\s*(\S+)').Groups[1].Value
    if ($lastRun -notmatch '^\d{4}-\d{2}-\d{2}$') { $lastRun = '1970-01-01' }
    $today = Get-Date -Format 'yyyy-MM-dd'
    if ($lastRun -ge $today) { exit 0 }

    $context = "daily-triage: no run recorded today (last_run: $lastRun). After the agent-learn promote pass (if one was requested), dispatch a background subagent to execute the run protocol in ~/agent-improvement/loops/daily-triage/LOOP.md, then relay its digest to the user. Do not block the user's own request while it runs. L1: report only."
    @{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $context } } | ConvertTo-Json -Compress
}
catch { }
exit 0
