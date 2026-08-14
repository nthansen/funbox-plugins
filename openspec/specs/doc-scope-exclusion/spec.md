# doc-scope-exclusion Specification

## Purpose
Keep documentation review inside repo boundaries: `revise-docs` discovers docs only from
tracked files (plus known `*.local.md` twins), and honors a scanned, user-confirmed
`excludeDirs` list persisted in `.claude/context/audience-rules.md` — so vendored/external
files (committed deps, submodules, build output) are never treated as first-party repo docs.
## Requirements
### Requirement: Tracked-only documentation discovery

`revise-docs` SHALL discover documentation files from the set of git-tracked files (e.g. via
`git ls-files`), which inherently excludes `.gitignore`d dependency and build output (such as
`node_modules/`, `dist/`). It SHALL additionally include known gitignored local doc twins by
explicit name check when present on disk — `audience-rules.local.md`, `CLAUDE.local.md`, and
`*.local.md` — and SHALL NOT use a blanket "include all untracked files" rule (which would
re-admit dependency directories). Discovery SHALL exclude any path under a configured
excluded directory.

#### Scenario: Gitignored dependency docs are skipped

- **WHEN** the repository contains a gitignored `node_modules/some-pkg/README.md`
- **THEN** `revise-docs` does not discover or attempt to edit it

#### Scenario: Local doc twin is included

- **WHEN** a gitignored `CLAUDE.local.md` (or `audience-rules.local.md`) exists on disk
- **THEN** `revise-docs` includes it in discovery despite it being untracked

#### Scenario: Committed vendored doc is excluded

- **WHEN** a tracked `vendor/lib/README.md` lives under a configured excluded directory
- **THEN** `revise-docs` does not treat it as a repo doc to update

### Requirement: Scanned and persisted exclusion list

On its first run, `revise-docs` SHALL scan the repository for
likely-vendored directories — git submodules, directories containing a non-root package
manifest, and well-known vendor directory names — and SHALL present the candidates for the
user to confirm. The confirmed set SHALL be persisted as an `excludeDirs` list in the
repository's documentation overlay (`.claude/context/audience-rules.md`), which is tracked
and therefore shared across worktrees. Subsequent runs SHALL read the persisted list
silently without re-prompting. The list SHALL be editable by the user in that file.

#### Scenario: Scan, confirm, persist once

- **WHEN** the tooling runs the first time in a repo with a committed `vendor/` directory and a submodule
- **THEN** it proposes those as exclusion candidates, the user confirms, and an `excludeDirs` list is written to `.claude/context/audience-rules.md`

#### Scenario: Persisted list is reused without prompting

- **WHEN** the tooling runs again and `.claude/context/audience-rules.md` already contains an `excludeDirs` list
- **THEN** it reads the list silently and does not re-prompt for exclusions

