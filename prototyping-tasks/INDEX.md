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
