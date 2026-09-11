// Tests for LOOP.md step 3's "a CLEAN verdict is an issue COMMENT, not a
// review record" rule.
//
// Run: node --test loops/pr-review-watch/verdict.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseCodexVerdict, selectVerdicts } from './check.mjs';

const HEAD = 'ca7cd18a1c3ea5c0fc8721ed593dc060348915ed';
const NOW = new Date('2026-09-11T12:00:00Z');
const ago = (h) => new Date(NOW.getTime() - h * 3600 * 1000).toISOString();

const issue = (at, body, login = 'chatgpt-codex-connector') => ({ created_at: at, body, user: { login }, html_url: 'https://x/1' });

// Verbatim from Aether-OS#75, the clean verdict Codex posted at
// 2026-09-09T15:00:38Z - the one this loop was blind to. Note the bolded
// label and the SHA abbreviated to 10 characters; an invented fixture without
// those got parsed fine and told us nothing.
const CLEAN = "Codex Review: Didn't find any major issues. :tada:\n\n**Reviewed commit:** `ca7cd18a1c`\n\n<details> <summary>About Codex in GitHub</summary>\nIf Codex has suggestions, it will comment; otherwise it will react with a thumbs up.\n</details>";

test('parses a clean Codex verdict and the commit it actually reviewed', () => {
  const v = parseCodexVerdict(CLEAN);
  assert.ok(v, 'the clean-verdict comment must be recognised at all');
  assert.equal(v.clean, true);
  assert.equal(v.sha, 'ca7cd18a1c', 'the abbreviated SHA as Codex actually writes it');
});

test('parses the "Did not" spelling as clean too', () => {
  const v = parseCodexVerdict(`Codex Review: Did not find any major issues.\n\nReviewed commit: ${HEAD}`);
  assert.equal(v?.clean, true);
});

test('a Codex comment with findings is not a clean verdict', () => {
  const v = parseCodexVerdict(`Codex Review: found 2 issues.\n\nReviewed commit: ${HEAD}`);
  assert.equal(v?.clean, false, 'must parse, but must not claim clean');
});

test('an unrelated comment is not a verdict', () => {
  assert.equal(parseCodexVerdict('lgtm, merging'), null);
});

test('a verdict with no Reviewed commit SHA is not trustworthy', () => {
  // Without the SHA there is nothing to match against the head, so it cannot
  // be reported as a verdict on what was pushed.
  assert.equal(parseCodexVerdict("Codex Review: Didn't find any major issues."), null);
});

test('a clean verdict on the current head reports as current', () => {
  const out = selectVerdicts({ issueComments: [issue(ago(1), CLEAN)], owner: 'mwgrant21', headSha: HEAD, seen: {}, now: NOW });
  assert.equal(out.length, 1);
  assert.equal(out[0].status, 'clean-current');
});

test('a clean verdict on a stale commit is NOT a clean verdict on the head', () => {
  // LOOP.md: "a clean verdict on a stale commit is not a clean verdict on what
  // you pushed." This is the case that would otherwise read as all-clear.
  const stale = CLEAN.replace('ca7cd18a1c', 'bbbbbbbbbb');
  const out = selectVerdicts({ issueComments: [issue(ago(1), stale)], owner: 'mwgrant21', headSha: HEAD, seen: {}, now: NOW });

  assert.equal(out.length, 1);
  assert.equal(out[0].status, 'clean-stale');
  assert.equal(out[0].headSha, HEAD, 'the report must carry the head it was compared against');
});

test("our own '@codex review' trigger is not a verdict", () => {
  const out = selectVerdicts({ issueComments: [issue(ago(1), '@codex review', 'mwgrant21')], owner: 'mwgrant21', headSha: HEAD, seen: {}, now: NOW });
  assert.deepEqual(out, []);
});

test('an already-seen verdict does not resurface', () => {
  const out = selectVerdicts({
    issueComments: [issue(ago(5), CLEAN)],
    owner: 'mwgrant21', headSha: HEAD, now: NOW,
    seen: { last_issue_comment_at: ago(2) },
  });
  assert.deepEqual(out, []);
});

test('a cursor written before this feature existed does not replay old verdicts', () => {
  // Migration: entries already on disk have no last_issue_comment_at. Treating
  // that as "never seen" would dump every PR's whole comment history on the
  // first poll after upgrading, so it falls back to the first-sight window.
  const out = selectVerdicts({
    issueComments: [issue(ago(400), CLEAN)],
    owner: 'mwgrant21', headSha: HEAD, now: NOW, windowH: 24,
    seen: { last_review_id: 1 },            // a pre-upgrade cursor entry
  });
  assert.deepEqual(out, [], 'a 400h-old verdict is not news on first sight of this field');
});

test('parses the label bolded with the colon outside the bold', () => {
  // Same information, different markdown. Anchoring on the exact punctuation
  // of one observed comment is how this broke the first time.
  const v = parseCodexVerdict("Codex Review: Didn't find any major issues.\n\n**Reviewed commit**: `ca7cd18a1c`");
  assert.equal(v?.sha, 'ca7cd18a1c');
});
