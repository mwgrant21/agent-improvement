# Domains

One file per domain (`powershell.md`, `app-dev.md`, `tooling.md`,
`browser-automation.md`, ...). Each holds the durable, graded lessons the loop has
promoted. Keep entries short and reusable - a lesson is a general rule, not a
one-off event.

## Lesson entry format

```
### <Short imperative title>

- <The rule: what to do or avoid>
- Why: <why this matters in this environment>
- Evidence: <where it was confirmed - session date / script / task>
- Added: YYYY-MM-DD (<machineId>)
```

Only lessons that pass the grade gate (see the `agent-learn` skill's
`grading-rubric.md`) land here. Everything below threshold is dropped locally and
never synced. Append-only in spirit: UPDATE an existing entry rather than
duplicating it; never silently delete another machine's lesson.
