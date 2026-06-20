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
