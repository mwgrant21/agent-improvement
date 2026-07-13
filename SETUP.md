# Work-machine setup (one time, ~10 minutes)

Brings the work account (`C:\Users\matthewgr`) into the agent-improvement loop so
lessons sync home <-> work. Paths below use `matthewgr`; adjust if the account differs.

## 1. Clone the repo to the home directory

    gh repo clone mwgrant21/agent-improvement C:\Users\matthewgr\agent-improvement

## 2. Set this machine's local state (gitignored, so it does NOT come from the clone)

Create `C:\Users\matthewgr\agent-improvement\local-state.json` with a DISTINCT machineId:

    {"machineId": "work-matthewgr", "lastProcessedSession": null}

The machineId must differ from home's `home-matt` - it labels which machine a lesson
came from and names the local capture buffer.

## 3. Install the agent-learn skill (copy, do not symlink)

    mkdir C:\Users\matthewgr\.claude\skills\agent-learn\references
    copy C:\Users\matthewgr\agent-improvement\skills\agent-learn\SKILL.md                       C:\Users\matthewgr\.claude\skills\agent-learn\SKILL.md
    copy C:\Users\matthewgr\agent-improvement\skills\agent-learn\references\grading-rubric.md    C:\Users\matthewgr\.claude\skills\agent-learn\references\grading-rubric.md
    copy C:\Users\matthewgr\agent-improvement\skills\agent-learn\references\sync.md              C:\Users\matthewgr\.claude\skills\agent-learn\references\sync.md

## 4. Install the hook scripts

    copy C:\Users\matthewgr\agent-improvement\hooks\capture-lesson-buffer.ps1  C:\Users\matthewgr\.claude\hooks\capture-lesson-buffer.ps1
    copy C:\Users\matthewgr\agent-improvement\hooks\agent-learn-onstart.ps1    C:\Users\matthewgr\.claude\hooks\agent-learn-onstart.ps1

The scripts resolve the store via `$env:USERPROFILE\agent-improvement`, so they need no
per-machine edits.

## 5. Wire the hooks into settings.json

In `C:\Users\matthewgr\.claude\settings.json`, under `"hooks"`, ADD a second
`SessionStart` entry and a `Stop` block (merge with any existing entries - do not
overwrite them):

    "SessionStart": [
      { "hooks": [ { "type": "command",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\matthewgr\\.claude\\hooks\\agent-learn-onstart.ps1\"",
        "timeout": 30, "statusMessage": "Loading agent-improvement lessons..." } ] }
    ],
    "Stop": [
      { "hooks": [ { "type": "command",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\matthewgr\\.claude\\hooks\\capture-lesson-buffer.ps1\"",
        "timeout": 30, "statusMessage": "Capturing session for agent-learn..." } ] }
    ]

Validate afterward: `powershell -Command "Get-Content ~\.claude\settings.json -Raw | ConvertFrom-Json"`
should not error.

## 6. Add the CLAUDE.md section

Copy the "## Agent-Improvement Loop" section from this machine's global CLAUDE.md
(`C:\Users\Matt\.claude\CLAUDE.md`) into the work machine's global CLAUDE.md
(`C:\Users\matthewgr\.claude\CLAUDE.md`), verbatim.

## 7. Verify

- Start a new Claude Code session. The SessionStart hook should inject the LESSONS.md
  index (you will see the powershell domain lessons in context).
- Run `/agent-learn status` - it should report the lesson count and 0 pending sessions.
- End the session, start another; confirm the previous session was captured and graded
  (a promote pass runs, silently if nothing qualifies).
