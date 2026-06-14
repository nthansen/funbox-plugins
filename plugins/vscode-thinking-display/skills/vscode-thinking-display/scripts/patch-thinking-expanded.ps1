#requires -Version 5
<#
.SYNOPSIS
    Make VS Code Claude Code thinking blocks default to EXPANDED each session.

.DESCRIPTION
    By default the extension's webview initializes its "are thinking blocks
    expanded" state to false, so every new session you have to click each
    "Thinking" header (or press Ctrl+O) to expand it. This flips that initial
    state to true so thinking renders expanded from the start. The click / Ctrl+O
    toggle still works normally afterwards.

    The state lives in the webview bundle as a `useState(!1)` immediately followed
    by the Ctrl+O keyboard handler (`if(<e>.ctrlKey&&<e>.key==="o")...`). That
    handler is the stable anchor: this patches the `useState(!1)` tied to it to
    `useState(!0)`. Minified identifiers are wildcarded, so it survives renames.

    Idempotent: a state already initialized to `!0` is left alone. A single
    pristine *.js.orig backup is made the first time the file is modified.

    This is the OPTIONAL companion to patch-vscode-thinking.ps1 (which makes
    thinking render at all). Reverse either/both with restore-vscode-thinking.ps1.
#>

# --- Extensions directory -------------------------------------------------
# Windows (default): %USERPROFILE%\.vscode\extensions
$ExtensionsDir = Join-Path $env:USERPROFILE '.vscode\extensions'
# Linux / WSL alternatives are handled by the bash version.
# --------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

# Stable source-level literal that only appears in the thinking webview bundle.
$findProbe = 'areThinkingBlocksExpanded'

# The expand-state initializer, anchored on the Ctrl+O thinking-toggle handler that
# immediately follows it. Group 1 = up to the useState arg, group 2 = the anchor tail.
$pattern = '(\.useState\()!1(\)(?:(?!useState)[^;]){0,60};function [A-Za-z_$][\w$]*\([A-Za-z_$][\w$]*\)\{if\([A-Za-z_$][\w$]*\.ctrlKey&&[A-Za-z_$][\w$]*\.key==="o")'
$replacement = '${1}!0${2}'

# Recognises an already-patched (expanded-by-default) state, for idempotency.
$alreadyPattern = '\.useState\(!0\)(?:(?!useState)[^;]){0,60};function [A-Za-z_$][\w$]*\([A-Za-z_$][\w$]*\)\{if\([A-Za-z_$][\w$]*\.ctrlKey&&[A-Za-z_$][\w$]*\.key==="o"'

if (-not (Test-Path -LiteralPath $ExtensionsDir)) {
    Write-Error "Extensions directory not found: $ExtensionsDir"
    exit 1
}

# Highest-versioned anthropic.claude-code-* directory (handles optional platform suffix).
$extDir = Get-ChildItem -LiteralPath $ExtensionsDir -Directory -Filter 'anthropic.claude-code-*' |
    Where-Object { $_.Name -match '(\d+\.\d+\.\d+)' } |
    Sort-Object { [version]([regex]::Match($_.Name, '\d+\.\d+\.\d+').Value) } |
    Select-Object -Last 1

if (-not $extDir) {
    Write-Error "No anthropic.claude-code-* extension found under $ExtensionsDir"
    exit 1
}
Write-Host "Using extension: $($extDir.Name)"

# Find bundles that contain the probe.
$candidates = Get-ChildItem -LiteralPath $extDir.FullName -Recurse -Filter '*.js' -File |
    Select-String -SimpleMatch -Pattern $findProbe -List |
    Select-Object -ExpandProperty Path

if (-not $candidates) {
    Write-Warning "Pattern not found in any *.js bundle under $($extDir.Name)."
    Write-Host   "Expected literal: $findProbe"
    Write-Host   "The minified form may have changed in this extension version."
    Write-Host   "Nothing was modified."
    Write-Host   "Please open an issue so the script can be updated:"
    Write-Host   "  https://github.com/nthansen/funbox-plugins/issues"
    exit 2
}

$enc          = New-Object System.Text.UTF8Encoding($false)   # UTF-8, no BOM
$totalPatched = 0
$totalAlready = 0
$filesPatched = @()

foreach ($path in $candidates) {
    $content = [System.IO.File]::ReadAllText($path)

    $totalAlready += ([regex]::Matches($content, $alreadyPattern)).Count

    $script:fp = 0
    $new = [regex]::Replace($content, $pattern, {
        param($m)
        $script:fp++
        return $m.Result($replacement)
    })

    if ($script:fp -gt 0) {
        $orig = "$path.orig"
        if (-not (Test-Path -LiteralPath $orig)) {
            Copy-Item -LiteralPath $path -Destination $orig   # pristine backup, once
        }
        [System.IO.File]::WriteAllText($path, $new, $enc)
        $totalPatched += $script:fp
        $filesPatched += $path
    }
}

Write-Host ""
if ($totalPatched -gt 0) {
    Write-Host "PATCHED: thinking blocks now default to expanded ($totalPatched site across $($filesPatched.Count) file(s))." -ForegroundColor Green
    $filesPatched | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
    Write-Host "==> Reload the VS Code window: Ctrl+Shift+P -> 'Developer: Reload Window'." -ForegroundColor Yellow
}
elseif ($totalAlready -gt 0) {
    Write-Host "ALREADY PATCHED: thinking blocks already default to expanded. Nothing to do." -ForegroundColor Cyan
}
else {
    Write-Warning "Found the probe but could not isolate the expand-state initializer."
    Write-Host    "The minified form may have changed. Nothing was modified."
    Write-Host    "Please open an issue so the script can be updated:"
    Write-Host    "  https://github.com/nthansen/funbox-plugins/issues"
    exit 2
}
