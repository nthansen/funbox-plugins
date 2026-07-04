## 1. Installer skills

- [x] 1.1 `install-docs-ci/SKILL.md`: add an exempt-set prompt alongside the doc-file-set question — **default** (built-in test globs) vs **add extras** (user supplies additional globs). On default, omit `exemptPatterns` from the config JSON. On add-extras, write `exemptPatterns` = (built-in default test globs, sourced from `context/audience-rules.md`) + the user's additions, into the config JSON AND persist to `.claude/context/audience-rules.md` (same mechanism as custom `docPatterns`). Add the exempt-set to the structured summary.
- [x] 1.2 `install-revise-hook/SKILL.md`: same exempt-set prompt + config/audience-rules persistence + summary line, mirroring 1.1.
- [x] 1.3 Confirm both SKILL.md keep scoped `allowed-tools` and `disable-model-invocation: true`, valid frontmatter; `claude plugin validate plugins/doc-sweep` passes.

## 2. Docs

- [x] 2.1 `context/audience-rules.md`: replace the "`exemptPatterns` … is not currently exposed as an installer choice" text with a note that both installers now offer a default-vs-add-extras exempt choice (add-extras persists here, like `docPatterns`).
- [x] 2.2 `README.md`: update the exempt paragraph — `exemptPatterns` is now an installer choice (default test globs, or add your own extras), not just a hand-edited config field.
- [x] 2.3 `CHANGELOG.md`: add an "Expose exemptPatterns to installers" entry.

## 3. Evals + quality gate

- [x] 3.1 `install-docs-ci/evals/evals.json` and `install-revise-hook/evals/evals.json`: add an assertion that choosing add-extras records `exemptPatterns` as (built-in tests + additions) in the config and persists it to `audience-rules.md`; keeping the default omits `exemptPatterns`.
- [x] 3.2 Regenerate both `evals/benchmark.json` via real eval runs so they clear the threshold; `node scripts/check-skill-gate.mjs` passes.

## 4. Validation + adversarial review

- [ ] 4.1 Run `node scripts/validate-marketplace.mjs`, `claude plugin validate plugins/doc-sweep`, `openspec validate --strict --all`, `node scripts/check-openspec-hygiene.mjs`; fix findings.
- [ ] 4.2 Adversarial review of the installer SKILL.md changes (edge cases: add-extras dedupe with built-in globs; reconfigure preserving exemptPatterns; interaction with the docPatterns choice); fix any Critical/Important.
- [ ] 4.3 Archive the change with `openspec archive` and fill any seeded spec Purpose (n/a — no new capability).
