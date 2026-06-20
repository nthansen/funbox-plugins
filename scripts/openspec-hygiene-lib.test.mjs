import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { scanSpecPlaceholders, findUnarchivedCompleteChanges } from './openspec-hygiene-lib.mjs';

function repo() {
  return mkdtempSync(join(tmpdir(), 'osh-'));
}
function writeSpec(root, cap, body) {
  const d = join(root, 'openspec', 'specs', cap);
  mkdirSync(d, { recursive: true });
  writeFileSync(join(d, 'spec.md'), body);
}
function writeChangeTasks(root, name, tasks) {
  const d = join(root, 'openspec', 'changes', name);
  mkdirSync(d, { recursive: true });
  writeFileSync(join(d, 'tasks.md'), tasks);
}

// --- A: placeholder scan ---

test('scanSpecPlaceholders flags the archive Purpose marker', () => {
  const r = repo();
  writeSpec(r, 'cap', '# cap\n\n## Purpose\nTBD - created by archiving change x. Update Purpose after archive.\n\n## Requirements\n');
  const errs = scanSpecPlaceholders(r);
  assert.ok(errs.some((e) => /Update Purpose after archive|TBD placeholder/.test(e)));
  rmSync(r, { recursive: true, force: true });
});

test('scanSpecPlaceholders flags a bare TBD Purpose body', () => {
  const r = repo();
  writeSpec(r, 'cap', '# cap\n\n## Purpose\nTBD\n\n## Requirements\n');
  assert.ok(scanSpecPlaceholders(r).some((e) => /TBD placeholder/.test(e)));
  rmSync(r, { recursive: true, force: true });
});

test('scanSpecPlaceholders flags an empty Purpose section', () => {
  const r = repo();
  writeSpec(r, 'cap', '# cap\n\n## Purpose\n\n## Requirements\n');
  assert.ok(scanSpecPlaceholders(r).some((e) => /empty/.test(e)));
  rmSync(r, { recursive: true, force: true });
});

test('scanSpecPlaceholders passes a real Purpose', () => {
  const r = repo();
  writeSpec(r, 'cap', '# cap\n\n## Purpose\nEnforce a real, meaningful purpose for this capability.\n\n## Requirements\n');
  assert.deepEqual(scanSpecPlaceholders(r), []);
  rmSync(r, { recursive: true, force: true });
});

test('scanSpecPlaceholders is a no-op when there are no specs', () => {
  const r = repo();
  assert.deepEqual(scanSpecPlaceholders(r), []);
  rmSync(r, { recursive: true, force: true });
});

// --- B: unarchived complete change ---

test('findUnarchivedCompleteChanges flags an all-done active change', () => {
  const r = repo();
  writeChangeTasks(r, 'feat-x', '## 1\n- [x] 1.1 a\n- [x] 1.2 b\n');
  const errs = findUnarchivedCompleteChanges(r);
  assert.ok(errs.some((e) => /feat-x/.test(e) && /not archived/.test(e)));
  rmSync(r, { recursive: true, force: true });
});

test('findUnarchivedCompleteChanges ignores a change with unchecked tasks', () => {
  const r = repo();
  writeChangeTasks(r, 'feat-y', '## 1\n- [x] 1.1 a\n- [ ] 1.2 b\n');
  assert.deepEqual(findUnarchivedCompleteChanges(r), []);
  rmSync(r, { recursive: true, force: true });
});

test('findUnarchivedCompleteChanges ignores the archive directory', () => {
  const r = repo();
  const d = join(r, 'openspec', 'changes', 'archive', '2026-01-01-old');
  mkdirSync(d, { recursive: true });
  writeFileSync(join(d, 'tasks.md'), '## 1\n- [x] 1.1 done\n');
  assert.deepEqual(findUnarchivedCompleteChanges(r), []);
  rmSync(r, { recursive: true, force: true });
});

test('findUnarchivedCompleteChanges is a no-op with no changes dir', () => {
  const r = repo();
  assert.deepEqual(findUnarchivedCompleteChanges(r), []);
  rmSync(r, { recursive: true, force: true });
});
