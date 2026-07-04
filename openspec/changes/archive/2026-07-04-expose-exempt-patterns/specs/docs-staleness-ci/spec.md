## MODIFIED Requirements

### Requirement: Manual installer skill scaffolds the workflow

doc-sweep SHALL provide a manual, model-non-invocable skill (`install-docs-ci`,
`disable-model-invocation: true`, with scoped `allowed-tools`) that installs the check only when
a user runs it, mirroring the `install-revise-hook` pattern. On a **fresh install** it SHALL
scaffold a GitHub Actions workflow file into the target repository's `.github/workflows/` that
invokes the doc-sweep-shipped check script on `pull_request`, vendor **both** the check script and
the shared `doc-classify.mjs` module under `.github/doc-sweep/`, collect the documentation-file set
(recorded as `docPatterns`, NOT the retired `docMode`), any excluded directories, and an
**exempt-set choice** — either the built-in default test globs (in which case `exemptPatterns` is
omitted so the classifier's built-in default applies) or **add-extras**, in which case the installer
SHALL record `exemptPatterns` as the concatenation of the built-in default test globs (sourced from
the documented default in `.claude/context/audience-rules.md`) and the user's additional globs, and
persist that list into `.claude/context/audience-rules.md` the same way `docPatterns`/`excludeDirs`
are persisted. It SHALL print a structured summary: the workflow path, the doc-set, the exempt-set,
the ack tokens, that blocking is the maintainer's branch-protection choice, and how to reconfigure or
uninstall by re-running the skill. When an install already exists it SHALL offer
Reconfigure / Uninstall / Cancel and SHALL be idempotent (it SHALL NOT duplicate the workflow).
Uninstall SHALL remove the workflow, the vendored check script, and the vendored `doc-classify.mjs`.
Nothing SHALL be installed until the user runs the skill and confirms.

#### Scenario: Fresh install scaffolds, vendors the classifier, and summarizes

- **WHEN** a user runs the installer and confirms scoping choices
- **THEN** a `pull_request` workflow is written to `.github/workflows/`, both the check script and `doc-classify.mjs` are vendored under `.github/doc-sweep/`, a config recording `docPatterns` (not `docMode`) is written, and a structured summary with reconfigure/uninstall instructions is printed

#### Scenario: Default exempt-set omits exemptPatterns

- **WHEN** the user keeps the default exempt-set (built-in test globs)
- **THEN** the written config omits `exemptPatterns` entirely, so the classifier's built-in default applies

#### Scenario: Add-extras records built-in tests plus the additions

- **WHEN** the user chooses to add extra exempt globs (e.g. a lockfile or generated directory)
- **THEN** the written config records `exemptPatterns` as the built-in default test globs followed by the user's additions, and the same list is persisted into `.claude/context/audience-rules.md`

#### Scenario: Idempotent re-run

- **WHEN** the installer is run again in a repo that already has the workflow
- **THEN** it does not duplicate the workflow and offers Reconfigure / Uninstall / Cancel

#### Scenario: Uninstall removes the vendored classifier too

- **WHEN** the user chooses uninstall
- **THEN** the scaffolded workflow, the vendored check script, and the vendored `doc-classify.mjs` are all removed, leaving other workflows and settings intact

#### Scenario: Plugin install alone is inert

- **WHEN** doc-sweep is installed but the installer skill has not been run
- **THEN** no workflow is scaffolded and no pull request is gated
