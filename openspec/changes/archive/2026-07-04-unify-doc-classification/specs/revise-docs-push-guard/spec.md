## MODIFIED Requirements

### Requirement: Opt-in interactive installer

doc-sweep SHALL provide a manual, model-non-invocable skill that installs the guard only
when a user runs it. On a **fresh install** the installer SHALL collect, via interactive
prompts: settings location (user-global vs project), repo applicability (all repos vs
doc-sweep-enabled only), the documentation-file set (recorded as `docPatterns`, NOT the retired
`docMode`), the **trigger event** (exactly one of `push` or `commit`, with `push` recommended as
default), and bypass/uninstall confirmation. It SHALL then copy the hook script **and the shared
`doc-classify.mjs` module** to a stable, version-independent path, write the chosen configuration
(including `trigger` and `docPatterns`), and merge an idempotent `PreToolUse`/`Bash` hook into
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
- **THEN** the hook script and `doc-classify.mjs` are copied to a stable path, a config capturing the choices (including `trigger` and `docPatterns`) is written, a `PreToolUse`/`Bash` entry is added, the marker is set to HEAD, and a structured summary with edit/uninstall instructions is printed

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
- **THEN** the `PreToolUse` entry, the copied hook script, the copied `doc-classify.mjs`, and the config are removed, leaving other settings and the marker file intact

### Requirement: Configurable staleness gate

The installed hook SHALL run on `PreToolUse` for `Bash` calls and SHALL gate the git
subcommand named by its configured `trigger` (`push` default, or `commit`). It SHALL deny
the gated command if and only if at least one non-documentation file changed in the range
from the last `revise-docs` marker to `HEAD`. When it denies, it SHALL return a reason that
names the gated verb and instructs the operator to run `revise-docs-and-mark`, commit any
changes, and retry. If only documentation files (or nothing) changed since the marker, it
SHALL allow the command. Doc/non-doc/excluded classification SHALL be delegated to the shared
`doc-classification` module (`doc-classify.mjs`) using the configured `docPatterns` and
`excludeDirs` (or that module's built-in default) — the hook SHALL NOT carry its own inline
doc/non-doc patterns and SHALL NOT read a `docMode`. A command that is not the configured trigger
SHALL be allowed without inspection.

#### Scenario: Non-doc change blocks the configured trigger

- **WHEN** the configured trigger command is attempted and a non-doc, non-excluded file changed since the marker
- **THEN** the hook denies it with a reason naming the gated verb and directing the user to run `revise-docs-and-mark`, commit, then retry

#### Scenario: Doc-only change allows

- **WHEN** the configured trigger command is attempted and only doc-set files changed since the marker
- **THEN** the hook allows it

#### Scenario: A .claude doc change allows

- **WHEN** the only change since the marker is to `.claude/context/audience-rules.md`
- **THEN** the shared classifier counts it as a doc and the hook allows the command

#### Scenario: Commit trigger ignores push

- **WHEN** the configured trigger is `commit` and the Bash command is a `git push`
- **THEN** the hook allows the call without inspection

#### Scenario: Non-trigger command ignored

- **WHEN** the Bash command is not the configured trigger subcommand
- **THEN** the hook allows the call without inspection
