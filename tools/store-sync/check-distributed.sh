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
# Prerequisite gate. Codex found (2026-09-13) that with dirname/grep absent
# from PATH this script printed errors yet exited 0 having checked zero files -
# a silent pass, the exact failure it exists to catch. Missing tools or an
# empty enumeration are now hard failures in every mode, not just --strict.
for tool in dirname find sort diff wc date grep; do
  command -v "$tool" >/dev/null 2>&1 || { echo "check-distributed: required tool '$tool' not on PATH - cannot check anything" >&2; exit 2; }
done
STORE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIVE="$HOME/.claude"
strict=0
[ "${1:-}" = "--strict" ] && strict=1

drift=0; missing=0; ok=0; nosrc=0

# Files whose ORIGIN lives outside this store (e.g. a skill versioned in an
# application repo and installed into ~/.claude). Copying those into the store
# would create a third copy and monitor the wrong pair -- store vs live --
# while the real origin drifted unwatched. The manifest instead points the
# check straight at the origin. See external-origins.tsv for the format.
EXTERNAL="$STORE/tools/store-sync/external-origins.tsv"

# Internal enumeration, with find's own status captured BEFORE anything is
# compared. Codex showed (2026-09-13, review of 5ba4503) that a failing find
# inside a process substitution was hidden whenever one external pair compared
# healthy: the pipeline's exit was discarded and the zero-file guard counted
# externals. A failed enumeration is now fatal on its own; a SUCCESSFUL empty
# enumeration is reported as a note and is not an error.
internal_raw="$(cd "$STORE" && find skills hooks -type f 2>/dev/null)"; find_rc=$?
if [ "$find_rc" -ne 0 ]; then
  echo "check-distributed: internal enumeration FAILED (find exit $find_rc) - refusing to compare anything" >&2
  exit 2
fi
# grep -v exits 1 when nothing survives; that is a legitimate empty result.
internal_list="$(printf '%s
' "$internal_raw" | grep -v '/tests/' | sort)" || true
internal_count=0

printf '%-50s %s\n' "DISTRIBUTED FILE" "STATUS"
printf '%-50s %s\n' "----------------" "------"

while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  internal_count=$((internal_count + 1))
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
done <<< "$internal_list"
[ "$internal_count" -eq 0 ] && echo "check-distributed: internal enumeration succeeded but found 0 files under skills/ hooks/ (external pairs still checked)" >&2

if [ -f "$EXTERNAL" ]; then
  while IFS=$'\t' read -r rel src; do
    case "${rel:-}" in ''|'#'*) continue ;; esac
    [ -n "${src:-}" ] || continue
    l="$LIVE/$rel"
    if [ ! -e "$src" ]; then
      # Never let an unreachable origin read as agreement: with no source there
      # is nothing to compare, and silence here is exactly the failure this
      # script exists to catch.
      printf '%-50s %s\n' "$rel" "MISSING SOURCE  $src"
      nosrc=$((nosrc + 1))
    elif [ ! -e "$l" ]; then
      printf '%-50s %s\n' "$rel" "MISSING LIVE"
      missing=$((missing + 1))
    elif diff --strip-trailing-cr -q "$src" "$l" >/dev/null 2>&1; then
      printf '%-50s %s\n' "$rel" "in sync (external)"
      ok=$((ok + 1))
    else
      s_lines=$(wc -l < "$src"); l_lines=$(wc -l < "$l")
      s_when=$(date -r "$src" '+%Y-%m-%d' 2>/dev/null)
      l_when=$(date -r "$l" '+%Y-%m-%d' 2>/dev/null)
      printf '%-50s %s\n' "$rel" "DRIFT  origin=${s_lines}L/${s_when}  live=${l_lines}L/${l_when}"
      drift=$((drift + 1))
    fi
  done < "$EXTERNAL"
fi

echo
echo "in sync: $ok | drift: $drift | missing live: $missing | missing source: $nosrc"
checked=$((ok + drift + missing + nosrc))
if [ "$checked" -eq 0 ]; then
  echo "check-distributed: enumerated ZERO files - refusing to report a clean result over nothing" >&2
  exit 2
fi

if [ "$drift" -gt 0 ] || [ "$missing" -gt 0 ] || [ "$nosrc" -gt 0 ]; then
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

[ "$strict" -eq 1 ] && [ $((drift + missing + nosrc)) -gt 0 ] && exit 1
exit 0
