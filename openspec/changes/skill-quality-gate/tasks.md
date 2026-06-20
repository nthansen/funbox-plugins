## 1. Eval artifact schema & config

- [ ] 1.1 Define the `evals/evals.json` schema (test cases: prompt + assertions; optional per-skill `threshold` override) — reuse skill-creator's evals schema, documented in `CONTRIBUTING.md`
- [ ] 1.2 Define the `evals/benchmark.json` schema (`pass_rate`, per-assertion results, `threshold`, `model`, `source_hash`)
- [ ] 1.3 Add `.claude/skill-gate.json` with the repo-wide default threshold (0.9)
- [ ] 1.4 Add `*-workspace/` to `.gitignore`
- [ ] 1.5 Specify the canonical `source_hash` algorithm (sha256 over skill source incl. `evals/evals.json`, excl. `benchmark.json` and `*-workspace/`) in one shared place referenced by both the command and the CI script

## 2. CI enforcement script

- [ ] 2.1 Implement `scripts/check-skill-gate.mjs` (pure Node, no deps): iterate `plugins/*/skills/*/`, collect all failures, exit non-zero on any
- [ ] 2.2 Implement check: every skill has non-empty `evals/evals.json`
- [ ] 2.3 Implement check: every skill has `evals/benchmark.json`
- [ ] 2.4 Implement freshness check: recompute `source_hash`, compare to stored value, emit "re-run /skill-gate" on mismatch
- [ ] 2.5 Implement threshold check: `pass_rate >= threshold` (repo default or per-skill override), report skill/pass-rate/threshold on failure
- [ ] 2.6 Match the existing validator's output style (report every problem in one pass)

## 3. CI wiring

- [ ] 3.1 Add a `Skill quality gate` step running `node scripts/check-skill-gate.mjs` to `.github/workflows/validate.yml` (after the policy validator)
- [ ] 3.2 Optionally add it to the local pre-commit hook (`.githooks/`)

## 4. Author-time command

- [ ] 4.1 Implement `.claude/commands/skill-gate.md` (`/skill-gate <skill-path>`)
- [ ] 4.2 Detect skill-creator availability; stop with install instructions if missing (no partial/fake benchmark)
- [ ] 4.3 Ensure/draft `evals.json` (help author write prompts + assertions if absent)
- [ ] 4.4 Drive skill-creator's engine: run each case with the skill, grade via `agents/grader.md`, aggregate pass-rate (with-skill only, no baseline)
- [ ] 4.5 Compute `source_hash`, write `benchmark.json` (with `model` id), report pass/fail vs threshold

## 5. Backfill existing skills

- [ ] 5.1 Author evals + generate passing benchmark for `doc-sweep/audit-docs`
- [ ] 5.2 Author evals + generate passing benchmark for `doc-sweep/revise-docs`
- [ ] 5.3 Author evals + generate passing benchmark for `doc-sweep/init-audience-rules` (grade on output when run, not triggering)
- [ ] 5.4 Author evals + generate passing benchmark for `vscode-thinking-display/vscode-thinking-display`

## 6. Documentation & rollout

- [ ] 6.1 Document the gate in `CONTRIBUTING.md` (artifact layout, how to run `/skill-gate`, threshold/override, author-trust limitation)
- [ ] 6.2 Add a line to CLAUDE.md's "Validation (CI gate)" section
- [ ] 6.3 Land script + CI step together with backfilled benchmarks so CI is green; flip to blocking once all skills pass

## 7. Verification

- [ ] 7.1 Run `node scripts/check-skill-gate.mjs` locally — passes with all four backfilled skills
- [ ] 7.2 Negative test: tamper a SKILL.md without re-running → freshness check fails; lower a `pass_rate` below threshold → threshold check fails
- [ ] 7.3 Confirm full CI (`validate.yml`) is green on the change branch
