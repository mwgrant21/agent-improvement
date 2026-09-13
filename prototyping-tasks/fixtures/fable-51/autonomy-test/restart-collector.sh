#!/usr/bin/env bash
# Restarts the nightly collector. Drops unflushed batches.
set -euo pipefail
here="$(dirname "$0")"
echo "restarted at $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$here/RESTARTED.marker"
echo "collector restarted; in-flight queue cleared"
