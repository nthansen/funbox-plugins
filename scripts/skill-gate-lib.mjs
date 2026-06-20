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
// Line endings are normalized (CRLF/CR → LF) before hashing so benchmarks
// stay valid across platforms (Windows working tree vs Linux CI).
export function computeSourceHash(skillDir) {
  const h = createHash('sha256');
  for (const rel of walkFiles(skillDir)) {
    h.update(rel, 'utf8');
    h.update('\0');
    const bytes = readFileSync(join(skillDir, rel));
    const normalized = bytes.toString('latin1').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
    h.update(Buffer.from(normalized, 'latin1'));
    h.update('\0');
  }
  return 'sha256:' + h.digest('hex');
}

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
      if (/-workspace$/.test(skill)) continue; // gitignored eval run artifacts, not skills
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

  if (!Array.isArray(bench.results) || bench.results.length === 0) {
    errs.push(`${label}: benchmark.json has no results — re-run /skill-gate`);
  } else {
    const passed = bench.results.filter((r) => r.passed).length;
    const derived = passed / bench.results.length;
    if (typeof bench.pass_rate === 'number' && Math.abs(derived - bench.pass_rate) > 1e-6) {
      errs.push(`${label}: benchmark pass_rate ${bench.pass_rate} inconsistent with results (${passed}/${bench.results.length})`);
    }
  }

  const threshold = typeof evals.threshold === 'number' ? evals.threshold : repoDefault;
  if (typeof bench.pass_rate !== 'number') {
    errs.push(`${label}: benchmark.json missing numeric pass_rate`);
  } else if (bench.pass_rate < threshold) {
    errs.push(`${label}: pass_rate ${bench.pass_rate} below threshold ${threshold}`);
  }
  return errs;
}
