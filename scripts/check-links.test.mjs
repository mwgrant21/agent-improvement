import { test } from 'node:test';
import assert from 'node:assert/strict';
import { slugify, headingSlugs, extractLinks, checkLinks } from './check-links.mjs';

test('slugify collapses punctuation and trims edges', () => {
  assert.equal(
    slugify('A stale compiled `.js` file can silently shadow its `.ts` source'),
    'a-stale-compiled-js-file-can-silently-shadow-its-ts-source',
  );
  assert.equal(slugify('Set $ErrorActionPreference = \'Stop\' at the top'),
    'set-erroractionpreference-stop-at-the-top');
});

test('headingSlugs picks up ### only, not ## or ####', () => {
  const md = ['# Domain', '## Section', '### Real Lesson', '#### Sub', '### Another One'].join('\n');
  assert.deepEqual(headingSlugs(md), ['real-lesson', 'another-one']);
});

test('extractLinks reports 1-based line numbers and multiple links per line', () => {
  const md = ['no links here', 'see [[alpha-one]] and [[beta-two]]'].join('\n');
  assert.deepEqual(extractLinks(md), [
    { target: 'alpha-one', line: 2 },
    { target: 'beta-two', line: 2 },
  ]);
});

test('links inside inline backticks are documentation examples, not links', () => {
  const md = 'Link a related lesson with `[[a-prefix-of-its-slugified-heading]]`.';
  assert.deepEqual(extractLinks(md), []);
});

test('links inside fenced blocks are ignored, and line numbers survive', () => {
  const md = ['```', 'see [[not-a-real-link]]', '```', 'but [[real-one]] counts'].join('\n');
  assert.deepEqual(extractLinks(md), [{ target: 'real-one', line: 4 }]);
});

test('a link that prefixes exactly one heading resolves', () => {
  const slugs = ['a-final-whole-branch-review-is-required-after-task-level-reviews-it-catches-more'];
  const problems = checkLinks(
    [{ target: 'a-final-whole-branch-review-is-required-after-task-level-reviews', line: 96 }],
    slugs,
  );
  assert.deepEqual(problems, []);
});

test('the real app-dev.md regression is caught as dead', () => {
  // The heading starts "a-final-whole-branch-review-IS-REQUIRED-...", so a link
  // derived from the abbreviated LESSONS.md row is not a prefix of it.
  const slugs = ['a-final-whole-branch-review-is-required-after-task-level-reviews-it-catches-cross-task-bugs'];
  const problems = checkLinks(
    [{ target: 'final-whole-branch-review-catches-cross-task-bugs', line: 96 }],
    slugs,
  );
  assert.equal(problems.length, 1);
  assert.equal(problems[0].kind, 'dead');
  assert.equal(problems[0].line, 96);
});

test('a prefix matching two headings is ambiguous, not OK', () => {
  const slugs = ['never-use-write-host-in-logging', 'never-use-write-host-in-pdq-steps'];
  const problems = checkLinks([{ target: 'never-use-write-host', line: 4 }], slugs);
  assert.equal(problems.length, 1);
  assert.equal(problems[0].kind, 'ambiguous');
  assert.equal(problems[0].matches.length, 2);
});

test('an exact full-slug link still resolves', () => {
  const slugs = ['one-state-file-per-loop'];
  assert.deepEqual(checkLinks([{ target: 'one-state-file-per-loop', line: 1 }], slugs), []);
});

test('no links is not a failure', () => {
  assert.deepEqual(checkLinks([], ['anything']), []);
});
