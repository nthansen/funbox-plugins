# Unify Doc Classification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse the three disagreeing "what is a doc?" definitions into one shared, declarative classifier so the two guard scripts stop duplicating logic and stop misclassifying `.claude/**/*.md`.

**Architecture:** A new dependency-free node module `doc-classify.mjs` owns doc/non-doc/excluded classification (built-in default doc-set + optional `docPatterns`/`excludeDirs` from a config JSON). `docs-ci-check.sh` and `revise-push-guard.sh` become thin git-plumbing wrappers that pipe changed files to it. `docMode` is removed everywhere; install skills vendor the module and record `docPatterns`.

**Tech Stack:** Bash (git plumbing), Node ≥20 ESM (classifier + `node --test`), GitHub Actions, OpenSpec.

## Global Constraints

- Shell files (`*.sh`) MUST stay LF (`.gitattributes`); pass `bash -n` + ShellCheck (keep existing `# shellcheck disable=SC2086` where word-splitting is intentional).
- No external/non-builtin node dependencies anywhere in doc-sweep scripts. JSON via node, never `jq`.
- `allowed-tools` in SKILL.md must stay scoped (no bare/wildcard `Bash`).
- New skills/changed skills must pass `claude plugin validate` and the skill-gate (`evals/benchmark.json` ≥ 0.9, hash-fresh).
- Node module id: current Claude model is `claude-opus-4-8[1m]` (for any benchmark `model` field).

---

### Task 1: Shared classifier module `doc-classify.mjs`

**Files:**
- Create: `plugins/doc-sweep/hooks/doc-classify.mjs`
- Test: `plugins/doc-sweep/hooks/doc-classify.test.mjs`

**Interfaces:**
- Produces (exported for tests): `globToRegExp(glob: string): RegExp`, `classify(files: string[], opts: {docPatterns?: string[], excludeDirs?: string[]}): {nonDoc: string[], docChanged: boolean}`, `DEFAULT_DOC_PATTERNS: string[]`.
- CLI: reads newline-separated paths on stdin, optional `--config <path>` (JSON `{docPatterns?, excludeDirs?}`), prints `{"nonDoc":[...],"docChanged":bool}` to stdout.

- [ ] **Step 1: Write the failing test**

```js
// plugins/doc-sweep/hooks/doc-classify.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { globToRegExp, classify, DEFAULT_DOC_PATTERNS } from './doc-classify.mjs';

test('globToRegExp: * stays within a segment', () => {
  assert.ok(globToRegExp('README*.md').test('README.md'));
  assert.ok(globToRegExp('**/README*.md').test('sub/README.dev.md'));
  assert.ok(!globToRegExp('README*.md').test('sub/README.md'));
});

test('globToRegExp: ** spans directories', () => {
  assert.ok(globToRegExp('.claude/**/*.md').test('.claude/context/audience-rules.md'));
  assert.ok(globToRegExp('docs/**').test('docs/api/ref.md'));
});

test('.claude markdown is a doc under the default set', () => {
  const r = classify(['.claude/context/audience-rules.md'], {});
  assert.equal(r.docChanged, true);
  assert.deepEqual(r.nonDoc, []);
});

test('default globs: README/docs/CHANGELOG are docs, src is not', () => {
  const r = classify(['README.md', 'docs/x.md', 'CHANGELOG.md', 'src/app.js'], {});
  assert.equal(r.docChanged, true);
  assert.deepEqual(r.nonDoc, ['src/app.js']);
});

test('docPatterns override replaces the default', () => {
  const r = classify(['README.md', 'docs/x.md'], { docPatterns: ['docs/**'] });
  assert.deepEqual(r.nonDoc, ['README.md']);
  assert.equal(r.docChanged, true);
});

test('excludeDirs paths are neither doc nor non-doc', () => {
  const r = classify(['vendor/lib/a.js', 'vendor/lib/README.md'], { excludeDirs: ['vendor'] });
  assert.deepEqual(r.nonDoc, []);
  assert.equal(r.docChanged, false);
});

test('DEFAULT_DOC_PATTERNS includes a .claude glob', () => {
  assert.ok(DEFAULT_DOC_PATTERNS.some((p) => p.includes('.claude')));
});

test('test-only change is exempt (empty nonDoc, docChanged false)', () => {
  const r = classify(['src/app.test.js', 'tests/unit/thing.js'], {});
  assert.deepEqual(r.nonDoc, []);
  assert.equal(r.docChanged, false);
});

test('tests alongside real code still enforce', () => {
  const r = classify(['src/app.test.js', 'src/app.js'], {});
  assert.deepEqual(r.nonDoc, ['src/app.js']);
});

test('excludeDirs wins over exempt and doc matching', () => {
  const r = classify(['vendor/x.test.js', 'vendor/README.md'], { excludeDirs: ['vendor'] });
  assert.deepEqual(r.nonDoc, []);
  assert.equal(r.docChanged, false);
});

test('configured exemptPatterns replaces the default', () => {
  const r = classify(['a.test.js'], { exemptPatterns: ['**/*.gen.js'] });
  assert.deepEqual(r.nonDoc, ['a.test.js']); // .test.js no longer exempt
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test plugins/doc-sweep/hooks/doc-classify.test.mjs`
Expected: FAIL — `Cannot find module './doc-classify.mjs'`.

