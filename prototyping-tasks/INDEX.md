# Prototyping tasks — index

One row per plan doc in this directory. Maintained by `port-gap`'s Phase 5
(close the loop) — every time a doc's Status section is updated, this table
gets a matching row update in the same commit. Never let this drift from
the docs themselves; if they disagree, the doc's own Status section is the
source of truth and this index is stale and needs re-syncing.

Status values: **BUILT** (fully done and verified), **PARTIAL** (some items
built, others deferred/handed off — see doc), **HANDED OFF** (routed to
`superpowers:writing-plans`, not yet implemented), **PLAN ONLY** (not
started).

| Doc | Source eval | Status | Notes |
|---|---|---|---|
| [codegraph-adopt-primary-2026-08-22.md](codegraph-adopt-primary-2026-08-22.md) | colbymchenry/codegraph | BUILT | MCP server registered + verified; `explore` tool steal-idea also built into code-graph-mcp; file-watcher steal-idea explicitly deferred (latency, not correctness gap) |
| [code-graph-mcp-kotlin-support-2026-08-22.md](code-graph-mcp-kotlin-support-2026-08-22.md) | zzet/gortex | BUILT | Kotlin language support added to code-graph-mcp, verified against real TarotApp code |
| [loop-operational-failure-ladder-2026-08-22.md](loop-operational-failure-ladder-2026-08-22.md) | bradygaster/squad | BUILT | New loop-design convention (loops/README.md) |
| [cross-tool-and-lineage-gaps-2026-08-16.md](cross-tool-and-lineage-gaps-2026-08-16.md) | (multi-gap internal audit) | PARTIAL | Gaps 1/2/3/6 built+verified; Gaps 4/5 handed off to writing-plans (plan exists, not implemented) |
| [orchestration-and-porting-gaps-2026-08-16.md](orchestration-and-porting-gaps-2026-08-16.md) | (multi-gap internal audit) | BUILT | 3/3 items built (runtime-router, port-gap itself, CLAUDE.md risk axis); empirical verification of routing quality still pending real use |
| [sdd-requirement-tracking-2026-08-16.md](sdd-requirement-tracking-2026-08-16.md) | (multi-gap internal audit) | BUILT | 3 items built + tested in scratch repos (sdd-tracking skill, acceptance-criteria-reviewer agent, statusline integration); 1 item (remote-MCP auth) is reference material only, deliberately no code — no attachment point exists yet |
| [skill-eval-loop-2026-08-16.md](skill-eval-loop-2026-08-16.md) | davila7/claude-code-templates skill-creator | PLAN ONLY | Not started |
| [claude-code-tips-dx-gaps-2026-08-30.md](claude-code-tips-dx-gaps-2026-08-30.md) | ykdojo/claude-code-tips | PLAN ONLY | 4 gaps (private-github-search, deterministic context reduction, gha triage, version-check). Repo is All-Rights-Reserved: install the plugin, never copy its code. Its `check-context.sh` reproduces the cache-read token-math bug already in our app-dev lessons — rewrite, don't adopt |
| [aether-os-windows-ci-2026-09-04.md](aether-os-windows-ci-2026-09-04.md) | mwgrant21/Aether-OS internal improvement review | BUILT | Blocking `windows-build` job + `scripts/verify-electron-artifacts.mjs`; green on a real runner (PR #46, run 34018756589, all 4 jobs success). Found and fixed a real Windows-only bug Ubuntu CI could never see: System32 bsdtar rejects `tar --force-local`, 6/6 tests red before the fix. Fresh `npm ci` confirmed the Electron binary lands and node-pty's prebuild loads on Node 24 |
| [aether-cross-engine-deliberation-broker-2026-09-04.md](aether-cross-engine-deliberation-broker-2026-09-04.md) | mwgrant21/Aether-OS cross-engine architecture review | PARTIAL | Build-order items 1-3 built: provider-neutral contract + conformance suite + fake harness, LegacyCodexAcp and CodexAppServer adapters (bindings generated off codex 0.153.2), immutable EvidenceBundleV1. Claude side is a REAL adapter over `claude -p` (a third option the plan's open question never considered; `mcp serve` rejected, Agent SDK deferred, no new dependency). `--restricted` alone proved NOT read-only - full fail-closed flag set verified adversarially. Not wired to IPC/UI; privacy §12 records the conditions. Items 4-9 not started |
| [aether-turn-lifecycle-restructure-2026-09-06.md](aether-turn-lifecycle-restructure-2026-09-06.md) | mwgrant21/Aether-OS PR #47, Codex review rounds 1-7 | PLAN ONLY | Give the app-server turn an explicit adapter-owned lifecycle. Seven review rounds, and rounds 4-7 were each a hazard the previous fix opened - the provider turn outlives sendTurn, so its state has no owner once sendTurn returns. Collapses five ad-hoc structures into one record. Also argues for one real live turn: turn/completed has never run against a real server, which is why the fakes could not catch any of it |
