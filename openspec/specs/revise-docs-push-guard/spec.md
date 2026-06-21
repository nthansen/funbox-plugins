# revise-docs-push-guard Specification

## Purpose
Give doc-sweep an opt-in, Claude-aware guard that blocks a `git push` when documentation
looks stale — a non-doc file changed since docs were last reviewed — and prompts running
the review-and-snapshot wrapper (`revise-docs-and-mark`) first, so doc updates land in the
same push. The snapshot mechanism is owned entirely by the guard; the base `revise-docs`
skill is untouched. The hook is deterministic, fails open, and parses JSON with `node`
(no `jq`); only Claude-driven pushes are gated.
## Requirements
### Requirement: Opt-in interactive installer

doc-sweep SHALL provide a manual, model-non-invocable skill that installs the guard only
when a user runs it. On a **fresh install** the installer SHALL collect, via interactive
prompts: settings location (user-global vs project), repo applicability (all repos vs
doc-sweep-enabled only), the documentation-file set, the **trigger event** (exactly one of
`push` or `commit`, with `push` recommended as default), and bypass/uninstall confirmation.
It SHALL then copy the hook script to a stable, version-independent path, write the chosen
configuration (including `trigger`), and merge an idempotent `PreToolUse`/`Bash` hook into
the selected `settings.json` without overwriting unrelated hooks. After writing the hook the
installer SHALL offer to seed the review marker — seed `HEAD` now (reported as an assumption,
with no review performed), run `revise-docs-and-mark` now, or leave it unseeded with a
warning that the next guarded action will block. The installer SHALL finally print a
structured summary: the settings/hook/config paths, the trigger, doc-set, repo scope, marker
state, behavior caveats (only Claude-driven git is gated, `node` is required, the hook fails
open), the bypass tokens, and how to edit or uninstall by re-running the skill. When an
install already exists, the installer SHALL offer Reconfigure / Uninstall / Cancel;
Reconfigure SHALL re-ask the choices pre-filled with the current config, rewrite the config
(and the matcher only if the hook path changed), and leave the marker untouched.

#### Scenario: Fresh install seeds and summarizes

- **WHEN** a user runs the installer, selects scoping options including a trigger, and chooses to seed the marker
- **THEN** the hook is copied to a stable path, a config capturing the choices (including `trigger`) is written, a `PreToolUse`/`Bash` entry is added, the marker is set to HEAD, and a structured summary with edit/uninstall instructions is printed

#### Scenario: Trigger is chosen at install

- **WHEN** the user selects `commit` as the trigger
- **THEN** the written config records `trigger: "commit"` and the summary reports that commit (not push) is gated

#### Scenario: Reconfigure an existing install

- **WHEN** the installer detects an existing install and the user chooses Reconfigure
- **THEN** it re-asks the choices pre-filled, rewrites the config, leaves the review marker unchanged, and prints the updated summary

#### Scenario: Idempotent re-run

- **WHEN** the installer is run again in a repo/scope that already has the hook installed
- **THEN** it does not duplicate the hook entry and offers Reconfigure / Uninstall / Cancel

#### Scenario: Uninstall

- **WHEN** the user chooses uninstall
- **THEN** the `PreToolUse` entry, the copied hook script, and the config are removed, leaving other settings and the marker file intact

### Requirement: Snapshot owned by a guard wrapper, not the base skill

The review snapshot SHALL be recorded by a guard-owned wrapper skill, NOT by `revise-docs`.
The wrapper SHALL invoke the unchanged `doc-sweep:revise-docs` skill, then make **exactly one
commit** of all resulting documentation changes (CLAUDE.md and README updates together),
and then write the current `HEAD` commit to a per-clone marker resolved from the repository's
common git directory — including when no documentation changes were needed (in which case no
commit is made but the marker is still advanced). `revise-docs` and the delegated
`claude-md-management:revise-claude-md` command SHALL remain edit-only and SHALL NOT commit;
`revise-docs` SHALL NOT reference the guard. This marks history as reviewed up to that commit
so the gate can distinguish reviewed from unreviewed work and a retried command is allowed.

#### Scenario: Base skill is untouched

- **WHEN** the change is implemented
- **THEN** `revise-docs` contains no marker/snapshot or commit step and no reference to the guard or installer

#### Scenario: One commit per review

- **WHEN** the wrapper runs and `revise-docs` updates multiple documentation files
- **THEN** the wrapper records all of them in a single commit, then advances the marker to HEAD

#### Scenario: Wrapper advances the snapshot with no doc changes

- **WHEN** the wrapper runs and `revise-docs` determines no documentation needs updating
- **THEN** the wrapper makes no commit but still records the snapshot at the current HEAD

#### Scenario: Retry after the wrapper is allowed

- **WHEN** a command was denied, the user runs the wrapper (which reviews docs, commits once, and records the snapshot), and retries
- **THEN** the gate finds no non-doc files after the marker and allows the command

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

### Requirement: Configurable staleness gate

The installed hook SHALL run on `PreToolUse` for `Bash` calls and SHALL gate the git
subcommand named by its configured `trigger` (`push` default, or `commit`). It SHALL deny
the gated command if and only if at least one non-documentation file changed in the range
from the last `revise-docs` marker to `HEAD`. When it denies, it SHALL return a reason that
names the gated verb and instructs the operator to run `revise-docs-and-mark`, commit any
changes, and retry. If only documentation files (or nothing) changed since the marker, it
SHALL allow the command. A documentation file is one matching the configured doc-file set
(default: `CLAUDE*.md`, `README*.md`, `CHANGELOG.md`, `docs/**`); files under configured
excluded directories SHALL be treated as neither doc nor non-doc (ignored entirely). A
command that is not the configured trigger SHALL be allowed without inspection.

#### Scenario: Non-doc change blocks the configured trigger

- **WHEN** the configured trigger command is attempted and a non-doc, non-excluded file changed since the marker
- **THEN** the hook denies it with a reason naming the gated verb and directing the user to run `revise-docs-and-mark`, commit, then retry

#### Scenario: Doc-only change allows

- **WHEN** the configured trigger command is attempted and only doc-set files changed since the marker
- **THEN** the hook allows it

#### Scenario: Commit trigger ignores push

- **WHEN** the configured trigger is `commit` and the Bash command is a `git push`
- **THEN** the hook allows the call without inspection

#### Scenario: Non-trigger command ignored

- **WHEN** the Bash command is not the configured trigger subcommand
- **THEN** the hook allows the call without inspection

