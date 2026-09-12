// pr-review-watch: the check described in LOOP.md steps 0-3, as a script.
//
// Exit codes (a watcher loops on 0, stops on 10, reports on 2):
//   0  ran fine, nothing new
//  10  ran fine, NEW review activity found (printed to stdout)
//   2  source unavailable or loop paused - NOT the same as "nothing new"
//
// Usage:
//   node check.mjs            # check and update the cursor
//   node check.mjs --dry-run  # check, print, do not touch the cursor
//
// The cursor is machine-local and gitignored on purpose; see STATE.md's
// "Why the cursor is machine-local" for the reasoning.
//
// The decision logic lives in the exported `selectFindings` so it can be
// tested without touching the network (check.test.mjs); the script body below
// only runs when this file is executed directly.

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const CURSOR = join(HERE, 'cursor.local.json');
const DRY = process.argv.includes('--dry-run');

// How far back to look on a PR this machine has never seen before. Long enough
// to cover "opened on the other machine, reviewed by Codex within minutes,
// first polled here a few minutes later"; short enough that tracking a new PR
// - or setting up a new machine - does not replay months of settled history.
const WINDOW_H = Number(process.env.PR_WATCH_WINDOW_H ?? 24);

// Anything the repo owner wrote is a request or a reply of ours, never feedback
// TO us. Narrowing this to the @codex-review prefix produced both of this
// loop's false positives (runs 1 and 3, 2026-09-07): a plain reply on a review
// thread is still ours. R1, retrospective 2026-09-10.
const isOwn = (c, owner) => c.user?.login === owner;

// Only Codex itself can issue a Codex verdict. Without this, anyone quoting a
// past "didn't find any major issues" comment produced a fresh CLEAN on the
// current head - a false all-clear, which is the exact failure this loop
// exists to prevent. Found by a Codex cross-runtime review, 2026-09-11.
// Issue comments carry the `[bot]` suffix; the GraphQL thread view does not.
const CODEX_LOGIN = /^chatgpt-codex-connector(\[bot\])?$/i;
const isCodex = (c) => CODEX_LOGIN.test(c.user?.login ?? '');

/**
 * Decide what to report for one PR.
 *
 * Two different questions, depending on whether this machine has seen the PR:
 *  - Tracked PR: the cursor is authoritative. Anything past it is new, however
 *    old it is.
 *  - First sight: there is no cursor to compare against. Baselining the lot
 *    silently is what used to lose a review that landed before this machine
 *    ever looked, so report what falls inside `windowH` instead - flagged
 *    `firstSeen`, because it is pre-existing activity, not new activity.
 *
 * Returns null when there is nothing to report.
 */
export function selectFindings({ reviews = [], comments = [], seen, owner, now = new Date(), windowH = WINDOW_H }) {
  const firstSeen = !seen;
  let newReviews;
  let newComments;

  if (firstSeen) {
    const cut = new Date(now.getTime() - windowH * 3600 * 1000).toISOString();
    newReviews = reviews.filter((r) => (r.submitted_at ?? '') > cut);
    newComments = comments.filter((c) => c.created_at > cut && !isOwn(c, owner));
  } else {
    newReviews = reviews.filter((r) => r.id > (seen.last_review_id ?? 0));
    newComments = comments.filter(
      (c) => c.created_at > (seen.last_comment_at ?? '') && !isOwn(c, owner)
    );
  }

  if (!newReviews.length && !newComments.length) return null;
  return { newReviews, newComments, firstSeen };
}

/**
 * Recognise a Codex verdict comment and the commit it claims to have reviewed.
 *
 * LOOP.md step 3: when Codex finds nothing it posts a plain PR comment and
 * submits no `PullRequestReview` at all, so a watcher reading only `reviews`
 * cannot tell "clean" from "still running".
 *
 * Returns null when this is not a Codex verdict, or when it carries no
 * `Reviewed commit:` SHA - without the SHA there is nothing to match against
 * the head, so it cannot be reported as a verdict on what was pushed.
 */
