## 1. Shared classifier module

- [x] 1.1 Create `plugins/doc-sweep/hooks/doc-classify.mjs` (LF): reads a newline-separated file list on stdin, accepts optional `--config <path>`, emits `{"nonDoc":[...],"docChanged":bool}` on stdout; no external deps
- [x] 1.2 Implement the in-house glob matcher supporting `*` (within a segment) and `**` (across segments) plus literals; unit-test its corners
- [x] 1.3 Built-in default doc-set = `CLAUDE*.md`, `README*.md`, `CHANGELOG.md`, `docs/**`, `.claude/**/*.md`; `docPatterns`/`excludeDirs`/`exemptPatterns` from `--config` JSON override the defaults; excluded paths are neither doc nor non-doc
- [x] 1.4 Add `exemptPatterns` (evaluated after `excludeDirs`, before `docPatterns`; dropped from `nonDoc`, doesn't set `docChanged`); built-in default = common test globs (`**/*.test.*`, `**/*.spec.*`, `**/test/**`, `**/tests/**`, `**/__tests__/**`, `**/*_test.go`, `**/*_test.py`)
- [x] 1.5 Add `plugins/doc-sweep/hooks/doc-classify.test.mjs` (`node --test`): default globs, `.claude/**` now a doc, docPatterns override, excludeDirs, `**` spans dirs, output shape, **test-only change exempt**, **tests + real code still non-doc**, **excludeDirs wins over exempt**
- [x] 1.6 Confirm `node --test plugins/doc-sweep/hooks/doc-classify.test.mjs` passes

## 2. Refactor both scripts to delegate

- [x] 2.1 `docs-ci-check.sh`: replace inline `is_doc`/`docMode`/excludeDirs parsing with a single pipe of changed files to `doc-classify.mjs --config <cfg>`; act on `nonDoc`/`docChanged`; keep merge-base, diff, ack, fail-open logic
- [x] 2.2 `revise-push-guard.sh`: replace inline `is_doc`/`docMode` with the classifier for both the range classification and the per-commit `[skip docs]` non-doc detection; keep trigger/bypass/marker/fail-open logic
- [x] 2.3 Update `test-docs-ci-check.sh` and `test-revise-push-guard.sh` to work through the classifier; add regression cases: an `.claude/context/audience-rules.md`-only change passes, and a **test-only change** (e.g. `src/app.test.js`) passes without an ack while tests + `src/app.js` still enforces
- [x] 2.4 `bash -n` + ShellCheck clean on both scripts; both shell test suites green

## 3. Retire docMode + declare docPatterns

- [x] 3.1 Remove all `docMode` handling from both scripts and the config schema (classifier owns classification)
- [x] 3.2 Add `docPatterns:` and `exemptPatterns:` blocks to `context/audience-rules.md` (default overlay), co-located with `excludeDirs`, documenting the machine-readable doc-set + the default test-exempt set as the twin of the prose table

## 4. Install skills

- [x] 4.1 `install-revise-hook` SKILL.md: copy `doc-classify.mjs` alongside the hook; write `docPatterns` (not `docMode`); uninstall removes the vendored classifier; update its `evals/evals.json` assertions accordingly
- [x] 4.2 `install-docs-ci` SKILL.md: vendor `doc-classify.mjs` under `.github/doc-sweep/`; write `docPatterns`; uninstall removes it; update its `evals/evals.json` assertions
- [x] 4.3 Regenerate both skills' `evals/benchmark.json` via `/skill-gate` so they clear the threshold; `node scripts/check-skill-gate.mjs` passes

## 5. CI wiring, docs, validation

- [x] 5.1 Wire `node --test plugins/doc-sweep/hooks/doc-classify.test.mjs` into `.github/workflows/validate.yml` alongside the existing `node --test` suites
- [x] 5.2 Update doc-sweep `README.md` (docPatterns replaces docMode; `exemptPatterns`/test-only-passes; classifier note) and `CHANGELOG.md`
- [x] 5.3 Run `node scripts/validate-marketplace.mjs`, `claude plugin validate plugins/doc-sweep`, `openspec validate --strict --all`, and `node scripts/check-openspec-hygiene.mjs`; fix findings
- [x] 5.4 Confirm funbox's own `docs-staleness.yml` (no-config) now treats `.claude/**` as docs via the fixed default
