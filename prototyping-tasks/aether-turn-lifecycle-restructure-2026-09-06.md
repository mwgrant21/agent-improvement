# Aether OS: give the app-server turn an explicit lifecycle

**Status: BUILT — 2026-09-06.** Shipped across three PRs, all merged to
`master`:

| PR | What it did | Merge |
|---|---|---|
| [#49](https://github.com/mwgrant21/Aether-OS/pull/49) | the restructure: `TurnRecord`, one `retireTurn`, five structures collapsed into one | `b6fc003` |
| [#50](https://github.com/mwgrant21/Aether-OS/pull/50) | the live turn — the part this doc said mattered most | `561e746` |
| [#51](https://github.com/mwgrant21/Aether-OS/pull/51) | a bug **the restructure itself introduced**; see "What the restructure got wrong" | `a077f55` |

New file: `electron/crossEngine/providers/turnRecord.ts`.
Rewritten: `electron/crossEngine/providers/codexAppServer.ts`.
See "What was actually built" for scope item-by-item, and the answered open
questions at the end.

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

## What was actually built

Scope item by item, against the six above:

1. **`TurnRecord` owned by the adapter** — built, `turnRecord.ts`. Fields as
   proposed plus the ones the closure had been carrying implicitly (`text`,
   `usage`, `approvalDenials`, `earlyCompletions`, `buffered`, `callerWaiting`,
   and an `outcome` promise deliberately **not** tied to the caller's deadline).
2. **`sendTurn` as a consumer** — built. It creates a record, races the record's
   `outcome` against its own deadline, and returns. On a deadline it hands the
   record to retention and walks away.
3. **One retirement function** — built. `retireTurn` is private, and every one
   of the eight paths that ends a turn funnels through it: transport death,
   terminal `turn/start` response, terminal `turn/completed`, deadline with the
   id known, `outcome.kind === 'gone'`, TTL expiry, cap eviction, dispose.
4. **`cancel()` sets a flag on the record** — built. Pre-ack / post-ack / late-ack
   collapsed: `cancel()` sets `cancelRequested`, and whoever learns the id next
   sends the interrupt.
5. **Five structures collapsed into one** — built. The adapter went from **20
   fields to 10**; `lateHandlers`, `earlyCompletions`, `turnWaiter`,
   `activeTurn` and `interrupted` are now fields of a record. (One residual
   name survives on purpose: the `retainedLateHandlerCount` getter is kept as
   a test-facing alias so PR #47's cap tests still assert the cap without
   being rewritten — the point of a refactor is that its safety net does not
   move.)
6. **Cap asserted in a test** — built, `MAX_LIVE_TURNS = 16`.

And the part this doc said mattered most: **the live turn shipped** (PR #50),
gated behind its own `AETHER_LIVE_PROVIDER_TURN=1` so CI never spends a token.
It exercises `turn/start` -> deltas -> `turn/completed` against a real
`codex app-server`. Its retirement assertion deliberately rides on the *same*
turn, after a verified completion, rather than paying for a second one — on its
own it would have passed just as happily after a timeout or an error, both of
which also retire the record, and would have asserted nothing.

## What the restructure got wrong

Recorded because it is the point of this doc, not an embarrassment to omit.

**The restructure introduced a bug that reduced the retention window to zero
under the shipped defaults** — the exact window the whole exercise existed to
provide. `expiresAt` was computed at record *creation* (`now + 120s`), but the
caller waits up to 300s before giving up. Arming the expiry at that point
computed `max(0, 120s - 300s) = 0`, so the record was retired on the very next
tick. A late `turn/start` acknowledgement then found no record, and a pre-ack
cancellation could never send its promised interrupt — round 6's hazard,
silently reintroduced by the fix for round 7.

Two things about how it was found:

- **No unit test could see it.** Both retention tests used `ttl > timeout`, the
  inverse of production (120,000 vs 40, and 40 vs 20). The TTL was made
  injectable *specifically* so these bounds would be tested rather than
  asserted about, and then both values landed on the wrong side of the one
  ratio that ships.
- **The live turn did not catch it either**, and could not: it tests a turn that
  *completes*, and this bug only exists on the path where the caller gives up
  first.

The fix (PR #51) folds the three steps that must happen together —
`callerWaiting = false`, restart the TTL from *now*, arm the timer — into one
`TurnRecord.beginRetention` operation. They had been written apart and the
middle one was simply missing. That is the same lesson as the original seven
rounds, one level down: **state that must change together belongs in one
operation**, or the steps drift.

## Open questions — answered

- **Map keyed by session, or one record per session?** Neither, as posed. The
  map is keyed by `turn/start`'s **JSON-RPC request id**
  (`Map<number, TurnRecord>`). That is the turn's only identity during the
  pre-ack window, which is precisely the window rounds 5 and 6 lived in — a
  session key would have had nothing to look up there, and the server-assigned
  `turnId` does not exist yet.
- **Is `phase` worth modelling explicitly?** Yes, but with **three** states, not
  the four proposed: `awaiting-ack | running | retired`. `retiring` never
  earned its place — retirement is synchronous inside `retireTurn`, so nothing
  can observe an intermediate state.
- **Does the same lifetime mismatch exist in `claudeHeadlessCli`?** **Checked —
  no.** `SessionState.child` already lives on the adapter, not in the `sendTurn`
  closure, so `cancel()` has a real owner to reach for; one process per turn
  means the OS handle *is* the lifetime, as predicted. One caveat worth writing
  down: `state.child = null` sits after the await rather than in a `finally`, so
  the guarantee currently rests on "nothing inside that promise rejects" (today,
  nothing does — it only ever resolves through `finish`). Adding a `throw` in
  that block would leak a live child. Latent, not a live bug; a `finally` would
  make it structural instead of circumstantial.
