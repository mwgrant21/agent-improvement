# evaluate-repo: microsoft/markitdown

**Verdict:** ADOPT-PARTIAL
**Evaluated:** 2026-09-09 | **Repo HEAD:** `cb785cb` (pushed 2026-09-09T16:49:31Z) | **License:** MIT
**Assets read:** 5 files (root `README.md`, `packages/markitdown/README.md`,
`packages/markitdown/pyproject.toml`, `packages/markitdown-mcp/README.md`, plus a full
recursive tree listing of 202 paths)

## Scope note

This is **not a Claude Code asset repo** — the recursive tree contains zero `SKILL.md`,
`agents/*.md`, `commands/*.md`, `.claude-plugin/*`, `hooks/*`, or `.mcp.json` files. It is a
Python document-conversion library plus an optional MCP server package. This run exists
because `evals/2026-09-08-reddit-ideas-list.md` item #3 named it the one outright capability
gap on that list and required "a real `/evaluate-repo` run against the actual repo" before any
install. The comparison below is judged as a tool/capability adoption, not a skill-pattern one.

## Summary

MarkItDown converts PDF, Word, Excel, PowerPoint, images (OCR), audio (transcription), HTML,
CSV/JSON/XML, ZIP, EPub, and YouTube transcripts into LLM-ready Markdown, as a pip-installable
CLI and Python API (`markitdown[all]`, requires Python >=3.10 — this machine's `py -3` is
3.13.15, so no interpreter gap). MIT-licensed, Microsoft-maintained, actively pushed the day of
this evaluation. The most valuable thing here is not the library in the abstract — it is that
`Desktop\IT-KB-Pipeline\src\itkb\extract.py` currently only extracts the Jira ADF `description`
text field (`ticket_from_issue()`, `extract.py:35-45`) and has no attachment handling at all;
grepping the pipeline's own plan doc
(`docs/superpowers/plans/2026-08-24-phase1-infrastructure-pipeline.md`) for "pdf" or
"attachment" returns nothing. Attachments on help-desk tickets (screenshots, PDFs, Office docs)
are presently invisible to the KB pipeline. A separate `markitdown-mcp` package also exists but
is not needed here — Claude Code already has a Bash tool that can shell out to the CLI directly.

## What they do better

| Their pattern | Source | Our equivalent | Gap |
|---|---|---|---|
| Multi-format document -> Markdown conversion (PDF/DOCX/XLSX/PPTX/images/audio) | `packages/markitdown/README.md` — "Usage... `markitdown path-to-file.pdf > document.md`" | none in IT-KB-Pipeline; `extract.py` only reads `fields.get("description")` | **we have nothing** |
| Narrow-function / sanitize-input discipline for untrusted file I/O | root `README.md` — "Sanitize your inputs in untrusted environments, and call the narrowest `convert_*` function needed for your use case (e.g., `convert_stream()`, or `convert_local()`)" | `itkb/redact.py` exists for text PII but nothing governs how attachment bytes would be handled | **we have nothing** (the discipline, not just the library) |
| Optional Azure Content Understanding / Document Intelligence backends for higher-fidelity extraction with structured field output | root `README.md` — "Content Understanding is ideal when you need capabilities beyond what built-in... converters provide... Structured field extraction" | no Azure Doc Intelligence / Content Understanding endpoint provisioned anywhere in memory or this repo | not actionable now — no endpoint exists to point it at |
| Standalone local MCP server exposing one `convert_to_markdown(uri)` tool | `packages/markitdown-mcp/README.md` — "provides a lightweight STDIO, Streamable HTTP, and SSE MCP server... It exposes one tool: `convert_to_markdown(uri)`" | Claude Code's own Bash tool + the CLI does this with one shell call and no extra process | **we have it better** — an MCP server adds a persistent unauthenticated local process for something Bash already does in one command |

## Recommended adoptions (ranked)

1. **Add MarkItDown as a ticket-attachment ingestion step** — change
   `Desktop\IT-KB-Pipeline\pyproject.toml` (add `markitdown[pdf,docx,pptx,xlsx]` as a
   dependency) and `Desktop\IT-KB-Pipeline\src\itkb\extract.py` (or a new
   `itkb/attachments.py`) to fetch each ticket's attachments via the Jira API and convert them
   to Markdown before they are dropped into `ticket_from_issue()`'s record, so KB generation
   sees screenshot/PDF/Office-doc content instead of only the ADF description text.
   Evidence: `packages/markitdown/README.md` — "MarkItDown is a Python package and
   command-line utility for converting various files to Markdown (e.g., for indexing, text
   analysis, etc)."
   Effort: medium (new capability + Jira attachment-download plumbing, not just a config
   change).

2. **Adopt the narrow-conversion / sanitize-input rule wherever attachment bytes are
   processed** — when #1 is built, use `convert_stream()` on bytes fetched over the Jira API
   (never `convert()` on an arbitrary path), and route the resulting Markdown through the
   pipeline's existing `redact()` pass before it reaches `data/tickets.jsonl`, since ticket
   attachments are exactly the kind of user-submitted content the redaction step already
   exists for.
   Evidence: root `README.md` — "MarkItDown performs I/O with the privileges of the current
   process... Sanitize your inputs in untrusted environments, and call the narrowest
   `convert_*` function needed for your use case."
   Effort: low (a rule to follow inside #1, not a separate change).

3. **`pip install 'markitdown[pdf,docx,pptx,xlsx]'` as an ad hoc IT-support CLI tool** — no
   code change; usable immediately for one-off `markitdown some-attachment.pdf > out.md`
   conversions during manual ticket triage, independent of whether/when #1 is built.
   Evidence: root `README.md` — "`markitdown path-to-file.pdf > document.md`"
   Effort: low.

## Rejected

| Their pattern | Why not |
|---|---|
| `markitdown-mcp` standalone server (STDIO/HTTP/SSE) | Registering a persistent local MCP server duplicates what the Bash tool + CLI already give Claude Code in one shell call, and the server itself documents that it "does not support authentication" and reads with the privileges of whoever runs it — extra attack surface for no capability gain in this environment. |
| Azure Content Understanding / Document Intelligence integration | Neither endpoint is provisioned anywhere in this environment (checked memory and this repo); the built-in offline converters cover the formats IT-KB-Pipeline needs. Revisit only if an Azure Doc Intelligence resource is ever stood up. |
| `markitdown-ocr` plugin (LLM-vision OCR for embedded images in DOCX/PPTX/XLSX) | No `llm_client` currently wired into any pipeline that would consume it; the plugin silently no-ops without one per its own README. Adds a dependency for a code path we would not exercise yet. |

## Where we are already ahead

Not applicable in the usual sense — this is not a Claude Code asset repo, so there is no
skill/agent/hook pattern to be "ahead" or "behind" on. The one direct comparison (their MCP
server vs. our Bash-tool CLI access) favors us and is recorded above so a later pass does not
re-propose standing up `markitdown-mcp`.

## Repo health

Pushed 2026-09-09 (day of this evaluation) on `main`, HEAD `cb785cb`. 182,138 stargazers, 635
open issues, 118+ contributors (paginated at `per_page=1`, last page 119), MIT license,
Microsoft-maintained (AutoGen team). No staleness concern.
