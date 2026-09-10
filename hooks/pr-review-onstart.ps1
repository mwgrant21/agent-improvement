# pr-review-onstart.ps1
# EVENT: SessionStart
# If the pr-review-watch loop is not paused, emit additionalContext asking the
# session to run the check in ~/agent-improvement/loops/pr-review-watch/LOOP.md
# and then leave a background watcher running for the rest of the session.
#
# Deliberately does NOT call `gh` itself. A SessionStart hook blocks the start
# of every session, and a network call there would add latency to each one and
# could hang on a bad connection. The hook decides WHETHER to check; the
# session does the checking, where it can be backgrounded.
#
# Never throws; always exits 0. Fails open (missing store/state -> silent).

$ErrorActionPreference = 'Stop'
try {
    try { [void][Console]::In.ReadToEnd() } catch {}

    $loopDir = Join-Path $env:USERPROFILE 'agent-improvement\loops\pr-review-watch'
    $statePath = Join-Path $loopDir 'STATE.md'
    if (-not (Test-Path $statePath)) { exit 0 }

    $state = Get-Content $statePath -Raw

    $paused = [regex]::Match($state, '(?m)^paused:\s*(\S+)').Groups[1].Value
    if ($paused -eq 'true') { exit 0 }

    # Report how long the machine-local cursor has been idle, so the session
    # can say something useful rather than re-reporting from zero. Absence of
    # the cursor is a first run, not an error.
    $cursorPath = Join-Path $loopDir 'cursor.local.json'
    $cursorNote = 'no cursor yet (first run on this machine)'
    if (Test-Path $cursorPath) {
        try {
            $cursor = Get-Content $cursorPath -Raw | ConvertFrom-Json
            # ConvertFrom-Json yields a PSCustomObject, and @(<one object>).Count is 1 for
            # ANY content - empty or twenty PRs. That made this note a constant reporting
            # '1 tracked PR(s)' against an empty cursor for the loop's whole life.
            # Count the PROPERTIES instead. R4, retrospective 2026-09-10.
            $n = @($cursor.prs.PSObject.Properties).Count
            $cursorNote = "cursor has $n tracked PR(s)"
        } catch {
            $cursorNote = 'cursor unreadable; treat as first run and rebuild it'
        }
    }

    $context = @"
pr-review-watch (L1, report-only): run the check in ~/agent-improvement/loops/pr-review-watch/LOOP.md now, in the background, and relay anything new. $cursorNote.

Then leave a background watcher polling on a ~10 minute cadence for the rest of this session, so review feedback surfaces here before it reaches email. The watcher must exit as soon as it finds something (waking this session) rather than reporting into a void.

Read the LOOP.md before running it - three of its rules are counter-intuitive and were each got wrong by hand: a 'eyes' reaction is not a verdict, an inline comment's commit_id is not proof of a re-review, and our own '@codex review' trigger comments are not findings.

L1 boundary, hard: read and report only. Never post a comment, never post '@codex review' (it spends money), never merge, never push. Do not block the user's own request while it runs.
"@

    @{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $context } } | ConvertTo-Json -Compress
}
catch { }
exit 0
