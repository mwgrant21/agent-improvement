# Setting up the learning loop on a machine

The lessons in this repo are useless on a machine where nothing feeds them. This
file is the whole install.

## New machine, from scratch

```powershell
git clone https://github.com/mwgrant21/agent-improvement.git $env:USERPROFILE\agent-improvement
powershell -File $env:USERPROFILE\agent-improvement\bootstrap.ps1
```

`bootstrap.ps1` copies the `agent-learn` and `loop-design` skills into
`~/.claude/skills/` and prompts once for this machine's `machineId`
(`home-matt`, `matthewgr`, `work-it`, ...). Run `bootstrap.ps1 -Check` any time
to audit without writing.

Then confirm `~/.claude/settings.json` wires the three hooks. If it came from
the `claude-config` snapshot it already does.

## What lives where, and why

| Thing | Location | Travels by |
|---|---|---|
| Lessons (`LESSONS.md`, `domains/*.md`) | this repo | git |
| Loop protocol + state (`loops/`) | this repo | git |
| Hook scripts (`hooks/*.ps1`) | this repo | git - referenced in place, no install |
| `agent-learn` / `loop-design` skills | this repo `skills/` | git, then `bootstrap.ps1` copies them |
| `settings.json` (the hook wiring) | `~/.claude/` | the `claude-config` repo |
| `machineId` (`local-state.json`) | this repo, gitignored | never - per machine |
| Capture buffer (`candidates/`) | this repo, gitignored | never - per machine |

Hooks are referenced directly out of this repo rather than copied into
`~/.claude/hooks/`, so `git pull` updates them with no install step. **Do not
leave copies in `~/.claude/hooks/`.** Three stale duplicates lived there until
2026-08-21 and cost a real misdiagnosis: a debugging session read
`~/.claude/hooks/capture-lesson-buffer.ps1`, reasoned about it for several steps,
and was wrong the whole time - the registered copy in this repo was several
commits ahead. A superseded copy in the conventional location is more dangerous
than no copy, because nothing about it looks wrong. `settings.json` is the only
source of truth for what actually runs; check the registration before the
implementation. Skills are
the exception: Claude Code only discovers skills under `~/.claude/skills/`, so
those get copied and `bootstrap.ps1` must be re-run after a pull that changes
them.

## Testing the hooks

```sh
powershell -NoProfile -ExecutionPolicy Bypass -File hooks/tests/run-all.ps1
```

Exit 0 means every test file passed. Exit 1 means one failed **or none were
found** - a runner that matches zero tests and reports success is the same
silent-under-report class as everything else on this page, so it refuses.
`-Filter <substring>` runs one file; `-Quiet` hides passing detail but never a
failure's.

Run it:

- after editing anything in `hooks/`, before committing;
- **after a Claude Code upgrade.** This is the one that matters. On 2026-08-21,
  2.1.238 stopped writing the session transcript during the session
  (`transcript_path` null, no `<session-id>.jsonl` on disk), which broke capture
  on a hook nobody had touched. Records kept landing, fully formed except for the
  summary, and two promote passes ran against "93 pending" and "14 pending"
  sessions that held nothing gradeable. The hooks depend on Claude Code's payload
  shape and on-disk layout, and neither is a contract.
- on a new machine, after `bootstrap.ps1`, as a wiring check.

Each test runs in its own `powershell.exe` child process. That is deliberate:
the tests swap `$env:USERPROFILE` to a synthetic fixture so the real capture
buffer is never touched, and a crash mid-test would otherwise strand the calling
session pointing at a temp directory. The child also pins execution to Windows
PowerShell 5.1 - the version `settings.json` actually runs the hooks under - even
when the runner is invoked from pwsh 7, where `$null` and `.Count` semantics
differ enough to change a result.

Nothing runs this automatically, on purpose. A pre-push hook in this repo would
sit in the path of the daily-triage loop's own unattended `git push` (run step 5),
so a failing test would block a loop from recording its state - a worse failure
than the untested hook it was guarding against.

## Why the hooks announce themselves when missing

Before 2026-08-06 the wiring was:

```sh
S="$USERPROFILE/.claude/hooks/agent-learn-onstart.ps1"; [ -f "$S" ] && powershell ... ; exit 0
```

`settings.json` syncs between machines. The `.ps1` files did not - they were in
no git repo at all. So a second machine would read a settings file declaring all
three hooks, fail the `[ -f ]` test, and **exit 0**. No lessons injected, no
sessions captured, no triage - and no error. The loop was not broken; it was
absent, which looked identical to working.

The wiring now warns on stdout instead of exiting silently, and `bootstrap.ps1`
audits the whole chain. Same failure class as the `~/projects/*` scan root that
daily-triage was reading as "nothing found" for weeks - see
`domains/loop-design.md`, "A loop must assert its scan root exists".

## Two lanes, do not cross them

- **Agent lane** - this repo. What the agent/tooling learned.
- **User lane** - `~/learning-profile` (repo `mwgrant21/learning-profile`), via
  the separate `learning` skill. What the USER prefers.

Never write one lane's data into the other.
