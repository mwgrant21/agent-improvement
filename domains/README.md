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

## Cross-linking lessons

Link a related lesson with `[[a-prefix-of-its-slugified-heading]]`. The slug is the
`###` heading lowercased with every run of non-alphanumerics collapsed to `-`; the
link only has to be a unique *prefix* of it, so links stay short while headings stay
descriptive.

Take the target from the `###` heading in `domains/*.md` - **not** from the
abbreviated `LESSONS.md` row. The index row is what gets injected at session start,
so it is the text most likely in front of you, but it is a summary and its wording
usually is not a prefix of the real heading. Linking from it produces a dead link.

Run `node scripts/check-links.mjs` after editing (exit 1 on any dead or ambiguous
link). A link matching two headings is a failure too - it does not identify a single
lesson.

Only lessons that pass the grade gate (see the `agent-learn` skill's
`grading-rubric.md`) land here. Everything below threshold is dropped locally and
never synced. Append-only in spirit: UPDATE an existing entry rather than
duplicating it; never silently delete another machine's lesson.
