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

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const CURSOR = join(HERE, 'cursor.local.json');
const DRY = process.argv.includes('--dry-run');

function gh(args, { allowFail = false } = {}) {
  try {
    return execFileSync('gh', args, { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
  } catch (err) {
    if (allowFail) return null;
    throw err;
  }
}

// --- step 0: kill switch --------------------------------------------------
const statePath = join(HERE, 'STATE.md');
if (existsSync(statePath)) {
  const paused = /^paused:\s*(\S+)/m.exec(readFileSync(statePath, 'utf8'))?.[1];
  if (paused === 'true') {
    console.log('pr-review-watch: paused');
    process.exit(2);
  }
}

// --- step 1: assert the source is reachable before believing a zero -------
// A failed `gh` and a genuinely quiet fleet must never look the same.
if (gh(['auth', 'status'], { allowFail: true }) === null) {
  console.log('pr-review-watch: gh UNAVAILABLE on this machine - not reporting "no new reviews"');
  process.exit(2);
}

// --- step 2: enumerate open PRs ------------------------------------------
const prs = JSON.parse(
  gh(['search', 'prs', '--author', '@me', '--state', 'open', '--json', 'repository,number,title,url', '--limit', '50'])
);

const cursor = existsSync(CURSOR) ? JSON.parse(readFileSync(CURSOR, 'utf8')) : { prs: {}, polls_since_report: 0 };
cursor.prs ??= {};

// Prune entries whose PR is no longer open, so the cursor stays bounded by
// open-PR count rather than growing forever.
const openKeys = new Set(prs.map((p) => `${p.repository.nameWithOwner}#${p.number}`));
for (const k of Object.keys(cursor.prs)) if (!openKeys.has(k)) delete cursor.prs[k];

// --- step 3: find what is new --------------------------------------------
const findings = [];
let baselined = 0;

for (const pr of prs) {
  const repo = pr.repository.nameWithOwner;
  const key = `${repo}#${pr.number}`;
  const reviews = JSON.parse(gh(['api', `repos/${repo}/pulls/${pr.number}/reviews`, '--paginate']));
  const comments = JSON.parse(gh(['api', `repos/${repo}/pulls/${pr.number}/comments`, '--paginate']));
  const owner = repo.split('/')[0];

  const maxReviewId = reviews.reduce((m, r) => Math.max(m, r.id), 0);
  const maxCommentAt = comments.reduce((m, c) => (c.created_at > m ? c.created_at : m), '');

  const seen = cursor.prs[key];
  if (!seen) {
    // First time this PR is seen on this machine: baseline it silently rather
    // than dumping its entire review history as "new".
    cursor.prs[key] = { last_review_id: maxReviewId, last_comment_at: maxCommentAt, title: pr.title, url: pr.url };
    baselined += 1;
    continue;
  }

  const newReviews = reviews.filter((r) => r.id > (seen.last_review_id ?? 0));
  const newComments = comments.filter(
    (c) =>
      c.created_at > (seen.last_comment_at ?? '') &&
      // Our own trigger comments are requests, not feedback.
      !(c.user?.login === owner && /^@codex\s+review/i.test(c.body ?? ''))
  );

  if (newReviews.length || newComments.length) {
    findings.push({ key, title: pr.title, url: pr.url, newReviews, newComments });
  }
  cursor.prs[key] = { last_review_id: maxReviewId, last_comment_at: maxCommentAt, title: pr.title, url: pr.url };
}

// --- report ---------------------------------------------------------------
if (findings.length === 0) {
  cursor.polls_since_report = (cursor.polls_since_report ?? 0) + 1;
  if (!DRY) writeFileSync(CURSOR, JSON.stringify(cursor, null, 2));
  const note = baselined ? ` (${baselined} PR(s) baselined this run)` : '';
  console.log(`pr-review-watch: no new review activity across ${prs.length} open PR(s)${note}`);
  process.exit(0);
}

console.log(`pr-review-watch: NEW review activity on ${findings.length} PR(s)\n`);
for (const f of findings) {
  console.log(`${f.key} — ${f.title}`);
  console.log(`  ${f.url}`);
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
