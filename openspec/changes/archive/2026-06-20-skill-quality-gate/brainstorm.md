<!--
Raw capture of superpowers:brainstorming output.
Decision log: background → decision chain Q1-Q6 → design trade-offs.
design.md reorganizes this into structured sections; do not duplicate.
-->

# Brainstorm — skill quality gate

## Background

The user wants a **quality gate**: any new skill should be run "through skill
creator," passing its "auditing mechanism with a threshold," before it counts as
acceptable in the funbox marketplace repo.

### What "skill-creator's auditing mechanism" actually is (research finding)

skill-creator (`claude-plugins-official`) is **not** a single audit score. It is
mostly an interactive, human-in-the-loop iteration loop (draft → run test cases
with/without skill → human reviews in a browser viewer → improve → repeat). The
pieces that could act as a "threshold gate" are three *different* things:

1. **`quick_validate.py`** — pure structural lint (frontmatter keys, kebab-case
   name, description length / no angle brackets). Deterministic, no LLM, fast,
   but binary pass/fail, not a tunable threshold.
2. **Description trigger-accuracy** (`run_loop.py` / `run_eval.py`) — runs
   should-/shouldn't-trigger queries and produces a numeric trigger accuracy
   (train/test %). The one mechanism that genuinely has a "score + threshold,"
   but needs hand-authored eval queries per skill and many `claude -p` runs.
3. **Functional eval pass-rate** (`agents/grader.md` + `aggregate_benchmark.py`)
   — needs hand-written test cases AND assertions per skill, LLM-graded,
   produces `pass_rate` per configuration.

A fourth option skill-creator does not ship: a rubric-based LLM grade of SKILL.md
(single 0–10). Considered, not chosen.

### Anti-reinvention research (key finding)

- **skill-creator already provides the entire functional-eval engine**:
  `run_eval.py` (runs the skill on a prompt), `agents/grader.md` (grades
  assertions), `aggregate_benchmark.py` (produces `pass_rate`). Do NOT rebuild.
- **plugin-dev** ships a `skill-reviewer` agent and a `plugin-validator` agent,
  but those are *qualitative rubric reviews* ("Pass / Needs Improvement" rating)
  with no numeric threshold and no execution — not the chosen mechanism.
- What exists nowhere: a **threshold gate** (pass_rate ≥ T → block/allow), a
  **CI freshness check** (verify a committed benchmark matches the current
  skill), and the **glue** wiring this into funbox's add-a-skill flow.

### Hard constraint

funbox CI runs on GitHub Actions with no Anthropic auth. Anything LLM-based
(trigger eval, functional eval, rubric grade) **cannot run in plain CI** without
secrets/cost/flakiness — only the deterministic structural checks can.

## Decision chain

**Q1 — What should the gate measure?**
→ **Functional eval pass-rate ≥ threshold** (test cases + assertions, graded).
Chosen over rubric grade, structural lint, and trigger-accuracy. The most
rigorous option.

**Q2 — Where/when does the gate run, given it needs an LLM?**
→ **Author-time skill + CI artifact check.** A `/`-command runs evals locally
(subagents), writes a committed benchmark; CI stays deterministic — it only
verifies the artifact exists, is fresh (hash of skill source matches), and
pass_rate ≥ threshold. Rejected: author-time-only (advisory, no enforcement) and
full execution in GitHub Actions (token cost, flaky, paid dependency on a public
repo).

**Q3 — What is the pass criterion?**
→ **Absolute pass-rate ≥ T.** With-skill assertion pass-rate must hit the
threshold; baseline (no-skill) runs are skipped. Rejected: must-beat-baseline by
margin (doubles cost, noisy) and both (most expensive, flakiest). Matches the
user's "pass a threshold" framing.

**Q4 — Packaging: internal tooling or shipped plugin?**
→ User flagged "ensure we aren't reinventing the wheel before deciding" →
triggered the anti-reinvention research above → resolved to **repo-internal
tooling that reuses skill-creator's engine.** Rejected: vendoring skill-creator's
scripts into funbox (duplicates code that drifts) and a new shipped "skill-gate"
plugin (heaviest; needs README/CHANGELOG/scoped tools + cross-marketplace
allowlist entry).

**Q5 — Scope: which skills, and the existing 4?**
→ **All skills, backfill now.** Every skill in funbox must carry a passing
committed benchmark, including the existing four (`audit-docs`, `revise-docs`,
`init-audience-rules`, `vscode-thinking-display`). Rejected: new-only and
new+changed. `init-audience-rules` is `disable-model-invocation` (manual
`/`-command) — graded on its *output when run*, not triggering, so functional
evals still apply.

**Q6 — Proposed defaults (approved):**
→ Threshold **0.9**, set repo-wide in `.claude/skill-gate.json` with optional
per-skill override in `evals.json`. Artifacts committed under `evals/` per skill.
No baseline runs. Runs use the session model id, recorded in benchmark.json.

## Design trade-offs

- **Decoupling LLM work from CI** is the central architectural move: expensive,
  non-deterministic evaluation happens locally at author time and is frozen into
  a committed artifact; CI does only cheap, deterministic verification.
- **The freshness hash is the trust hinge.** `source_hash` = sha256 over the
  skill's source files *including* `evals/evals.json`, *excluding* `benchmark.json`
  and the run workspace. Any edit to SKILL.md, bundled scripts/references, or the
  assertions flips the hash → CI demands a fresh re-run. Without this, a stale
  benchmark could pass for a changed skill.
- **Explicit non-goal / honest limitation:** because CI can't re-run the LLM, the
  gate is **author-trust**, not adversarial-proof — an author could weaken
  assertions to pass (visible in the committed `evals.json` diff). The gate raises
  the floor and produces a reviewable quality artifact; it does not guarantee
  correctness against a malicious author.
- **Separation of concerns:** `validate-marketplace.mjs` stays the *policy* layer;
  the new `check-skill-gate.mjs` is the *quality* layer — a distinct CI step.
