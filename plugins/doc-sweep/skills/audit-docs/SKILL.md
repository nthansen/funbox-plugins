---
name: audit-docs
description: Audit all CLAUDE.md files across the repo for quality, currency, and correct audience targeting. Not session-specific — use any time to review documentation health.
---

Audit all CLAUDE.md files in this repo for quality, currency, and correct audience targeting.

## Audience rules (read first)

Before proceeding, load the **documentation audience rules** — they define what belongs in
each file type. Prefer the consuming project's rules; fall back to this plugin's bundled
default:

1. If `${CLAUDE_PROJECT_DIR}/.claude/context/audience-rules.md` exists, use it — plus
   `${CLAUDE_PROJECT_DIR}/.claude/context/audience-rules.local.md` if present (personal
   exceptions).
2. Otherwise use this plugin's bundled default at
   `${CLAUDE_PLUGIN_ROOT}/context/audience-rules.md`.

## Process

Delegate to the `claude-md-management:claude-md-improver` skill (a declared dependency of this
plugin) via the Skill tool:

- Pass the **contents** of the audience rules loaded above in the args — do not pass file
  paths for the sub-skill to resolve.
- Ask it to flag any content in the wrong file type (human-facing text that belongs in a
  README, local paths that belong in `CLAUDE.local.md`), evaluate quality against its rubric,
  and output a quality report before proposing changes.
- Get approval before applying any updates.
- After it completes, explicitly report its findings and any changes it proposed or made.
- If it exits without output, say so clearly rather than continuing silently.
