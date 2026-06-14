#requires -Version 5
<#
.SYNOPSIS
    Patch the VS Code Claude Code extension so omitted thinking-display defaults
    to "summarized" (so Opus/Fable thinking renders).

.DESCRIPTION
    Works around the bug where newer models can resolve a thinking config whose
    `display` is omitted/undefined, so the extension never passes
    --thinking-display to the CLI and thinking arrives empty.

    Rather than touching each individual thinking-config branch, this patches the
    single chokepoint where the flag is emitted:

        if(<l>.type!=="disabled"&&<l>.display)<B>.push("--thinking-display",<l>.display)
                                  ^^^^^^^^^^^^                              ^^^^^^^^^^^
    becomes:

        if(<l>.type!=="disabled")<B>.push("--thinking-display",<l>.display??"summarized")

    This covers EVERY config shape (enabled, adaptive, fallback, and any future
    one): anything with an omitted display gets "summarized", while an explicit
    display value is preserved. The minified identifiers (l, B) are matched by
    shape with a backreference, so they survive renames across builds.

    Idempotent: a chokepoint already ending in `.display??"summarized")` is left
    alone. A single pristine *.js.orig backup is made per file the first time it
    is actually modified. Reverse with restore-vscode-thinking.ps1.

    NOTE: If you previously applied the older per-branch version of this patch,
    run restore-vscode-thinking.ps1 first to get a pristine file, then re-run
    this script. The two approaches touch different locations.
#>

# --- Extensions directory -------------------------------------------------
# Windows (default): %USERPROFILE%\.vscode\extensions
$ExtensionsDir = Join-Path $env:USERPROFILE '.vscode\extensions'
# Linux / WSL alternatives (handled by the bash version, shown here for reference):
#   ~/.vscode-server/extensions               # VS Code Server / Remote-SSH / WSL backend
#   ~/.vscode/extensions                       # native Linux VS Code
#   /mnt/c/Users/<you>/.vscode/extensions      # WSL reaching the Windows install
# --------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

# Stable literal used to locate candidate bundles.
$findProbe = '--thinking-display'

# The flag-emitting chokepoint. Group 1 = thinking-config var, group 2 = argv array.
# Identifiers are matched generically (with a backreference) to survive minifier renames.
$pattern = 'if\(([A-Za-z_$][\w$]*)\.type!=="disabled"&&\1\.display\)([A-Za-z_$][\w$]*)\.push\("--thinking-display",\1\.display\)'
$replacement = 'if(${1}.type!=="disabled")${2}.push("--thinking-display",${1}.display??"summarized")'

# Recognises an already-patched chokepoint (so re-runs are no-ops).
$alreadyPattern = '\.push\("--thinking-display",[A-Za-z_$][\w$]*\.display\?\?"summarized"\)'

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

# Find bundles that contain the probe (fast: stops at first hit per file).
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

    $script:fp = 0   # patched in this file
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
    Write-Host "PATCHED: $totalPatched chokepoint(s) across $($filesPatched.Count) file(s)." -ForegroundColor Green
    $filesPatched | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
    Write-Host "==> Reload the VS Code window: Ctrl+Shift+P -> 'Developer: Reload Window'." -ForegroundColor Yellow
}
elseif ($totalAlready -gt 0) {
    Write-Host "ALREADY PATCHED: $totalAlready chokepoint(s) already default display to `"summarized`". Nothing to do." -ForegroundColor Cyan
}
else {
    # Probe matched a file but the chokepoint shape could not be rewritten.
    Write-Warning "Found the literal but could not isolate the --thinking-display chokepoint."
    Write-Host    "The minified form may have changed. Nothing was modified."
    Write-Host    "Please open an issue so the script can be updated:"
    Write-Host    "  https://github.com/nthansen/funbox-plugins/issues"
    exit 2
}