export function parseCodexVerdict(body = '') {
  if (!/codex\s*review/i.test(body)) return null;
  // Codex writes this as "**Reviewed commit:** `ca7cd18a1c`" - bold markers and
  // backticks around a SHA abbreviated to 10 chars. Skip any run of markdown
  // punctuation between the label and the SHA rather than assuming one layout.
  const sha = /reviewed\s+commit[*`:\s]*([0-9a-f]{7,40})/i.exec(body)?.[1];
  if (!sha) return null;
  return { clean: /did\s*n(?:o|')?t\s+find\s+any\s+major\s+issues/i.test(body), sha };
}

/**
 * Clean verdicts worth surfacing, each matched against the PR head.
 *
 * A clean verdict on a stale commit is not a clean verdict on what you pushed,
 * so the two are reported as different things rather than both as "all clear".
 */
export function selectVerdicts({ issueComments = [], owner, headSha, seen, now = new Date(), windowH = WINDOW_H }) {
  // A cursor entry written before this feature existed has no
  // last_issue_comment_at. Treating that as "never seen" would replay every
  // PR's whole comment history on the first poll after upgrading, so fall back
  // to the same first-sight window used elsewhere.
  const since = seen?.last_issue_comment_at ?? new Date(now.getTime() - windowH * 3600 * 1000).toISOString();

  const out = [];
  for (const c of issueComments) {
    if (c.created_at <= since) continue;
    if (isOwn(c, owner)) continue;
    if (!isCodex(c)) continue;

    const v = parseCodexVerdict(c.body ?? '');
    if (!v?.clean) continue;

    const n = Math.min(v.sha.length, (headSha ?? '').length);
    const current = n > 0 && headSha.slice(0, n) === v.sha.slice(0, n);
    out.push({
      status: current ? 'clean-current' : 'clean-stale',
      sha: v.sha,
      headSha,
      at: c.created_at,
      url: c.html_url,
    });
  }
  return out;
}

function gh(args, { allowFail = false } = {}) {
  try {
    return execFileSync('gh', args, { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
  } catch (err) {
    if (allowFail) return null;
    throw err;
  }
}

function main() {
  // --- step 0: kill switch ------------------------------------------------
  const statePath = join(HERE, 'STATE.md');
  if (existsSync(statePath)) {
    const paused = /^paused:\s*(\S+)/m.exec(readFileSync(statePath, 'utf8'))?.[1];
    if (paused === 'true') {
      console.log('pr-review-watch: paused');
      process.exit(2);
    }
  }

  // --- step 1: assert the source is reachable before believing a zero -----
  // A failed `gh` and a genuinely quiet fleet must never look the same.
  if (gh(['auth', 'status'], { allowFail: true }) === null) {
    console.log('pr-review-watch: gh UNAVAILABLE on this machine - not reporting "no new reviews"');
    process.exit(2);
  }

  // --- step 2: enumerate open PRs -----------------------------------------
  const prs = JSON.parse(
    gh(['search', 'prs', '--author', '@me', '--state', 'open', '--json', 'repository,number,title,url', '--limit', '50'])
  );

  const cursor = existsSync(CURSOR) ? JSON.parse(readFileSync(CURSOR, 'utf8')) : { prs: {}, polls_since_report: 0 };
  cursor.prs ??= {};

  // Prune entries whose PR is no longer open, so the cursor stays bounded by
  // open-PR count rather than growing forever.
  const openKeys = new Set(prs.map((p) => `${p.repository.nameWithOwner}#${p.number}`));
  for (const k of Object.keys(cursor.prs)) if (!openKeys.has(k)) delete cursor.prs[k];

  // --- step 3: find what is new -------------------------------------------
  const findings = [];
  let baselined = 0;

  for (const pr of prs) {
    const repo = pr.repository.nameWithOwner;
    const key = `${repo}#${pr.number}`;
    const reviews = JSON.parse(gh(['api', `repos/${repo}/pulls/${pr.number}/reviews`, '--paginate']));
    const comments = JSON.parse(gh(['api', `repos/${repo}/pulls/${pr.number}/comments`, '--paginate']));
    // Issue comments are a separate endpoint from inline review comments, and
    // a clean Codex verdict only ever appears here - see selectVerdicts.
    const issueComments = JSON.parse(gh(['api', `repos/${repo}/issues/${pr.number}/comments`, '--paginate']));
    const headSha = JSON.parse(gh(['api', `repos/${repo}/pulls/${pr.number}`])).head.sha;
    const owner = repo.split('/')[0];

    const maxReviewId = reviews.reduce((m, r) => Math.max(m, r.id), 0);
    const maxCommentAt = comments.reduce((m, c) => (c.created_at > m ? c.created_at : m), '');
    const maxIssueAt = issueComments.reduce((m, c) => (c.created_at > m ? c.created_at : m), '');

    const seen = cursor.prs[key];
    const hit = selectFindings({ reviews, comments, seen, owner });
    const verdicts = selectVerdicts({ issueComments, owner, headSha, seen });

    if (hit || verdicts.length) findings.push({ key, title: pr.title, url: pr.url, verdicts, newReviews: [], newComments: [], firstSeen: !seen, ...(hit ?? {}) });
    else if (!seen) baselined += 1;

    cursor.prs[key] = {
      last_review_id: maxReviewId,
      last_comment_at: maxCommentAt,
      last_issue_comment_at: maxIssueAt,
      title: pr.title,
      url: pr.url,
    };
  }

  // --- report -------------------------------------------------------------
  if (findings.length === 0) {
    cursor.polls_since_report = (cursor.polls_since_report ?? 0) + 1;
    if (!DRY) writeFileSync(CURSOR, JSON.stringify(cursor, null, 2));
    const note = baselined ? ` (${baselined} PR(s) baselined this run)` : '';
    console.log(`pr-review-watch: no new review activity across ${prs.length} open PR(s)${note}`);
    process.exit(0);
  }

  console.log(`pr-review-watch: review activity on ${findings.length} PR(s)\n`);
  for (const f of findings) {
    const tag = f.firstSeen ? '   [first seen on this machine - activity below is pre-existing, not new]' : '';
    console.log(`${f.key} — ${f.title}${tag}`);
    console.log(`  ${f.url}`);
    for (const v of f.verdicts ?? []) {
      if (v.status === 'clean-current') {
        console.log(`  CLEAN   Codex found no major issues on ${v.sha.slice(0, 7)} - the current head - at ${v.at}`);
      } else {
        console.log(`  STALE   Codex found no major issues on ${v.sha.slice(0, 7)}, but the head is now ${(v.headSha ?? '?').slice(0, 7)}`);
        console.log(`          That is NOT a clean verdict on what you pushed.`);
      }
    }
    for (const r of f.newReviews) {
      console.log(`  REVIEW  ${r.user.login} [${r.state}] on ${r.commit_id.slice(0, 7)} at ${r.submitted_at}`);
    }
    for (const c of f.newComments) {
      const sev = /P1\s*Badge|badge\/P1/.test(c.body) ? 'P1' : /P2\s*Badge|badge\/P2/.test(c.body) ? 'P2' : '--';
      const firstLine =
        (c.body ?? '')
          .split('\n')
          // Tags first: stripping < and > as bare punctuation would turn
          // "<sub><sub>" into "subsub" and leave it in the output.
          .map((l) =>
            l
              .replace(/!\[.*?\]\(.*?\)/g, '')
              .replace(/<\/?[a-zA-Z][^>]*>/g, '')
              .replace(/[*_`]/g, '')
              .trim()
          )
          .find((l) => l.length > 0) ?? '';
      console.log(`  ${sev}  ${c.path}:${c.line ?? c.original_line}  ${firstLine.slice(0, 100)}`);
    }
    console.log('');
  }

  cursor.polls_since_report = 0;
  if (!DRY) writeFileSync(CURSOR, JSON.stringify(cursor, null, 2));
  process.exit(10);
}

if (process.argv[1] && import.meta.url.endsWith(process.argv[1].replace(/\\/g, '/').split('/').pop())) {
  main();
}
