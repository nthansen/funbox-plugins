## ADDED Requirements

### Requirement: Deterministic PR-time staleness check

doc-sweep SHALL provide a deterministic, no-LLM, no-secret check that runs on a pull request
and evaluates documentation staleness against the **merge base** of the PR (no committed marker
or persisted state). The check SHALL classify each file changed between the merge base and the
PR head as a documentation file or a non-documentation file using the configured doc-file set
(default: `CLAUDE*.md`, `README*.md`, `CHANGELOG.md`, `docs/**`); files under configured
excluded directories SHALL be ignored entirely (neither doc nor non-doc). The check SHALL
**fail** if and only if at least one non-doc, non-excluded file changed, no doc file changed,
and no acknowledgment is present. Otherwise it SHALL **pass**. When it fails, it SHALL emit a
message that names the offending non-doc paths and states every way to clear it (update docs, or
add a `[skip docs]` line to any commit message in the PR range or to the PR body). The check SHALL parse the
event/diff with `node` (not `jq`), and SHALL be self-contained in a doc-sweep-shipped script.

#### Scenario: Code-only change fails

- **WHEN** a PR changes at least one non-doc, non-excluded file, changes no doc file, and carries no acknowledgment
- **THEN** the check fails and names the offending non-doc paths and the ways to clear it

#### Scenario: Code plus docs passes

- **WHEN** a PR changes non-doc files and also changes at least one doc-set file
- **THEN** the check passes with no acknowledgment required

#### Scenario: Docs-only change passes

- **WHEN** a PR changes only doc-set files (or only excluded files)
- **THEN** the check passes

#### Scenario: Excluded paths are ignored

- **WHEN** a PR changes only files under a configured excluded directory
- **THEN** those files count as neither doc nor non-doc and the check passes

### Requirement: Shared acknowledgment token

The check SHALL treat a pull request as acknowledged — and pass despite a code-only diff — when
any one of the following is present: a `[skip docs]` token in any commit message within the PR
range; a `[skip docs]` token in the pull request body; or an actual doc-set change (implicit
pass). The commit-message form and the PR-body form SHALL be equivalent so that an author who
forgot to include the token in a commit can clear the check by editing the PR body without
rewriting git history. `[skip docs]` (chosen to mirror the familiar `[skip ci]` convention) SHALL
be the single acknowledgment token shared with the local `revise-docs-push-guard` hook.

#### Scenario: Commit-message ack passes

- **WHEN** a PR has a code-only diff and any commit message in range contains `[skip docs]`
- **THEN** the check passes

#### Scenario: PR-body ack passes

- **WHEN** a PR has a code-only diff, no `[skip docs]` in any commit message, but the PR body contains `[skip docs]`
- **THEN** the check passes

#### Scenario: Ack token is shared with the hook

- **WHEN** the acknowledgment token is defined
- **THEN** it is the same `[skip docs]` token the local push-guard hook recognizes, so both guards share one language

### Requirement: Manual installer skill scaffolds the workflow

doc-sweep SHALL provide a manual, model-non-invocable skill (`install-docs-ci`,
`disable-model-invocation: true`, with scoped `allowed-tools`) that installs the check only when
a user runs it, mirroring the `install-revise-hook` pattern. On a **fresh install** it SHALL
scaffold a GitHub Actions workflow file into the target repository's `.github/workflows/` that
invokes the doc-sweep-shipped check script on `pull_request`, collect the doc-file set and any
excluded directories, and print a structured summary: the workflow path, the doc-set, the ack
tokens, that blocking is the maintainer's branch-protection choice, and how to reconfigure or
uninstall by re-running the skill. When an install already exists it SHALL offer
Reconfigure / Uninstall / Cancel and SHALL be idempotent (it SHALL NOT duplicate the workflow).
Nothing SHALL be installed until the user runs the skill and confirms.

#### Scenario: Fresh install scaffolds and summarizes

- **WHEN** a user runs the installer and confirms scoping choices
- **THEN** a `pull_request` workflow calling the shipped check script is written to `.github/workflows/`, and a structured summary with reconfigure/uninstall instructions is printed

#### Scenario: Idempotent re-run

- **WHEN** the installer is run again in a repo that already has the workflow
- **THEN** it does not duplicate the workflow and offers Reconfigure / Uninstall / Cancel

#### Scenario: Uninstall

- **WHEN** the user chooses uninstall
- **THEN** the scaffolded workflow file is removed, leaving other workflows and settings intact

#### Scenario: Plugin install alone is inert

- **WHEN** doc-sweep is installed but the installer skill has not been run
- **THEN** no workflow is scaffolded and no pull request is gated
