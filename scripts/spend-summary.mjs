#!/usr/bin/env node
// Summarize Claude Code token usage from ~/.claude/projects/**/*.jsonl for
// given dates (default: yesterday and today). Self-contained on purpose - no
// dependency on the TokenMonitor repo, must run on any machine with Node.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

export function summarizeUsage(lines, isoDates) {
  const dates = new Set(isoDates);
  const byId = new Map();          // message id -> {model, usage} (last wins)
  let anon = 0;
  for (const raw of lines) {
    let rec;
    try { rec = JSON.parse(raw); } catch { continue; }
    if (rec?.type !== 'assistant' || !rec.message?.usage) continue;
    const day = String(rec.timestamp || '').slice(0, 10);
    if (!dates.has(day)) continue;
    byId.set(rec.message.id ?? `anon-${anon++}`, rec.message);
  }
  const byModel = {}; const totals = { input: 0, output: 0, cacheRead: 0, cacheCreate: 0 };
  for (const msg of byId.values()) {
    const u = msg.usage;
    const m = byModel[msg.model || 'unknown'] ??= { input: 0, output: 0, cacheRead: 0, cacheCreate: 0 };
    m.input += u.input_tokens || 0;            totals.input += u.input_tokens || 0;
    m.output += u.output_tokens || 0;          totals.output += u.output_tokens || 0;
    m.cacheRead += u.cache_read_input_tokens || 0;       totals.cacheRead += u.cache_read_input_tokens || 0;
    m.cacheCreate += u.cache_creation_input_tokens || 0; totals.cacheCreate += u.cache_creation_input_tokens || 0;
  }
  const denom = totals.cacheRead + totals.cacheCreate + totals.input;
  return { byModel, totals, cacheHitRate: denom ? totals.cacheRead / denom : 0 };
}

function* jsonlFiles(dir) {
  let entries = [];
  try { entries = readdirSync(dir, { withFileTypes: true }); } catch { return; }
  for (const e of entries) {
    const p = join(dir, e.name);
    if (e.isDirectory()) yield* jsonlFiles(p);
    else if (e.name.endsWith('.jsonl')) yield p;
  }
}

function isoDay(d) { return d.toISOString().slice(0, 10); }

if (process.argv[1] && import.meta.url.endsWith(process.argv[1].replace(/\\/g, '/').split('/').pop())) {
  const today = new Date();
  const yesterday = new Date(today.getTime() - 86400000);
  const dates = process.argv.slice(2).length ? process.argv.slice(2) : [isoDay(yesterday), isoDay(today)];
  const root = join(homedir(), '.claude', 'projects');
  const oldest = dates.slice().sort()[0];
  const cutoff = Math.min(Date.now() - 3 * 86400000, new Date(oldest + 'T00:00:00Z').getTime() - 86400000);
  const lines = [];
  for (const f of jsonlFiles(root)) {
    try {
      if (statSync(f).mtimeMs < cutoff) continue;
      lines.push(...readFileSync(f, 'utf8').split('\n'));
    } catch { /* unreadable file - skip */ }
  }
  const s = summarizeUsage(lines, dates);
  console.log(`Token usage for ${dates.join(', ')}:`);
  for (const [model, m] of Object.entries(s.byModel)) {
    console.log(`- ${model}: in ${m.input} / out ${m.output} / cacheRead ${m.cacheRead} / cacheCreate ${m.cacheCreate}`);
  }
  console.log(`- TOTAL: in ${s.totals.input} / out ${s.totals.output} / cache hit rate ${(s.cacheHitRate * 100).toFixed(1)}%`);
}
