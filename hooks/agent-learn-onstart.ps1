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
    # Count pending records AND how many are unusable. A record whose capture
    # failed still lands in the buffer with every field populated except the
    # summary, so a bare pending count reports a healthy-looking number over
    # records that carry nothing to grade. On 2026-08-21 two promote passes ran
    # against 93 and 14 "pending" sessions while the recent ones were empty,
    # because nothing distinguished the two.
    $pending = 0
    $unusable = 0
    if (Test-Path $bufferPath) {
        $lines = @(Get-Content $bufferPath | Where-Object { $_.Trim() -ne '' })
        $pending = $lines.Count
        foreach ($l in $lines) {
            try {
                $r = $l | ConvertFrom-Json
                if ($r.summary_source -eq 'unavailable' -or [string]::IsNullOrWhiteSpace($r.summary)) { $unusable++ }
            } catch { $unusable++ }
        }
    }
    if ($pending -gt 0) {
        $context += "`nagent-learn: $pending candidate session(s) pending in the capture buffer. As your FIRST action this session, invoke the agent-learn skill and run its promote pass (extract -> grade -> promote durable lessons, then sync). Keep it silent if nothing clears the gate, then proceed with the user's request."
        if ($unusable -gt 0) {
            $context += " CAPTURE DEGRADED: $unusable of $pending record(s) have NO usable summary (summary_source=unavailable or empty). Do not read that as 'those sessions held no lesson' - the capture failed for them. Judge those from direct session knowledge if they are this session's own, and otherwise say so explicitly in the pass rather than silently dropping them."
        }
    }

    if ($context -ne '') {
        @{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $context } } | ConvertTo-Json -Compress
    }
}
catch { }
exit 0
