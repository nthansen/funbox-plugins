---
name: revise-docs
description: Review the session for learnings and update all documentation files in the repo. CLAUDE.md files are for Claude; README.md files are for humans. Use after a working session to capture new commands, renamed paths, gotchas, or architectural decisions into the right docs.
allowed-tools: Read, Glob, Grep, Edit, Write, Skill, Bash(git ls-files*)
---

Review this session for learnings and update documentation accordingly.

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

After loading, tell the user in **one short line** which layers are in effect — e.g.
`Rules loaded: base + default overlay`, `base + project overlay`, and append `+ local
(audience-rules.local.md)` when the personal twin is present. Keep it to that one line; never
block on it.

- If the line is `base + default overlay` (no project overlay) **and**
  `${CLAUDE_PROJECT_DIR}/.claude/context/audience-rules.local.md` has no `overlay-hint: off`
  marker, append ` · tailor this repo with /init-audience-rules` to the line.
- If the user asks to silence that pointer (e.g. "turn it off", "stop showing this"), write
  `overlay-hint: off` into `audience-rules.local.md` yourself (create the file if missing),
  confirm it, and from then on show just the loaded line — which now includes `+ local
  (audience-rules.local.md)`, so the opt-out stays visible — without the pointer.

## Process

1. **CLAUDE.md files** — delegate to the `claude-md-management:revise-claude-md` skill (a
   declared dependency of this plugin) via the Skill tool:
   - First load the audience rules above, and pass their **contents** in the args — do not
     pass file paths for the sub-skill to resolve.
   - After it completes, explicitly report its findings and any changes it proposed or made.
   - If it exits without output, say so clearly rather than continuing silently.

2. **README.md files** — handle directly using tracked-only discovery:
   - Discover docs from tracked files: `git ls-files '*README.md' 'README.md'` (honors
     .gitignore, so `node_modules/`, `dist/`, and other gitignored trees drop out
     automatically). Also include local twins if present on disk: `audience-rules.local.md`,
     `CLAUDE.local.md`, `*.local.md` (explicit existence-checks; never blanket-include
     untracked files). Then drop any path whose leading directory component matches an entry
     in the `excludeDirs` list read from `.claude/context/audience-rules.md`.
   - **If `excludeDirs` is absent** (first run): scan the repository for likely-vendored
     directories — git submodules, directories containing a non-root package manifest, and
     well-known vendor directory names (e.g. `vendor/`, `third_party/`) — present the
     candidates to the user, wait for confirmation, and persist the confirmed set as an
     `excludeDirs` list in `.claude/context/audience-rules.md`. Subsequent runs read the
     list silently without re-prompting.
   - For each discovered (and not excluded) file:
     - Read each file
     - Reflect on this session: new commands, renamed files, changed paths, new tools/config
     - Propose a diff per file that needs changing
     - Ask for approval before applying any changes
     - Apply only the approved changes
