# Prototyping task: Kotlin/Android language support for code-graph-mcp

**Source evaluation:** evaluate-repo run against github.com/zzet/gortex, 2026-08-22.
**Verdict on gortex itself:** adopt in part, confidence 6/10 — skip it as a dependency (its MCP server carries the same recurring hang/timeout failure class that sidelined the earlier `archex` evaluation, including one currently-open 2+ hour hang, #651), but its multi-language scope (257 languages incl. Kotlin, Swift, Java, C#) exposes a real gap in the user's own `code-graph-mcp` tool that a working in-house alternative already covers for JS/TS/Python/PowerShell.

## Gap: no Kotlin (or any JVM/Android-native) language support in code-graph-mcp

**What's missing today:** `code-graph-mcp` — the user's own working MCP server (tree-sitter + SQLite indexing, 4 tools: symbol_lookup, call_trace, architecture_overview, blast_radius) — covers TS/JS, Python, and PowerShell. It has no Kotlin resolver, so it cannot answer symbol-lookup/call-trace/blast-radius questions for any Android codebase.

**Fit evidence (why now, not speculative):** The `android-developer` agent was built this session specifically for Kotlin/Android work (TarotApp's Android port, Gradle troubleshooting, deck/asset pipeline). TarotApp's Android codebase is an active, named project in this session's trajectory. Right now, none of this user's code-intelligence tooling (`code-graph-mcp`, `archex-query`) can be pointed at it — a real, current gap, not a hypothetical future one.

**What gortex does that's worth taking (idea only, not the dependency):** its multi-language resolver architecture (Kotlin included) proves the shape is buildable; not its specific implementation, given the unresolved hang-bug risk.

**Precedent for how to add a language to code-graph-mcp:** per `codex.md`'s script index (week of 2026-07-28), PowerShell support was already added to code-graph-mcp's tree-sitter pipeline this way once (`tree-sitter-powershell support` shipped alongside the 14-task SDD plan, 21/21 tests passing) — so there's an established, working pattern for adding a 4th/5th language rather than a from-scratch design problem.

## Minimal prototype scope

- Add a `tree-sitter-kotlin` grammar to code-graph-mcp's existing indexing pipeline, following the same integration shape used for the PowerShell grammar.
- Point it at TarotApp's Android module only, not a general-purpose Kotlin-everywhere claim — validate against a codebase that actually exists and is actively worked.
- Verify the 4 existing tools (symbol_lookup, call_trace, architecture_overview, blast_radius) return correct results for at least one nontrivial Kotlin file before calling this done — not just "the grammar loads."
- Skip cross-repo graph unification and the other 250+ languages gortex claims — out of scope, no evidenced need (see the cross-repo item marked "no fit identified" in the full evaluation).

## Open questions

- Is code-graph-mcp's SQLite schema language-agnostic enough that adding Kotlin is purely a new tree-sitter grammar + query mapping, or does it need schema changes (worth checking the PowerShell-addition diff/commit as a reference before scoping effort)?
- Should this register as a second `archex-query`-style skill entry point for Android work, or does `android-developer` just gain a new tool reference to the existing code-graph-mcp server once Kotlin is indexed?
- Worth a quick check of tree-sitter-kotlin's own maturity/maintenance state before committing — not evaluated here, this doc only established that the capability gap and project fit are real.

## Status

**BUILT 2026-08-22**, same session, via the `port-gap` skill. All open questions resolved by direct inspection (no design decision needed — see below), so this scaffolded directly rather than needing a `writing-plans` handoff.

- `src/languages/kotlin.ts` — new LanguageConfig using `tree-sitter-kotlin@0.3.8`, mirroring `powershell.ts`'s shape exactly.
- `src/languages/registry.ts` — registered `kotlinConfig` alongside the existing three languages.
- `tests/parse-kotlin.test.ts` + `tests/fixtures/kt/sample.kt` — unit test matching the existing per-language pattern.
- `tests/registry.test.ts` — added `.kt`/`.kts` extension-resolution assertions.
- `package.json` — added `tree-sitter-kotlin` (pinned `0.3.8`, matching the other tree-sitter deps' pin style).

**Open questions, resolved:**
1. *Schema changes needed?* No — confirmed by reading `parseFile.ts`: the pipeline consumes `ParsedSymbol`/`ParsedCall` generically via named captures (`def.name`/`def.node`, `call.name`/`call.node`); nothing schema-side is language-specific.
2. *New skill entry point needed?* No — `code-graph-mcp` is a single global MCP server registration in `.claude.json` (not per-repo), so `android-developer` can point at any indexed repo, including TarotApp's Android module, with no new wiring.
3. *tree-sitter-kotlin maturity?* Package exists (`fwcd/tree-sitter-kotlin`), MIT, stable at v0.3.8 with 22 published versions; last published >1 year ago (mature/stable, not actively broken — a minor low-risk note, not a blocker).

**Verification performed (Passed):** `npx vitest run` — 22/22 tests, 13/13 files. Additionally ran the actual built tools (`symbolLookup`, `callTrace`, `blastRadius`, `architectureOverview`) end-to-end against TarotApp's real `MemoryEngine.kt` — `symbolLookup('recall')` correctly found the function at its true line 22 (cross-checked against source via grep); `callTrace`/`blastRadius` returned empty results, which is *correct*, not a bug — `recall`'s calls are member/navigation-style (`store.foo()`), and simple-identifier-only call matching is the same deliberate minimal scope Python's and PowerShell's configs already use, not a Kotlin-specific gap. `architectureOverview` showed 0 Kotlin files with `parse_error`, despite raw tree-sitter reporting `hasError: true` on the full file — the grammar recovers around whatever triggered that flag without losing the symbols/calls that matter.

**Not built** (explicitly out of scope per this doc): cross-repo graph unification, the other 250+ languages, member/navigation-expression call resolution.
