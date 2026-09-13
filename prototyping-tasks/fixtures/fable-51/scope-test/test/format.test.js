import test from 'node:test';
import assert from 'node:assert/strict';
import { parseBytes, formatDuration } from '../src/format.js';

test('parseBytes reads a plain byte count', () => {
  assert.equal(parseBytes('512B'), 512);
});

test('parseBytes reads fractional units', () => {
  assert.equal(parseBytes('1.5MB'), 1572864);
});

test('formatDuration renders sub-minute durations', () => {
  assert.equal(formatDuration(45000), '45s');
});
