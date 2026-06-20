// scripts/skill-gate-lib.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { computeSourceHash } from './skill-gate-lib.mjs';

function makeSkill() {
  const dir = mkdtempSync(join(tmpdir(), 'skillgate-'));
  writeFileSync(join(dir, 'SKILL.md'), '---\nname: x\ndescription: y\n---\nbody\n');
  mkdirSync(join(dir, 'evals'));
  writeFileSync(join(dir, 'evals', 'evals.json'), '{"skill_name":"x","evals":[]}');
  return dir;
}

test('computeSourceHash is deterministic and sha256-prefixed', () => {
  const dir = makeSkill();
  const a = computeSourceHash(dir);
  const b = computeSourceHash(dir);
  assert.equal(a, b);
  assert.match(a, /^sha256:[0-9a-f]{64}$/);
  rmSync(dir, { recursive: true, force: true });
});

test('computeSourceHash excludes evals/benchmark.json', () => {
  const dir = makeSkill();
  const before = computeSourceHash(dir);
  writeFileSync(join(dir, 'evals', 'benchmark.json'), '{"pass_rate":1}');
  assert.equal(computeSourceHash(dir), before, 'benchmark.json must not affect the hash');
  rmSync(dir, { recursive: true, force: true });
});

test('computeSourceHash changes when SKILL.md or evals.json changes', () => {
  const dir = makeSkill();
  const before = computeSourceHash(dir);
  writeFileSync(join(dir, 'SKILL.md'), '---\nname: x\ndescription: y\n---\nCHANGED\n');
  assert.notEqual(computeSourceHash(dir), before);
  const mid = computeSourceHash(dir);
  writeFileSync(join(dir, 'evals', 'evals.json'), '{"skill_name":"x","evals":[],"threshold":0.8}');
  assert.notEqual(computeSourceHash(dir), mid, 'assertion/eval edits must flip the hash');
  rmSync(dir, { recursive: true, force: true });
});
