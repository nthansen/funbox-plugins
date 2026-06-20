## ADDED Requirements

### Requirement: Per-skill committed eval artifacts

Every skill under `plugins/*/skills/*/` SHALL carry committed evaluation artifacts:
an `evals/evals.json` containing at least one test case (prompt + assertions) and an
`evals/benchmark.json` containing the recorded result. Raw run outputs and
transcripts SHALL NOT be committed; they live in a gitignored `*-workspace/`
sibling.

#### Scenario: Skill missing eval inputs
- **WHEN** the CI check runs against a skill directory with no `evals/evals.json`, or an `evals.json` containing zero test cases
- **THEN** the check fails and reports that the skill must define at least one eval case

#### Scenario: Skill missing benchmark
- **WHEN** a skill has `evals/evals.json` but no `evals/benchmark.json`
- **THEN** the check fails and instructs the author to run `/skill-gate` to produce the benchmark

#### Scenario: Workspace artifacts excluded
- **WHEN** a contributor runs the gate locally
- **THEN** the `*-workspace/` run directory is ignored by git and never committed

### Requirement: Functional pass-rate threshold

The gate SHALL pass a skill only when its with-skill assertion pass-rate recorded in
`benchmark.json` is greater than or equal to the applicable threshold. The threshold
SHALL default to 0.9, be configurable repo-wide in `.claude/skill-gate.json`, and be
overridable per skill via a field in that skill's `evals.json`. Baseline (no-skill)
runs SHALL NOT be required.

#### Scenario: Pass-rate meets threshold
- **WHEN** `benchmark.json` reports `pass_rate` ≥ the applicable threshold
- **THEN** the CI check passes for that skill

#### Scenario: Pass-rate below threshold
- **WHEN** `benchmark.json` reports `pass_rate` < the applicable threshold
- **THEN** the CI check fails and reports the skill name, its pass-rate, and the threshold it missed

#### Scenario: Per-skill override
- **WHEN** a skill's `evals.json` declares a threshold that differs from the repo-wide default
- **THEN** the gate evaluates that skill against its own declared threshold

### Requirement: Benchmark freshness via source hash

`benchmark.json` SHALL store a `source_hash` computed as the sha256 over the skill's
source files including `evals/evals.json` but excluding `benchmark.json` and any
`*-workspace/` directory. The CI check SHALL recompute this hash and fail if it does
not match the stored value, so that any change to the SKILL.md, bundled resources, or
assertions forces a fresh evaluation.

#### Scenario: Stale benchmark after skill edit
- **WHEN** a skill's SKILL.md, a bundled resource, or its `evals.json` is changed without regenerating `benchmark.json`
- **THEN** the recomputed `source_hash` differs from the stored value and the CI check fails with a "benchmark stale — re-run /skill-gate" message

#### Scenario: Fresh benchmark
- **WHEN** the recomputed `source_hash` matches the value stored in `benchmark.json`
- **THEN** the freshness check passes for that skill

### Requirement: Author-time gate command

The repo SHALL provide a `/skill-gate <skill-path>` command that drives the installed
skill-creator eval engine (running each test case against the skill, grading
assertions, aggregating the pass-rate), computes the `source_hash`, writes
`evals/benchmark.json` (including `pass_rate`, per-assertion results, the threshold
used, the model id, and `source_hash`), and reports pass or fail against the
threshold. The command SHALL detect when skill-creator is not installed and instruct
the contributor to install it rather than failing silently.

#### Scenario: Generating a benchmark
- **WHEN** an author runs `/skill-gate` on a skill that has `evals.json`
- **THEN** the command runs the eval cases, grades them, and writes a `benchmark.json` whose `source_hash` matches the current skill source

#### Scenario: skill-creator not installed
- **WHEN** an author runs `/skill-gate` and the skill-creator engine is unavailable
- **THEN** the command stops and tells the contributor to install skill-creator instead of producing a partial or fake benchmark

### Requirement: Deterministic CI enforcement

CI SHALL enforce the gate via a pure-Node script (`scripts/check-skill-gate.mjs`)
added as a step in `.github/workflows/validate.yml`. The script SHALL require no
Anthropic auth, run no LLM, collect and report every failing skill in one pass (in
the style of the existing `validate-marketplace.mjs`), and exit non-zero if any skill
fails any gate condition.

#### Scenario: All skills pass
- **WHEN** every skill has fresh eval artifacts meeting its threshold
- **THEN** the CI step exits zero and the build proceeds

#### Scenario: Multiple failures reported together
- **WHEN** several skills fail different gate conditions
- **THEN** the script reports all failures in a single run and exits non-zero

#### Scenario: No paid dependency in CI
- **WHEN** the CI step executes
- **THEN** it performs only deterministic file and hash checks with no network or LLM calls

### Requirement: Full coverage of existing skills

All skills present in the repo at rollout SHALL carry passing eval artifacts,
including `audit-docs`, `revise-docs`, `init-audience-rules`, and
`vscode-thinking-display`. Manual-invocation skills (e.g. `init-audience-rules`,
which is `disable-model-invocation`) SHALL be evaluated on the output produced when
the skill is run, not on triggering behavior.

#### Scenario: Backfilled existing skills
- **WHEN** the change lands
- **THEN** each of the four existing skills has `evals.json` and a passing `benchmark.json`, and the CI gate is green

#### Scenario: Manual-invocation skill
- **WHEN** the gate evaluates `init-audience-rules`
- **THEN** the eval cases exercise the skill's output when run, not whether it auto-triggers
