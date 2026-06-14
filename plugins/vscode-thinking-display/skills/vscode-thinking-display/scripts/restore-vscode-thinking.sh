#!/usr/bin/env bash
#
# restore-vscode-thinking.sh
#
# Restore the VS Code Claude Code extension bundles from their *.js.orig backups,
# optionally limited to one of the two fixes.
#
# Finds the *.js.orig backups under the anthropic.claude-code-* extension(s) and
# moves them back over the originals, undoing the patch(es). Each backup is
# classified by a probe so you can revert just one fix:
#
#   display  -> the bundle containing "--thinking-display"        (extension.js)
#   expand   -> the bundle containing "areThinkingBlocksExpanded" (webview/index.js)
#   both     -> everything (default)
#
# Backups that match neither probe are left untouched (they are not ours).
#
# Usage:
#   restore-vscode-thinking.sh [display|expand|both]

set -euo pipefail

# --- Extensions directory -------------------------------------------------
# Auto-detected from the common locations below — the first one that actually
# contains the Claude Code extension wins. Override by exporting EXT_DIR:
#   EXT_DIR=/custom/path bash restore-vscode-thinking.sh
# Candidates:
#   ~/.vscode-server/extensions            VS Code Server / dev container / WSL remote
#   ~/.vscode/extensions                   native Linux or macOS desktop VS Code
#   /mnt/c/Users/$USER/.vscode/extensions  WSL reaching a Windows install
# Windows desktop uses %USERPROFILE%\.vscode\extensions (handled by the .ps1).
# --------------------------------------------------------------------------
if [ -z "${EXT_DIR:-}" ]; then
    for _cand in \
        "$HOME/.vscode-server/extensions" \
        "$HOME/.vscode/extensions" \
        "/mnt/c/Users/${USER:-}/.vscode/extensions"; do
        [ -d "$_cand" ] || continue
        if find "$_cand" -maxdepth 1 -type d -name 'anthropic.claude-code-*' 2>/dev/null | grep -q .; then
            EXT_DIR="$_cand"; break
        fi
        if [ -z "${EXT_DIR:-}" ]; then EXT_DIR="$_cand"; fi   # fallback: first existing dir
    done
fi
EXT_DIR="${EXT_DIR:-$HOME/.vscode-server/extensions}"

FIX="${1:-both}"
case "$FIX" in
    display|expand|both) ;;
    *) echo "Usage: $(basename "$0") [display|expand|both]" >&2; exit 1 ;;
esac

DISPLAY_PROBE='--thinking-display'          # identifies the display-fix bundle
EXPAND_PROBE='areThinkingBlocksExpanded'    # identifies the expand-fix bundle
want_display=false; want_expand=false
case "$FIX" in
    display) want_display=true ;;
    expand)  want_expand=true ;;
    both)    want_display=true; want_expand=true ;;
esac

if [ ! -d "$EXT_DIR" ]; then
    echo "Extensions directory not found: $EXT_DIR" >&2
    exit 1
fi

# Scope to the Claude Code extension(s) only (don't touch unrelated extensions' backups).
# Portable read loop (works on bash 3.2, e.g. stock macOS — `mapfile` is bash 4+).
origs=()
while IFS= read -r _line; do
    if [ -n "$_line" ]; then origs+=("$_line"); fi
done < <(find "$EXT_DIR" -maxdepth 1 -type d -name 'anthropic.claude-code-*' \
    -exec find {} -type f -name '*.js.orig' \; 2>/dev/null || true)

if [ "${#origs[@]}" -eq 0 ]; then
    echo "No *.js.orig backups found under any anthropic.claude-code-* extension. Nothing to restore."
    exit 0
fi

echo "Reverting: $FIX"
restored=0
skipped=0
for o in "${origs[@]}"; do
    target="${o%.orig}"
    is_display=false; is_expand=false
    grep -qF -- "$DISPLAY_PROBE" "$o" 2>/dev/null && is_display=true
    grep -qF -- "$EXPAND_PROBE"  "$o" 2>/dev/null && is_expand=true

    if { $is_display && $want_display; } || { $is_expand && $want_expand; }; then
        mv -f "$o" "$target"
        kind="unknown"; $is_display && kind="display"; $is_expand && kind="expand"
        echo "Restored ($kind) $target"
        restored=$((restored + 1))
    else
        echo "Skipped  $target"
        skipped=$((skipped + 1))
    fi
done

echo
if [ "$restored" -gt 0 ]; then
    echo "Restored $restored file(s)$( [ "$skipped" -gt 0 ] && echo ", left $skipped in place" )."
    echo "==> Reload the VS Code window: Ctrl+Shift+P -> 'Developer: Reload Window'."
else
    echo "Nothing matched '$FIX'. No files restored."
fi
