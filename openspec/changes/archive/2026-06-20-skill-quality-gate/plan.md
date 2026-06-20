# Skill Quality Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a functional quality gate so every funbox skill carries committed eval inputs and a hash-verified benchmark whose pass-rate meets a threshold, enforced deterministically in CI.

**Architecture:** Expensive LLM evaluation happens at author time via a `/skill-gate` command that drives the installed skill-creator engine and freezes results into a committed `evals/benchmark.json`. A pure-Node CI script (`scripts/check-skill-gate.mjs`) deterministically verifies, for every skill, that eval inputs exist, the benchmark's `source_hash` still matches the skill source, and `pass_rate >= threshold`. Pure functions live in `scripts/skill-gate-lib.mjs` and are unit-tested with the built-in `node --test` runner (zero dependencies, matching the existing validator).

**Tech Stack:** Node ≥20 ESM (`node:fs`, `node:crypto`, `node:path`, `node:test`), GitHub Actions, Claude Code slash command (Markdown), skill-creator (`claude-plugins-official`) at author time only.

---

## Task 1: Shared library — `source_hash` algorithm

**Files:**
- Create: `scripts/skill-gate-lib.mjs`
- Test: `scripts/skill-gate-lib.test.mjs`

- [ ] **Step 1: Write the failing test for `computeSourceHash`**

```js
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `node --test scripts/skill-gate-lib.test.mjs`
Expected: FAIL — `Cannot find module './skill-gate-lib.mjs'` (or `computeSourceHash is not a function`).

- [ ] **Step 3: Implement `computeSourceHash` (and a `walkFiles` helper)**

```js
// scripts/skill-gate-lib.mjs
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { createHash } from 'node:crypto';

// All files under skillDir, as forward-slash relative paths, sorted, excluding
// the generated benchmark and any defensive *-workspace/ segment.
export function walkFiles(skillDir) {
  const out = [];
  const walk = (abs) => {
    for (const e of readdirSync(abs)) {
      const p = join(abs, e);
      if (statSync(p).isDirectory()) {
        if (/-workspace$/.test(e)) continue; // defensive: never hash run output
        walk(p);
      } else {
        out.push(relative(skillDir, p).split(sep).join('/'));
      }
    }
  };
  walk(skillDir);
  return out
    .filter((rel) => rel !== 'evals/benchmark.json')
    .sort();
}

