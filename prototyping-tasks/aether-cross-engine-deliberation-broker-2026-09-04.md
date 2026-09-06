# Aether OS cross-engine deliberation broker

**Status: PARTIAL - 2026-09-06.** Build-order items 1-3 built and tested; items 4-9 not started.
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

**Open question resolved by probe, against the plan's first option.** `claude mcp serve` was
checked live (Claude Code 2.1.263): its entire option surface is `--debug`/`--verbose`. It exposes
Claude Code's *tools* to an MCP client and has no session, turn, cancellation, approval, or usage
semantics, so it cannot drive the Claude side of a deliberation. A real Claude adapter needs
`@anthropic-ai/claude-agent-sdk`, which is not a dependency of this project. Adding it is a new
runtime dependency and a second auth path, so it was left to its own scoped task; the stub throws
`NOT_IMPLEMENTED` from `connect()` rather than letting a caller silently degrade to Codex-only.

Tests: 77 new (`providers.test.ts` 52, `evidenceBundle.test.ts` 24, plus one added guard), full
suite 1289 -> 1366 passing, 133/133 files. The provenance requirement is covered directly -
modifying a cited file, hash, line range, base SHA, or test command makes the citation unsupported,
and a tampered bundle invalidates every citation in it.

`src/shared/noApiCalls.test.ts`'s Codex-boundary guard tripped on the new `'codex-acp'`
`ProviderId` literal. It was **not** loosened: the two identifier-only files are allowlisted by
name, and a new assertion now fails if either ever names the adapter package or resolves a module
path. Any other file mentioning `codex-acp` still fails as before.

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
