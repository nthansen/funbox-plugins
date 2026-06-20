## 1. Eval artifact schema & config

- [x] 1.1 Define the `evals/evals.json` schema (test cases: prompt + assertions; optional per-skill `threshold` override) — reuse skill-creator's evals schema, documented in `CONTRIBUTING.md`
- [x] 1.2 Define the `evals/benchmark.json` schema (`pass_rate`, per-assertion results, `threshold`, `model`, `source_hash`)
- [x] 1.3 Add `.claude/skill-gate.json` with the repo-wide default threshold (0.9)
- [x] 1.4 Add `*-workspace/` to `.gitignore`
- [x] 1.5 Specify the canonical `source_hash` algorithm (sha256 over skill source incl. `evals/evals.json`, excl. `benchmark.json` and `*-workspace/`) in one shared place referenced by both the command and the CI script

## 2. CI enforcement script

- [x] 2.1 Implement `scripts/check-skill-gate.mjs` (pure Node, no deps): iterate `plugins/*/skills/*/`, collect all failures, exit non-zero on any
- [x] 2.2 Implement check: every skill has non-empty `evals/evals.json`
- [x] 2.3 Implement check: every skill has `evals/benchmark.json`
- [x] 2.4 Implement freshness check: recompute `source_hash`, compare to stored value, emit "re-run /skill-gate" on mismatch
- [x] 2.5 Implement threshold check: `pass_rate >= threshold` (repo default or per-skill override), report skill/pass-rate/threshold on failure
- [x] 2.6 Match the existing validator's output style (report every problem in one pass)

## 3. CI wiring

- [x] 3.1 Add a `Skill quality gate` step running `node scripts/check-skill-gate.mjs` to `.github/workflows/validate.yml` (after the policy validator)
- [x] 3.2 Optionally add it to the local pre-commit hook (`.githooks/`) — skipped (optional; CI is the gate)

## 4. Author-time command

- [x] 4.1 Implement `.claude/commands/skill-gate.md` (`/skill-gate <skill-path>`)
- [x] 4.2 Detect skill-creator availability; stop with install instructions if missing (no partial/fake benchmark)
- [x] 4.3 Ensure/draft `evals.json` (help author write prompts + assertions if absent)
- [x] 4.4 Drive skill-creator's engine: run each case with the skill, grade via `agents/grader.md`, aggregate pass-rate (with-skill only, no baseline)
- [x] 4.5 Compute `source_hash`, write `benchmark.json` (with `model` id), report pass/fail vs threshold

## 5. Backfill existing skills

- [x] 5.1 Author evals + generate passing benchmark for `doc-sweep/audit-docs`
- [x] 5.2 Author evals + generate passing benchmark for `doc-sweep/revise-docs`
- [x] 5.3 Author evals + generate passing benchmark for `doc-sweep/init-audience-rules` (grade on output when run, not triggering)
- [x] 5.4 Author evals + generate passing benchmark for `vscode-thinking-display/vscode-thinking-display`

## 6. Documentation & rollout

- [x] 6.1 Document the gate in `CONTRIBUTING.md` (artifact layout, how to run `/skill-gate`, threshold/override, author-trust limitation)
- [x] 6.2 Add a line to CLAUDE.md's "Validation (CI gate)" section
- [x] 6.3 Land script + CI step together with backfilled benchmarks so CI is green; flip to blocking once all skills pass

## 7. Verification

- [x] 7.1 Run `node scripts/check-skill-gate.mjs` locally — passes with all four backfilled skills
- [x] 7.2 Negative test: tamper a SKILL.md without re-running → freshness check fails; lower a `pass_rate` below threshold → threshold check fails
- [ ] 7.3 Confirm full CI (`validate.yml`) is green on the change branch