// sha256 over (relPath \0 bytes \0) for every source file, in sorted order.
export function computeSourceHash(skillDir) {
  const h = createHash('sha256');
  for (const rel of walkFiles(skillDir)) {
    h.update(rel, 'utf8');
    h.update('\0');
    h.update(readFileSync(join(skillDir, rel)));
    h.update('\0');
  }
  return 'sha256:' + h.digest('hex');
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `node --test scripts/skill-gate-lib.test.mjs`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/skill-gate-lib.mjs scripts/skill-gate-lib.test.mjs
git commit -m "feat(skill-gate): add source_hash algorithm + tests"
```

---

## Task 2: Shared library — discovery, threshold, and per-skill check

**Files:**
- Modify: `scripts/skill-gate-lib.mjs`
- Modify: `scripts/skill-gate-lib.test.mjs`

- [ ] **Step 1: Write failing tests for `loadThreshold` and `checkSkill`**

```js
// append to scripts/skill-gate-lib.test.mjs
import { loadThreshold, checkSkill } from './skill-gate-lib.mjs';

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
```

Note: regenerate `benchmark.json` AFTER writing the final `evals.json` in each test, because `evals.json` is part of `source_hash` — `passingBenchmark` is called last so its `source_hash` matches.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `node --test scripts/skill-gate-lib.test.mjs`
Expected: FAIL — `loadThreshold`/`checkSkill` not exported.

- [ ] **Step 3: Implement `loadThreshold`, `discoverSkills`, and `checkSkill`**

```js
// append to scripts/skill-gate-lib.mjs
export const DEFAULT_THRESHOLD = 0.9;

function readJSON(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

export function loadThreshold(root) {
  const cfg = join(root, '.claude', 'skill-gate.json');
  if (!existsSync(cfg)) return DEFAULT_THRESHOLD;
  try {
    const t = readJSON(cfg).threshold;
    return typeof t === 'number' ? t : DEFAULT_THRESHOLD;
  } catch {
    return DEFAULT_THRESHOLD;
  }
}

// Every plugins/*/skills/*/ directory (absolute paths).
export function discoverSkills(root) {
  const out = [];
  const pluginsRoot = join(root, 'plugins');
  if (!existsSync(pluginsRoot)) return out;
  for (const plugin of readdirSync(pluginsRoot)) {
    const skillsDir = join(pluginsRoot, plugin, 'skills');
    if (!existsSync(skillsDir) || !statSync(skillsDir).isDirectory()) continue;
    for (const skill of readdirSync(skillsDir)) {
      const sdir = join(skillsDir, skill);
      if (statSync(sdir).isDirectory()) out.push(sdir);
    }
  }
  return out;
}

// Returns an array of human-readable error strings ([] === passing).
export function checkSkill(skillDir, repoDefault) {
  const errs = [];
  const label = skillDir;
  const evalsPath = join(skillDir, 'evals', 'evals.json');
  const benchPath = join(skillDir, 'evals', 'benchmark.json');

  if (!existsSync(evalsPath)) {
    errs.push(`${label}: missing evals/evals.json — define eval cases and run /skill-gate`);
    return errs;
  }
  let evals;
  try {
    evals = readJSON(evalsPath);
  } catch (e) {
    errs.push(`${label}: evals/evals.json is invalid JSON — ${e.message}`);
    return errs;
  }
  if (!Array.isArray(evals.evals) || evals.evals.length === 0) {
    errs.push(`${label}: evals.json must define at least one eval case`);
    return errs;
  }

  if (!existsSync(benchPath)) {
    errs.push(`${label}: missing evals/benchmark.json — run /skill-gate to generate it`);
    return errs;
  }
  let bench;
  try {
    bench = readJSON(benchPath);
  } catch (e) {
    errs.push(`${label}: evals/benchmark.json is invalid JSON — ${e.message}`);
    return errs;
  }

  const fresh = computeSourceHash(skillDir);
  if (bench.source_hash !== fresh) {
    errs.push(`${label}: benchmark stale (source_hash mismatch) — re-run /skill-gate`);
  }

  const threshold = typeof evals.threshold === 'number' ? evals.threshold : repoDefault;
  if (typeof bench.pass_rate !== 'number') {
    errs.push(`${label}: benchmark.json missing numeric pass_rate`);
  } else if (bench.pass_rate < threshold) {
    errs.push(`${label}: pass_rate ${bench.pass_rate} below threshold ${threshold}`);
  }
  return errs;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `node --test scripts/skill-gate-lib.test.mjs`
Expected: PASS (all Task 1 + Task 2 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/skill-gate-lib.mjs scripts/skill-gate-lib.test.mjs
git commit -m "feat(skill-gate): add discovery, threshold, and per-skill check"
```

---

## Task 3: CI entry script `check-skill-gate.mjs`

**Files:**
- Create: `scripts/check-skill-gate.mjs`

- [ ] **Step 1: Implement the CLI entry (collect all failures, exit non-zero on any)**

```js
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
}

if (errors.length) {
  console.error(`\nskill-gate: ${errors.length} problem(s):`);
  for (const e of errors) console.error('  ✗ ' + e);
  process.exit(1);
}

console.log(`skill-gate: ${skills.length} skill(s) passed (threshold ${threshold}).`);
```

- [ ] **Step 2: Run it (expect failures — no evals exist yet)**

Run: `node scripts/check-skill-gate.mjs`
Expected: non-zero exit, listing each existing skill as `missing evals/evals.json` (audit-docs, init-audience-rules, revise-docs, vscode-thinking-display). This confirms discovery + reporting work before any backfill.

- [ ] **Step 3: Commit**

```bash
git add scripts/check-skill-gate.mjs
git commit -m "feat(skill-gate): add deterministic CI check script"
```

---

## Task 4: Repo config and gitignore

**Files:**
- Create: `.claude/skill-gate.json`
- Modify: `.gitignore`

- [ ] **Step 1: Create the threshold config**

```json
{
  "threshold": 0.9
}
```

- [ ] **Step 2: Ignore run workspaces**

Append to `.gitignore`:

```gitignore
# skill-gate eval run artifacts (transcripts/outputs) — never committed
*-workspace/
```

- [ ] **Step 3: Verify the gitignore takes effect**

Run: `mkdir -p plugins/doc-sweep/skills/audit-docs-workspace && git status --porcelain plugins/doc-sweep/skills/`
Expected: the `-workspace` directory does NOT appear in `git status`. Then `rm -rf plugins/doc-sweep/skills/audit-docs-workspace`.

- [ ] **Step 4: Commit**

```bash
git add .claude/skill-gate.json .gitignore
git commit -m "feat(skill-gate): add threshold config and ignore run workspaces"
```

---

## Task 5: Author-time `/skill-gate` command

**Files:**
- Create: `.claude/commands/skill-gate.md`

- [ ] **Step 1: Write the command definition**

Create `.claude/commands/skill-gate.md` with this content (frontmatter + body):

```markdown
---
description: Run a funbox skill through skill-creator's eval engine and write/update its evals/benchmark.json so it clears the quality gate.
argument-hint: <path-to-skill-dir>
---

# /skill-gate

Generate (or refresh) the committed quality-gate artifacts for the skill at
`$ARGUMENTS`. This reuses the installed **skill-creator** engine — it does not
reimplement evaluation.

## Steps

1. **Preflight.** Confirm `skill-creator` (claude-plugins-official) is available
   (its `agents/grader.md` and `scripts/aggregate_benchmark.py` exist). If it is
   not installed, STOP and tell the user to install it — do NOT fabricate a
   benchmark.

2. **Ensure eval inputs.** Read `<skill>/evals/evals.json`. If absent, draft it
   WITH the user: 2-3 realistic prompts plus objectively-checkable assertions
   (skill-creator schema: `skill_name`, optional `threshold`, `evals[]` with
   `id`, `prompt`, `assertions[]`, `files[]`). For manual/`disable-model-invocation`
   skills, write prompts that exercise the skill's OUTPUT when run, not triggering.

3. **Run with-skill (no baseline).** For each eval, run the skill against the
   prompt in a `<skill-name>-workspace/iteration-N/` sibling (gitignored). Grade
   each assertion per skill-creator's `agents/grader.md` (prefer a script for
   programmatically-checkable assertions). Aggregate with
   `python -m scripts.aggregate_benchmark` from the skill-creator dir, or compute
   `pass_rate = passed_assertions / total_assertions` directly.

4. **Write benchmark.** Compute the canonical `source_hash` (see
   `scripts/skill-gate-lib.mjs` — sha256 over skill source incl. evals.json, excl.
   benchmark.json and `*-workspace/`). Write `<skill>/evals/benchmark.json`:
   `{ skill, pass_rate, threshold, model, source_hash, results[] }`, where
   `threshold` is the per-skill override or the repo default in
   `.claude/skill-gate.json`, and `model` is the session model id.

5. **Report.** State pass_rate vs threshold and PASS/FAIL. Remind the user to
   `git add` the `evals/` artifacts (but not the workspace), then run
   `node scripts/check-skill-gate.mjs` to confirm the gate is green.
```

- [ ] **Step 2: Verify the command parses (no allowed-tools to over-scope)**

Run: `node scripts/validate-marketplace.mjs`
Expected: PASS — the command lives under `.claude/commands/`, not under `plugins/`, so the marketplace validator is unaffected; this step just confirms nothing regressed.

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/skill-gate.md
git commit -m "feat(skill-gate): add author-time /skill-gate command"
```

---

## Task 6: Backfill the four existing skills

For EACH skill below, drive `/skill-gate` (or perform its steps manually) to author
`evals/evals.json` and generate a passing `evals/benchmark.json`. Do them one at a
time; commit after each so a regression is easy to bisect.

**Skills & their eval focus:**
- `plugins/doc-sweep/skills/audit-docs` — given a repo with stale/misaudienced CLAUDE.md, assert the audit report flags the right files/issues.
- `plugins/doc-sweep/skills/revise-docs` — given a session with a new command/renamed path, assert the right doc files get the right edits (CLAUDE.md vs README split).
- `plugins/doc-sweep/skills/init-audience-rules` — run the manual command; assert it writes a correct audience-rules overlay (graded on output, not triggering).
- `plugins/vscode-thinking-display/skills/vscode-thinking-display` — assert the patch/restore scripts are selected per-OS and produce the expected file transform (deterministic, scriptable assertions).

- [ ] **Step 1: Backfill `audit-docs`**

Run `/skill-gate plugins/doc-sweep/skills/audit-docs`. Verify:

Run: `node scripts/check-skill-gate.mjs`
Expected: `audit-docs` no longer listed as failing (others may still fail).

```bash
git add plugins/doc-sweep/skills/audit-docs/evals/evals.json plugins/doc-sweep/skills/audit-docs/evals/benchmark.json
git commit -m "test(skill-gate): backfill evals for audit-docs"
```

- [ ] **Step 2: Backfill `revise-docs`** — same procedure, then:

```bash
git add plugins/doc-sweep/skills/revise-docs/evals/
git commit -m "test(skill-gate): backfill evals for revise-docs"
```

- [ ] **Step 3: Backfill `init-audience-rules`** — same procedure (output-graded), then:

```bash
git add plugins/doc-sweep/skills/init-audience-rules/evals/
git commit -m "test(skill-gate): backfill evals for init-audience-rules"
```

- [ ] **Step 4: Backfill `vscode-thinking-display`** — same procedure, then:

```bash
git add plugins/vscode-thinking-display/skills/vscode-thinking-display/evals/
git commit -m "test(skill-gate): backfill evals for vscode-thinking-display"
```

- [ ] **Step 5: Confirm all four pass together**

Run: `node scripts/check-skill-gate.mjs`
Expected: `skill-gate: 4 skill(s) passed (threshold 0.9).`

---

## Task 7: Wire into CI

**Files:**
- Modify: `.github/workflows/validate.yml`

- [ ] **Step 1: Add the unit-test + gate steps after the policy validator**

Insert after the `Marketplace & plugin policy` step in `.github/workflows/validate.yml`:

```yaml
      - name: Skill-gate library unit tests
        run: node --test scripts/skill-gate-lib.test.mjs

      # Quality layer: every skill must have fresh eval artifacts meeting its
      # threshold. Deterministic, no LLM, no Anthropic auth (artifacts are
      # produced at author time by /skill-gate and committed).
      - name: Skill quality gate
        run: node scripts/check-skill-gate.mjs
```

- [ ] **Step 2: Verify the workflow is valid YAML and the commands match local**

Run: `node --test scripts/skill-gate-lib.test.mjs && node scripts/check-skill-gate.mjs`
Expected: tests PASS; gate prints `4 skill(s) passed`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/validate.yml
git commit -m "ci(skill-gate): run unit tests and quality gate in validate.yml"
```

---

## Task 8: Documentation

**Files:**
- Modify: `CONTRIBUTING.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Document the gate in `CONTRIBUTING.md`**

Add a "Skill quality gate" section covering: the per-skill `evals/evals.json` +
`evals/benchmark.json` layout; how to run `/skill-gate <skill-dir>` (and that it
needs skill-creator installed); the default threshold (0.9) and per-skill override;
that `*-workspace/` is gitignored; and the explicit author-trust limitation (CI
can't re-run the LLM — assertion changes are reviewed via the `evals.json` diff).

- [ ] **Step 2: Add a line to CLAUDE.md's "Validation (CI gate)" section**

Add a bullet noting `scripts/check-skill-gate.mjs` enforces per-skill functional
eval pass-rate ≥ threshold via a committed, hash-verified `benchmark.json`, and that
benchmarks are (re)generated with `/skill-gate`.

- [ ] **Step 3: Commit**

```bash
git add CONTRIBUTING.md CLAUDE.md
git commit -m "docs(skill-gate): document the skill quality gate"
```

---

## Task 9: End-to-end verification (negative tests)

**Files:** none (verification only)

- [ ] **Step 1: Freshness negative test**

Append a space to a SKILL.md without re-running the gate:

Run: `printf ' ' >> plugins/doc-sweep/skills/audit-docs/SKILL.md && node scripts/check-skill-gate.mjs; git checkout -- plugins/doc-sweep/skills/audit-docs/SKILL.md`
Expected: non-zero exit with `benchmark stale (source_hash mismatch) — re-run /skill-gate`, then the checkout restores green.

- [ ] **Step 2: Threshold negative test**

Temporarily lower a pass_rate below threshold:

Run: `node -e "const f='plugins/doc-sweep/skills/audit-docs/evals/benchmark.json';const fs=require('fs');const b=JSON.parse(fs.readFileSync(f));b.pass_rate=0.1;fs.writeFileSync(f,JSON.stringify(b))" && node scripts/check-skill-gate.mjs; git checkout -- plugins/doc-sweep/skills/audit-docs/evals/benchmark.json`
Expected: non-zero exit with `pass_rate 0.1 below threshold 0.9` (note: this edits benchmark.json, which is excluded from the hash, so the failure is the threshold check, not staleness), then checkout restores green.

- [ ] **Step 3: Full suite green**

Run: `node --test scripts/skill-gate-lib.test.mjs && node scripts/validate-marketplace.mjs && node scripts/check-skill-gate.mjs`
Expected: unit tests PASS; policy validator PASS; gate prints `4 skill(s) passed`.

- [ ] **Step 4: Push and confirm CI is green**

```bash
git push -u origin <change-branch>
```
Then confirm the `validate` workflow (including the two new steps) is green on the PR.
