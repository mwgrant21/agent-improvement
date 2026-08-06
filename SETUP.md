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
`~/.claude/hooks/`, so `git pull` updates them with no install step. Skills are
the exception: Claude Code only discovers skills under `~/.claude/skills/`, so
those get copied and `bootstrap.ps1` must be re-run after a pull that changes
them.

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
