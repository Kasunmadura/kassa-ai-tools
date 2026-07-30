# List-MyTickets.ps1
# Lists Jira tickets assigned to you. Standalone tool (separate from the full
# morning check) for when you just want a quick ticket list.
#
# Usage:
#   .\List-MyTickets.ps1
#   .\List-MyTickets.ps1 -ProjectKey CHA
#   .\List-MyTickets.ps1 -Status "In Progress"
#   .\List-MyTickets.ps1 -IncludeDone
#   .\List-MyTickets.ps1 -Jql "project = CHA AND sprint in openSprints()"

param(
    [string]$ProjectKey = "CHA",
    [string]$Status,
    [switch]$IncludeDone,
    [string]$Jql
)

. "$PSScriptRoot\JiraHelpers.ps1"

if (-not $Jql) {
    $Jql = "project = $ProjectKey AND assignee = currentUser()"
    if ($Status) {
        $Jql += " AND status = `"$Status`""
    } elseif (-not $IncludeDone) {
        $Jql += " AND statusCategory != Done"
    }
    $Jql += " ORDER BY updated DESC"
}

Write-Host "`n=== My Jira Tickets ($ProjectKey) - $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===" -ForegroundColor Cyan
Write-Host "JQL: $Jql`n" -ForegroundColor DarkGray

try {
    $result = Get-JiraMyIssues -ProjectKey $ProjectKey -Jql $Jql
    if (-not $result.issues -or $result.issues.Count -eq 0) {
        Write-Host "No matching tickets found."
    } else {
        $result.issues | ForEach-Object {
            [PSCustomObject]@{
                Key      = $_.key
                Status   = $_.fields.status.name
                Assignee = $_.fields.assignee.displayName
                Summary  = $_.fields.summary
            }
        } | Format-Table -AutoSize -Wrap
        Write-Host "Total: $($result.issues.Count) ticket(s)" -ForegroundColor Green
    }
} catch {
    Write-Host "Could not reach Jira: $($_.Exception.Message)" -ForegroundColor Red
}
