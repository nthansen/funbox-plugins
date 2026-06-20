#!/usr/bin/env node
// funbox OpenSpec hygiene gate — complements `openspec validate` (run alongside in
// CI). validate enforces structure but accepts a TBD Purpose and ignores lifecycle;
// this catches (A) placeholder Purposes in living specs and (B) a fully-implemented
// change left un-archived. Both self-scope, so non-OpenSpec PRs see no findings.
//
// Pure Node, no deps. Run from the repo root:
//   node scripts/check-openspec-hygiene.mjs
// Exits non-zero (printing every problem) if anything is unclean.

import { scanSpecPlaceholders, findUnarchivedCompleteChanges } from './openspec-hygiene-lib.mjs';

const root = process.cwd();
const errors = [...scanSpecPlaceholders(root), ...findUnarchivedCompleteChanges(root)];

if (errors.length) {
  console.error(`\nopenspec-hygiene: ${errors.length} problem(s):`);
  for (const e of errors) console.error('  ✗ ' + e);
  process.exit(1);
}

console.log('openspec-hygiene: specs and changes are clean.');
