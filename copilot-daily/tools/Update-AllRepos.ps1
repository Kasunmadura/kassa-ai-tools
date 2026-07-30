# Update-AllRepos.ps1
# Scans every git repo folder directly under a root "GitHub" folder, and for
# each one: fetches, updates the default branch (main/master), and updates
# your own local working branches that track a remote (pull/fast-forward).
# Skips repos with uncommitted changes rather than risking data loss, and
# always returns each repo to the branch it was on before running.
#
# Usage:
#   .\Update-AllRepos.ps1
#   .\Update-AllRepos.ps1 -Root "C:\Users\me\Documents\GitHub"
#   .\Update-AllRepos.ps1 -WhatIf   # just report status, don't fetch/pull

param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot | Split-Path -Parent | Split-Path -Parent),
    [switch]$WhatIf
)

if (-not (Test-Path $Root)) {
    Write-Host "Root folder not found: $Root" -ForegroundColor Red
    exit 1
}

$repos = Get-ChildItem -Path $Root -Directory -Force | Where-Object {
    Test-Path (Join-Path $_.FullName ".git")
}

if ($repos.Count -eq 0) {
    Write-Host "No git repos found directly under $Root" -ForegroundColor Yellow
    exit 0
}

Write-Host "`n=== Update-AllRepos: $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===" -ForegroundColor Cyan
Write-Host "Root: $Root  |  Repos found: $($repos.Count)`n" -ForegroundColor DarkGray

$summary = @()

foreach ($repo in $repos) {
    $path = $repo.FullName
    Write-Host "--- $($repo.Name) ---" -ForegroundColor Yellow
    Push-Location $path
    try {
        $status = git status --porcelain 2>$null
        if ($status) {
            Write-Host "  Skipped: uncommitted changes present." -ForegroundColor DarkYellow
            $summary += [PSCustomObject]@{ Repo = $repo.Name; Result = "Skipped (dirty working tree)" }
            continue
        }

        $originalBranch = git rev-parse --abbrev-ref HEAD 2>$null
        if (-not $originalBranch) {
            Write-Host "  Skipped: could not determine current branch." -ForegroundColor DarkYellow
            $summary += [PSCustomObject]@{ Repo = $repo.Name; Result = "Skipped (no branch)" }
            continue
        }

        if ($WhatIf) {
            Write-Host "  Would fetch + update default branch and local tracking branches (current: $originalBranch)."
            $summary += [PSCustomObject]@{ Repo = $repo.Name; Result = "WhatIf: current branch $originalBranch" }
            continue
        }

        Write-Host "  Fetching all remotes/branches..."
        git fetch --all --prune 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

        # Determine default branch (main or master) from the remote HEAD.
        $defaultBranch = (git remote show origin 2>$null | Select-String "HEAD branch: (.+)").Matches.Groups[1].Value
        if (-not $defaultBranch) { $defaultBranch = "main" }

        # Update the default branch.
        if (git branch --list $defaultBranch) {
            git checkout $defaultBranch 2>&1 | Out-Null
            $pullOut = git pull --ff-only 2>&1
            Write-Host "  $defaultBranch : $pullOut"
        } else {
            Write-Host "  No local '$defaultBranch' branch to update." -ForegroundColor DarkGray
        }

        # Update the user's own local branches that track a remote (skip default, already done).
        $localBranches = git for-each-ref --format='%(refname:short) %(upstream:short)' refs/heads/ 2>$null
        foreach ($line in $localBranches) {
            $parts = $line -split '\s+', 2
            $branch = $parts[0]
            $upstream = if ($parts.Count -gt 1) { $parts[1] } else { $null }
            if (-not $upstream -or $branch -eq $defaultBranch) { continue }
            git checkout $branch 2>&1 | Out-Null
            $pullOut = git pull --ff-only 2>&1
            Write-Host "  $branch : $pullOut"
        }

        # Return to the branch the repo was on originally.
        git checkout $originalBranch 2>&1 | Out-Null
        Write-Host "  Done (back on $originalBranch)." -ForegroundColor Green
        $summary += [PSCustomObject]@{ Repo = $repo.Name; Result = "Updated (default: $defaultBranch)" }
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        $summary += [PSCustomObject]@{ Repo = $repo.Name; Result = "Error: $($_.Exception.Message)" }
    } finally {
        Pop-Location
    }
    Write-Host ""
}

Write-Host "=== Summary ===" -ForegroundColor Cyan
$summary | Format-Table -AutoSize -Wrap
