# Retrospective — unify-doc-classification

## §0 Evidence

- **Commits:** 15 on branch (`178c249..HEAD`); 2 propose, 13 implementation/fix/docs.
- **Diff size:** 25 files, +1591 / −345; ~16 non-artifact files touched.
- **Tasks:** 19/19 `[x]`.
- **Subagents dispatched:** ~19 — 6 implementers, 4 fix subagents, 6 per-task adversarial reviewers,
  1 final whole-branch adversarial review (opus), 2 benchmark eval-runners.
- **New external dependencies:** 0 (classifier is `node:` builtins only).
- **OpenSpec validate at archive:** 5/5 strict pass.
- **Test coverage signal:** `doc-classify.test.mjs` 13 cases; `test-docs-ci-check.sh` + 
  `test-revise-push-guard.sh` shell suites; both install-skill benchmarks 1.0 (18/18, 19/19).
- **Post-merge bugs:** n/a (pre-merge).
- **Commit chain:** propose → exempt fold-in → classifier → 2 script refactors (+2 fixes) →
  docMode retire/audience-rules → installers (+fix) → benchmarks → CI/docs → final-review fixes.

## §1 Wins

- **The adversarial reviews earned their cost.** Three real defects were caught that all-green tests
  missed: the merge-commit `[skip docs]` bypass (`09d7491`), the unguarded downstream JSON parse that
  silently masked bad classifier output (`72f6b14`), and the install-reconfigure path leaving the
  vendored classifier missing → permanent silent fail-open (`5f94af9`). None had a failing test
  before review; each got one after.
- **The originating bug is fixed and regression-locked:** `.claude/**/*.md` now classifies as docs in
  both guards, with tests in all three suites.
- **Single source of truth achieved:** one `doc-classify.mjs`, one default set, consumed identically
  by both guards (final review confirmed no divergence in invocation or parsing).
- **Scope expansion handled cleanly:** the user's mid-apply `exemptPatterns` idea was folded into the
  design (brainstorm Q6, D7) before any code, not bolted on.

## §2 Misses

- 🟡 **Two script refactors (Tasks 2, 3) both needed fix rounds** for robustness gaps the plan's
  example code carried (unquoted `$cfg_arg`, unguarded parse, merge-commit diff-tree). The plan
  transcribed working-but-fragile snippets; the adversarial reviews are what caught them.
- 📌 **Doc/code drift appeared twice** (audience-rules exempt list missing go/py globs → `c0f5b33`;
  README/CHANGELOG claiming `exemptPatterns` is installer-configurable → `d66e650`) — ironic for a
  change whose whole point is killing drift. Both caught (controller + final review) and fixed.
- 📌 **One eval assertion was miswritten** (required `docPatterns` for the default choice, which the
  skill correctly omits) — caught during benchmark regen, corrected.

## §3 Plan deviations

- Task 2 rewrote a pre-existing `docMode:minimal` test to its `docPatterns` equivalent (docMode
  retired) — a necessary, disclosed deviation.
- Fix rounds added tests/behavior beyond the plan (merge-commit handling, JSON-parse guard,
  trailing-slash normalization, empty-config fallback, reconfigure re-copy) — all from adversarial
  findings, all net improvements to the plan's baseline.

## §4 Skill / workflow compliance

Apply-phase skills for the superpowers-bridge schema:
- `using-git-worktrees` — ✓ (Step 0 detection: already on the dedicated feature branch; worked in
  place to preserve the schema's "complete cycle in one PR" property — a legitimate work-in-place path).
- `subagent-driven-development` — ✓ (fresh implementer per task, per-task review, final review).
- `test-driven-development` (transitive) — ✓ (each task added failing tests first).
- `requesting-code-review` (transitive) — ✓ (per-task + final whole-branch review; made explicitly
  adversarial per user directive).
- `finishing-a-development-branch` — ✓ (PR step).

### Deliberately Skipped Skills
None. Every apply-phase skill was used.

## §5 Surprises

- **The local grep crashes on `grep -F '[skip docs]'`** (SIGABRT) on this Windows Git Bash — surfaced
  in the *prior* change and honored here by keeping all matching in `node`. A reminder that "it's just
  a grep" isn't portable.
- **The plan's own example code was the main defect source**, not misunderstanding — the reviewers
  found fragility in code the plan handed the implementers verbatim. Adversarial review of
  plan-mandated code is worth it even when implementers transcribe faithfully.

## §6 Promote candidates → long-term learning

- [ ] 📌 Plan example code is a starting point, not vetted — adversarially review plan-mandated
  snippets, not just implementer output.
  → **Promote to** CLAUDE.md / schema note
  > **Why**: 3 of 4 fix rounds this cycle addressed fragility in code the plan supplied verbatim.
  > **How to apply**: when a plan hands complete code, the per-task review should probe that code's
  > edge cases (quoting, error paths, merge/edge git behavior), not assume the plan vetted them.
- [ ] 📌 A "kill the drift" change is itself drift-prone — check doc↔code↔spec default lists match
  exactly before closing.
  > **Why**: two doc/code drifts appeared in this very change.
  > **How to apply**: when a change centralizes a default (a pattern list, a config schema), grep the
  > default across code, bundled docs, README, and specs as an explicit verify step.
