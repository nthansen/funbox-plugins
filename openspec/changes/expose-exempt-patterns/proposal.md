## Why

The `doc-classification` classifier already reads `exemptPatterns` from its config, but neither
installer exposes it — so a project that wants to exempt more than the built-in test globs (e.g.
lockfiles, generated dirs) must hand-edit the per-install config JSON. The bundled docs even state
`exemptPatterns` is "not currently exposed as an installer choice." This change makes it a
first-class installer choice, mirroring the existing `docPatterns` (doc-file-set) UX.

## What Changes

- **Both installers gain an exempt-set choice** (`install-docs-ci`, `install-revise-hook`),
  collected alongside the existing doc-file-set question:
  - **default** → omit `exemptPatterns` from the config JSON (the classifier's built-in test globs
    apply) — exactly like the `docPatterns` default.
  - **add extras** → the installer writes `exemptPatterns` = **(built-in test globs + the user's
    additional globs)** as one concrete list into the config JSON *and* persists it to
    `.claude/context/audience-rules.md`, the same way custom `docPatterns`/`excludeDirs` are
    persisted. The classifier's "a non-empty list replaces the default" semantics then apply to the
    full list, so the user keeps the tests **and** their extras without re-typing the test globs.
  - The installer sources the built-in test globs from the documented default list in
    `audience-rules.md` (single source — no re-hardcoding).
- **No classifier change** — `doc-classify.mjs` already supports `exemptPatterns`; this is purely an
  installer + docs surface change.
- **Docs flip** — the `audience-rules.md`, README, and CHANGELOG lines that say `exemptPatterns` is
  not installer-configurable are updated to describe the new choice.

Non-goals: changing classifier semantics or the built-in default exempt set; adding named exempt
presets; exposing `exemptPatterns` anywhere other than the two installers.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `docs-staleness-ci`: the `install-docs-ci` skill now also collects an `exemptPatterns` choice
  (default vs add-extras) and records it in the vendored config, mirroring the `docPatterns` flow.
- `revise-docs-push-guard`: the `install-revise-hook` skill now also collects an `exemptPatterns`
  choice and records it, mirroring the `docPatterns` flow.

## Impact

- **Modified**: both install `SKILL.md` + their `evals/evals.json` (new assertion) + regenerated
  `evals/benchmark.json`; `plugins/doc-sweep/context/audience-rules.md`,
  `plugins/doc-sweep/README.md`, `plugins/doc-sweep/CHANGELOG.md`; the two modified capability specs.
- **Unchanged**: `doc-classify.mjs` and its tests; the guard scripts.
- **Validation**: skills must pass `claude plugin validate` + the skill-gate (regenerated benchmarks
  ≥ 0.9); marketplace policy; `openspec validate --strict --all`.
