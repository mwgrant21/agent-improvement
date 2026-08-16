# evaluate-repo: microsoft/power-platform-skills

**Verdict:** ADOPT-PARTIAL
**Evaluated:** 2026-08-16 | **Repo HEAD:** abe68e0 (2026-08-14, matches locally installed marketplace checkout) | **License:** MIT
**Assets read:** 6 files — `plugins/code-apps/AGENTS.md`, `plugins/code-apps/shared/memory-bank.md`, `plugins/code-apps/shared/planning-policy.md`, `plugins/power-automate/AGENTS.md`, `plugins/power-automate/CLAUDE.md`, repo tree listing (1441 paths)

## Summary
This is not a fresh third-party repo — it's the upstream source of the `power-platform-skills` marketplace already installed on this machine (`~/.claude/plugins/marketplaces/power-platform-skills`), with `power-pages`, `model-apps`, `canvas-apps`, `code-apps-preview`, `mobile-app`, and `power-automate` plugins already enabled and current (local checkout matches HEAD). The user pointed at `plugins/code-apps/AGENTS.md` wanting to "add it for the round robin project." That plugin builds **Power Apps Code Apps** — sandboxed React/Vite apps that must go through Power Platform connectors and deploy via the `pa` CLI. The UW Router project's front end (`Downloads\uw-router-teams-tab`) is a standalone React + Fluent UI v9 **Teams tab** using `@microsoft/teams-js` directly — a different product surface with no `pa` deployment, no connector sandbox, and no Dataverse backing. The single most valuable thing found isn't in code-apps at all: it's the `memory-bank.md` convention (a project-root, git-committed status/progress file), which would suit UW Router's own now-local git repo better than code-apps' connector tooling does.

## What they do better
| Their pattern | Source | Our equivalent | Gap |
|---|---|---|---|
| Project-root `memory-bank.md`: committed, git-tracked file recording completed steps, decisions, created resources, current status — read at skill start, updated after each major step | `plugins/code-apps/shared/memory-bank.md` | Global cross-session auto-memory at `~/.claude/projects/C--Users-IT/memory/` (this session's `uw-router-project.md`) | **We have it worse for this project** — our memory is machine/account-scoped and invisible to anyone opening `Downloads\uw-router-teams-tab`'s own (unpushed) git repo. UW Router's governance hold on Azure AD/SSO is currently only recorded in global memory, not in the repo itself. |
| Explicit `EnterPlanMode` gate with a fixed trigger list (new features, multi-file changes, new connectors/data sources, config/env changes) and an exit checklist | `plugins/code-apps/shared/planning-policy.md` | Global CLAUDE.md "Planning" section — confidence-level framing, softer/advisory | Have it, roughly — mechanism differs (advisory vs. hard tool-gate) but intent overlaps. Not worth adopting verbatim. |
| `flowagent` MCP server for direct flow/env/connection/run operations (list/create/edit/publish/run, run history, diagnose) — already installed and enabled | `plugins/power-automate/AGENTS.md` | Nothing UW-Router-specific; project has been developed via the Power Automate portal per memory | **We have nothing being used** — this is the actually-correct tool for the round robin project's flow work (a Power Automate cloud flow), and it's already enabled, unlike code-apps. |

## Recommended adoptions (ranked)
1. **Add a project-root status file to the UW Router Teams tab repo.** Create `Downloads\uw-router-teams-tab\PROJECT-STATUS.md` (or `memory-bank.md` to match the naming convention) recording: current phase (shadow-test live, 6 associates), the two SharePoint lists and their purpose, Teams SDK wiring status, and — most importantly — the standing governance hold ("no Azure AD app registration / Graph / SSO without Chris + governance sign-off"). Update it after major steps, same discipline as `memory-bank.md` describes. This makes the constraint visible to anyone who clones the repo, not just to sessions on this machine.
   Evidence: `plugins/code-apps/shared/memory-bank.md` — "Update the memory bank immediately after completing each major step. This ensures progress is saved even if the session ends unexpectedly."
   Effort: low

2. **Use the already-installed `power-automate` plugin/`flowagent` MCP tools for the actual round-robin flow work**, instead of reaching for `code-apps`. It's enabled, current, and purpose-built for cloud-flow list/create/edit/publish/run/diagnose operations against the UW-Router flow.
   Evidence: `plugins/power-automate/AGENTS.md` — "If `flowagent-*` MCP tools are present in your tool surface, USE THEM for any flow/env/connection/run operation."
   Effort: low (no install needed — already enabled)

## Rejected
| Their pattern | Why not |
|---|---|
| Adding/using `code-apps` plugin skills (`/create-code-app`, `/add-dataverse`, connector-first sandbox model) for the round-robin project | Wrong product surface. UW Router's front end is a standalone Teams tab (React + Fluent UI v9 + `@microsoft/teams-js`), not a Power Apps Code App — it has no `pa` CLI deployment, no connector sandbox, and isn't Dataverse-backed. Forcing it through code-apps' connector-first model would require rearchitecting a working app for no benefit. |
| `create-code-app`'s `npx degit microsoft/PowerAppsCodeApps/templates/vite` scaffolding convention | Not applicable — UW Router's Teams tab is already scaffolded and has working `@microsoft/teams-js` wiring; there is no new code app to scaffold. |

## Where we are already ahead
Global auto-memory already tracks UW Router's status, decisions, and the governance hold in more narrative/contextual detail than the `memory-bank.md` template would (see `uw-router-project.md`). The gap isn't capability, it's **portability** — that memory doesn't travel with the project's own git repo. Adopting recommendation #1 complements rather than replaces the existing system.

## Repo health
MIT license, 706 stars, 74 open issues, actively maintained (pushed same day as evaluation). Locally installed marketplace checkout is already at HEAD — no update needed.
