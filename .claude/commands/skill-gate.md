---
description: Run a funbox skill through skill-creator's eval engine and write/update its evals/benchmark.json so it clears the quality gate.
argument-hint: <path-to-skill-dir>
---

# /skill-gate

Generate (or refresh) the committed quality-gate artifacts for the skill at
`$ARGUMENTS`. This reuses the installed **skill-creator** engine — it does not
reimplement evaluation.

## Steps

1. **Preflight.** Confirm `skill-creator` (claude-plugins-official) is available
   (its `agents/grader.md` and `scripts/aggregate_benchmark.py` exist). If it is
   not installed, STOP and tell the user to install it — do NOT fabricate a
   benchmark.

2. **Ensure eval inputs.** Read `<skill>/evals/evals.json`. If absent, draft it
   WITH the user: 2-3 realistic prompts plus objectively-checkable assertions
   (skill-creator schema: `skill_name`, optional `threshold`, `evals[]` with
   `id`, `prompt`, `assertions[]`, `files[]`). For manual/`disable-model-invocation`
   skills, write prompts that exercise the skill's OUTPUT when run, not triggering.

3. **Run with-skill (no baseline).** For each eval, run the skill against the
   prompt in a `<skill-name>-workspace/iteration-N/` sibling (gitignored). Grade
   each assertion per skill-creator's `agents/grader.md` (prefer a script for
   programmatically-checkable assertions). Aggregate with
   `python -m scripts.aggregate_benchmark` from the skill-creator dir, or compute
   `pass_rate = passed_assertions / total_assertions` directly.

4. **Write benchmark.** Compute the canonical `source_hash` (see
   `scripts/skill-gate-lib.mjs` — sha256 over skill source incl. evals.json, excl.
   benchmark.json and `*-workspace/`). Write `<skill>/evals/benchmark.json`:
   `{ skill, pass_rate, threshold, model, source_hash, results[] }`, where
   `threshold` is the per-skill override or the repo default in
   `.claude/skill-gate.json`, and `model` is the session model id.

5. **Report.** State pass_rate vs threshold and PASS/FAIL. Remind the user to
   `git add` the `evals/` artifacts (but not the workspace), then run
   `node scripts/check-skill-gate.mjs` to confirm the gate is green.
