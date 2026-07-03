## MODIFIED Requirements

### Requirement: Self-skip, bypass, and fail-open

The hook SHALL NOT obstruct work outside its intended scope. When configured for
doc-sweep-enabled repos only, it SHALL allow immediately in a repository lacking
doc-sweep markers (e.g. no `.claude/context/audience-rules.md` or `CLAUDE.md`). It
SHALL allow when the push command carries an explicit one-shot bypass token
(`DOC_SWEEP_REVISE_SKIP=1` or `--no-verify`). It SHALL additionally allow when every
non-doc commit in the gated range carries the shared `[skip docs]` acknowledgment token
(in its commit message) defined by the `docs-staleness-ci` capability, so a change
acknowledged as not needing docs clears both the local hook and the CI check with one
token. On any internal error it SHALL fail open (allow the push) rather than block.

#### Scenario: Unrelated repo is skipped
- **WHEN** repo applicability is "doc-sweep-enabled only" and the current repo has no doc-sweep markers
- **THEN** the hook allows the push without evaluating staleness

#### Scenario: Explicit bypass
- **WHEN** the push command contains `DOC_SWEEP_REVISE_SKIP=1` or `--no-verify`
- **THEN** the hook allows the push

#### Scenario: Shared [skip docs] acknowledgment clears the hook
- **WHEN** the non-doc commits in the gated range each contain `[skip docs]` in their commit message
- **THEN** the hook allows the push, treating the change as acknowledged as not needing docs

#### Scenario: Internal error fails open
- **WHEN** the hook encounters an internal error (e.g. cannot resolve the marker or run git)
- **THEN** it allows the push and emits a non-blocking note rather than denying
