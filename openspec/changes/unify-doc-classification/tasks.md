## 1. Shared classifier module

- [ ] 1.1 Create `plugins/doc-sweep/hooks/doc-classify.mjs` (LF): reads a newline-separated file list on stdin, accepts optional `--config <path>`, emits `{"nonDoc":[...],"docChanged":bool}` on stdout; no external deps
- [ ] 1.2 Implement the in-house glob matcher supporting `*` (within a segment) and `**` (across segments) plus literals; unit-test its corners
- [ ] 1.3 Built-in default doc-set = `CLAUDE*.md`, `README*.md`, `CHANGELOG.md`, `docs/**`, `.claude/**/*.md`; `docPatterns`/`excludeDirs` from `--config` JSON override the default; excluded paths are neither doc nor non-doc
- [ ] 1.4 Add `plugins/doc-sweep/hooks/doc-classify.test.mjs` (`node --test`): default globs, `.claude/**` now a doc, docPatterns override replaces default, excludeDirs, `**` spans dirs, output shape
- [ ] 1.5 Confirm `node --test plugins/doc-sweep/hooks/doc-classify.test.mjs` passes

## 2. Refactor both scripts to delegate

- [ ] 2.1 `docs-ci-check.sh`: replace inline `is_doc`/`docMode`/excludeDirs parsing with a single pipe of changed files to `doc-classify.mjs --config <cfg>`; act on `nonDoc`/`docChanged`; keep merge-base, diff, ack, fail-open logic
- [ ] 2.2 `revise-push-guard.sh`: replace inline `is_doc`/`docMode` with the classifier for both the range classification and the per-commit `[skip docs]` non-doc detection; keep trigger/bypass/marker/fail-open logic
- [ ] 2.3 Update `test-docs-ci-check.sh` and `test-revise-push-guard.sh` to work through the classifier; add a regression case: an `.claude/context/audience-rules.md`-only PR/change passes
- [ ] 2.4 `bash -n` + ShellCheck clean on both scripts; both shell test suites green

## 3. Retire docMode + declare docPatterns

- [ ] 3.1 Remove all `docMode` handling from both scripts and the config schema (classifier owns classification)
- [ ] 3.2 Add a `docPatterns:` block to `context/audience-rules-base.md` (or the default overlay `audience-rules.md`), co-located with `excludeDirs`, documenting the machine-readable doc-set as the twin of the prose table

## 4. Install skills

- [ ] 4.1 `install-revise-hook` SKILL.md: copy `doc-classify.mjs` alongside the hook; write `docPatterns` (not `docMode`); uninstall removes the vendored classifier; update its `evals/evals.json` assertions accordingly
- [ ] 4.2 `install-docs-ci` SKILL.md: vendor `doc-classify.mjs` under `.github/doc-sweep/`; write `docPatterns`; uninstall removes it; update its `evals/evals.json` assertions
- [ ] 4.3 Regenerate both skills' `evals/benchmark.json` via `/skill-gate` so they clear the threshold; `node scripts/check-skill-gate.mjs` passes

## 5. CI wiring, docs, validation

- [ ] 5.1 Wire `node --test plugins/doc-sweep/hooks/doc-classify.test.mjs` into `.github/workflows/validate.yml` alongside the existing `node --test` suites
- [ ] 5.2 Update doc-sweep `README.md` (docPatterns replaces docMode; classifier note) and `CHANGELOG.md`
- [ ] 5.3 Run `node scripts/validate-marketplace.mjs`, `claude plugin validate plugins/doc-sweep`, `openspec validate --strict --all`, and `node scripts/check-openspec-hygiene.mjs`; fix findings
- [ ] 5.4 Confirm funbox's own `docs-staleness.yml` (no-config) now treats `.claude/**` as docs via the fixed default
