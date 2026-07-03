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
