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

    # Resolve the transcript. The payload's transcript_path is tried first, but it
    # is NOT trusted: on 2026-08-12 a promote pass found 36 of 60 buffered records
    # unusable because the payload named a file under the HOME project directory
    # for sessions whose cwd was a project directory, where their transcripts do
    # not live. Test-Path failed, the summary came out empty, and the record was
    # written anyway - so two passes reported "N pending" while capturing nothing
    # from any real project work.
    #
    # Fall back to locating the transcript by session_id across every project
    # directory, which is the one identifier that cannot be misfiled.
    $tp = $data.transcript_path
    $resolved = $null
    $source = 'unavailable'

    if ($tp -and (Test-Path $tp)) {
        $resolved = $tp
        $source = 'payload'
    }
    elseif ($data.session_id) {
        try {
            $projRoot = Join-Path $env:USERPROFILE '.claude\projects'
            if (Test-Path $projRoot) {
                $hit = Get-ChildItem -Path $projRoot -Filter "$($data.session_id).jsonl" -Recurse -File -ErrorAction SilentlyContinue |
                    Select-Object -First 1
                if ($hit) {
                    $resolved = $hit.FullName
                    $source = 'session-id-search'
                }
            }
        } catch {}
    }

    # Cheap summary: last assistant text block in the transcript tail. Best-effort;
    # the promote pass opens the transcript itself when it needs more.
    $summary = ''
    if ($resolved) {
        try {
            $tail = Get-Content -Path $resolved -Tail 80 -ErrorAction Stop
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
    if ($summary.Length -eq 0 -and $source -ne 'unavailable') { $source = 'transcript-had-no-text' }

    # summary_source makes a capture FAILURE distinguishable from a session that
    # genuinely had nothing to say. Without it an empty summary is ambiguous, and
    # the ambiguity is what let the defect above survive two promote passes: the
    # record count kept climbing, which reads as a healthy pipeline.
    $record = [ordered]@{
        session_id      = $data.session_id
        ended_at        = (Get-Date -Format 's')
        cwd             = $data.cwd
        transcript_path = $resolved
        payload_path    = $tp
        summary_source  = $source
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