- [ ] **Step 3: Write minimal implementation**

```js
// plugins/doc-sweep/hooks/doc-classify.mjs
import { readFileSync } from 'node:fs';

// Doc globs. `**/` is an optional prefix (matches root and nested); `**` at the tail
// matches everything under a dir. Kept consistent with the audience-rules base
// (all *.md under .claude/ are Claude-facing docs).
export const DEFAULT_DOC_PATTERNS = [
  '**/CLAUDE*.md',
  '**/README*.md',
  '**/CHANGELOG.md',
  'docs/**',
  '**/docs/**',
  '.claude/**/*.md',
  '**/.claude/**/*.md',
];

// First-party changes that do not require docs (distinct from excludeDirs, which is vendored).
// Evaluated after excludeDirs and before docPatterns. Default: common test files.
export const DEFAULT_EXEMPT_PATTERNS = [
  '**/*.test.*',
  '**/*.spec.*',
  '**/test/**',
  '**/tests/**',
  '**/__tests__/**',
  '**/*_test.go',
  '**/*_test.py',
];

// Translate a glob to an anchored RegExp. Supported: `**/` (optional dir prefix),
// `**` (across segments), `*` (within one segment), literals. No braces/char-classes.
export function globToRegExp(glob) {
  let re = '';
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === '*' && glob[i + 1] === '*') {
      i++; // consume second *
      if (glob[i + 1] === '/') { i++; re += '(?:.*/)?'; } // **/ -> optional dir prefix
      else re += '.*';                                     // ** -> anything incl. /
    } else if (c === '*') {
      re += '[^/]*';
    } else if ('.+^${}()|[]\\/'.includes(c)) {
      re += '\\' + c;
    } else {
      re += c;
    }
  }
  return new RegExp('^' + re + '$');
}

export function classify(files, { docPatterns, excludeDirs, exemptPatterns } = {}) {
  const docRes = ((docPatterns && docPatterns.length) ? docPatterns : DEFAULT_DOC_PATTERNS).map(globToRegExp);
  const exemptRes = ((exemptPatterns && exemptPatterns.length) ? exemptPatterns : DEFAULT_EXEMPT_PATTERNS).map(globToRegExp);
  const excludes = excludeDirs || [];
  const nonDoc = [];
  let docChanged = false;
  for (const f of files) {
    if (!f) continue;
    if (excludes.some((ex) => f === ex || f.startsWith(ex + '/'))) continue; // excluded (vendored)
    if (exemptRes.some((r) => r.test(f))) continue;                          // exempt (e.g. tests)
    if (docRes.some((r) => r.test(f))) docChanged = true;                    // documentation
    else nonDoc.push(f);                                                     // doc-requiring
  }
  return { nonDoc, docChanged };
}

function main() {
  const argv = process.argv.slice(2);
  let cfgPath = null;
  for (let i = 0; i < argv.length; i++) if (argv[i] === '--config') cfgPath = argv[++i];
  let opts = {};
  if (cfgPath) {
    try {
      const c = JSON.parse(readFileSync(cfgPath, 'utf8'));
      opts = { docPatterns: c.docPatterns, excludeDirs: c.excludeDirs, exemptPatterns: c.exemptPatterns };
    } catch { /* fall back to defaults */ }
  }
  let input = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (d) => (input += d));
  process.stdin.on('end', () => {
    const files = input.split('\n').map((s) => s.trim()).filter(Boolean);
    process.stdout.write(JSON.stringify(classify(files, opts)));
  });
}

// Run as CLI only when invoked directly (not when imported by tests).
if (import.meta.url === `file://${process.argv[1]}` || process.argv[1]?.endsWith('doc-classify.mjs')) {
  main();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test plugins/doc-sweep/hooks/doc-classify.test.mjs`
Expected: PASS (all tests).

- [ ] **Step 5: Smoke-test the CLI**

Run: `printf 'src/app.js\n.claude/context/audience-rules.md\n' | node plugins/doc-sweep/hooks/doc-classify.mjs`
Expected: `{"nonDoc":["src/app.js"],"docChanged":true}`

- [ ] **Step 6: Commit**

```bash
git add plugins/doc-sweep/hooks/doc-classify.mjs plugins/doc-sweep/hooks/doc-classify.test.mjs
git commit -m "feat(doc-sweep): add shared doc-classify.mjs classifier"
```

---

### Task 2: `docs-ci-check.sh` delegates to the classifier

**Files:**
- Modify: `plugins/doc-sweep/hooks/docs-ci-check.sh`
- Test: `plugins/doc-sweep/hooks/test-docs-ci-check.sh`

**Interfaces:**
- Consumes: `doc-classify.mjs` CLI (`{nonDoc, docChanged}` JSON).

- [ ] **Step 1: Add a failing regression test** — append to `test-docs-ci-check.sh` before `exit $fail`:

```bash
# .claude markdown counts as a doc (regression: was misclassified non-doc)
repo="$(mkrepo)"; base="$(basesha "$repo")"; commitfile "$repo" src/app.js; commitfile "$repo" .claude/context/audience-rules.md
run "$base" "$repo"; assert_pass $? ".claude/*.md change satisfies the check"

