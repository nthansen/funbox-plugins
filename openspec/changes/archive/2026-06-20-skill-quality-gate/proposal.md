## Why

funbox's CI gate proves a skill is *structurally* valid but never that it actually
does its job — a SKILL.md can pass every check and still fail at its stated task.
We want a functional quality bar: each skill must pass an evaluation with a
pass-rate threshold. skill-creator already provides the eval engine, so now is the
moment to wire a thin gate around it rather than let unmeasured skills accumulate.
The payoff is a reviewable, enforced quality floor for every skill in the
marketplace.

## What Changes

**Skill acceptance criteria**
- From: a skill is acceptable if it passes structural/policy validation.
- To: a skill is acceptable only if it also carries committed eval inputs and a
  hash-fresh benchmark whose functional pass-rate ≥ threshold (default 0.9).
- Reason: structural validity does not imply the skill works.
- Impact: non-breaking for consumers; new requirement for contributors and a CI gate.

**New author-time tooling**
- A `/skill-gate <skill-path>` command drives the installed skill-creator engine
  (run eval cases → grade assertions → aggregate pass-rate), computes a
  `source_hash`, writes `evals/benchmark.json`, and reports pass/fail vs threshold.

**New CI verification**
- A pure-Node `scripts/check-skill-gate.mjs`, added as a step in `validate.yml`,
  fails the build if any skill lacks `evals/evals.json`/`benchmark.json`, has a
  stale `source_hash`, or has `pass_rate < threshold`.

**Backfill**
- All four existing skills get `evals.json` + a passing `benchmark.json`.

**Config & hygiene**
- `.claude/skill-gate.json` holds the repo-wide threshold; `.gitignore` excludes the
  `*-workspace/` run artifacts.

## Capabilities

### New Capabilities
- `skill-eval-gate`: Author-time generation and CI enforcement of per-skill
  functional evaluations — committed eval inputs, a hash-verified benchmark
  artifact, an absolute pass-rate threshold, and the `/skill-gate` command plus the
  `check-skill-gate.mjs` CI check that reuse skill-creator's eval engine.

### Modified Capabilities
<!-- None — funbox has no existing OpenSpec capability specs (openspec/specs/ is empty). -->

## Impact

- **New files:** `.claude/commands/skill-gate.md`, `scripts/check-skill-gate.mjs`,
  `.claude/skill-gate.json`, per-skill `evals/evals.json` + `evals/benchmark.json`.
- **Modified files:** `.github/workflows/validate.yml` (new step), `.gitignore`
  (`*-workspace/`), `CONTRIBUTING.md` and `CLAUDE.md` (document the gate).
- **Dependencies:** author-time use of the installed `skill-creator`
  (`claude-plugins-official`); CI has **no** new dependency (pure Node, like the
  existing validator).
- **Systems:** adds a quality layer alongside the existing policy validator; no
  runtime/deployment surface affected.
