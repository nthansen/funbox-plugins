# doc-scope-exclusion Specification

## Purpose
Keep documentation review and the doc-staleness guard inside repo boundaries: discover docs
only from tracked files (plus known `*.local.md` twins), and honor a scanned, user-confirmed
`excludeDirs` list — persisted in `.claude/context/audience-rules.md` and mirrored into the
guard hook config — so vendored/external files (committed deps, submodules, build output) are
never treated as first-party repo docs by either `revise-docs` or the push/commit guard.
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

On its first run (or at guard install), the tooling SHALL scan the repository for
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

### Requirement: Guard hook honors the exclusion list

The guard hook SHALL honor the configured `excludeDirs` set when classifying changed files:
a changed file under an excluded directory SHALL NOT count as a non-doc change (so it never
triggers a block) and SHALL NOT count as a satisfying doc change. The exclusion configuration
SHALL be mirrored into the hook's config so the hook applies the same boundaries as
`revise-docs`.

#### Scenario: Vendored source change does not block

- **WHEN** the only change since the marker is to a file under an excluded directory (e.g. `vendor/lib/main.js`)
- **THEN** the hook does not deny the gated command on account of that file

#### Scenario: Vendored README does not count as a doc review

- **WHEN** the changes since the marker are a non-doc first-party file plus an edit to an excluded `vendor/lib/README.md`
- **THEN** the hook still denies (the vendored README does not satisfy the doc requirement)

