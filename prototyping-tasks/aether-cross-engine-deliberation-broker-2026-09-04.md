# Aether OS cross-engine deliberation broker

**Status: PARTIAL - 2026-09-06.** Build-order items 1-3 built and tested; items 4-9 not started.

> **Refreshed 2026-09-06, after PR #47 merged (aether-os `35e7c0d`).** The build
> notes below describe the adapters as first written. Seven Codex review rounds
> landed on them afterwards and changed several load-bearing details, recorded
> here so this doc is not read as current:
>
> - **`codexAppServer` could not run at all on Windows.** `spawn('codex')` fails
>   ENOENT: the npm-installed `codex` is a `.cmd` shim, which Node's non-shell
>   spawn will not resolve and refuses to execute since CVE-2024-27980. It now
>   resolves `@openai/codex/bin/codex.js` and launches it with `process.execPath`,
>   the same indirection `acpProcess.ts` already used. Every unit test injected a
>   fake child, so nothing exercised the real path until it was reviewed.
> - **The turn lifecycle was inverted.** `turn/start` resolves on ACCEPTANCE,
>   typically `status: "inProgress"`, with the outcome arriving later as
>   `turn/completed`. Treating the response as the outcome classified every normal
>   turn as `error` with empty text.
> - **`health()` read a field that does not exist.** `GetAccountResponse` is
>   `{ account: Account | null, requiresOpenaiAuth }` with the billing mode in
>   `account.type`, not a top-level `authMode`. Separately, `account/read` must be
>   sent with an explicit `{}` — omitting the params key entirely makes the server
>   reject it, and that rejection was being swallowed into `authMode: 'unknown'`.
> - **`claudeHeadlessCli` inherited the whole environment.** An operator with
>   `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_BASE_URL` set would
>   have had every turn billed through a metered key or third-party gateway.
>   `acpProcess.ts`'s build-from-nothing allowlist is now shared by both sides.
> - **`--restricted` is NOT read-only**, contrary to how it was first summarised.
>   Measured, it left 110 tools available including `Write`, `Edit`, `NotebookEdit`
>   and `Skill`. The guarantee needs the full set: `--restricted`,
>   `--strict-mcp-config`, `--disable-slash-commands`, a fail-closed
>   `--allowedTools Read Grep Glob`, and `--permission-prompts none`.
> - **`EvidenceBundleV1` rejects absolute paths and `..` traversal**, rather than
>   silently relativising them into an immutable record.
>
> Rounds 4-7 were each a hazard introduced by the previous round's fix. The root
> cause — the provider turn outliving `sendTurn`, so its state has no owner once
> `sendTurn` returns — is scoped separately in
> [aether-turn-lifecycle-restructure-2026-09-06.md](aether-turn-lifecycle-restructure-2026-09-06.md).
>
> Build-order status is unchanged: items 1-3 built, items 4-9 not started.
No provider registration, authentication state, or live-tree write path was changed, and no real
Claude or Codex session was driven.

Built (`electron/crossEngine/`):

- `providers/contract.ts` - the provider-neutral `ProviderAdapter` interface: capabilities,
  sessions, turns, streamed events, cancellation, usage, normalized `ProviderError` codes, and a
  single-member `PermissionDecision = 'denied'` so widening read-only policy is a visible type
  change rather than silent drift.
- `providers/fakeProvider.ts` + `providers/providerConformance.ts` - the fake-provider harness
  the plan requires *before* connecting a real provider, plus one shared conformance suite every
  adapter must pass. Capability-gated: an adapter is tested on what it claims.
- `providers/legacyCodexAcp.ts` - wraps the shipped `AcpClient` behind the contract. Honest about
  its weaknesses in `capabilities()` (no resumable sessions, no turn-level cancel, no usage, no
  output schema). `codexVerifier.ts` is untouched and still drives `AcpClient` directly, so
  one-shot verification behaviour is unchanged.
- `providers/codexAppServer.ts` - the real `codex app-server` adapter. Every method and field came
  from bindings generated off the installed CLI (`codex app-server generate-ts`, 0.153.2), not
  from documentation: `initialize`, `thread/start`, `turn/start`, `turn/interrupt`,
  `account/read`, `item/agentMessage/delta`, `thread/tokenUsage/updated`. Read-only is enforced
  at the *protocol* level (`sandbox: 'read-only'`, `approvalPolicy: 'never'`), not by
  after-the-fact refusal, and every approval request is still answered `denied`.
