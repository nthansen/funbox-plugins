#!/usr/bin/env node
// funbox marketplace validator — the repo POLICY layer.
//
// Schema/frontmatter/hooks correctness is handled by the official `claude plugin validate`
// (run alongside this in CI). This script enforces the funbox-specific criteria that the
// official validator doesn't: required README+CHANGELOG per plugin, scoped allowed-tools,
// danger-pattern scan, cross-marketplace dependency allowlist, and orphan-dir checks.
// See CONTRIBUTING.md.
//
// Pure Node, no dependencies. Run from the repo root:
//   node scripts/validate-marketplace.mjs
//
// Exits non-zero (and prints every problem) if anything fails. Used by both CI
// (.github/workflows/validate.yml) and the local pre-commit hook (.githooks/).

import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const root = process.cwd();
const errors = [];
const err = (m) => errors.push(m);
const rel = (p) => relative(root, p).replace(/\\/g, '/');
const isDir = (p) => existsSync(p) && statSync(p).isDirectory();

function readJSON(p) {
  try {
    return JSON.parse(readFileSync(p, 'utf8'));
  } catch (e) {
    err(`${rel(p)}: invalid JSON — ${e.message}`);
    return null;
  }
}

// --- 1. marketplace.json -----------------------------------------------------
const mpPath = join(root, '.claude-plugin', 'marketplace.json');
let mp = null;
if (!existsSync(mpPath)) {
  err('.claude-plugin/marketplace.json is missing');
} else {
  mp = readJSON(mpPath);
}

const listed = new Map(); // plugin name -> source
if (mp) {
  if (typeof mp.name !== 'string' || !mp.name) err('marketplace.json: "name" must be a non-empty string');
  if (!mp.owner || typeof mp.owner.name !== 'string') err('marketplace.json: "owner.name" is required');
  if (!Array.isArray(mp.plugins)) {
    err('marketplace.json: "plugins" must be an array');
  } else {
    mp.plugins.forEach((p, i) => {
      const at = `marketplace.json plugins[${i}]`;
      if (typeof p.name !== 'string' || !p.name) return err(`${at}: "name" is required`);
      if (typeof p.description !== 'string' || !p.description) err(`${at} (${p.name}): "description" is required`);
      if (typeof p.source !== 'string' || !p.source.startsWith('./plugins/')) {
        return err(`${at} (${p.name}): "source" must be a path starting with "./plugins/"`);
      }
      if (listed.has(p.name)) err(`${at}: duplicate plugin name "${p.name}"`);
      listed.set(p.name, p.source);
    });
  }
}

// --- 2. each listed plugin ---------------------------------------------------
const mpName = mp && typeof mp.name === 'string' ? mp.name : null;
const allowedCross = mp && Array.isArray(mp.allowCrossMarketplaceDependenciesOn)
  ? mp.allowCrossMarketplaceDependenciesOn
  : [];
const REQUIRED_PLUGIN_FILES = ['README.md', 'CHANGELOG.md'];
for (const [name, source] of listed) {
  const dir = join(root, source);
  if (!isDir(dir)) {
    err(`plugin "${name}": source "${source}" does not exist`);
    continue;
  }
  const manifestPath = join(dir, '.claude-plugin', 'plugin.json');
  if (!existsSync(manifestPath)) {
    err(`plugin "${name}": missing .claude-plugin/plugin.json`);
  } else {
    const man = readJSON(manifestPath);
    if (man) {
      if (man.name !== name) err(`plugin "${name}": plugin.json name "${man.name}" != marketplace entry "${name}"`);
      if (typeof man.description !== 'string' || !man.description) err(`plugin "${name}": plugin.json "description" is required`);
      if (man.dependencies !== undefined) validateDependencies(name, man.dependencies);
    }
  }
  for (const f of REQUIRED_PLUGIN_FILES) {
    if (!existsSync(join(dir, f))) err(`plugin "${name}": required file ${f} is missing`);
  }
  const skillsDir = join(dir, 'skills');
  if (isDir(skillsDir)) {
    for (const skill of readdirSync(skillsDir)) {
      const sdir = join(skillsDir, skill);
      if (!isDir(sdir)) continue;
      const skp = join(sdir, 'SKILL.md');
      if (!existsSync(skp)) err(`plugin "${name}" skill "${skill}": missing SKILL.md`);
      else validateSkill(name, skill, skp);
    }
  }
}

// --- 3. no orphan plugin directories ----------------------------------------
const pluginsRoot = join(root, 'plugins');
if (isDir(pluginsRoot)) {
  for (const d of readdirSync(pluginsRoot)) {
    if (!isDir(join(pluginsRoot, d))) continue;
    if (![...listed.keys()].includes(d)) err(`plugins/${d}/ exists but is not listed in marketplace.json`);
  }
}

