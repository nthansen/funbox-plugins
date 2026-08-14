# Changelog — funbox

Distributed on the **funbox** rolling `main` channel: no pinned versions, no tags. Every commit
is the current version, resolved by commit SHA; `/plugin marketplace update funbox` moves you to
the latest. See the
[commit history](https://github.com/nthansen/funbox-plugins/commits/main/plugins/funbox) for the
full record.

## Consolidation

The former standalone `doc-sweep` plugin became this `funbox` plugin — the context-driven doc
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
