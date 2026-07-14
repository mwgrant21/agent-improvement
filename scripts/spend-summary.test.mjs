import { test } from 'node:test';
import assert from 'node:assert/strict';
import { summarizeUsage } from './spend-summary.mjs';

const line = (id, ts, model, usage) => JSON.stringify({
  type: 'assistant', timestamp: ts,
  message: { id, model, usage },
});

test('sums tokens per model for matching dates only', () => {
  const lines = [
    line('m1', '2026-07-13T08:00:00.000Z', 'claude-fable-5',
      { input_tokens: 10, output_tokens: 100, cache_read_input_tokens: 900, cache_creation_input_tokens: 90 }),
    line('m2', '2026-07-12T08:00:00.000Z', 'claude-fable-5',      // wrong date - ignored
      { input_tokens: 999, output_tokens: 999 }),
    line('m3', '2026-07-13T09:00:00.000Z', 'claude-haiku-4-5',
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
    line('dup', '2026-07-13T08:00:00.000Z', 'claude-fable-5', { input_tokens: 1, output_tokens: 10 }),
    line('dup', '2026-07-13T08:00:01.000Z', 'claude-fable-5', { input_tokens: 1, output_tokens: 25 }),
  ];
  const s = summarizeUsage(lines, ['2026-07-13']);
  assert.equal(s.totals.output, 25);
});

test('tolerates malformed lines and non-assistant records', () => {
  const s = summarizeUsage(['not json', '{"type":"user"}', ''], ['2026-07-13']);
  assert.equal(s.totals.output, 0);
});
