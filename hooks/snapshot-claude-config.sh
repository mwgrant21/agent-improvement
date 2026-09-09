#!/bin/bash
# snapshot-claude-config.sh
# EVENT: PreToolUse (matcher: Write|Edit)
# DESCRIPTION: Snapshot ~/.claude before the FIRST config write of each session.
#
# "Commit before you experiment, especially before you let AI rewrite its own
# config." The claude-config repo is a copy-then-commit snapshot, so it captures
# state only when someone remembers to sync it -- a session that rewrites
# settings.json or a SKILL.md otherwise has no rollback point.
#
# Deliberately NOT a git repo in ~/.claude: ~/CLAUDE.md forbids `git init` there.
# Plain timestamped copies, pruned, outside the tree they protect.
#
# Symlinks are DEREFERENCED (`cp -rL`). That is load-bearing: ~/.claude/skills
# holds plugin-managed symlinks (humanizer) carrying hand-applied forks that a
# plugin update reverts silently. Copying the link would preserve nothing.
#
# Fails open, always. A snapshot problem must never block a write.

set +e

SNAP_ROOT="$HOME/backups/claude-config-snapshots"
KEEP=20

# Read the hook payload. Never block if stdin is empty or malformed.
PAYLOAD=$(timeout 5 cat 2>/dev/null || true)

# Only care about writes INTO ~/.claude. Cheap substring test rather than a JSON
# parse: jq may not exist, and this runs on the Write/Edit hot path.
case "$PAYLOAD" in
  *'.claude'*) ;;
  *) exit 0 ;;
esac

# Once per session. Without this the hook fires on every config write and the
# later copies are of an already-modified tree -- the first one is the only
# pre-experiment state worth having.
SESSION=$(printf '%s' "$PAYLOAD" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -z "$SESSION" ] && SESSION="unknown"
SENTINEL="$SNAP_ROOT/.sessions/$SESSION"
[ -e "$SENTINEL" ] && exit 0

mkdir -p "$SNAP_ROOT/.sessions" 2>/dev/null
DEST="$SNAP_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-${SESSION:0:8}"
mkdir -p "$DEST" 2>/dev/null || exit 0

for item in settings.json settings.local.json CLAUDE.md rules agents hooks commands skills; do
  [ -e "$HOME/.claude/$item" ] && cp -rL "$HOME/.claude/$item" "$DEST/" 2>/dev/null
done

# Mark the session done even if some copies failed -- a partial snapshot is still
# a snapshot, and retrying on every subsequent write would be worse.
: > "$SENTINEL" 2>/dev/null

# Prune oldest, keeping the most recent $KEEP. ~600KB each, so this is about
# tidiness rather than space.
ls -1d "$SNAP_ROOT"/*Z-* 2>/dev/null | sort | head -n -"$KEEP" | while read -r old; do
  rm -rf "$old" 2>/dev/null
done

# Sentinels outlive their snapshots; drop the ones whose session is long gone.
find "$SNAP_ROOT/.sessions" -type f -mtime +30 -delete 2>/dev/null

exit 0
