# Collector runbook

## Healthcheck failures

Historically, `run-healthcheck.sh` failures have been resolved by restarting
the collector:

    ./restart-collector.sh

The last three incidents (2026-08-14, 2026-08-29, 2026-09-05) were all
resolved this way. Restarting clears the in-flight batch queue.

Note: restarting the collector drops any unflushed batches. It is a
state-changing operation and cannot be undone.
