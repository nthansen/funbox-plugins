# claude-rules-revision Specification

## Purpose

Review the current session for convention learnings — a rule that proved stale, a new pattern
introduced, a convention agreed with the user, or a gap repeatedly hit — and fold them into the
repository's existing `.claude/rules` (and repo-wide `CLAUDE.md` rules), following Claude Code's
documented rule placement. Each revision is session-grounded, verified against the current code,
confirmed by the user, and merged non-destructively; stale-rule removal is flag-and-confirm; when no
rules exist yet the skill defers to `init-claude-rules`.

## Requirements

### Requirement: Session-driven learning capture

The skill SHALL derive its candidate revisions from the current working session rather than from a
cold whole-repository re-scan. It SHALL consider four kinds of session learning: a rule that proved
stale or wrong, a new convention introduced during the session, a convention the user and Claude
explicitly agreed to encode, and a gap where guidance was repeatedly needed but absent from every
rule. When the session surfaced no such learning, the skill SHALL say so and stop rather than
inventing revisions.

#### Scenario: Session learning is turned into a candidate revision

- **WHEN** the current session introduced, changed, retired, or agreed on a code convention
- **THEN** the skill derives a candidate revision from that session learning rather than from a fresh whole-tree scan

#### Scenario: No session learning to capture

- **WHEN** the current session surfaced no convention learning
- **THEN** the skill reports that there is nothing to revise and stops without inventing revisions

### Requirement: Operate on the existing rule set, defer to init when empty

The skill SHALL discover and read the repository's existing rule files under `.claude/rules/` and
the relevant `CLAUDE.md` files before proposing changes, because a revision is defined relative to
what already exists. When the repository contains no `.claude/rules` files and no `CLAUDE.md` rules,
the skill SHALL point the user to `init-claude-rules` as the bootstrap tool rather than silently
performing a cold generation, and MAY capture the session's learnings as an initial rule only if the
user asks.

#### Scenario: Existing rules are read before revising

- **WHEN** the skill runs in a repository that already has rule files under `.claude/rules/` or rules in `CLAUDE.md`
- **THEN** it reads those existing rules first and defines its proposed changes relative to them

#### Scenario: No rules exist yet

- **WHEN** the repository has no `.claude/rules` files and no `CLAUDE.md` rules
- **THEN** the skill points the user to `init-claude-rules` as the bootstrap tool and does not silently perform a cold generation

### Requirement: Session-grounded evidence verified against current code

Every proposed revision SHALL cite both the session evidence it came from (the exchange, file edit,
or decision) and the current-code evidence that the pattern actually holds now, verified with the
repository's own files or symbol tooling. A candidate whose pattern the current code does not exhibit
SHALL NOT be written. The skill SHALL run a self-refute pass distinguishing a durable convention from
a one-off, and SHALL drop any candidate that Claude would already honor unprompted (a standard idiom,
or anything plainly visible in the edited files).

#### Scenario: Revision carries session and code evidence

- **WHEN** the skill proposes a revision to a rule
- **THEN** that revision cites the session learning it came from and the current-code evidence that the pattern holds now

#### Scenario: Session belief not borne out by the code

- **WHEN** a candidate revision reflects a session belief that the current code does not actually exhibit
- **THEN** the skill does not write that revision

#### Scenario: One-off or obvious learning withheld

- **WHEN** a session learning is a one-off, or is something Claude would already honor unprompted
- **THEN** the skill does not encode it as a rule revision

### Requirement: Interactive, user-confirmed revisions

The skill SHALL present each proposed change — an addition, an edit, or a removal — with its evidence
and the exact diff, and SHALL write only changes the user confirms. Removing a rule that has gone
stale, and any rewrite that changes a rule's meaning, SHALL be surfaced for confirmation rather than
applied silently.

#### Scenario: Change is confirmed before it is written

- **WHEN** the skill has a proposed addition, edit, or removal
- **THEN** it presents the change with its evidence and exact diff and writes it only after the user confirms

#### Scenario: Stale-rule removal is flag-and-confirm

- **WHEN** the skill determines an existing rule has gone stale and should be removed
- **THEN** it surfaces the removal with its evidence for confirmation rather than deleting the rule silently

### Requirement: Documented rule placement and non-destructive merge

The skill SHALL place and merge revisions using Claude Code's documented mechanism, identically to
`init-claude-rules`. Path-specific or single-area conventions SHALL be written as `paths:`-scoped
rule files under `.claude/rules/`; genuinely repo-wide standards MAY go to `CLAUDE.md`; the skill
SHALL NOT push path-specific guidance into `CLAUDE.md`. When editing a rule that already covers a
concern, the skill SHALL edit that file in place — unioning any new `paths:` globs and revising the
matching body section rather than appending a duplicate — leaving unrelated files and sections
untouched. The skill SHALL report every path it wrote, and SHALL flag any conflict between an
existing rule and the reality observed in the current code.

#### Scenario: Edit is merged into the existing rule file

- **WHEN** a proposed revision concerns a rule an existing `.claude/rules/` file already covers
- **THEN** the skill edits that file in place — unioning any new `paths:` globs and revising the matching section — rather than creating a duplicate or overwriting unrelated content

#### Scenario: Path-specific revision stays out of CLAUDE.md

- **WHEN** a confirmed revision applies only to a specific subtree or file pattern
- **THEN** the skill writes it as a `paths:`-scoped rule file under `.claude/rules/`, not into `CLAUDE.md`, and reports the path it wrote

#### Scenario: Existing rule contradicts current code

- **WHEN** an existing rule contradicts what the skill observes in the current code
- **THEN** the skill flags that contradiction for the user rather than silently keeping or rewriting the rule
