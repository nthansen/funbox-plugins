// scripts/skill-gate-lib.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { computeSourceHash } from './skill-gate-lib.mjs';
import { loadThreshold, checkSkill, discoverSkills } from './skill-gate-lib.mjs';

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

// append to scripts/skill-gate-lib.test.mjs

function passingBenchmark(dir, overrides = {}) {
  const bm = {
    skill: 'x',
    pass_rate: 1.0,
    threshold: 0.9,
    model: 'claude-opus-4-8',
    source_hash: computeSourceHash(dir),
    results: [{ eval_id: 1, text: 'does the thing', passed: true, evidence: 'ok' }],
    ...overrides,
  };
  writeFileSync(join(dir, 'evals', 'benchmark.json'), JSON.stringify(bm));
  return bm;
}

test('loadThreshold reads repo default, falling back to 0.9', () => {
  const dir = mkdtempSync(join(tmpdir(), 'repo-'));
  assert.equal(loadThreshold(dir), 0.9);
  mkdirSync(join(dir, '.claude'));
  writeFileSync(join(dir, '.claude', 'skill-gate.json'), '{"threshold":0.8}');
  assert.equal(loadThreshold(dir), 0.8);
  rmSync(dir, { recursive: true, force: true });
});

test('checkSkill: missing evals.json fails', () => {
  const dir = mkdtempSync(join(tmpdir(), 'skillgate-'));
  writeFileSync(join(dir, 'SKILL.md'), 'x');
  const errs = checkSkill(dir, 0.9);
  assert.ok(errs.some((e) => /evals\.json/.test(e)));
  rmSync(dir, { recursive: true, force: true });
});

test('checkSkill: empty evals array fails', () => {
  const dir = makeSkill();
  const errs = checkSkill(dir, 0.9);
  assert.ok(errs.some((e) => /at least one eval/.test(e)));
  rmSync(dir, { recursive: true, force: true });
});

test('checkSkill: missing benchmark fails with re-run hint', () => {
  const dir = makeSkill();
  writeFileSync(join(dir, 'evals', 'evals.json'), '{"skill_name":"x","evals":[{"id":1,"prompt":"p"}]}');
  const errs = checkSkill(dir, 0.9);
  assert.ok(errs.some((e) => /\/skill-gate/.test(e)));
  rmSync(dir, { recursive: true, force: true });
});

test('checkSkill: stale source_hash fails', () => {
  const dir = makeSkill();
  writeFileSync(join(dir, 'evals', 'evals.json'), '{"skill_name":"x","evals":[{"id":1,"prompt":"p"}]}');
  passingBenchmark(dir, { source_hash: 'sha256:deadbeef' });
  const errs = checkSkill(dir, 0.9);
  assert.ok(errs.some((e) => /stale/.test(e)));
  rmSync(dir, { recursive: true, force: true });
});

test('checkSkill: pass_rate below threshold fails', () => {
  const dir = makeSkill();
  writeFileSync(join(dir, 'evals', 'evals.json'), '{"skill_name":"x","evals":[{"id":1,"prompt":"p"}]}');
  passingBenchmark(dir, { pass_rate: 0.5 });
  const errs = checkSkill(dir, 0.9);
  assert.ok(errs.some((e) => /0\.5.*0\.9|below threshold/.test(e)));
  rmSync(dir, { recursive: true, force: true });
});

test('checkSkill: fresh + passing returns no errors', () => {
  const dir = makeSkill();
  writeFileSync(join(dir, 'evals', 'evals.json'), '{"skill_name":"x","evals":[{"id":1,"prompt":"p"}]}');
  passingBenchmark(dir);
  assert.deepEqual(checkSkill(dir, 0.9), []);
  rmSync(dir, { recursive: true, force: true });
});

test('checkSkill: per-skill threshold override is enforced', () => {
  const dir = makeSkill();
  writeFileSync(join(dir, 'evals', 'evals.json'), '{"skill_name":"x","threshold":0.95,"evals":[{"id":1,"prompt":"p"}]}');
  passingBenchmark(dir, { pass_rate: 0.92, threshold: 0.95 });
  const errs = checkSkill(dir, 0.9); // repo default 0.9, but skill demands 0.95
  assert.ok(errs.some((e) => /0\.95|below threshold/.test(e)));
  rmSync(dir, { recursive: true, force: true });
});

test('discoverSkills skips *-workspace run directories', () => {
  const root = mkdtempSync(join(tmpdir(), 'repo-'));
  const skills = join(root, 'plugins', 'p', 'skills');
  mkdirSync(join(skills, 'real-skill'), { recursive: true });
  mkdirSync(join(skills, 'real-skill-workspace'), { recursive: true });
  const found = discoverSkills(root).map((d) => d.split(/[\\/]/).pop());
  assert.ok(found.includes('real-skill'));
  assert.ok(!found.includes('real-skill-workspace'), 'must not treat *-workspace as a skill');
  rmSync(root, { recursive: true, force: true });
});

test('computeSourceHash normalizes line endings (CRLF == LF)', () => {
  const lf = mkdtempSync(join(tmpdir(), 'skillgate-'));
  const crlf = mkdtempSync(join(tmpdir(), 'skillgate-'));
  for (const dir of [lf, crlf]) { mkdirSync(join(dir, 'evals')); }
  writeFileSync(join(lf, 'SKILL.md'), 'line one\nline two\n');
  writeFileSync(join(crlf, 'SKILL.md'), 'line one\r\nline two\r\n');
  writeFileSync(join(lf, 'evals', 'evals.json'), '{"a":1}\n');
  writeFileSync(join(crlf, 'evals', 'evals.json'), '{"a":1}\r\n');
  assert.equal(computeSourceHash(lf), computeSourceHash(crlf), 'CRLF and LF must hash identically');
  rmSync(lf, { recursive: true, force: true });
  rmSync(crlf, { recursive: true, force: true });
});
