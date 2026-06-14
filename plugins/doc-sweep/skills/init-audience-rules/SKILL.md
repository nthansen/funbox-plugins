---
name: init-audience-rules
description: Scaffold a project-specific audience-rules overlay for doc-sweep — the small set of conventions layered on top of the invariant base (extra doc file types, per-file contents emphasis, shell/path stance). Use when setting up doc-sweep for a project, customizing what belongs in CLAUDE.md vs README, adding a project-specific doc file type, or initializing audience rules.
allowed-tools: Read, Glob, Grep, Write
disable-model-invocation: true
---

Create a project-scoped audience-rules **overlay** so doc-sweep's `revise-docs` and
`audit-docs` skills apply *this repo's* conventions on top of the invariant base. The overlay
holds only the project's differences — it does **not** restate the file-boundary law.

## How doc-sweep resolves rules (read first)

doc-sweep loads rules in two layers, and the effective ruleset is **base + overlay**:

- **Base** (`${CLAUDE_PLUGIN_ROOT}/context/audience-rules-base.md`) — the invariant
  file-boundary law (which files are Claude- vs human-facing, shared vs local; the `.local.md`
  convention). **Always enforced; never overridden.** Do **not** restate it in the project file.
- **Overlay** — the tunable layer. The doc skills use the project's
  `${CLAUDE_PROJECT_DIR}/.claude/context/audience-rules.md` if it exists, otherwise the bundled
  default overlay (`${CLAUDE_PLUGIN_ROOT}/context/audience-rules.md`). An overlay may **add file
  types** and **refine per-file contents and shell/path conventions**, but must **not**
  reassign a file's audience or scope.

So the file you scaffold here is an **overlay — only the project's differences**, not a full
ruleset.

(User/global-scoped overlays are not supported yet — this skill targets project scope only.)

## Process

1. **Check for an existing project file.** If
   `${CLAUDE_PROJECT_DIR}/.claude/context/audience-rules.md` already exists, do **not**
   overwrite it blindly — read it, summarize what it already says, and offer to revise it
   instead of replacing it. Only proceed to a fresh scaffold if the user confirms or no file
   exists.

2. **Load the base and the default overlay for reference.** Read the base
   (`${CLAUDE_PLUGIN_ROOT}/context/audience-rules-base.md`) so you know what's already invariant
   and don't restate it, and the bundled default overlay
   (`${CLAUDE_PLUGIN_ROOT}/context/audience-rules.md`) as the starting template for the tunable
   layer.

3. **Inspect the project to know what to tailor.** Look for the repo's actual conventions:
   - Primary shell / OS — check existing `CLAUDE.md` / `CLAUDE.local.md`, `Makefile`,
     `scripts/`, `.gitattributes` (e.g. a Windows/PowerShell-primary repo flips the default's
     POSIX-`sh` assumption).
   - Layout — monorepo vs single package (affects the CLAUDE.md glob and where READMEs live).
   - Whether the repo uses the `.local.md` twins, and whether `.gitignore` already excludes
     them.
   - Any house conventions already implied by the existing docs.

4. **Draft the overlay — only the project's differences.** Start it with a standard one-line
   header that names it as an overlay and points at the base, so a human reading the file cold
   doesn't mistake it for the complete ruleset (and "fix" it by pasting the base law back in):

   ```markdown
   # Documentation audience rules — <project> project overlay

   > doc-sweep **overlay** — layered on the invariant base (`audience-rules-base.md`); lists
   > only this project's differences. The base still applies in full.
   ```

   Then include just the tunable parts that differ from the base + default overlay: extra doc
   **file types** (as new table rows beyond the base four), per-file **contents** emphasis, and
   the **shell/path** stance. Do **not** copy the base boundary law or the `.local.md`
   convention — those are always enforced. Note what each entry changes relative to the default
   overlay and why.

   Keep each entry to the **routing rule** the doc skills need — *how to sort content by
   audience*. Defer project **rationale and knowledge** (why a gotcha exists, versioning models,
   build details, etc.) to `CLAUDE.md`, which owns it; don't re-state it here. The overlay tells
   the skill where content goes, not why the project works the way it does — so no fact is
   duplicated across files.

5. **Get approval, then write.** Show the full draft. On approval, write it to
   `${CLAUDE_PROJECT_DIR}/.claude/context/audience-rules.md`, creating `.claude/context/` if
   needed. This file is **team-shared — commit it** (it's the opposite of a `.local` file).

6. **Wrap up.** Confirm the path written, and remind the user that `revise-docs` / `audit-docs`
   will now use it automatically. If they want personal, gitignored tweaks on top, mention the
   `audience-rules.local.md` companion (and that `.gitignore` should exclude it).
