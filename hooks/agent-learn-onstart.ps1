# agent-learn-onstart.ps1
# EVENT: SessionStart
# Stage 2+5 of the loop. Surfaces the LESSONS.md index for read-back, and if the
# capture buffer holds pending sessions, instructs the model to run the agent-learn
# promote pass as its first action. Emits Claude Code SessionStart additionalContext.
#
# Never throws; always exits 0.

$ErrorActionPreference = 'Stop'
try {
    # Drain stdin so the pipe never blocks (event JSON is not needed here).
    try { [void][Console]::In.ReadToEnd() } catch {}

    $store = Join-Path $env:USERPROFILE 'agent-improvement'
    if (-not (Test-Path $store)) { exit 0 }   # store not installed on this machine

    $context = ''

    # Read-back: inject the lightweight LESSONS.md index.
    $lessonsPath = Join-Path $store 'LESSONS.md'
    if (Test-Path $lessonsPath) {
        $lessons = Get-Content $lessonsPath -Raw
        $context += "Agent-improvement lessons index (read-back). When a session touches a listed domain, read ~/agent-improvement/domains/<domain>.md and honor it:`n`n$lessons`n"
    }

    # Pending buffer -> instruct the promote pass.
    $machineId = 'unknown'
    $statePath = Join-Path $store 'local-state.json'
    if (Test-Path $statePath) {
        try { $machineId = (Get-Content $statePath -Raw | ConvertFrom-Json).machineId } catch {}
    }
    if ([string]::IsNullOrWhiteSpace($machineId)) { $machineId = 'unknown' }

    $bufferPath = Join-Path $store "candidates\$machineId-buffer.jsonl"
    $pending = 0
    if (Test-Path $bufferPath) {
        $pending = @(Get-Content $bufferPath | Where-Object { $_.Trim() -ne '' }).Count
    }
    if ($pending -gt 0) {
        $context += "`nagent-learn: $pending candidate session(s) pending in the capture buffer. As your FIRST action this session, invoke the agent-learn skill and run its promote pass (extract -> grade -> promote durable lessons, then sync). Keep it silent if nothing clears the gate, then proceed with the user's request."
    }

    if ($context -ne '') {
        @{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $context } } | ConvertTo-Json -Compress
    }
}
catch { }
exit 0
