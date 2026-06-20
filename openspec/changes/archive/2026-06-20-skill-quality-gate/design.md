## Context

funbox is a Claude Code plugin marketplace with a strong, CI-enforced contribution
gate (`scripts/validate-marketplace.mjs` + `claude plugin validate` + shell/PowerShell
parse + gitleaks, all in `.github/workflows/validate.yml`). Today nothing measures
the *functional quality* of a skill — a SKILL.md can be structurally valid yet not
actually accomplish its stated job.

The user wants a quality gate: every skill should pass a functional evaluation with
a pass-rate threshold before it is accepted. Research established that
**skill-creator** (`claude-plugins-official`) already ships the functional-eval
engine — `run_eval.py` (runs a skill on a prompt), `agents/grader.md` (grades
assertions), `aggregate_benchmark.py` (computes `pass_rate`). `plugin-dev` ships a
`skill-reviewer` agent, but that is a qualitative rubric review with no numeric
threshold and no execution. The missing pieces are a **threshold gate**, a **CI
freshness check**, and the **glue** into funbox's workflow.

Hard constraint: funbox CI runs on GitHub Actions with no Anthropic auth, so any
LLM-based evaluation cannot run in CI without secrets, token cost, and flakiness.

Stakeholders: funbox maintainer (nthansen), future skill contributors, and Claude
acting as author/runner of the gate.

## Goals / Non-Goals

**Goals:**
- Every skill under `plugins/*/skills/*/` carries committed eval inputs and a
  committed, hash-verified benchmark whose functional pass-rate meets a threshold.
- Reuse skill-creator's eval engine; build only the threshold check, the CI
  freshness verification, and the workflow glue.
- Keep the expensive, non-deterministic LLM evaluation at author time; keep CI
  deterministic, dependency-free, and fast.
- Backfill all four existing skills so the gate is fully enforced from day one.

**Non-Goals:**
- Re-running evals inside GitHub Actions (no LLM in CI).
- Baseline (no-skill / with-skill delta) comparison — absolute pass-rate only.
- Trigger-accuracy evaluation or rubric grading (considered, not chosen).
- Adversarial-proof enforcement — the gate is author-trust, not tamper-proof.
- A shippable marketplace plugin — this is repo-internal tooling.

## Decisions

### D1: Measure functional eval pass-rate
- **Choice:** The gate measures the with-skill assertion pass-rate from running the
  skill against committed test cases, graded by assertions.
- **Rationale:** Most rigorous signal that a skill does its job; the engine already
  exists in skill-creator.
- **Alternatives considered:** rubric LLM grade (cheap/universal but subjective, not
  a skill-creator feature); structural lint (deterministic but binary, already
  partly covered by validators); trigger-accuracy (a real score+threshold but needs
  per-skill trigger query sets and many runs).

### D2: Author-time generation + deterministic CI verification
- **Choice:** A `/`-command runs the evals locally and writes a committed
  `benchmark.json`; a pure-Node CI check verifies that artifact.
- **Rationale:** Decouples LLM work (local, author) from enforcement (CI,
  deterministic). Respects the no-auth-in-CI constraint while still blocking merges.
- **Alternatives considered:** author-time-only (advisory, unenforceable); full
  execution in GitHub Actions with an API key (token cost, non-determinism, paid
  dependency on a public repo).

### D3: Absolute pass-rate ≥ threshold (default 0.9)
- **Choice:** Gate passes when `pass_rate ≥ threshold`; no baseline runs. Threshold
  default 0.9, set repo-wide in `.claude/skill-gate.json`, optional per-skill
  override in `evals.json`.
- **Rationale:** Matches the user's "pass a threshold" framing; halves run cost (no
  baseline); avoids noisy borderline failures.
- **Alternatives considered:** must-beat-baseline-by-margin; both absolute AND
  beats-baseline (most expensive, flakiest).

### D4: Repo-internal tooling reusing skill-creator
- **Choice:** A funbox `/`-command + a Node CI script; the command drives the
  *installed* skill-creator engine. No new plugin, no vendored scripts.
- **Rationale:** Thinnest path; no duplicated code that can drift; no
  cross-marketplace dependency allowlist entry needed (it is contributor tooling,
  not a `plugin.json` dependency). funbox already dogfoods external plugins.
- **Alternatives considered:** vendoring skill-creator's scripts (duplication/drift);
  a shipped "skill-gate" plugin (heaviest; README/CHANGELOG/scoped tools + allowlist).

### D5: Freshness via `source_hash`
- **Choice:** `benchmark.json` stores `source_hash` = sha256 over the skill's source
  files *including* `evals/evals.json`, *excluding* `benchmark.json` and the run
  workspace. CI recomputes and compares.
- **Rationale:** Any edit to SKILL.md, bundled resources, or the assertions flips the
  hash, forcing a fresh re-run. This is the trust hinge that prevents a stale
  benchmark from passing for a changed skill.
- **Alternatives considered:** hashing SKILL.md only (assertion edits would go
  unverified); no hash (stale benchmarks pass silently).

### D6: All skills in scope; backfill the existing four
- **Choice:** Every skill must carry a passing benchmark, including `audit-docs`,
  `revise-docs`, `init-audience-rules`, `vscode-thinking-display`.
- **Rationale:** Full enforcement from day one; avoids a grandfather list.
  `init-audience-rules` (manual `disable-model-invocation`) is graded on its output
  when run, not on triggering, so functional evals still apply.
- **Alternatives considered:** new-only; new+changed (lighter rollout but leaves
  existing skills unmeasured).

## Risks / Trade-offs

- [Risk] **Author-trust, not tamper-proof** — an author could weaken assertions to
  pass. → Mitigation: `evals.json` is committed and the change is visible in the PR
  diff; reviewers can inspect assertion changes. Documented as an explicit non-goal.
- [Risk] **LLM non-determinism makes a borderline skill flap** around the threshold.
  → Mitigation: absolute pass-rate (no baseline) reduces variance; threshold default
  0.9 leaves headroom; authors can add runs if needed.
- [Trade-off] **CI cannot prove the benchmark was honestly produced**, only that it
  is internally consistent and hash-fresh. → Accepted: the gate raises the quality
  floor and creates a reviewable artifact; full verification would require paid,
  flaky LLM execution in CI.
- [Risk] **Dependency on skill-creator being installed** at author time. → Mitigation:
  the `/`-command checks for it and instructs the contributor to install it; CI does
  not depend on it at all.
- [Trade-off] **Backfilling four skills is upfront work.** → Accepted for full
  enforcement from day one.

## Migration Plan

1. Land the CI script (`scripts/check-skill-gate.mjs`) and `validate.yml` step in a
   **non-blocking / warn** mode first, or land it together with the backfilled
   benchmarks so CI is green on merge.
2. Add `.claude/skill-gate.json` (threshold) and `.gitignore` entry for
   `*-workspace/`.
3. Author `evals.json` + generate `benchmark.json` for all four existing skills.
4. Flip the CI step to blocking once all skills are green.
5. Document in `CONTRIBUTING.md` and CLAUDE.md.

Rollback: remove the `validate.yml` step (and optionally the script + artifacts);
no runtime/deployment surface is affected — this is repo tooling only.

## Open Questions

- Final home/name of the `/`-command: `.claude/commands/skill-gate.md`
  (`/skill-gate <skill-path>`) is the proposed default.
- Whether to record the model id in `benchmark.json` as advisory only (proposed) or
  to also gate on a minimum model tier (not proposed).
- Number of eval runs per test case (single run proposed; authors may increase for
  variance-sensitive skills).
