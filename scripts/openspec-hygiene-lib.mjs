// OpenSpec hygiene checks — the funbox QUALITY layer for OpenSpec artifacts.
//
// `openspec validate` enforces structural rules but accepts a TBD Purpose as
// "valid" and says nothing about lifecycle (a finished change left un-archived).
// These pure-Node checks close those two gaps. They SELF-SCOPE: a repo/PR with no
// specs or no active changes produces no findings, so they never force OpenSpec
// onto work that doesn't use it.
//
// Pure Node, no dependencies. Two exported checks, each returning an array of
// human-readable error strings ([] === clean).

import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, relative, sep } from 'node:path';

const relPath = (root, p) => relative(root, p).split(sep).join('/');

function mdFilesUnder(dir) {
  const out = [];
  if (!existsSync(dir)) return out;
  for (const e of readdirSync(dir)) {
    const p = join(dir, e);
    if (statSync(p).isDirectory()) out.push(...mdFilesUnder(p));
    else if (e.endsWith('.md')) out.push(p);
  }
  return out;
}

// A — placeholder scan of the living capability specs (openspec/specs/**).
// `openspec archive` seeds new capability specs with a TBD Purpose and the marker
// "Update Purpose after archive", which the author must replace. validate passes
// regardless (a TBD is a non-empty section), so we catch it here.
export function scanSpecPlaceholders(root) {
  const errs = [];
  const specsDir = join(root, 'openspec', 'specs');
  for (const f of mdFilesUnder(specsDir)) {
    const txt = readFileSync(f, 'utf8');
    if (txt.includes('Update Purpose after archive')) {
      errs.push(`${relPath(root, f)}: contains the archive placeholder "Update Purpose after archive" — fill in the spec's Purpose`);
      continue;
    }
    // Body of the "## Purpose" section: the lines after the heading up to the next
    // heading (or EOF). Line-based to avoid newline-greedy regex pitfalls.
    const lines = txt.split(/\r?\n/);
    const start = lines.findIndex((l) => /^##[ \t]+Purpose[ \t]*$/.test(l));
    if (start !== -1) {
      const body = [];
      for (let j = start + 1; j < lines.length; j++) {
        if (/^#{1,6}[ \t]/.test(lines[j])) break;
        body.push(lines[j]);
      }
      const b = body.join('\n').trim();
      if (b === '') {
        errs.push(`${relPath(root, f)}: "## Purpose" section is empty`);
      } else if (/^TBD\b/i.test(b)) {
        errs.push(`${relPath(root, f)}: "## Purpose" is still a TBD placeholder — write the real purpose`);
      }
    }
  }
  return errs;
}

// B — a fully-implemented change that was never archived. Self-scoping: only an
// active openspec/changes/<name>/ whose tasks.md has at least one task and zero
// unchecked tasks is flagged. Changes mid-implementation (some unchecked) and
// repos with no active changes produce nothing.
export function findUnarchivedCompleteChanges(root) {
  const errs = [];
  const changesDir = join(root, 'openspec', 'changes');
  if (!existsSync(changesDir)) return errs;
  for (const name of readdirSync(changesDir)) {
    if (name === 'archive') continue;
    const dir = join(changesDir, name);
    if (!statSync(dir).isDirectory()) continue;
    const tasksPath = join(dir, 'tasks.md');
    if (!existsSync(tasksPath)) continue;
    const txt = readFileSync(tasksPath, 'utf8');
    const checked = (txt.match(/^\s*-\s*\[[xX]\]/gm) || []).length;
    const unchecked = (txt.match(/^\s*-\s*\[ \]/gm) || []).length;
    if (checked > 0 && unchecked === 0) {
      errs.push(`openspec/changes/${name}: all ${checked} task(s) complete but the change is not archived — run \`openspec archive ${name}\` before merging`);
    }
  }
  return errs;
}