- `providers/claudeAgentSdk.ts` - declared, conformance-checked stub. See resolved question below.
- `evidenceBundle.ts` - `EvidenceBundleV1`: base SHA, dirty-patch hash, allowlisted file hashes,
  verified line ranges, test-command provenance, and a manifest hash over a canonical
  serialization. Deep-frozen at runtime. Carries hashes and project-relative paths only - no file
  contents, no command output, no absolute paths.

Small, behaviour-preserving change to `acpClient.ts`: an optional `onStreamEvent` observer and a
`promptSessionRaw()` extracted from `prompt()` (which now delegates to it), so an adapter can own
session lifetime and stream events. Thought/tool chunks are observable but deliberately NOT folded
into the accumulated answer, which would have corrupted existing verification results.

**Open question resolved by probe — and the plan posed it as a false binary.** It asked whether
`claude mcp serve` was sufficient *or* the Agent SDK was needed. Both were probed against Claude
Code 2.1.263, but so was a third path the plan never considered, and that third path won:

- `claude mcp serve` — entire option surface is `--debug`/`--verbose`. Exposes Claude Code's
  *tools* to an MCP client; no session, turn, cancellation, approval or usage semantics.
  Cannot drive a deliberation. **Rejected.**
- `@anthropic-ai/claude-agent-sdk` — would work, but adds a runtime dependency and a second
  authentication path. **Deferred.**
- `claude -p --output-format stream-json` — satisfies the whole contract using the CLI already
  installed, under the operator's existing login. **Chosen.** Verified by running it: `session_id`
  in `system`/`init` and `result`, `--resume` continues a session headlessly (a resumed turn
  recalled the prior answer), `stream_event`/`content_block_delta` carries text, and `result`
  carries `stop_reason` plus a usage block. A `rate_limit_event` line also carries reset windows,
  which feeds the provider-telemetry backlog item for free.

So `providers/claudeHeadlessCli.ts` is a **real adapter, not a stub**, and passes the full
conformance suite rather than only its pre-connect half. `claudeAgentSdk.ts` is deleted.

**`--restricted` alone is NOT read-only** — an early summary of this work said it was, and that
was wrong. Measured: `--restricted` left 110 tools available, *including* `Write`, `Edit`,
`NotebookEdit`, `Skill` and MCP write tools. The guarantee needs the whole set: `--restricted`,
`--strict-mcp-config` (tool surface 110 → 21, `mcp_servers: []`), `--disable-slash-commands`,
a fail-closed `--allowedTools Read Grep Glob` allowlist rather than a denylist, and
`--permission-prompts none` so denial is automatic rather than incidental. Verified
adversarially: asked to write a file *and* to spawn a subagent that writes one, the session
refused both — "Permission for this tool use was denied. It requires approval, and this session
has no approval surface" — and no file appeared on disk.

**Privacy.** Nothing about shipped outbound behaviour changed: no IPC handler, store action or
UI control constructs the adapter, so it is reachable only from tests. `docs/privacy-and-data.md`
gains §12 documenting it as a distinct future exception anyway — it would be Aether composing
and sending a turn on its own initiative, unlike §11's operator-driven terminals — along with
the conditions for ever wiring it up (its own opt-in, separate from `crossEngineCfg.enabled`).
`PROGRESS.standing-decisions.md` and `CLAUDE.md`'s "no model call site" bullet were amended to
match rather than left quietly false.

Tests: 88 new across the provider and evidence suites; full suite 1289 -> 1377 passing,
suite 1289 -> 1366 passing, 133/133 files. The provenance requirement is covered directly -
modifying a cited file, hash, line range, base SHA, or test command makes the citation unsupported,
and a tampered bundle invalidates every citation in it.

`src/shared/noApiCalls.test.ts`'s Codex-boundary guard tripped on the `'codex-acp'` `ProviderId`
literal. The first fix allowlisted two files; the better fix, applied 2026-09-06, renames the ids
to camelCase so the collision never happens. The original guard is restored **verbatim** with no
allowlist to maintain, and a strictly narrower assertion replaces it: no module outside
`acpProcess.ts` may `require.resolve` an `@agentclientprotocol` package — the operation that
actually reaches the executable, which a token grep cannot express. Two further guards were
added: only `claudeHeadlessCli.ts` may spawn the `claude` binary, and that adapter's read-only
flag set cannot be weakened (no `--disallowedTools`, no `bypassPermissions`, no `acceptEdits`).

Not built (items 4-9): read-only reciprocal review mode, the termination/policy engine, the
cross-engine trace UI, the debugging test loop, decision-tree interrogation, single-writer worktree
mode, `deliberation.db`, and the adapter-parity test that would let ACP be retired.

## Gap

