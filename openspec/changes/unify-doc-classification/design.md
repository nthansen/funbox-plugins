## Context

doc-sweep classifies "what is a doc" in three disagreeing places: the audience-rules prose (the
skills' source of truth), and a verbatim-duplicated `is_doc()` in each of `revise-push-guard.sh`
(the local hook) and `docs-ci-check.sh` (the CI check). The scripts key off a `docMode` enum
(`minimal`/`with-skill`/`default`) hardcoded as bash globs. That set omits `.claude/**/*.md`, which
the audience-rules base explicitly calls Claude-facing docs — so a PR editing only
`.claude/context/audience-rules.md` is scored as "code changed, no docs" and the CI check fails it.
The duplication also guarantees future drift. Constraints from the repo: node is already a hard
dependency ("no jq"); the CI check must stay deterministic and secret-free; `excludeDirs` already
establishes a "persist in audience-rules, mirror into the per-install config JSON" flow the scripts
read via `JSON.parse`; a `uses:`-style shared action was previously rejected on supply-chain grounds
(the CI script is vendored into consumer repos instead).

## Goals / Non-Goals

**Goals**
- One definition of the script-side doc-file-set, fixing the `.claude/**` divergence bug.
- Kill the copy-pasted `is_doc` across the two scripts.
- Keep the classifier deterministic, dependency-free, and unit-testable.
- Preserve the existing `excludeDirs` mechanism rather than invent a parallel one.

**Non-Goals**
- Wiring the skills' runtime to `docPatterns` — they classify by *audience* (Claude vs human) among
  known docs, not doc-vs-non-doc, so there is no `is_doc` to share. They stay prose-driven.
- Changing `[skip docs]` semantics, the merge-base baseline, or the advisory (non-blocking) posture.
- Improving the heuristic's inherent crudeness (it still can't tell whether docs were *warranted*);
  that limitation is acknowledged, not addressed here.

## Decisions

**D1 — Unify up, not simplify down.** Two directions: (A) one shared declarative doc-set + shared
classifier; (B) accept the crude nag and reduce docs to "any `*.md` or `docs/`", deleting `docMode`.
Absent the bug, B would win for a solo repo; the divergence bug tips it to A because the fix and the
unification are the same work.

**D2 — Scope: scripts + shared source; skills untouched at runtime.** Rejected wiring the skills to
read `docPatterns` (forced fit — they don't do doc-vs-non-doc classification, and it would churn
their eval benchmarks). Rejected script-dedupe-only (leaves two definitions). Chosen: a shared
declarative `docPatterns` source + one classifier the scripts consume; skills keep prose rules with a
consistent machine-readable twin.

**D3 — Patterns live in audience-rules, mirrored to the config JSON (no new parser).** Reading
`docPatterns` straight from markdown would need a YAML-in-markdown parser in node. Instead reuse the
established `excludeDirs` flow: `audience-rules.md` is the human-authoritative source that the
install skill reads/writes and **mirrors** into the per-install config JSON; the classifier reads
`docPatterns`/`excludeDirs` from that JSON, else a built-in default. The vendored CI `docs-ci.json`
carries the mirror; funbox's no-config dogfood run uses the built-in default.

**D4 — Hard-retire `docMode`.** The classifier understands only `docPatterns` + the built-in
default. Removed from both scripts, the config schema, and both installers (which now write
`docPatterns`). Alternatives (alias `docMode`→presets; keep both) rejected to avoid perpetuating the
two-ways-to-say-it problem. Accepted breaking edge: a stale config still carrying `docMode` falls
back to the default set until regenerated.

**D5 — node module for classification, bash for git.** git plumbing (merge-base, diff, log,
per-commit `[skip docs]`) stays bash; classification + JSON + glob matching move into one
`doc-classify.mjs` that both scripts shell into once. A tiny in-house glob matcher (`*`, `**`) avoids
any external dependency. Vendored alongside each installed script.

**D6 — Classifier interface.** `doc-classify.mjs` reads a newline-separated file list on stdin,
takes optional `--config <path>`, and emits `{"nonDoc":[…],"docChanged":bool}` on stdout. Config
resolution: `docPatterns`/`excludeDirs` from `--config` JSON if present, else built-in default
(`CLAUDE*.md`, `README*.md`, `CHANGELOG.md`, `docs/**`, `.claude/**/*.md`). The hook additionally
invokes it per-commit for its `[skip docs]` per-commit rule (small ranges, acceptable cost).

## Risks / Trade-offs

- **Stale `docMode` config → default fallback** → acceptable (effectively single-user); installers
  regenerate configs with `docPatterns`.
- **Vendored copies must now ship two files** (`docs-ci-check.sh` + `doc-classify.mjs`) → installers
  copy both; uninstall removes both.
- **In-house glob matcher could mis-handle an exotic pattern** → keep the supported syntax explicit
  (`*` within a segment, `**` across segments, literals) and unit-test the corners; `docPatterns`
  authors stick to that vocabulary.
- **Per-commit classifier calls in the hook loop** → ranges are small; if ever hot, batch later.
- **Heuristic still crude** → unchanged by design; the check stays advisory, `[skip docs]` remains
  the escape hatch.

## Migration Plan

1. Land `doc-classify.mjs` + unit tests; wire the node test into CI.
2. Refactor both scripts to delegate to it; update their shell test suites (incl. an
   audience-rules-only-PR regression that must pass).
3. Add `docPatterns` to the audience-rules; update both install skills to vendor the classifier and
   write `docPatterns` (drop `docMode`); regenerate their eval benchmarks.
4. Update doc-sweep README/CHANGELOG; funbox dogfood already runs no-config → picks up the fixed
   default automatically.
5. Rollback: revert is additive — restore the inline `is_doc` and `docMode` reads; no data migration.

## Open Questions

None blocking. Whether to later expose `docPatterns` to the skills' runtime is deferred (see D2).
