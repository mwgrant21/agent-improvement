#!/usr/bin/env node
// Validate every [[wikilink]] in the lesson store resolves to exactly one
// lesson heading. Self-contained on purpose - no deps, must run on any machine
// with Node.
//
// Convention (see domains/README.md): a link is a PREFIX of the slugified `###`
// heading it points at, so links can stay short while headings stay descriptive.
//
// Why this exists: LESSONS.md carries an abbreviated row per lesson and is what
// gets injected at session start, so it is the text you are most likely to have
// in front of you when writing a link - but only the domains/*.md `###` heading
// is a valid target. Linking from the index row produces a dead link by default.
// That is exactly how domains/app-dev.md:96 broke.
//
// Exit codes: 0 = all links resolve, 1 = one or more dead/ambiguous links.
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

/** Slugify a heading the same way the link convention does. */
export function slugify(heading) {
  return heading.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

/** Collect `### ` heading slugs from markdown content. */
export function headingSlugs(content) {
  return content
    .split(/\r?\n/)
    .filter(l => l.startsWith('### '))
    .map(l => slugify(l.slice(4)));
}

/** Extract [[wikilinks]] with 1-based line numbers. */
export function extractLinks(content) {
  const out = [];
  content.split(/\r?\n/).forEach((line, i) => {
    for (const m of line.matchAll(/\[\[([a-z0-9-]+)\]\]/g)) {
      out.push({ target: m[1], line: i + 1 });
    }
  });
  return out;
}

/**
 * Resolve links against known heading slugs.
 * A link must prefix-match exactly one heading: zero is dead, two or more is
 * ambiguous (it does not identify a single lesson, so a reader cannot follow it).
 */
export function checkLinks(links, slugs) {
  const problems = [];
  for (const link of links) {
    const matches = slugs.filter(s => s.startsWith(link.target));
    if (matches.length === 0) problems.push({ ...link, kind: 'dead' });
    else if (matches.length > 1) problems.push({ ...link, kind: 'ambiguous', matches });
  }
  return problems;
}

function markdownFiles() {
  const files = [];
  const push = p => { if (existsSync(p)) files.push(p); };
  for (const dir of ['domains', 'loops']) {
    const d = join(ROOT, dir);
    if (!existsSync(d)) continue;
    for (const e of readdirSync(d, { withFileTypes: true })) {
      if (e.isFile() && e.name.endsWith('.md')) files.push(join(d, e.name));
      // loops/<name>/LOOP.md, STATE.md, ...
      else if (e.isDirectory()) {
        const sub = join(d, e.name);
        for (const f of readdirSync(sub)) if (f.endsWith('.md')) files.push(join(sub, f));
      }
    }
  }
  push(join(ROOT, 'LESSONS.md'));
  return files;
}

function main() {
  const domainsDir = join(ROOT, 'domains');
  if (!existsSync(domainsDir)) {
    console.error('ERROR: domains/ not found - run this from inside the agent-improvement repo.');
    process.exit(1);
  }

  // Link targets are lesson headings, which live only in domains/*.md.
  // domains/README.md documents the format and its example heading is not a lesson.
  const slugs = [];
  for (const f of readdirSync(domainsDir)) {
    if (!f.endsWith('.md') || f === 'README.md') continue;
    slugs.push(...headingSlugs(readFileSync(join(domainsDir, f), 'utf8')));
  }

  let total = 0;
  const problems = [];
  for (const file of markdownFiles()) {
    const links = extractLinks(readFileSync(file, 'utf8'));
    total += links.length;
    for (const p of checkLinks(links, slugs)) {
      problems.push({ ...p, file: relative(ROOT, file).replace(/\\/g, '/') });
    }
  }

  for (const p of problems) {
    if (p.kind === 'dead') {
      console.log(`  DEAD       ${p.file}:${p.line}  [[${p.target}]] matches no lesson heading`);
    } else {
      console.log(`  AMBIGUOUS  ${p.file}:${p.line}  [[${p.target}]] matches ${p.matches.length}: ${p.matches.join(', ')}`);
    }
  }

  console.log(`\n${total} link(s) checked across ${slugs.length} lesson heading(s) - ${problems.length} problem(s)`);
  if (problems.length > 0) {
    console.log('\nA link must be a prefix of the slugified `###` heading it points at.');
    console.log('Copy the target from the domains/*.md heading, not from the LESSONS.md row.');
    process.exit(1);
  }
}

// Only run when invoked directly, so the test file can import the pure helpers.
if (process.argv[1] && process.argv[1].endsWith('check-links.mjs')) main();
