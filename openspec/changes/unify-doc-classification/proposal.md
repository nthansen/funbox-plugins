## Why

"What is a doc?" is defined in three places that disagree: the audience-rules prose (used by the
skills), and a copy-pasted `is_doc()` in each of `revise-push-guard.sh` and `docs-ci-check.sh`. The
scripts classify `.claude/**/*.md` as **non-docs**, but the audience-rules call them docs — so a PR
that edits only `.claude/context/audience-rules.md` (doc-sweep's own canonical doc) **fails** the
docs-staleness check. The duplicated classifier will keep drifting. This change collapses the
script-side definition to a single shared, declarative source.

## What Changes

- **New shared classifier** `plugins/doc-sweep/hooks/doc-classify.mjs` — one node module that,
  given a file list, classifies each path as doc / non-doc / excluded using a `docPatterns` set
  (+ `excludeDirs`) or a built-in default. Contains a small in-house glob matcher (`*`, `**`), no
  external deps; unit-tested.
- **Built-in default doc-set now includes `.claude/**/*.md`** (alongside `CLAUDE*.md`, `README*.md`,
  `CHANGELOG.md`, `docs/**`) — **fixes the divergence bug**.
- **Both scripts become thin git-plumbing wrappers** — `revise-push-guard.sh` and
  `docs-ci-check.sh` drop their duplicated `is_doc`/`docMode`/config-parsing and delegate
  classification to `doc-classify.mjs`. Git logic (merge-base, diff, log, per-commit `[skip docs]`)
  stays in bash.
- **`docMode` is hard-retired** (**BREAKING** for any config still carrying it — it silently falls
  back to the default set until regenerated). Removed from both scripts, the config schema, and both
  install skills, which now record `docPatterns`.
- **`docPatterns` block added to the audience-rules** (base default overlay), co-located with
  `excludeDirs`, as the human-authoritative twin of the prose table; mirrored into the per-install
  config JSON exactly like `excludeDirs` (no new markdown parser).
- **Install skills vendor `doc-classify.mjs`** alongside their script.

Non-goals: wiring the skills' runtime to `docPatterns` (they stay prose-driven; they classify by
audience, not doc-vs-non-doc); changing `[skip docs]` semantics, the merge-base baseline, or the
advisory posture; any LLM-in-CI judgement.

## Capabilities

### New Capabilities
- `doc-classification`: the shared doc/non-doc/excluded classifier — its `docPatterns` +
  `excludeDirs` inputs, the built-in default doc-set (including `.claude/**/*.md`), the glob
  semantics, and the config-resolution order. Owned by `doc-classify.mjs`.

### Modified Capabilities
- `docs-staleness-ci`: the CI check delegates classification to `doc-classification` instead of an
  inline `is_doc`/`docMode`; the installer vendors `doc-classify.mjs` and records `docPatterns`.
- `revise-docs-push-guard`: the hook delegates classification to `doc-classification`; `docMode`
  removed; the installer vendors `doc-classify.mjs` and records `docPatterns`.

## Impact

- **New**: `plugins/doc-sweep/hooks/doc-classify.mjs` + `doc-classify.test.mjs` (node --test).
- **Modified**: `revise-push-guard.sh`, `docs-ci-check.sh` and their shell test suites; both
  install skills (`install-revise-hook`, `install-docs-ci`) SKILL.md + regenerated eval benchmarks;
  `context/audience-rules-base.md` / `audience-rules.md` (add `docPatterns`); doc-sweep
  `README.md`/`CHANGELOG.md`; the two modified capability specs.
- **Validation**: new node test wired into CI (alongside the existing `node --test` suites); scripts
  still pass `bash -n` + ShellCheck; skills must clear `claude plugin validate` + skill-gate.
- No new runtime dependency beyond node (already required); no secrets.
