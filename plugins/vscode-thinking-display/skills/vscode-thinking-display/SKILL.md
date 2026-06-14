---
name: vscode-thinking-display
description: Patch (or restore) the VS Code Claude Code extension so Opus/Fable models render thinking summaries, and optionally make thinking blocks default to expanded. Use when the user wants to enable/show extended thinking in the VS Code extension, fix empty or unexpandable Opus/Fable thinking blocks, keep thinking always expanded, re-apply the patch after an extension update, or undo it. Detects the OS and runs the matching bundled script.
# Pre-approve this skill's own bundled scripts so they run without a permission
# prompt (which would stall/fail in auto-accept and headless modes). Scoped to the
# specific script filenames; the `*` absorbs whatever absolute install path (plugin
# cache or ~/.claude/skills) they live under. Each rule is tool-specific, so it only
# ever matches on the relevant OS — PowerShell on Windows, Bash elsewhere; the
# others stay inert. Deny rules in settings.json still take precedence.
allowed-tools:
  # Windows (PowerShell tool)
  - PowerShell(& *patch-vscode-thinking.ps1*)
  - PowerShell(& *patch-thinking-expanded.ps1*)
  - PowerShell(& *restore-vscode-thinking.ps1*)
  # Linux / macOS / WSL (Bash tool)
  - Bash(bash *patch-vscode-thinking.sh*)
  - Bash(bash *patch-thinking-expanded.sh*)
  - Bash(bash *restore-vscode-thinking.sh*)
---

# Patch Claude Code thinking display (VS Code extension)

Enables thinking summaries for Opus/Fable models in the **VS Code Claude Code extension**
by defaulting an omitted thinking-`display` to `"summarized"` at the single chokepoint
where the extension emits the `--thinking-display` CLI flag:

```js
if(l.type!=="disabled"&&l.display)B.push("--thinking-display",l.display)   // before
if(l.type!=="disabled")B.push("--thinking-display",l.display??"summarized") // after
```

This works around an upstream bug where newer models can resolve a thinking config whose
`display` is omitted, so the flag is never passed and thinking arrives empty (rendering as
an empty / unexpandable "Thought for Xs" stub). Patching the chokepoint rather than each
config branch covers **every** shape (enabled, adaptive, fallback, and any future one):
anything omitted becomes summarized, while an explicit `display` value is preserved. The
minified identifiers are matched by shape, so the patch survives variable renames.

This patches the **VS Code extension's bundled JS** — it is unrelated to CLI-only patches.

The patch is **idempotent** (re-running is safe), makes a one-time `*.js.orig` backup per
modified file, and is fully reversible with the restore script.

## When to use

- "Enable / show Opus thinking in VS Code", "my thinking blocks are empty/unexpandable",
  "the extension updated and thinking is gone again" → run the **patch**.
- "Undo the thinking patch", "revert the extension change" → run the **restore**.

## How to apply

1. **Detect the OS** — a binary split: Windows (`win32`) → run the `.ps1`; macOS / Linux
   (including WSL and devcontainers) → run the `.sh`. Nothing branches on WSL vs native
   Linux vs macOS: the bash script auto-detects the extensions directory by probing known
   paths in order (see step 2), so no finer distinction is needed.
2. **Run the matching script** from this skill's `scripts/` directory (paths are relative
   to this SKILL.md):

   **Windows** (PowerShell):
   ```powershell
   & ".\scripts\patch-vscode-thinking.ps1"
   ```

   **Linux / macOS / WSL** (bash):
   ```bash
   bash ./scripts/patch-vscode-thinking.sh
   ```

   The `.sh` scripts auto-detect the extensions directory (`~/.vscode-server/extensions`,
   then `~/.vscode/extensions`, then `/mnt/c/Users/<you>/.vscode/extensions`), preferring
   whichever actually contains the extension. If it lives elsewhere, prepend
   `EXT_DIR=/custom/path` to the command.

3. **Report the result** — patched, already-patched, or pattern-not-found. **Exit code 2**
   means the probe matched but the minified shape changed, so nothing was modified: tell the
   user the workaround needs updating and ask them to **open an issue** at
   <https://github.com/nthansen/funbox-plugins/issues> (the scripts print
   this URL too).
4. **Offer the optional expand step.** After the main patch, ask the user:
   *"Also make thinking blocks default to expanded each session?"* If yes, run the companion
   script (same OS detection):

   **Windows:** `& ".\scripts\patch-thinking-expanded.ps1"`
   **Linux/macOS/WSL:** `bash ./scripts/patch-thinking-expanded.sh`

   Mention that `Ctrl+O` already toggles all thinking blocks expanded/collapsed live in the
   extension — this patch just changes the per-session **default** to expanded (the toggle
   still works). This is purely cosmetic and independent of the display fix.
5. **Tell the user to reload VS Code:** `Ctrl+Shift+P` → *Developer: Reload Window*.

## How to restore

Same OS detection. **First ask the user which fix to revert** — the display fix, the
expand-default fix, or both — then pass it to the restore script (`display` | `expand` |
`both`; default `both`). The script classifies each `*.js.orig` backup by probe and only
restores the selected one(s); backups it doesn't recognize are left untouched. Reload the VS
Code window afterwards.

- **Windows:** `& ".\scripts\restore-vscode-thinking.ps1" -Fix both`
- **Linux/macOS:** `bash ./scripts/restore-vscode-thinking.sh both`

Examples: revert only the always-expanded behavior with `-Fix expand` / `expand`; revert only
the thinking-display fix with `-Fix display` / `display`.

## Notes

- Patches the **highest-versioned** `anthropic.claude-code-*` extension found. VS Code
  installs updates into a new versioned folder, so **re-apply after each extension update**.
- **Upgrading from the older per-branch patch?** That version appended a duplicate
  `display:"summarized"` to each `{type:"enabled",…}` config object. Run the **restore**
  script first (to recover a pristine bundle), then re-run the patch so only the chokepoint
  is modified.
- This is a **stopgap** for an open upstream bug; an official fix may land in any release
  and make the patch unnecessary (or change the minified shape it targets).
- **If the workaround stops working** (the patch exits with code 2, or thinking still doesn't
  render/expand after patching and reloading), the extension's bundle shape likely changed.
  Ask the user to open an issue at
  <https://github.com/nthansen/funbox-plugins/issues> with their extension
  version so the scripts can be updated.
- Prefer not to patch? Switching the extension to **"Use Terminal mode"** renders through the
  CLI renderer, which isn't affected by this webview bug — but you still need extended thinking
  enabled in that mode yourself (terminal mode doesn't turn it on or auto-show it), and it
  changes the UI.
- **Auto-accept / headless runs:** the skill's own scripts are pre-approved via
  `allowed-tools` in the frontmatter, so once the user opts in they run without a permission
  prompt. A `deny` rule in `settings.json` still overrides this — if a run is blocked, check
  for a Bash/PowerShell deny rule.
