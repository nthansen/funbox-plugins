## ADDED Requirements

### Requirement: Opt-in interactive installer

doc-sweep SHALL provide a manual, model-non-invocable skill that installs the
push-time guard only when a user runs it. The installer SHALL collect, via
interactive prompts, four scoping choices — settings location (user-global vs
project), repo applicability (all repos vs doc-sweep-enabled repos only), the
documentation-file set, and bypass/uninstall — then copy the hook script to a stable,
version-independent path, write the chosen configuration, and merge a `PreToolUse`
hook matching the `Bash` tool into the selected `settings.json`. The merge SHALL be
idempotent and SHALL NOT overwrite unrelated existing hooks.

#### Scenario: Fresh install
- **WHEN** a user runs the installer and selects scoping options
- **THEN** the hook script is copied to a stable absolute path, a config capturing the choices is written, and a `PreToolUse`/`Bash` entry referencing that script is added to the chosen settings.json

#### Scenario: Idempotent re-run
- **WHEN** the installer is run again in a repo/scope that already has the hook installed
- **THEN** it does not duplicate the hook entry and offers to update or uninstall

#### Scenario: Uninstall
- **WHEN** the user chooses uninstall
- **THEN** the `PreToolUse` entry, the copied hook script, and the config are removed, leaving other settings intact

### Requirement: Push-time staleness gate

The installed hook SHALL run on `PreToolUse` for `Bash` calls and SHALL deny a
`git push` if and only if at least one non-documentation file changed in the range
from the last `revise-docs` marker to `HEAD`. When it denies, it SHALL return a reason
instructing the operator to run `revise-docs`, commit any changes, and push again. If
only documentation files (or nothing) changed since the marker, it SHALL allow the
push. A documentation file is one matching the configured doc-file set (default:
`CLAUDE*.md`, `README*.md`, `CHANGELOG.md`, `docs/**`).

#### Scenario: Non-doc change blocks
- **WHEN** a `git push` is attempted and a non-doc file changed since the marker
- **THEN** the hook denies the push with a reason directing the user to run `revise-docs`, commit, then push

#### Scenario: Doc-only change allows
- **WHEN** a `git push` is attempted and only doc-set files changed since the marker
- **THEN** the hook allows the push

#### Scenario: Non-push command ignored
- **WHEN** the Bash command is not a `git push`
- **THEN** the hook allows the call without inspection

### Requirement: Snapshot owned by a guard wrapper, not the base skill

The review snapshot SHALL be recorded by a guard-owned wrapper skill, NOT by
`revise-docs`. The wrapper SHALL invoke the unchanged `doc-sweep:revise-docs` skill and
then write the current `HEAD` commit to a per-clone marker resolved from the
repository's common git directory, including when no documentation changes were needed.
`revise-docs` SHALL remain unmodified and SHALL NOT reference the guard. This marks
history as reviewed up to that commit so the gate can distinguish reviewed from
unreviewed work and a retried push is allowed.

#### Scenario: Base skill is untouched
- **WHEN** the change is implemented
- **THEN** `revise-docs` contains no marker/snapshot step and no reference to the guard or installer; it operates exactly as before

#### Scenario: Wrapper advances the snapshot with no doc changes
- **WHEN** the wrapper runs and `revise-docs` determines no documentation needs updating
- **THEN** the wrapper still records the snapshot at the current HEAD

#### Scenario: Retry after the wrapper is allowed
- **WHEN** a push was denied, the user runs the wrapper (which reviews docs and records the snapshot) and commits any doc changes, and pushes again
- **THEN** the gate finds no non-doc files after the marker and allows the push

### Requirement: Self-skip, bypass, and fail-open

The hook SHALL NOT obstruct work outside its intended scope. When configured for
doc-sweep-enabled repos only, it SHALL allow immediately in a repository lacking
doc-sweep markers (e.g. no `.claude/context/audience-rules.md` or `CLAUDE.md`). It
SHALL allow when the push command carries an explicit bypass token
(`DOC_SWEEP_REVISE_SKIP=1` or `--no-verify`). On any internal error it SHALL fail open
(allow the push) rather than block.

#### Scenario: Unrelated repo is skipped
- **WHEN** repo applicability is "doc-sweep-enabled only" and the current repo has no doc-sweep markers
- **THEN** the hook allows the push without evaluating staleness

#### Scenario: Explicit bypass
- **WHEN** the push command contains `DOC_SWEEP_REVISE_SKIP=1` or `--no-verify`
- **THEN** the hook allows the push

#### Scenario: Internal error fails open
- **WHEN** the hook encounters an internal error (e.g. cannot resolve the marker or run git)
- **THEN** it allows the push and emits a non-blocking note rather than denying

### Requirement: No default activation

The guard SHALL NOT change any behavior until a user explicitly installs it. Merely
installing the doc-sweep plugin SHALL NOT register the hook, and the `revise-docs`
marker write SHALL be inert (harmless) when no hook is installed.

#### Scenario: Plugin install alone is inert
- **WHEN** doc-sweep is installed but the installer skill has not been run
- **THEN** no `PreToolUse` hook is registered and `git push` is never gated