// --- 4. danger-pattern scan in scripts --------------------------------------
const DANGER = [
  [/(curl|wget|iwr|Invoke-WebRequest)\b[^\n]*\|[^\n]*\b(sh|bash|zsh|iex|Invoke-Expression)\b/i, 'pipes a network download straight into a shell'],
  [/\brm\s+-[a-zA-Z]+\s+["']?(\/(\s|$|["'])|~(\/|\s|$)|\$\{?HOME)/, 'rm -rf targeting / or $HOME'],
  [/\bbase64\b[^\n]*-d[^\n]*\|[^\n]*\b(sh|bash|zsh)\b/i, 'base64-decodes content into a shell'],
];
function scanScripts(dir) {
  for (const e of readdirSync(dir)) {
    const p = join(dir, e);
    if (isDir(p)) {
      scanScripts(p);
      continue;
    }
    if (!/\.(sh|ps1)$/.test(e)) continue;
    const txt = readFileSync(p, 'utf8');
    for (const [re, why] of DANGER) if (re.test(txt)) err(`${rel(p)}: flagged — ${why} (needs maintainer review)`);
  }
}
if (isDir(pluginsRoot)) scanScripts(pluginsRoot);

// --- skill frontmatter validator --------------------------------------------
function validateSkill(plugin, skill, path) {
  const txt = readFileSync(path, 'utf8');
  const m = txt.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!m) return err(`${rel(path)}: missing YAML frontmatter block`);
  const fm = m[1];

  const nameM = fm.match(/^name:\s*(.+?)\s*$/m);
  if (!nameM) err(`${rel(path)}: frontmatter "name" is required`);
  else {
    const nm = nameM[1].trim().replace(/^["']|["']$/g, '');
    if (nm !== skill) err(`${rel(path)}: frontmatter name "${nm}" != directory "${skill}"`);
  }

  const descM = fm.match(/^description:\s*(.+?)\s*$/m);
  if (!descM) err(`${rel(path)}: frontmatter "description" is required`);
  else if (descM[1].trim().length > 1024) err(`${rel(path)}: frontmatter "description" exceeds 1024 chars`);

  // allowed-tools must be scoped — no bare/​wildcard execution tools.
  const atIdx = fm.indexOf('allowed-tools:');
  if (atIdx !== -1) {
    const items = fm
      .slice(atIdx)
      .split('\n')
      .slice(1)
      .map((l) => l.match(/^\s*-\s*(.+?)\s*$/))
      .filter(Boolean)
      .map((x) => x[1]);
    for (const it of items) {
      if (isUnscopedExecTool(it)) err(`${rel(path)}: allowed-tools entry "${it}" is unscoped/too broad — scope it to specific commands or files`);
    }
  }
}

function isUnscopedExecTool(entry) {
  const e = entry.replace(/^["']|["']$/g, '').trim();
  if (/^(Bash|PowerShell|Shell)$/.test(e)) return true; // bare grant
  const m = e.match(/^(Bash|PowerShell|Shell)\((.*)\)$/);
  if (m) {
    const arg = m[2].trim();
    if (arg === '' || arg === '*' || arg === '*:*') return true; // wildcard-everything
  }
  return false;
}

function validateDependencies(plugin, deps) {
  if (!Array.isArray(deps)) return err(`plugin "${plugin}": "dependencies" must be an array`);
  for (const dep of deps) {
    let dname, dmarket;
    if (typeof dep === 'string') {
      dname = dep;
    } else if (dep && typeof dep === 'object') {
      dname = dep.name;
      dmarket = dep.marketplace;
    } else {
      err(`plugin "${plugin}": invalid dependency entry (must be a string or object)`);
      continue;
    }
    if (typeof dname !== 'string' || !dname) err(`plugin "${plugin}": a dependency is missing "name"`);
    // Cross-marketplace dependencies must be allowlisted in marketplace.json.
    if (dmarket && dmarket !== mpName && !allowedCross.includes(dmarket)) {
      err(`plugin "${plugin}": cross-marketplace dependency on "${dmarket}" is not allowlisted — add "${dmarket}" to "allowCrossMarketplaceDependenciesOn" in marketplace.json`);
    }
  }
}

// --- report ------------------------------------------------------------------
if (errors.length) {
  console.error(`\n✗ funbox validation failed (${errors.length} problem${errors.length > 1 ? 's' : ''}):`);
  for (const e of errors) console.error('  • ' + e);
  console.error('\nSee CONTRIBUTING.md for the criteria.\n');
  process.exit(1);
}
console.log('✓ funbox validation passed');
