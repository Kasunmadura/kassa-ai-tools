# Invoke-MorningCheck.ps1
# Run each morning: shows your open Jira tickets + GitHub PRs needing attention
# across ALL repos you have access to (not just one repo).
#
# Usage:
#   pwsh .\Invoke-MorningCheck.ps1

param(
    [string]$JiraProjectKey = "CHA"
)

. "$PSScriptRoot\JiraHelpers.ps1"

Write-Host "`n=== MORNING CHECK: $(Get-Date -Format 'yyyy-MM-dd') ===" -ForegroundColor Cyan

Write-Host "`n--- Jira: My open tickets ($JiraProjectKey) ---" -ForegroundColor Yellow
try {
    $issues = Get-JiraMyIssues -ProjectKey $JiraProjectKey
    if ($issues.issues.Count -eq 0) {
        Write-Host "No open tickets assigned to you."
    } else {
        foreach ($i in $issues.issues) {
            Write-Host ("{0,-10} [{1,-12}] {2}" -f $i.key, $i.fields.status.name, $i.fields.summary)
        }
    }
} catch {
    Write-Host "Could not reach Jira: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Board fallback: https://tower.catchsoftware.net/jira/secure/RapidBoard.jspa?rapidView=559&projectKey=$JiraProjectKey"
}

Write-Host "`n--- GitHub: PRs waiting on your review (all repos) ---" -ForegroundColor Yellow
$reviewJson = gh search prs --review-requested=@me --state open --json repository,number,title,author,updatedAt --limit 50 | ConvertFrom-Json
if (-not $reviewJson -or $reviewJson.Count -eq 0) {
    Write-Host "Nothing awaiting your review. Nice."
} else {
    foreach ($p in $reviewJson) {
        Write-Host ("{0,-45} #{1,-5} {2}  (by {3})" -f $p.repository.nameWithOwner, $p.number, $p.title, $p.author.login)
    }
}

Write-Host "`n--- GitHub: Your own open PRs (all repos) ---" -ForegroundColor Yellow
$myJson = gh search prs --author=@me --state open --json repository,number,title,isDraft,updatedAt --limit 50 | ConvertFrom-Json
if (-not $myJson -or $myJson.Count -eq 0) {
    Write-Host "You have no open PRs."
} else {
    foreach ($p in $myJson) {
        $draft = if ($p.isDraft) { " [DRAFT]" } else { "" }
        Write-Host ("{0,-45} #{1,-5} {2}{3}" -f $p.repository.nameWithOwner, $p.number, $p.title, $draft)
    }
}

Write-Host "`nDone. Have a good day!`n" -ForegroundColor Cyan
