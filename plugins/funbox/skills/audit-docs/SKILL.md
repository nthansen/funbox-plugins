---
name: audit-docs
description: Audit all CLAUDE.md files across the repo for quality, currency, and correct audience targeting. Not session-specific — use any time to review documentation health.
allowed-tools: Read, Glob, Grep, Skill
---

Audit all CLAUDE.md files in this repo for quality, currency, and correct audience targeting.

## Audience rules (read first)

Before proceeding, load the **documentation audience rules**. They come in two layers — an
invariant **base** plus a **tunable overlay** — and the effective rules are base + overlay:

1. Always load the base: `${CLAUDE_PLUGIN_ROOT}/context/audience-rules-base.md`. This is the
   file-boundary law and is never overridden.
2. Then load the overlay: the project's
   `${CLAUDE_PROJECT_DIR}/.claude/context/audience-rules.md` (plus `audience-rules.local.md` if
   present, for personal exceptions) if it exists; otherwise the bundled default overlay at
   `${CLAUDE_PLUGIN_ROOT}/context/audience-rules.md`.

The overlay may add file types and refine per-file contents and shell/path conventions, but
never reassigns a file's audience or scope. Apply base + overlay together as the effective
ruleset.

In your report, state in **one short line** which layers are in effect — e.g.
`Rules loaded: base + default overlay`, `base + project overlay`, and append `+ local
(audience-rules.local.md)` when present. Always show this (it's a health fact, not a nudge), so
the repo being on default rules is never hidden — even if the `/init-audience-rules` pointer was
silenced in `revise-docs`.

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
