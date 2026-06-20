#!/usr/bin/env node
// funbox skill quality gate — the QUALITY layer (validate-marketplace.mjs is POLICY).
//
// Deterministic, dependency-free verification that every skill carries fresh eval
// artifacts meeting its threshold. Runs NO LLM and needs NO Anthropic auth — the
// expensive evaluation is produced at author time by `/skill-gate` and frozen into
// each skill's evals/benchmark.json. Run from the repo root:
//   node scripts/check-skill-gate.mjs
// Exits non-zero (printing every problem) if any skill fails.

import { discoverSkills, loadThreshold, checkSkill } from './skill-gate-lib.mjs';
import { relative } from 'node:path';

const root = process.cwd();
const threshold = loadThreshold(root);
const skills = discoverSkills(root);
const errors = [];

for (const dir of skills) {
  for (const e of checkSkill(dir, threshold)) {
    errors.push(e.replace(dir, relative(root, dir).replace(/\\/g, '/')));
  }
}

if (skills.length === 0) {
  console.error('skill-gate: no skills found under plugins/*/skills/ — nothing to check');
  process.exit(1);
}

if (errors.length) {
  console.error(`\nskill-gate: ${errors.length} problem(s):`);
  for (const e of errors) console.error('  ✗ ' + e);
  process.exit(1);
}

console.log(`skill-gate: ${skills.length} skill(s) passed (threshold ${threshold}).`);