# test-only change is exempt → passes without an ack
repo="$(mkrepo)"; base="$(basesha "$repo")"; commitfile "$repo" src/app.test.js
run "$base" "$repo"; assert_pass $? "test-only change passes (exempt)"

# tests + real code still enforces
repo="$(mkrepo)"; base="$(basesha "$repo")"; commitfile "$repo" src/app.test.js; commitfile "$repo" src/app.js
run "$base" "$repo"; assert_fail $? "tests + src still enforces"
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash plugins/doc-sweep/hooks/test-docs-ci-check.sh`
Expected: FAIL on `.claude/*.md change satisfies the check` (current inline `is_doc` misses `.claude/**`).

- [ ] **Step 3: Replace inline classification with the classifier.** In `docs-ci-check.sh`, delete the `is_doc()` function, the `docmode`/`excludes` config block, and the `while read ... is_doc` loop. Resolve the script dir and call the module:

```bash
here="$(cd "$(dirname "$0")" && pwd)"
cfg_arg=""; [ -n "${1:-}" ] && [ -f "$1" ] && cfg_arg="--config $1"
# shellcheck disable=SC2086
result="$(printf '%s\n' "$changed" | node "$here/doc-classify.mjs" $cfg_arg 2>/dev/null)" || { warn "classify failed; passing (fail-open)"; pass; }
docchanged="$(printf '%s' "$result" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write(String(JSON.parse(s).docChanged)))' 2>/dev/null)"
nondoc="$(printf '%s' "$result" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write((JSON.parse(s).nonDoc||[]).join("\n")))' 2>/dev/null)"
[ -z "$nondoc" ] && pass
[ "$docchanged" = "true" ] && pass
has_ack && pass
```

Keep the failure message loop reading `$nondoc` (now newline-separated).

- [ ] **Step 4: Run tests to verify pass**

Run: `bash plugins/doc-sweep/hooks/test-docs-ci-check.sh`
Expected: all `ok:` including the new regression.

- [ ] **Step 5: Lint**

Run: `bash -n plugins/doc-sweep/hooks/docs-ci-check.sh && shellcheck plugins/doc-sweep/hooks/docs-ci-check.sh`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add plugins/doc-sweep/hooks/docs-ci-check.sh plugins/doc-sweep/hooks/test-docs-ci-check.sh
git commit -m "refactor(doc-sweep): docs-ci-check delegates to doc-classify.mjs"
```

---

### Task 3: `revise-push-guard.sh` delegates to the classifier

**Files:**
- Modify: `plugins/doc-sweep/hooks/revise-push-guard.sh`
- Test: `plugins/doc-sweep/hooks/test-revise-push-guard.sh`

**Interfaces:**
- Consumes: `doc-classify.mjs` CLI.

- [ ] **Step 1: Add a failing regression test** — append before `exit $fail`:

```bash
# .claude markdown-only change since marker → allow (regression)
repo="$(mkrepo)"; mark "$repo"; commitfile "$repo" .claude/context/audience-rules.md
out="$(run 'git push' "$repo" "$no_cfg")"; assert_allow "$out" ".claude/*.md change allows push"

# test-only change since marker → allow (exempt)
repo="$(mkrepo)"; mark "$repo"; commitfile "$repo" src/app.test.js
out="$(run 'git push' "$repo" "$no_cfg")"; assert_allow "$out" "test-only change allows push (exempt)"
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash plugins/doc-sweep/hooks/test-revise-push-guard.sh`
Expected: FAIL on `.claude/*.md change allows push`.

- [ ] **Step 3: Replace inline classification.** Remove `is_doc()`, the `docmode` read, and the `while read ... is_doc` loop that builds `$nondoc`. Compute `$nondoc` via the module:

```bash
here="$(cd "$(dirname "$0")" && pwd)"
cfg_arg=""; [ -n "$cfg" ] && [ -f "$cfg" ] && cfg_arg="--config $cfg"
# shellcheck disable=SC2086
nondoc="$(printf '%s\n' "$changed" | node "$here/doc-classify.mjs" $cfg_arg 2>/dev/null \
  | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write((JSON.parse(s).nonDoc||[]).join(" ")))' 2>/dev/null)"
```

For the per-commit `[skip docs]` loop, replace the inner per-commit `is_doc` scan with a classifier call on that commit's files:

```bash
cfiles="$(git diff-tree --no-commit-id --name-only -r "$c" 2>/dev/null)"
cnon="$(printf '%s\n' "$cfiles" | node "$here/doc-classify.mjs" $cfg_arg 2>/dev/null \
  | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write((JSON.parse(s).nonDoc||[]).join("\n")))' 2>/dev/null)"
[ -n "$cnon" ] && { unacked=1; break; }
```

Keep `trigger`/`excludeDirs`→config, bypass, marker, and fail-open logic. Note `excludeDirs` now flows to the classifier via the config file (still read into `$cfg`).

- [ ] **Step 4: Run tests to verify pass**

Run: `bash plugins/doc-sweep/hooks/test-revise-push-guard.sh`
Expected: all `ok:` including both `[skip docs]` cases and the new `.claude` regression.

- [ ] **Step 5: Lint**

Run: `bash -n plugins/doc-sweep/hooks/revise-push-guard.sh && shellcheck plugins/doc-sweep/hooks/revise-push-guard.sh`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add plugins/doc-sweep/hooks/revise-push-guard.sh plugins/doc-sweep/hooks/test-revise-push-guard.sh
git commit -m "refactor(doc-sweep): push-guard delegates to doc-classify.mjs; retire inline is_doc"
```

---

### Task 4: Retire `docMode`; declare `docPatterns` in audience-rules

**Files:**
- Modify: `plugins/doc-sweep/context/audience-rules.md` (default overlay)
- Verify: no remaining `docMode` in `plugins/doc-sweep/hooks/*.sh`

- [ ] **Step 1: Grep for stragglers**

Run: `grep -rn docMode plugins/doc-sweep/hooks/ || echo "clean"`
Expected: `clean` (Tasks 2–3 removed script usages). Any hit → remove it.

- [ ] **Step 2: Add the `docPatterns` block** to `audience-rules.md`, co-located with the excludeDirs concept:

```markdown
## Machine-readable doc-file-set

The guard scripts (CI check + push hook) classify paths via `doc-classify.mjs`, which reads a
`docPatterns` glob list (the machine-readable twin of the audience table above) and an
`exemptPatterns` list of first-party changes that don't require docs (default: tests). Defaults when
unset: docs = `**/CLAUDE*.md`, `**/README*.md`, `**/CHANGELOG.md`, `docs/**`, `.claude/**/*.md`;
exempt = common test globs. Installers persist the project's choices here (mirrored into the
per-install config JSON, like `excludeDirs`):

    docPatterns:
      - "**/CLAUDE*.md"
      - "**/README*.md"
      - "**/CHANGELOG.md"
      - "docs/**"
      - ".claude/**/*.md"
    exemptPatterns:      # first-party paths that don't require docs (default: tests)
      - "**/*.test.*"
      - "**/*.spec.*"
      - "**/test/**"
      - "**/tests/**"
      - "**/__tests__/**"
```

