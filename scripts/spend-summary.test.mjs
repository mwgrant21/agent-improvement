import { test } from 'node:test';
import assert from 'node:assert/strict';
import { summarizeUsage, localDay } from './spend-summary.mjs';

// Dates are bucketed by LOCAL calendar day, so tests build timestamps from
// local wall-clock times to stay green in any timezone.
const localTs = (y, m, d, h, min = 0) => new Date(y, m - 1, d, h, min).toISOString();

const line = (id, ts, model, usage) => JSON.stringify({
  type: 'assistant', timestamp: ts,
  message: { id, model, usage },
});

test('sums tokens per model for matching dates only', () => {
  const lines = [
    line('m1', localTs(2026, 7, 13, 8), 'claude-fable-5',
      { input_tokens: 10, output_tokens: 100, cache_read_input_tokens: 900, cache_creation_input_tokens: 90 }),
    line('m2', localTs(2026, 7, 12, 8), 'claude-fable-5',      // wrong date - ignored
      { input_tokens: 999, output_tokens: 999 }),
    line('m3', localTs(2026, 7, 13, 9), 'claude-haiku-4-5',
      { input_tokens: 5, output_tokens: 50, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 }),
  ];
  const s = summarizeUsage(lines, ['2026-07-13']);
  assert.equal(s.byModel['claude-fable-5'].output, 100);
  assert.equal(s.byModel['claude-haiku-4-5'].output, 50);
  assert.equal(s.totals.input, 15);
  assert.equal(s.totals.cacheRead, 900);
  // hit rate = cacheRead / (cacheRead + cacheCreate + input) = 900/1005
  assert.ok(Math.abs(s.cacheHitRate - 900 / 1005) < 1e-9);
});

test('dedups streamed duplicates by message id (last wins)', () => {
  const lines = [
    line('dup', localTs(2026, 7, 13, 8), 'claude-fable-5', { input_tokens: 1, output_tokens: 10 }),
    line('dup', localTs(2026, 7, 13, 8, 1), 'claude-fable-5', { input_tokens: 1, output_tokens: 25 }),
  ];
  const s = summarizeUsage(lines, ['2026-07-13']);
  assert.equal(s.totals.output, 25);
});

test('tolerates malformed lines and non-assistant records', () => {
  const s = summarizeUsage(['not json', '{"type":"user"}', ''], ['2026-07-13']);
  assert.equal(s.totals.output, 0);
});

test('records without message.id both count instead of collapsing', () => {
  const lines = [
    line(undefined, localTs(2026, 7, 13, 8), 'claude-fable-5', { input_tokens: 1, output_tokens: 10 }),
    line(undefined, localTs(2026, 7, 13, 8, 1), 'claude-fable-5', { input_tokens: 1, output_tokens: 25 }),
  ];
  const s = summarizeUsage(lines, ['2026-07-13']);
  assert.equal(s.totals.output, 35);
});

test('evening records stay on the LOCAL day even when UTC has rolled over', () => {
  // 11:30pm local on 07-13; in negative-UTC-offset zones the ISO string is
  // already 07-14. Regression test for the today+tomorrow labeling bug.
  const ts = localTs(2026, 7, 13, 23, 30);
  const lines = [line('m1', ts, 'claude-fable-5', { input_tokens: 1, output_tokens: 10 })];
  assert.equal(localDay(new Date(ts)), '2026-07-13');
  assert.equal(summarizeUsage(lines, ['2026-07-13']).totals.output, 10);
  assert.equal(summarizeUsage(lines, ['2026-07-14']).totals.output, 0);
});

test('cacheHitRate is 0 when there is no usage data (zero denominator)', () => {
  const s = summarizeUsage([], ['2026-07-13']);
  assert.equal(s.cacheHitRate, 0);
});