Aether's current cross-engine path is a deliberately narrow, one-shot Codex verification of a completed Claude dispatch. It creates a fresh Codex ACP session, supplies a temporary read-only snapshot, retains the final structured verdict, and denies provider tool permissions. It does not support durable peer sessions, reciprocal questions, debugging experiments, bounded debate, or a decision tree.

The installed runtimes now expose richer local control surfaces: Codex CLI 0.153.2 provides `app-server` and `mcp-server`, while Claude Code 2.1.260 provides `mcp serve`. Official Codex documentation recommends App Server for rich clients needing authentication, conversation history, approvals, and streamed agent events. This makes a provider-neutral broker a current, concrete Aether need rather than a speculative integration.

## Architectural decision

Aether owns the conversation. Claude and Codex must not be registered as unrestricted peers that can recursively invoke each other.

Add a `DeliberationOrchestrator` with provider adapters:

- `CodexAppServerAdapter` over local stdio JSON-RPC.
- A Claude adapter selected by a protocol spike between `claude mcp serve` and the Claude Agent SDK.
- `LegacyCodexAcpAdapter` retained until one-shot verification reaches parity through the new path.

Every run uses an immutable evidence bundle, a policy and budget, an explicit writer role, and a bounded state machine:

`preparing -> independent-analysis -> exchange -> challenge -> synthesis -> completed | awaiting-human | cancelled | failed`

## Minimal prototype

1. Generate and pin Codex App Server TypeScript bindings against the tested CLI version.
2. Implement a fake-provider contract harness before connecting either real provider.
3. Define provider-neutral types for capabilities, sessions, turns, streamed events, cancellation, usage, and approval requests.
4. Define `EvidenceBundleV1`: base SHA, dirty-patch hash, allowlisted file hashes, verified line ranges, test-command provenance, and snapshot manifest hash.
5. Add a separate `deliberation.db`; do not place orchestration state in either collector database.
6. Implement one read-only workflow first: independent analysis, one reciprocal challenge per provider, then evidence-backed synthesis.
7. Enforce initial limits: two providers, two exchange rounds, three branches per node, depth three, one approved test batch per round, and ten minutes wall time.
8. Persist only structured claims, citations, hashes, usage, decisions, dissent, and stop reasons. Keep raw prompts, source excerpts, and provider streams ephemeral.
9. Expose the run as a turn DAG in the existing diagnostics surface, including evidence edges and unresolved contradictions.
10. Preserve current one-shot `VerificationResultV1` behavior through an adapter-parity test before retiring ACP.

## Safety boundaries

- Local stdio transports only for the prototype; no listening network socket.
- Both providers default to read-only disposable snapshots with network disabled.
- Providers propose tests; Aether validates and executes approved tests in disposable snapshots.
- Exactly one writer may be designated in a later implementation phase. Live-tree edits remain a separate user-approved action.
- Permissions never transfer from one provider to the other.
- Detectors may recommend a deliberation but may not start one automatically.
- Stop on material unresolved disagreement, two no-new-evidence rounds, a repeated claim cycle, any budget limit, invalid provenance, provider failure, auth change, or user cancellation.
- Consensus without valid evidence does not resolve a material claim; preserve dissent for the operator.

## Verification plan

- Adapter contract tests for malformed/out-of-order JSON-RPC, unknown methods, process death, timeout, cancellation, and capability changes.
- State-machine tests for every mode and stop reason.
- Property tests showing provider output cannot exceed round, branch, time, or usage limits.
- Adversarial tests for prompt injection, path traversal, symlinks, fabricated citations, recursive provider calls, and permission escalation.
- Provenance tests that modify a cited file/hash/line and require the claim to become unsupported.
- Windows CI with fake providers; real Claude/Codex smoke tests remain explicit local opt-in so CI contains no credentials.

## Backlog integration

This replaces the standalone Codex-telemetry item in Aether's 13-item improvement backlog. Telemetry becomes provider-neutral deliberation usage and health. It also expands the project/worktree launcher, nested trace, Doctor panel, incremental evidence index, IPC hardening, ACL protection, detector feedback, and Windows CI items. Renderer recovery and collector consolidation stay independent.

## Open questions

- Does `claude mcp serve` expose sufficient session, cancellation, approval, and event semantics, or should the first Claude adapter use the Agent SDK?
- Which ChatGPT/Claude subscription authentication paths are stable and permitted for embedded orchestration without adding API-key billing?
- Should the first synthesis be deterministic rule-based reconciliation, a designated arbiter turn, or operator-only when claims conflict?
- What exact structured content may be persisted without violating Aether's store-the-signal-not-the-payload privacy rule?
- Which debug commands can be safely allowlisted for disposable-snapshot execution on Windows?
