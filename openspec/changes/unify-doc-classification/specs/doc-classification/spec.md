## ADDED Requirements

### Requirement: Single shared classifier module

doc-sweep SHALL provide a single node module (`doc-classify.mjs`) that classifies a list of file
paths into documentation, non-documentation, and excluded, and SHALL be the **sole** doc/non-doc
classifier used by both the docs-staleness CI check and the revise-docs push-guard hook (neither
SHALL carry its own inline classification logic). The module SHALL read a newline-separated list of
file paths on stdin, accept an optional `--config <path>` argument, and emit on stdout a JSON object
`{ "nonDoc": [<paths>], "docChanged": <boolean> }` where `nonDoc` lists the changed non-doc,
non-excluded paths and `docChanged` is true iff at least one changed path is a documentation file.
The module SHALL have no external (non-builtin) dependencies and SHALL parse JSON with node.

#### Scenario: Both scripts delegate to the module

- **WHEN** the CI check or the push-guard hook needs to classify changed files
- **THEN** it pipes the file list to `doc-classify.mjs` and acts on the returned `nonDoc`/`docChanged` result, rather than applying its own inline doc/non-doc patterns

#### Scenario: Output shape

- **WHEN** the module is given a mix of doc, non-doc, and excluded paths
- **THEN** it emits `{ "nonDoc": [...only the non-doc non-excluded paths...], "docChanged": true|false }` as JSON on stdout

### Requirement: Built-in default doc-set includes `.claude/**`

When no `docPatterns` is configured, the module SHALL treat a path as a documentation file iff it
matches the built-in default set: `CLAUDE*.md`, `README*.md`, `CHANGELOG.md`, `docs/**`, and
`.claude/**/*.md` (at any directory depth). This default SHALL be consistent with the audience-rules
base, under which all `*.md` files beneath `.claude/` are Claude-facing documentation.

#### Scenario: A .claude markdown change counts as a doc

- **WHEN** the only changed path is `.claude/context/audience-rules.md` and no `docPatterns` override is configured
- **THEN** the module classifies it as a documentation file (`docChanged` true, `nonDoc` empty)

#### Scenario: Default doc globs

- **WHEN** the changed set is `README.md`, `docs/api/x.md`, and `CHANGELOG.md` with no override
- **THEN** all three classify as documentation and `nonDoc` is empty

### Requirement: Configurable patterns and glob semantics

The module SHALL resolve `docPatterns` and `excludeDirs` from the `--config` JSON when present,
otherwise from the built-in default (`excludeDirs` defaulting to empty). Glob matching SHALL support
`*` (matches within a single path segment) and `**` (matches across segments), plus literal
segments. A path under any `excludeDirs` entry (the entry itself or a descendant) SHALL be treated as
**excluded** — neither documentation nor non-documentation — and SHALL NOT appear in `nonDoc` nor set
`docChanged`.

#### Scenario: docPatterns override replaces the default

- **WHEN** the config sets `docPatterns` to `["docs/**"]` and the changed set is `README.md` and `docs/x.md`
- **THEN** only `docs/x.md` is a doc; `README.md` is non-doc (the default globs no longer apply)

#### Scenario: Excluded directory is ignored

- **WHEN** the config sets `excludeDirs` to `["vendor"]` and the changed set is `vendor/lib/a.js` and `vendor/lib/README.md`
- **THEN** both paths are excluded — `nonDoc` is empty and `docChanged` is false

#### Scenario: `**` spans directories

- **WHEN** `docPatterns` contains `.claude/**/*.md` and the changed path is `.claude/context/audience-rules.md`
- **THEN** the path matches and classifies as documentation
