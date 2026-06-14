---
name: revise-docs
description: Review the session for learnings and update all documentation files in the repo. CLAUDE.md files are for Claude; README.md files are for humans. Use after a working session to capture new commands, renamed paths, gotchas, or architectural decisions into the right docs.
---

Review this session for learnings and update documentation accordingly.

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

1. **CLAUDE.md files** — delegate to the `claude-md-management:revise-claude-md` skill (a
   declared dependency of this plugin) via the Skill tool:
   - First load the audience rules above, and pass their **contents** in the args — do not
     pass file paths for the sub-skill to resolve.
   - After it completes, explicitly report its findings and any changes it proposed or made.
   - If it exits without output, say so clearly rather than continuing silently.

2. **README.md files** — handle directly; glob `**/README.md` (skip `node_modules/`):
   - Read each file
   - Reflect on this session: new commands, renamed files, changed paths, new tools/config
   - Propose a diff per file that needs changing
   - Ask for approval before applying any changes
   - Apply only the approved changes
