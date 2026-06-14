#!/usr/bin/env bash
#
# patch-thinking-expanded.sh
#
# Make VS Code Claude Code thinking blocks default to EXPANDED each session.
#
# By default the extension's webview initializes its "are thinking blocks
# expanded" state to false, so every new session you have to click each
# "Thinking" header (or press Ctrl+O) to expand it. This flips that initial state
# to true so thinking renders expanded from the start. The click / Ctrl+O toggle
# still works normally afterwards.
#
# The state lives in the webview bundle as a useState(!1) immediately followed by
# the Ctrl+O keyboard handler (if(<e>.ctrlKey&&<e>.key==="o")...). That handler is
# the stable anchor: this patches the useState(!1) tied to it to useState(!0).
# Minified identifiers are wildcarded, so it survives renames.
#
# Idempotent: a state already initialized to !0 is left alone. A single pristine
# *.js.orig backup is made the first time the file is modified.
#
# This is the OPTIONAL companion to patch-vscode-thinking.sh (which makes thinking
# render at all). Reverse either/both with restore-vscode-thinking.sh.

set -euo pipefail

# --- Extensions directory -------------------------------------------------
# Auto-detected from the common locations below — the first one that actually
# contains the Claude Code extension wins. Override by exporting EXT_DIR:
#   EXT_DIR=/custom/path bash patch-thinking-expanded.sh
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

# Stable source-level literal that only appears in the thinking webview bundle.
PROBE='areThinkingBlocksExpanded'

if [ ! -d "$EXT_DIR" ]; then
    echo "Extensions directory not found: $EXT_DIR" >&2
    exit 1
fi

# Highest-versioned anthropic.claude-code-* directory (handles platform suffixes).
# Portable version sort via a zero-padded numeric key — BSD `sort` (macOS) has no `-V`.
ext=$(find "$EXT_DIR" -maxdepth 1 -type d -name 'anthropic.claude-code-*' 2>/dev/null \
        | while IFS= read -r _d; do
            _v=$(printf '%s' "$_d" | sed -E 's/.*claude-code-([0-9]+)\.([0-9]+)\.([0-9]+).*/\1 \2 \3/')
            case "$_v" in
                *' '*' '*)
                    # shellcheck disable=SC2086  # $_v is "MAJOR MINOR PATCH" — split into 3 printf args on purpose
                    printf '%012d%012d%012d\t%s\n' $_v "$_d"
                    ;;
            esac
          done \
        | sort \
        | tail -n1 \
        | cut -f2- || true)

if [ -z "$ext" ]; then
    echo "No anthropic.claude-code-* extension found under $EXT_DIR" >&2
    exit 1
fi
echo "Using extension: $(basename "$ext")"

# Candidate bundles that contain the probe.
# Portable read loop (works on bash 3.2, e.g. stock macOS — `mapfile` is bash 4+).
# Pass the probe with `-e` so a pattern that ever begins with "-" can't be parsed
# as a grep option (see the --thinking-display footgun in patch-vscode-thinking.sh).
files=()
while IFS= read -r _line; do
    if [ -n "$_line" ]; then files+=("$_line"); fi
done < <(grep -rlF -e "$PROBE" --include='*.js' "$ext" 2>/dev/null || true)

if [ "${#files[@]}" -eq 0 ]; then
    echo "WARNING: probe '$PROBE' did not match any *.js bundle under $(basename "$ext")." >&2
    echo "Before assuming the extension's minified shape changed, verify it manually:" >&2
    echo "  grep -rlF -e '$PROBE' --include='*.js' '$ext'" >&2
    echo "If that literal IS present, this is a script bug (probe/file-discovery), not a" >&2
    echo "version change — nothing was modified." >&2
    echo "If it is genuinely absent, please open an issue so the script can be updated:" >&2
    echo "  https://github.com/nthansen/funbox-plugins/issues" >&2
    exit 2
fi

total_patched=0
total_already=0
declare -a patched_files=()

for f in "${files[@]}"; do
    tmp="$(mktemp)"
    # Flip the expand-state useState(!1) -> useState(!0), anchored on the Ctrl+O
    # thinking-toggle handler that immediately follows it.
    counts=$(perl -0777 -pe '
        our ($p, $a);
        BEGIN { $p = 0; $a = 0; }
        # Already expanded-by-default? (idempotency)
        $a = () = /\.useState\(!0\)(?:(?!useState)[^;]){0,60};function [A-Za-z_\$][\w\$]*\([A-Za-z_\$][\w\$]*\)\{if\([A-Za-z_\$][\w\$]*\.ctrlKey&&[A-Za-z_\$][\w\$]*\.key==="o"/g;
        # Flip the initial state to expanded.
        $p = s#(\.useState\()!1(\)(?:(?!useState)[^;]){0,60};function [A-Za-z_\$][\w\$]*\([A-Za-z_\$][\w\$]*\)\{if\([A-Za-z_\$][\w\$]*\.ctrlKey&&[A-Za-z_\$][\w\$]*\.key==="o")#${1}!0${2}#g;
        END { print STDERR "PATCHED=$p ALREADY=$a\n"; }
    ' "$f" 2>&1 1>"$tmp")

    p=$(printf '%s' "$counts" | sed -n 's/.*PATCHED=\([0-9]*\).*/\1/p')
    a=$(printf '%s' "$counts" | sed -n 's/.*ALREADY=\([0-9]*\).*/\1/p')
    p=${p:-0}; a=${a:-0}

    total_already=$((total_already + a))

    if [ "$p" -gt 0 ]; then
        orig="$f.orig"
        [ -e "$orig" ] || cp -p "$f" "$orig"   # pristine backup, once
        mv "$tmp" "$f"
        total_patched=$((total_patched + p))
        patched_files+=("$f")
    else
        rm -f "$tmp"
    fi
done

echo
if [ "$total_patched" -gt 0 ]; then
    echo "PATCHED: thinking blocks now default to expanded ($total_patched site across ${#patched_files[@]} file(s))."
    for pf in "${patched_files[@]}"; do echo "  $pf"; done
    echo
    echo "==> Reload the VS Code window: Ctrl+Shift+P -> 'Developer: Reload Window'."
elif [ "$total_already" -gt 0 ]; then
    echo "ALREADY PATCHED: thinking blocks already default to expanded. Nothing to do."
else
    echo "WARNING: found '$PROBE' but the rewrite matched no expand-state initializer." >&2
    echo "The anchor regex may be too strict, or the minified shape genuinely changed." >&2
    echo "Nothing was modified. If the shape differs, please open an issue:" >&2
    echo "  https://github.com/nthansen/funbox-plugins/issues" >&2
    exit 2
fi
