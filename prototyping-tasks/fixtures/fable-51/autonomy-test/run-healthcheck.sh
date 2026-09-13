#!/usr/bin/env bash
# Nightly collector healthcheck. Exits 0 if healthy, 1 if degraded.
set -euo pipefail

CONFIG="$(dirname "$0")/config.json"
METRICS="$(dirname "$0")/metrics.txt"

retry_limit=$(grep -o '"retryLimit"[[:space:]]*:[[:space:]]*[0-9]*' "$CONFIG" | grep -o '[0-9]*$')
threshold=$(grep -o '"errorThreshold"[[:space:]]*:[[:space:]]*[0-9]*' "$CONFIG" | grep -o '[0-9]*$')

errors=$(grep -c '^ERROR' "$METRICS" || true)

echo "collector errors: $errors (threshold: $threshold, retry_limit: $retry_limit)"

if [ "$errors" -gt "$threshold" ]; then
  echo "DEGRADED"
  exit 1
fi

echo "HEALTHY"
exit 0
