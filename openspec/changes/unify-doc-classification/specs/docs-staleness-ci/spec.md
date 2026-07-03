## MODIFIED Requirements

### Requirement: Deterministic PR-time staleness check

doc-sweep SHALL provide a deterministic, no-LLM, no-secret check that runs on a pull request
and evaluates documentation staleness against the **merge base** of the PR (no committed marker
or persisted state). The check SHALL delegate classification of each file changed between the merge
base and the PR head to the shared `doc-classification` module (`doc-classify.mjs`) — it SHALL NOT
carry its own inline doc/non-doc patterns. Files under configured excluded directories are ignored
entirely (neither doc nor non-doc), per that module. The check SHALL **fail** if and only if at least
one non-doc, non-excluded file changed, no doc file changed, and no acknowledgment is present.
Otherwise it SHALL **pass**. When it fails, it SHALL emit a message that names the offending non-doc
paths and states every way to clear it (update docs, or add a `[skip docs]` line to any commit
message in the PR range or to the PR body). The check SHALL parse the event/diff with `node` (not
`jq`), and SHALL be self-contained in a doc-sweep-shipped script paired with the vendored
`doc-classify.mjs`.

#### Scenario: Code-only change fails

- **WHEN** a PR changes at least one non-doc, non-excluded file, changes no doc file, and carries no acknowledgment
- **THEN** the check fails and names the offending non-doc paths and the ways to clear it

#### Scenario: Code plus docs passes

- **WHEN** a PR changes non-doc files and also changes at least one doc-set file
- **THEN** the check passes with no acknowledgment required

#### Scenario: Docs-only change passes

- **WHEN** a PR changes only doc-set files (or only excluded files)
- **THEN** the check passes

#### Scenario: A .claude doc change satisfies the check

- **WHEN** a PR changes a non-doc file and also changes `.claude/context/audience-rules.md`
- **THEN** the shared classifier counts the `.claude/**/*.md` change as a doc and the check passes

#### Scenario: Test-only change passes without an ack

- **WHEN** a PR changes only files matching the shared classifier's `exemptPatterns` (e.g. `**/*.test.*`) and no doc-requiring file
- **THEN** the classifier returns an empty `nonDoc` and the check passes with no acknowledgment required

#### Scenario: Excluded paths are ignored

- **WHEN** a PR changes only files under a configured excluded directory
- **THEN** those files count as neither doc nor non-doc and the check passes

### Requirement: Manual installer skill scaffolds the workflow

doc-sweep SHALL provide a manual, model-non-invocable skill (`install-docs-ci`,
`disable-model-invocation: true`, with scoped `allowed-tools`) that installs the check only when
a user runs it, mirroring the `install-revise-hook` pattern. On a **fresh install** it SHALL
scaffold a GitHub Actions workflow file into the target repository's `.github/workflows/` that
invokes the doc-sweep-shipped check script on `pull_request`, vendor **both** the check script and
the shared `doc-classify.mjs` module under `.github/doc-sweep/`, collect the documentation-file set
(recorded as `docPatterns`, NOT the retired `docMode`) and any excluded directories, and print a
structured summary: the workflow path, the doc-set, the ack tokens, that blocking is the maintainer's
branch-protection choice, and how to reconfigure or uninstall by re-running the skill. When an
install already exists it SHALL offer Reconfigure / Uninstall / Cancel and SHALL be idempotent (it
SHALL NOT duplicate the workflow). Uninstall SHALL remove the workflow, the vendored check script,
and the vendored `doc-classify.mjs`. Nothing SHALL be installed until the user runs the skill and
confirms.

#### Scenario: Fresh install scaffolds, vendors the classifier, and summarizes

- **WHEN** a user runs the installer and confirms scoping choices
- **THEN** a `pull_request` workflow is written to `.github/workflows/`, both the check script and `doc-classify.mjs` are vendored under `.github/doc-sweep/`, a config recording `docPatterns` (not `docMode`) is written, and a structured summary with reconfigure/uninstall instructions is printed

#### Scenario: Idempotent re-run

- **WHEN** the installer is run again in a repo that already has the workflow
- **THEN** it does not duplicate the workflow and offers Reconfigure / Uninstall / Cancel

#### Scenario: Uninstall removes the vendored classifier too

- **WHEN** the user chooses uninstall
- **THEN** the scaffolded workflow, the vendored check script, and the vendored `doc-classify.mjs` are all removed, leaving other workflows and settings intact

#### Scenario: Plugin install alone is inert

- **WHEN** doc-sweep is installed but the installer skill has not been run
- **THEN** no workflow is scaffolded and no pull request is gated
