#!/bin/bash
# check-distributed.sh -- report drift between this store's distributed copies
# and the live files Claude Code actually loads.
#
# The store holds distributed copies of skills/ and hooks/. Claude Code loads
# from ~/.claude/. Nothing keeps the two in step, and nothing noticed when they
# fell apart: on 2026-09-09 a sweep found three drifted files, two of them hooks
# wired into settings.json and RUNNING at a version from seven weeks earlier.
# One of those stale hooks was silently failing to capture transcripts for any
# session whose cwd was a project directory -- 62 of 194 buffered records on
# home-matt had no usable summary as a result.
#
# Direction is NOT uniform. In that same sweep two files were newer in the store
# and one was newer live, so a blanket "sync one way" would have destroyed work
# whichever way it ran. This script therefore REPORTS ONLY and names both sides;
# a human decides each direction from the evidence.
#
#     bash tools/store-sync/check-distributed.sh          # report
#     bash tools/store-sync/check-distributed.sh --strict  # exit 1 on any drift
#
# Line endings are ignored (--strip-trailing-cr): the store keeps CRLF on .ps1
# via git normalisation while the live copies are LF, which is not drift.

set -u
STORE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIVE="$HOME/.claude"
strict=0
[ "${1:-}" = "--strict" ] && strict=1

drift=0; missing=0; ok=0

printf '%-50s %s\n' "DISTRIBUTED FILE" "STATUS"
printf '%-50s %s\n' "----------------" "------"

while IFS= read -r rel; do
  s="$STORE/$rel"
  l="$LIVE/$rel"
  if [ ! -e "$l" ]; then
    printf '%-50s %s\n' "$rel" "MISSING LIVE"
    missing=$((missing + 1))
  elif diff --strip-trailing-cr -q "$s" "$l" >/dev/null 2>&1; then
    printf '%-50s %s\n' "$rel" "in sync"
    ok=$((ok + 1))
  else
    s_lines=$(wc -l < "$s"); l_lines=$(wc -l < "$l")
    s_when=$(date -r "$s" '+%Y-%m-%d' 2>/dev/null)
    l_when=$(date -r "$l" '+%Y-%m-%d' 2>/dev/null)
    printf '%-50s %s\n' "$rel" "DRIFT  store=${s_lines}L/${s_when}  live=${l_lines}L/${l_when}"
    drift=$((drift + 1))
  fi
done < <(cd "$STORE" && find skills hooks -type f 2>/dev/null | grep -v '/tests/' | sort)

echo
echo "in sync: $ok | drift: $drift | missing live: $missing"

if [ "$drift" -gt 0 ] || [ "$missing" -gt 0 ]; then
  cat <<'NOTE'

Resolve each file on its own evidence -- do NOT sync wholesale in either
direction. For each drifted file, read the actual diff and decide which side is
ahead:

    diff --strip-trailing-cr ~/.claude/<rel> <rel>

Newer content usually announces itself: a comment citing a dated incident, a
guard that references a bug. Line count and mtime are hints, not proof -- an
mtime changes when a file is copied, so a stale copy can look recent.
NOTE
fi

[ "$strict" -eq 1 ] && [ $((drift + missing)) -gt 0 ] && exit 1
exit 0
