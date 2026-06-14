#!/usr/bin/env bash
#
# patch-vscode-thinking.sh
#
# Patch the VS Code Claude Code extension so an omitted thinking-display defaults
# to "summarized" (so Opus/Fable thinking renders).
#
# Works around the bug where newer models can resolve a thinking config whose
# `display` is omitted/undefined, so the extension never passes --thinking-display
# to the CLI and thinking arrives empty.
#
# Rather than touching each individual thinking-config branch, this patches the
# single chokepoint where the flag is emitted:
#
#   if(<l>.type!=="disabled"&&<l>.display)<B>.push("--thinking-display",<l>.display)
#
# becomes:
#
#   if(<l>.type!=="disabled")<B>.push("--thinking-display",<l>.display??"summarized")
#
# This covers EVERY config shape (enabled, adaptive, fallback, and any future
# one): anything with an omitted display gets "summarized", while an explicit
# display value is preserved. The minified identifiers (l, B) are matched by
# shape with a backreference, so they survive renames across builds.
#
# Idempotent: a chokepoint already ending in .display??"summarized") is left
# alone. A single pristine *.js.orig backup is made per file the first time it is
# actually modified. Reverse with restore-vscode-thinking.sh.
#
# NOTE: If you previously applied the older per-branch version of this patch, run
# restore-vscode-thinking.sh first to get a pristine file, then re-run this
# script. The two approaches touch different locations.

set -euo pipefail

# --- Extensions directory -------------------------------------------------
# Auto-detected from the common locations below — the first one that actually
# contains the Claude Code extension wins. Override by exporting EXT_DIR:
#   EXT_DIR=/custom/path bash patch-vscode-thinking.sh
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

# Stable literal used to locate candidate bundles.
PROBE='--thinking-display'

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
# NOTE: pass the probe with `-e`. It starts with "--", so without -e grep parses it
# as an option and aborts ("grep: unrecognized option '--thinking-display'"), which
# would make the patch wrongly report the chokepoint as missing.
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
    # Rewrite the flag-emitting chokepoint. Identifiers are matched generically
    # (backreference \1) so the patch survives minifier renames.
    # stdout (patched content) -> $tmp ; stderr (counts) -> captured in $counts.
    counts=$(perl -0777 -pe '
        our ($p, $a);
        BEGIN { $p = 0; $a = 0; }
        # Count chokepoints already defaulted to "summarized" (idempotency).
        $a = () = /\.push\("--thinking-display",[A-Za-z_\$][\w\$]*\.display\?\?"summarized"\)/g;
        # Default the omitted display to "summarized" at the single chokepoint.
        $p = s{if\(([A-Za-z_\$][\w\$]*)\.type!=="disabled"&&\1\.display\)([A-Za-z_\$][\w\$]*)\.push\("--thinking-display",\1\.display\)}{if($1.type!=="disabled")$2.push("--thinking-display",$1.display??"summarized")}g;
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
    echo "PATCHED: $total_patched chokepoint(s) across ${#patched_files[@]} file(s)."
    for pf in "${patched_files[@]}"; do echo "  $pf"; done
    echo
    echo "==> Reload the VS Code window: Ctrl+Shift+P -> 'Developer: Reload Window'."
elif [ "$total_already" -gt 0 ]; then
    echo "ALREADY PATCHED: $total_already chokepoint(s) already default display to \"summarized\". Nothing to do."
else
    echo "WARNING: found '$PROBE' but the rewrite matched no chokepoint to patch." >&2
    echo "The chokepoint regex may be too strict, or the minified shape genuinely changed." >&2
    echo "Inspect the surrounding expression manually — it should look like:" >&2
    echo "  if(l.type!==\"disabled\"&&l.display)B.push(\"--thinking-display\",l.display)" >&2
    echo "Nothing was modified. If the shape differs, please open an issue:" >&2
    echo "  https://github.com/nthansen/funbox-plugins/issues" >&2
    exit 2
fi
