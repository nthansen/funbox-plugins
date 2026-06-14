#requires -Version 5
<#
.SYNOPSIS
    Restore the VS Code Claude Code extension bundles from their *.js.orig backups,
    optionally limited to one of the two fixes.

.DESCRIPTION
    Finds the *.js.orig backups under the anthropic.claude-code-* extension(s) and
    moves them back over the originals, undoing the patch(es). Each backup is
    classified by a probe so you can revert just one fix:

      display  -> the bundle containing "--thinking-display"      (extension.js)
      expand   -> the bundle containing "areThinkingBlocksExpanded" (webview/index.js)
      both     -> everything (default)

    Backups that match neither probe are left untouched (they are not ours).

.PARAMETER Fix
    Which fix to revert: 'display', 'expand', or 'both' (default).
#>

param(
    [ValidateSet('display', 'expand', 'both')]
    [string]$Fix = 'both'
)

# --- Extensions directory -------------------------------------------------
# Windows (default): %USERPROFILE%\.vscode\extensions
$ExtensionsDir = Join-Path $env:USERPROFILE '.vscode\extensions'
# Linux / WSL alternatives are handled by the bash version.
# --------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

$displayProbe = '--thinking-display'          # identifies the display-fix bundle
$expandProbe  = 'areThinkingBlocksExpanded'   # identifies the expand-fix bundle
$wantDisplay  = $Fix -in @('display', 'both')
$wantExpand   = $Fix -in @('expand', 'both')

if (-not (Test-Path -LiteralPath $ExtensionsDir)) {
    Write-Error "Extensions directory not found: $ExtensionsDir"
    exit 1
}

# Scope to the Claude Code extension(s) only (don't touch unrelated extensions' backups).
$extDirs = Get-ChildItem -LiteralPath $ExtensionsDir -Directory -Filter 'anthropic.claude-code-*'
if (-not $extDirs) {
    Write-Host "No anthropic.claude-code-* extension found under $ExtensionsDir. Nothing to restore."
    exit 0
}

$origs = $extDirs | ForEach-Object {
    Get-ChildItem -LiteralPath $_.FullName -Recurse -Filter '*.js.orig' -File
}

if (-not $origs) {
    Write-Host "No *.js.orig backups found. Nothing to restore."
    exit 0
}

Write-Host "Reverting: $Fix"
$restored = 0
$skipped  = 0
foreach ($o in $origs) {
    $content   = [System.IO.File]::ReadAllText($o.FullName)
    $isDisplay = $content.Contains($displayProbe)
    $isExpand  = $content.Contains($expandProbe)
    $target    = $o.FullName.Substring(0, $o.FullName.Length - '.orig'.Length)

    if (($isDisplay -and $wantDisplay) -or ($isExpand -and $wantExpand)) {
        Move-Item -LiteralPath $o.FullName -Destination $target -Force
        $kind = if ($isDisplay) { 'display' } elseif ($isExpand) { 'expand' } else { 'unknown' }
        Write-Host "Restored ($kind) $target"
        $restored++
    }
    else {
        Write-Host "Skipped  $target"
        $skipped++
    }
}

Write-Host ""
if ($restored -gt 0) {
    Write-Host "Restored $restored file(s)$(if ($skipped) { ", left $skipped in place" })." -ForegroundColor Green
    Write-Host "==> Reload the VS Code window: Ctrl+Shift+P -> 'Developer: Reload Window'." -ForegroundColor Yellow
}
else {
    Write-Host "Nothing matched '$Fix'. No files restored." -ForegroundColor Cyan
}
