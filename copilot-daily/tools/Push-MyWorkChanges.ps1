# Push-MyWorkChanges.ps1
# Commits and pushes any pending changes in the "mywork" repo
# (github.com:Kasunmadura/kassa-ai-tools, branch main) to origin.
#
# The mywork repo root is 3 levels up from this script:
#   tools -> copilot-daily -> mywork
#
# Usage:
#   .\Push-MyWorkChanges.ps1                          # auto-generated commit message
#   .\Push-MyWorkChanges.ps1 -Message "custom message"
#   .\Push-MyWorkChanges.ps1 -WhatIf                  # just show what would be committed/pushed

param(
    [string]$Message,
    [switch]$WhatIf
)

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

if (-not (Test-Path (Join-Path $repoRoot ".git"))) {
    Write-Host "Not a git repo: $repoRoot" -ForegroundColor Red
    exit 1
}

Push-Location $repoRoot
try {
    $status = git status --porcelain
    if (-not $status) {
        Write-Host "No changes to push. Working tree clean in $repoRoot." -ForegroundColor Green
        exit 0
    }

    Write-Host "=== Pending changes in mywork ===" -ForegroundColor Cyan
    git status --short

    if ($WhatIf) {
        Write-Host "`n(WhatIf) Would stage, commit, and push these changes to origin main." -ForegroundColor Yellow
        exit 0
    }

    git add -A

    if (-not $Message) {
        # Build a short auto-summary from the changed file list.
        $changedFiles = ($status | ForEach-Object { ($_ -split '\s+', 3)[-1] }) -join ", "
        if ($changedFiles.Length -gt 200) { $changedFiles = $changedFiles.Substring(0, 200) + "..." }
        $Message = "Update copilot-daily toolkit: $changedFiles"
    }

    git commit -m $Message
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Commit failed." -ForegroundColor Red
        exit 1
    }

    git push origin main
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Push failed." -ForegroundColor Red
        exit 1
    }

    Write-Host "Pushed to origin main." -ForegroundColor Green
} finally {
    Pop-Location
}
