# Prototyping task: add a Windows-native CI lane to Aether OS

**Source evaluation:** evaluate-repo improvement review of `mwgrant21/Aether-OS`, 2026-09-04.
**Verdict:** genuine gap, worth adding; fits now. Aether OS is a Windows-first Electron app, yet its checked-in CI runs only on `ubuntu-latest`. Its sole open issue (#22) is Windows-session/GPU-specific, and recent commits document Windows-only AppContainer ACL, Electron postinstall, `node-pty`, and archive-tool behavior.

## Gap: the platform carrying the product risk is not represented in CI

The current workflow validates Node 22/24 and the Go collector on Linux. That is valuable for portable logic, but it cannot catch the failure modes that have consumed the most real debugging time: Electron/AppContainer ACL setup, Windows path and shell semantics, `node-pty` loading, the exact Electron binary install sequence, or Windows-specific build output.

This plan does not claim a hosted runner can reproduce the desktop-lock/GPU-context issue. The first goal is narrower: stop merging Windows build/runtime regressions that Linux CI cannot observe.

## Fit evidence

- The project is an Electron desktop cockpit used on Windows, with Windows-specific setup in `scripts/grant-appcontainer-acl.js`.
- GitHub shows one open issue, #22, for a white renderer after Windows desktop lock; instrumentation landed, but the incident remains unfixed.
- The 2026-08-19 Electron 43.4.1 upgrade documented a first-launch failure caused by the binary not existing when the ACL grant ran.
- The same upgrade recorded five local failures caused by GNU `tar --force-local` assumptions on Windows `bsdtar`, a concrete example of Linux-green behavior diverging from the target host.

## Minimal prototype scope

1. Add one independent `windows-latest` CI job; do not expand the existing Linux matrix initially.
2. Use one supported Node version for the first proof (prefer the project's primary local version, otherwise Node 24), then run:
   - `npm ci`
   - `npm test`
   - `npm run build`
   - `npm run electron:build`
3. Add explicit artifact assertions for `out/main`, `out/preload`, and `out/renderer`, because a partial Electron build can present as a white-screen product bug.
4. Add a small smoke check that the installed Electron binary exists and `node-pty` can be loaded by the Node process used in CI. Do not launch an interactive Claude/Codex terminal.
5. Keep the Windows job blocking once its initial platform findings are fixed. Do not mark it `continue-on-error`; that would turn the gap into decoration.
6. Record any failures as platform findings before changing product code. In particular, separate test-harness portability defects from real runtime defects.

## Explicit non-goals

- Reproducing #22's lock/unlock GPU failure on a GitHub-hosted runner.
- Publishing installers or creating a release pipeline.
- Code-signing, auto-update, or changing the project's current personal-tool packaging decision.
- Driving a live Claude or Codex session in CI.

## Acceptance evidence for a later implementation

- A pull request shows the existing Linux jobs and the new Windows job green.
- The Windows log proves Electron and `node-pty` loaded from the fresh `npm ci` install.
- The Electron build output contains populated main, preload, and renderer trees.
- A deliberate Windows-only failing probe is shown red before the final fix, so the lane is proven non-vacuous.

## Open questions

- Should the first lane use Node 22, Node 24, or the exact version used on the primary development machine? One lane is enough for the prototype; widen only after it pays for itself.
- Does `grant-appcontainer-acl.js` behave safely without elevation on `windows-latest`, or should CI exercise its decision logic separately while skipping the actual ACL mutation?
- Which of the previously observed `bsdtar` failures remain on current master? Treat this as discovery, not as a reason to weaken the job.
- After the build lane is stable, is a non-interactive packaged-app launch viable on GitHub-hosted Windows, or does renderer/GPU smoke testing belong on a self-hosted runner with a real desktop session?

## Status

**PARTIAL - 2026-09-06.** Implemented and verified locally; not yet proven by a real GitHub run.

Built:

- `.github/workflows/ci.yml` - new blocking `windows-build` job on `windows-latest`,
  Node 24.x, running `npm ci`, `npm test`, `npm run build`, `npm run electron:build`.
  Not `continue-on-error`. The existing Linux matrix and Go job are untouched, per the
  plan's "one independent job" scope.
- `scripts/verify-electron-artifacts.mjs` - asserts `out/main`, `out/preload` and
  `out/renderer` each contain non-empty files, that the Electron binary exists, and that
  `node-pty` loads and exposes `spawn()`. Cross-platform, runnable locally.
- `electron/crossEngine/snapshotBuilder.ts` - dropped the GNU-only `tar --force-local`.

**The lane was proven non-vacuous by a real bug, not a synthetic probe.** The plan asked
for "a deliberate Windows-only failing probe shown red before the final fix"; the platform
finding turned out to be better evidence:

- `C:\Windows\System32\tar.exe` is bsdtar 3.8.8 and rejects `--force-local` outright
  (`Option --force-local is not supported`, exit 1), so `buildVerificationSnapshot()` failed
  on a default Windows box.
- It was invisible locally because Git Bash puts GNU tar ahead of System32 on PATH. Under a
  PowerShell-launched process - which is what GitHub's Windows runner uses -
  `snapshotBuilder.test.ts` goes **6/6 red** with the flag and **6/6 green** without.
- Every Ubuntu job was green the entire time this was broken. That is precisely the class of
  failure this lane exists to catch.

Open questions resolved by reading/probing rather than assumption:

- *Node version for the first lane*: 24.x, matching the newest Linux matrix entry so a failure
  is attributable to the OS, not the runtime. (Local dev is on 25.8.2; the repo has no `.nvmrc`.)
- *Does `grant-appcontainer-acl.js` behave unelevated on `windows-latest`?* Yes - it exits 0
  when `electron/dist` is absent and catches `icacls` failures with a warning rather than
  failing the install. No CI special-casing needed; verified by reading it.
- *Which bsdtar failures remain on master?* Exactly one, the `--force-local` call above.

Still outstanding (why this is PARTIAL, not BUILT): nothing has been pushed, so no PR has shown
the job green on a real runner, and the fresh-`npm ci` Electron/node-pty smoke has only been
observed against this machine's existing `node_modules`. The packaged-app / renderer-GPU smoke
test remains a deliberate non-goal.
