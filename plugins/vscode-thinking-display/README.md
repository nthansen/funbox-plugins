# vscode-thinking-display

Restore **thinking summaries** in the **VS Code Claude Code extension** for Opus/Fable
models, by patching the extension's bundled JavaScript to pass `display:"summarized"`.

Part of the [**funbox**](../../README.md) Claude Code plugin marketplace.

## The bug

Starting with Opus 4.7, the Claude API changed the default for `thinking.display` from
`"summarized"` to `"omitted"`. Thinking blocks still appear in the response stream, but the
thinking text is empty unless the client explicitly sets `display:"summarized"`. The VS Code
extension's fallback thinking-config branch never sets it, so on Opus/Fable models the
thinking panel renders as an empty, unexpandable **"Thought for Xs"** stub.

This is an open upstream issue, reported many times:

- [#63459](https://github.com/anthropics/claude-code/issues/63459) — fallback thinking-config branch omits `display`
- [#49322](https://github.com/anthropics/claude-code/issues/49322), [#49757](https://github.com/anthropics/claude-code/issues/49757), [#49902](https://github.com/anthropics/claude-code/issues/49902), [#51131](https://github.com/anthropics/claude-code/issues/51131) — Opus 4.7 thinking not rendered / not expandable
- [#66887](https://github.com/anthropics/claude-code/issues/66887) — same for Fable 5
- [#50171](https://github.com/anthropics/claude-code/issues/50171), [#14092](https://github.com/anthropics/claude-code/issues/14092) — related visibility reports

## The fix

The scripts locate the highest-versioned `anthropic.claude-code-*` extension and patch the
single chokepoint where the extension emits the `--thinking-display` CLI flag, defaulting an
omitted `display` to `"summarized"`:

```js
if(l.type!=="disabled"&&l.display)B.push("--thinking-display",l.display)    // before
if(l.type!=="disabled")B.push("--thinking-display",l.display??"summarized")  // after
```

Patching the chokepoint rather than each config branch covers **every** thinking-config
shape (enabled, adaptive, fallback, and any future one): anything omitted becomes
summarized, while an explicit `display` value is preserved. The minified identifiers are
matched by shape, so the patch survives variable renames between builds.

- **Idempotent** — already-patched occurrences are skipped.
- **Backed up** — a pristine `*.js.orig` is saved once per modified file.
- **Reversible** — the restore script puts the originals back.

### Optional: thinking blocks expanded by default

A separate, optional patch makes thinking blocks render **expanded by default** each session
instead of collapsed. The extension already has a hidden shortcut — **`Ctrl+O`** toggles all
thinking blocks expanded/collapsed — but that resets to collapsed every session. This patch
flips the per-session default to expanded (the `Ctrl+O` / click toggle still works). It
targets `webview/index.js`, anchored on that `Ctrl+O` handler, and is idempotent + reversible
just like the display fix. When run via the skill, Claude asks whether you want this before
applying it.

## Usage

### As a Claude Code plugin (recommended)

From inside Claude Code, add the funbox marketplace and install this plugin:

```text
/plugin marketplace add nthansen/funbox-plugins
/plugin install vscode-thinking-display@funbox
```

That's it. The skill is then available as `/vscode-thinking-display:vscode-thinking-display`
(or just ask Claude to "patch claude thinking"); it detects your OS and runs the right
script. To update later, run `/plugin marketplace update funbox`.

**Local / development install** — clone the repo and point the marketplace at the folder:

```text
git clone https://github.com/nthansen/funbox-plugins
```
```text
/plugin marketplace add ./funbox-plugins
/plugin install vscode-thinking-display@funbox
```

Edits you make in the clone are picked up after `/plugin marketplace update`.

### As a standalone skill (no plugin)

Prefer not to use the plugin system? Copy just the skill folder into your skills directory
(paths are from a repo checkout root):

```bash
# Linux / macOS
cp -r plugins/vscode-thinking-display/skills/vscode-thinking-display ~/.claude/skills/

# Windows (PowerShell)
Copy-Item -Recurse plugins\vscode-thinking-display\skills\vscode-thinking-display $env:USERPROFILE\.claude\skills\
```

Then ask Claude to "patch claude thinking" (or `/vscode-thinking-display`).

### Running the scripts directly

Paths below are relative to this plugin folder (`plugins/vscode-thinking-display/` in the repo):

```powershell
# Windows — display fix
.\skills\vscode-thinking-display\scripts\patch-vscode-thinking.ps1
# Windows — optional "expanded by default"
.\skills\vscode-thinking-display\scripts\patch-thinking-expanded.ps1
```

```bash
# Linux / macOS / WSL — display fix
bash ./skills/vscode-thinking-display/scripts/patch-vscode-thinking.sh
# Linux / macOS / WSL — optional "expanded by default"
bash ./skills/vscode-thinking-display/scripts/patch-thinking-expanded.sh
```

After patching, reload VS Code: `Ctrl+Shift+P` → **Developer: Reload Window**.

To undo, run the matching `restore-vscode-thinking.*` script and reload again. It takes an
optional selector — `display`, `expand`, or `both` (default) — so you can revert just one of
the two fixes:

```powershell
# Windows — revert only the always-expanded behavior, keep the display fix
.\skills\vscode-thinking-display\scripts\restore-vscode-thinking.ps1 -Fix expand
```
```bash
# Linux / macOS / WSL — revert everything
bash ./skills/vscode-thinking-display/scripts/restore-vscode-thinking.sh both
```

### Linux / macOS / WSL extension paths

The bash scripts auto-detect the extensions directory, trying these in order and using the
first that actually contains the Claude Code extension:

- `~/.vscode-server/extensions` — VS Code Server / dev container / WSL remote
- `~/.vscode/extensions` — native Linux or macOS desktop VS Code
- `/mnt/c/Users/<you>/.vscode/extensions` — WSL reaching a Windows install

If yours lives somewhere else, point the scripts at it with the `EXT_DIR` env var:

```bash
EXT_DIR=/custom/path bash ./skills/vscode-thinking-display/scripts/patch-vscode-thinking.sh
```

## Caveats

- **Re-apply after extension updates.** VS Code installs updates into a new versioned
  folder; the patch only affects the version present when it ran.
- **Stopgap.** This is a workaround for an open upstream bug. An official fix may land in
  any release and make this unnecessary — or change the minified shape the scripts target
  (in which case the patch exits with code 2 and the scripts need updating).
- **No-patch alternative.** Switching the extension to **"Use Terminal mode"** renders
  through the CLI renderer, which isn't affected by this webview bug — so thinking shows there.
  But you still have to turn on extended thinking for that mode yourself; terminal mode
  doesn't enable or auto-show it, and it changes the UI.
- **If the workaround stops working** — the patch exits with code 2, or thinking still
  doesn't render/expand after patching and reloading — the extension's minified bundle shape
  has probably changed. Please [open an issue](https://github.com/nthansen/funbox-plugins/issues)
  with your extension version so the scripts can be updated.

## Versioning

Distributed on the **funbox** rolling `main` channel — the plugin omits `version` in
`plugin.json`, so every commit is the current version and `/plugin marketplace update funbox`
moves you to the latest. Changes are tracked in [CHANGELOG.md](CHANGELOG.md).

## Disclaimer

Not affiliated with, authorized, or endorsed by Anthropic. "Claude", "Opus", and "Fable"
are referenced for identification only. This tool modifies the locally installed VS Code
extension's bundled files; use it at your own risk. Backups (`*.js.orig`) are made and the
change is reversible, but an extension update or upstream fix may render it unnecessary or
require an update to the scripts.

## License

Released into the public domain under [The Unlicense](../../LICENSE). Do whatever you want
with it — no attribution required.