- [ ] **Step 3: Commit**

```bash
git add plugins/doc-sweep/context/audience-rules.md
git commit -m "docs(doc-sweep): declare machine-readable docPatterns; retire docMode"
```

---

### Task 5: Install skills vendor the classifier + write `docPatterns`

**Files:**
- Modify: `plugins/doc-sweep/skills/install-docs-ci/SKILL.md`, `.../install-docs-ci/evals/evals.json`
- Modify: `plugins/doc-sweep/skills/install-revise-hook/SKILL.md`, `.../install-revise-hook/evals/evals.json`

- [ ] **Step 1: install-docs-ci SKILL.md** — in step 4 (copy script), also copy `../../hooks/doc-classify.mjs` to `.github/doc-sweep/doc-classify.mjs`; change the config write from `docMode` to `docPatterns`; in Uninstall, also delete the vendored `doc-classify.mjs`. Update the summary's "Doc-file set" line to reflect `docPatterns`.

- [ ] **Step 2: install-revise-hook SKILL.md** — in step 3 (copy hook), also copy `../../hooks/doc-classify.mjs` next to the hook; step 5 config writes `docPatterns` not `docMode`; Uninstall deletes the copied `doc-classify.mjs`.

- [ ] **Step 3: Update both `evals/evals.json`** — replace assertions mentioning `docMode` with `docPatterns`, and add an assertion that the installer copies `doc-classify.mjs` alongside the script and removes it on uninstall.

