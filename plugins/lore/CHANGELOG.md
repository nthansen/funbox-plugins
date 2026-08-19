# Changelog — lore

Distributed on the **funbox** rolling `main` channel: no pinned versions, no tags. Every commit
is the current version, resolved by commit SHA; `/plugin marketplace update funbox` moves you to
the latest. See the
[commit history](https://github.com/nthansen/funbox-plugins/commits/main/plugins/lore) for the
full record.

## Unreleased

- **New `revise-claude-rules` skill.** The `.claude/rules` counterpart to `revise-docs`, and the
  incremental sibling of `init-claude-rules`: after a working session it reviews what the session
  revealed about the repo's conventions — a rule gone stale, a new pattern introduced, a convention
  agreed with the user, or a gap repeatedly hit — and folds those learnings into the **existing**
  `.claude/rules` (and repo-wide `CLAUDE.md` rules). Session-driven rather than a cold re-scan: each
  change is verified against the current code, presented with its evidence and exact diff, and
  merged non-destructively, with stale-rule removal handled as flag-and-confirm. When no rules exist
  yet it defers to `init-claude-rules`.
- **New `init-claude-rules` skill.** The `.claude/rules` counterpart to `/init`: interactively
  derives a repo's Claude rules from its own structure, recurring code patterns, and declared config
  signals — evidence-backed and user-confirmed, never invented. Works on any codebase (git
  optional); scans from the repo/folder root, attributes conventions per subtree for
  monorepo/polyglot trees, and writes path-specific rules as `paths:`-scoped files under
  `.claude/rules/` (repo-wide standards go to a concise `CLAUDE.md` entry), merging
  non-destructively with any existing rules. Large tracked-but-irrelevant directories can be
  excluded via `~/.claude/rules-ignore` (user) or `.claude/rules-ignore` (repo).

## Consolidation

The former standalone `doc-sweep` plugin became this `lore` plugin — the context-driven doc
skills (`revise-docs`, `audit-docs`, `init-audience-rules`), distributed as skills.

Dropped in the process:

- **Docs-staleness CI check** and the **revise-docs push guard** hooks. Both were mechanical "a
  doc must change when code changes" gates — they can't tell whether the docs are *right*. The
  point of the doc skills is to generate correct docs from live session context, which no
  deterministic hook can do.
- The **`install-docs-ci`**, **`install-revise-hook`**, and **`revise-docs-and-mark`** skills,
  which existed only to install and feed those hooks.
- The **`vscode-thinking-display`** plugin/skill (VS Code extension thinking-summary patch) — no
  longer maintained.
