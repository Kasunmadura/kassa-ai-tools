# Invoke-SessionStartRepoSync.ps1
# Wrapper invoked by the Copilot CLI "sessionStart" hook (see ../hooks/session-start-repo-sync.json).
# Runs Update-AllRepos.ps1 quietly for real (no -WhatIf) and emits a single JSON line with
# "additionalContext" summarizing results, so the CLI session opens already aware of what
# was updated/skipped. Never throws on individual repo errors - Update-AllRepos.ps1 already
# skips dirty repos safely and reports per-repo results.
#
# Only used as a hook entry point. For manual/interactive use, call
# ..\tools\Update-AllRepos.ps1 directly instead (it prints full colored output).

$ErrorActionPreference = "SilentlyContinue"

$updateScript = Join-Path $PSScriptRoot "..\tools\Update-AllRepos.ps1"

try {
    $output = & $updateScript 2>&1 | Out-String
} catch {
    $output = "Update-AllRepos.ps1 failed to run: $($_.Exception.Message)"
}

# Pull out just the summary table lines (after "=== Summary ===") to keep the
# injected context short.
$summaryIndex = $output.IndexOf("=== Summary ===")
$context = if ($summaryIndex -ge 0) {
    $output.Substring($summaryIndex)
} else {
    $output
}

$context = $context.Trim()
if ($context.Length -gt 1500) {
    $context = $context.Substring(0, 1500) + "`n...(truncated)"
}

$payload = @{
    additionalContext = "Daily repo sync ran at session start:`n$context"
} | ConvertTo-Json -Compress

Write-Output $payload
