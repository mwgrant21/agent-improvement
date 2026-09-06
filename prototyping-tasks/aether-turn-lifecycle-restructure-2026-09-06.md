# Aether OS: give the app-server turn an explicit lifecycle

**Status: PLAN ONLY — 2026-09-06.** No Aether OS code has been changed for this
doc. The symptom it describes is bounded in `ef61da8` (merged in PR #47); the
structural fix below is deliberately NOT in that PR.

## Where this came from

Seven consecutive Codex review rounds on PR #47, findings 3, 3, 1, 1, 1, 1, 1.
**Rounds 4 through 7 were each a hazard introduced by the previous round's
fix.** Every individual fix was correct; the sequence still did not converge.

On round 7 the reviewer was asked directly whether the design was converging or
the state machine was wrong, and answered:

> "This is also the structural lifetime mismatch behind the recent cancellation
> fixes: the provider turn outlives `sendTurn`, so its late acknowledgement
> state should live in an explicit per-turn lifecycle that is retired on
> acknowledgement, completion, or child death rather than in an unbounded
> response-handler side table."

That is the root cause. It is worth recording the chain, because it is a clean
example of a class of bug that local correctness cannot catch:

| Round | Fix | Gap it opened |
|---|---|---|
| 3 | `activeTurn.set(acceptedId)` so `cancel()` has an id | a stale notification could overwrite that id |
| 4 | take the id only from `turn/start` | a cancel arriving *before* the ack has no id at all |
| 5 | replay the interrupt once the ack arrives | the replay never runs if the ack misses the deadline |
| 6 | `onLate` handler for a late ack | the handler is retained forever if the ack never comes |
| 7 | bound the handler table | (symptom bounded; cause untouched) |

Each row is `sendTurn` reaching one step further past the end of its own scope.

## The actual problem

`sendTurn` owns the turn's state in its closure, but **the provider-side turn
outlives `sendTurn`**. When `sendTurn` returns — completed, timed out, or
cancelled — the turn may still be running on the server, and the things that
still matter about it (its accepted id, whether a cancellation is outstanding,
whether a late acknowledgement should trigger an interrupt) have no owner.

Everything from round 4 onward is an attempt to smuggle that state out of a
closure that has already ended: a flag on the adapter, then a map, then a
callback, then a bounded map of callbacks.

## Minimal prototype scope

1. Introduce a `TurnRecord` owned by the adapter, not by `sendTurn`:
   `{ sessionId, requestId, turnId, cancelRequested, phase, createdAt }` where
   `phase` is `pending-ack | running | retiring | retired`.
2. `sendTurn` becomes a *consumer* of a record: it creates one, awaits the
   outcome, and returns. It does not own the record's lifetime.
3. Retire a record on exactly one of: terminal `turn/completed`, a terminal
   `turn/start` response, child death, adapter dispose, or TTL. Retirement is
   one function, not five call sites.
4. `cancel()` sets `cancelRequested` on the record. Whether the interrupt is
   sent now or when the id arrives is the record's business, not the caller's —
   which removes the pre-ack / post-ack / late-ack special cases entirely.
5. Delete `lateHandlers`, `earlyCompletions`, `turnWaiter`, `activeTurn` and
   `interrupted` as separate structures; they are all fields of one record.
6. Cap the number of live records and assert the cap in a test, as
   `retainedLateHandlerCount` does today.

## Explicit non-goals

- Changing the `ProviderAdapter` contract. This is internal to the app-server
  adapter; `legacyCodexAcp` and `claudeHeadlessCli` are untouched.
- Changing observable behaviour. Every one of the ~40 existing app-server tests
  must pass unmodified — that is the primary safety net for this refactor.
- Wiring the adapter to IPC or UI. Still deliberately unreachable.

## Acceptance evidence

- All existing tests green with no edits to their assertions.
- The five state structures above collapse into one, and the diff is a net
  reduction in `codexAppServer.ts`.
- A test proving a turn's record is retired on each of the five paths.
- **A live turn.** See below — this is the part that matters most.

## The thing that would actually have prevented all seven rounds

`turn/completed` has never run against a real `codex app-server`. Every finding
across seven rounds was in that region, and the reason is structural: the unit
fakes encode the author's understanding of the protocol, so they can only catch
deviations from that understanding, never a misunderstanding of it. Round 2's
inverted turn lifecycle (treating `turn/start`'s response as the outcome) would
have been caught in seconds by one real turn; instead it took a reviewer, and
the fixes for it generated four more findings.

`providers.live.test.ts` already exists and is opt-in via
`AETHER_LIVE_PROVIDER_SMOKE=1`. It deliberately never sends a turn, to avoid
spending model tokens. **That exclusion should be revisited**: one trivial
prompt through a real thread, gated behind its own env var so CI never runs it,
would exercise `turn/start` -> deltas -> `turn/completed` end to end. The cost
is a handful of Codex tokens per run. Weigh that against seven review rounds.

## Open questions

- Should the record live in a map keyed by session, or should a session own at
  most one record (the current de-facto assumption)? The adapter enforces one
  in-flight turn per thread today but nothing states it.
- Is `phase` worth modelling explicitly, or is it derivable from which fields
  are populated? Explicit is probably right given how much implicit state
  caused here.
- Does the same lifetime mismatch exist in `claudeHeadlessCli`? It spawns one
  process per turn, so the process *is* the lifetime — likely not, but it has
  not been checked.
