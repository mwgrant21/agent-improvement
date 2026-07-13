# capture-lesson-buffer.ps1
# EVENT: Stop
# Appends a compact record of the finished session to the agent-improvement buffer,
# for the next SessionStart promote pass to grade. Stage 1 (CAPTURE) of the loop.
#
# Never throws and always exits 0 - a learning hook must never disrupt a session.
# Reads the Claude Code hook event JSON from stdin.

$ErrorActionPreference = 'Stop'
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $data = $raw | ConvertFrom-Json

    $store = Join-Path $env:USERPROFILE 'agent-improvement'
    if (-not (Test-Path $store)) { exit 0 }   # store not installed on this machine

    # machineId from local-state.json (labels which machine captured the session)
    $machineId = 'unknown'
    $statePath = Join-Path $store 'local-state.json'
    if (Test-Path $statePath) {
        try { $machineId = (Get-Content $statePath -Raw | ConvertFrom-Json).machineId } catch {}
    }
    if ([string]::IsNullOrWhiteSpace($machineId)) { $machineId = 'unknown' }

    $candDir = Join-Path $store 'candidates'
    if (-not (Test-Path $candDir)) { New-Item -ItemType Directory -Path $candDir -Force | Out-Null }
    $bufferPath = Join-Path $candDir "$machineId-buffer.jsonl"

    # Cheap summary: last assistant text block in the transcript tail. Best-effort;
    # the promote pass opens the transcript itself when it needs more.
    $summary = ''
    $tp = $data.transcript_path
    if ($tp -and (Test-Path $tp)) {
        try {
            $tail = Get-Content -Path $tp -Tail 80 -ErrorAction Stop
            foreach ($line in $tail) {
                try {
                    $entry = $line | ConvertFrom-Json
                    if ($entry.type -eq 'assistant' -and $entry.message.content) {
                        foreach ($block in $entry.message.content) {
                            if ($block.type -eq 'text' -and $block.text) { $summary = $block.text }
                        }
                    }
                } catch {}
            }
        } catch {}
    }
    $summary = ($summary -replace '\s+', ' ').Trim()
    if ($summary.Length -gt 300) { $summary = $summary.Substring($summary.Length - 300) }

    $record = [ordered]@{
        session_id      = $data.session_id
        ended_at        = (Get-Date -Format 's')
        cwd             = $data.cwd
        transcript_path = $tp
        summary         = $summary
    }
    $json = $record | ConvertTo-Json -Compress

    # Append as UTF-8 without BOM (per environment encoding rules).
    $enc = New-Object System.Text.UTF8Encoding($false)
    $sw = New-Object System.IO.StreamWriter($bufferPath, $true, $enc)
    try { $sw.WriteLine($json) } finally { $sw.Close() }
}
catch { }
exit 0