- [ ] **Step 4: Validate skill frontmatter**

Run: `claude plugin validate plugins/doc-sweep`
Expected: passes with warnings (version only).

- [ ] **Step 5: Regenerate benchmarks**

Run: `/skill-gate plugins/doc-sweep/skills/install-docs-ci` then `/skill-gate plugins/doc-sweep/skills/install-revise-hook`
Then: `node scripts/check-skill-gate.mjs`
Expected: all skills pass (≥ 0.9).

- [ ] **Step 6: Commit**

```bash
git add plugins/doc-sweep/skills/install-docs-ci plugins/doc-sweep/skills/install-revise-hook
git commit -m "feat(doc-sweep): installers vendor doc-classify.mjs and record docPatterns"
```

---

### Task 6: CI wiring, docs, validation

**Files:**
- Modify: `.github/workflows/validate.yml`
- Modify: `plugins/doc-sweep/README.md`, `plugins/doc-sweep/CHANGELOG.md`

- [ ] **Step 1: Wire the node test into CI** — in `validate.yml`, next to the existing `node --test` steps, add:

```yaml
      - name: doc-classify unit tests
        run: node --test plugins/doc-sweep/hooks/doc-classify.test.mjs
```

- [ ] **Step 2: Update README + CHANGELOG** — README: replace `docMode` doc-file-set copy with `docPatterns`; document `exemptPatterns` (test-only changes pass without an ack; configurable); note a single `doc-classify.mjs` backs both guards. CHANGELOG: add a "Unify doc classification" entry noting the `.claude/**` fix, `docMode` retirement (BREAKING for stale configs), the shared module, and the new test-exempt behavior.

- [ ] **Step 3: Full local gate**

Run:
```bash
node --test plugins/doc-sweep/hooks/doc-classify.test.mjs \
 && bash plugins/doc-sweep/hooks/test-docs-ci-check.sh \
 && bash plugins/doc-sweep/hooks/test-revise-push-guard.sh \
 && node scripts/validate-marketplace.mjs \
 && node scripts/check-skill-gate.mjs \
 && openspec validate --strict --all \
 && node scripts/check-openspec-hygiene.mjs
```
Expected: all pass.

- [ ] **Step 4: Confirm funbox dogfood picks up the fix** — funbox's `docs-staleness.yml` runs the check with no config, so the built-in default (incl. `.claude/**`) applies automatically; no workflow change needed. Note this in the CHANGELOG entry.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/validate.yml plugins/doc-sweep/README.md plugins/doc-sweep/CHANGELOG.md
git commit -m "ci+docs(doc-sweep): run doc-classify tests; document docPatterns"
```

---

## Self-Review

- **Spec coverage:** `doc-classification` capability → Task 1 (module, default incl. `.claude/**`, glob, config resolution, **exemptPatterns** incl. test-only-exempt / tests+code-enforces / excludeDirs-wins). `docs-staleness-ci` MODIFIED (delegate + vendor + docPatterns; test-only-passes scenario) → Tasks 2, 5. `revise-docs-push-guard` MODIFIED (delegate, retire docMode, vendor, docPatterns) → Tasks 3, 4, 5. No spec requirement left without a task.
- **Placeholder scan:** none — all code steps carry real code.
- **Type consistency:** `classify()` returns `{nonDoc, docChanged}` everywhere; scripts read `.nonDoc`/`.docChanged` verbatim; `globToRegExp`/`DEFAULT_DOC_PATTERNS`/`DEFAULT_EXEMPT_PATTERNS` names match between module and tests.
