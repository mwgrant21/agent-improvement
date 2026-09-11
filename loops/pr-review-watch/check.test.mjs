// Tests for pr-review-watch's "what is new on this PR" decision.
//
// Run: node --test loops/pr-review-watch/check.test.mjs
//
// `now` and `windowH` are injected so these never depend on the wall clock or
// the machine's timezone.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { selectFindings } from './check.mjs';

const NOW = new Date('2026-09-11T12:00:00Z');
const ago = (h) => new Date(NOW.getTime() - h * 3600 * 1000).toISOString();

const review = (id, at) => ({ id, submitted_at: at, state: 'COMMENTED', user: { login: 'chatgpt-codex-connector' }, commit_id: 'a'.repeat(40) });
const comment = (at, body = 'a finding', login = 'chatgpt-codex-connector') => ({ created_at: at, body, user: { login }, path: 'src/x.ts', line: 5 });

const call = (over = {}) =>
  selectFindings({ reviews: [], comments: [], seen: undefined, owner: 'mwgrant21', now: NOW, windowH: 24, ...over });

test('a first-seen PR reports review activity inside the window, marked as pre-existing', () => {
  // The bug: opened on the work PC, Codex reviewed minutes later, and this
  // machine's first poll silently baselined the whole thing away.
  const r = call({ reviews: [review(100, ago(0.2))], comments: [comment(ago(0.2))] });

  assert.ok(r, 'expected a first-seen PR with recent activity to report something');
  assert.equal(r.firstSeen, true, 'must be flagged so the report does not call it "new"');
  assert.equal(r.newReviews.length, 1);
  assert.equal(r.newComments.length, 1);
});

test('a first-seen PR stays silent when all its activity predates the window', () => {
  // Why the baseline exists at all: adding a machine must not replay history.
  const r = call({ reviews: [review(100, ago(400))], comments: [comment(ago(400))] });

  assert.equal(r, null, 'months-old history on a newly-tracked PR is not news');
});

test('a known PR reports only reviews newer than the cursor', () => {
  const r = call({
    seen: { last_review_id: 100, last_comment_at: ago(5) },
    reviews: [review(100, ago(6)), review(101, ago(1))],
    comments: [],
  });

  assert.ok(r);
  assert.equal(r.firstSeen, false);
  assert.deepEqual(r.newReviews.map((x) => x.id), [101], 'the already-seen review 100 must not resurface');
});

test('a known PR ignores the window entirely', () => {
  // The window is a first-sight concession only. On a tracked PR the cursor is
  // authoritative, so an old-but-unseen review still reports.
  const r = call({
    seen: { last_review_id: 100, last_comment_at: ago(500) },
    reviews: [review(101, ago(400))],
    comments: [],
    windowH: 24,
  });

  assert.ok(r, 'an unseen review older than the window must still report on a tracked PR');
  assert.deepEqual(r.newReviews.map((x) => x.id), [101]);
});

test("our own '@codex review' trigger comment is a request, not a finding", () => {
  const r = call({
    seen: { last_review_id: 0, last_comment_at: ago(5) },
    comments: [comment(ago(1), '@codex review', 'mwgrant21')],
  });

  assert.equal(r, null);
});

test("our own trigger comment is excluded on a first-seen PR too", () => {
  // The exclusion lived only on the cursor path; the new first-seen path must
  // not reintroduce it as a "finding".
  const r = call({ comments: [comment(ago(1), '@codex review', 'mwgrant21')] });

  assert.equal(r, null);
});

test('a plain reply of ours on a review thread is not feedback to us', () => {
  // R1, retrospective 2026-09-10: this exact shape was both of the loop's false
  // positives. The narrower "@codex review" prefix test let it through, so a
  // test covering only the prefix case cannot detect the regression.
  const r = call({
    seen: { last_review_id: 0, last_comment_at: ago(5) },
    comments: [comment(ago(1), 'Agreed and fixed in 5fba9d8 - resolving.', 'mwgrant21')],
  });

  assert.equal(r, null);
});
