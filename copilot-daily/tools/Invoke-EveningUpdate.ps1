# Invoke-EveningUpdate.ps1
# Run each evening: builds a summary of recent GitHub activity (real commit
# messages, not just PR titles), lets you add your own extra comment, and
# posts it all to the Jira ticket. Optionally also transitions the status.
#
# Usage examples:
#   pwsh .\Invoke-EveningUpdate.ps1 -TicketKey CHA-4138
#   pwsh .\Invoke-EveningUpdate.ps1 -TicketKey CHA-4138 -Comment "Blocked on DBA access, will chase tomorrow"
#   pwsh .\Invoke-EveningUpdate.ps1 -TicketKey CHA-4138 -Comment "PLAT env done" -Transition
#   pwsh .\Invoke-EveningUpdate.ps1 -TicketKey CHA-4138 -SinceDays 2
#
# Notes:
#   -TicketKey  : Jira issue key. If omitted, the script tries to detect it from the
#                 current git branch name (e.g. feature/CHA-4138-something -> CHA-4138).
#   -Comment    : Your own free-text note to append to the auto-generated summary.
#                 If omitted, you'll be prompted interactively (press Enter to skip).
#   -Transition : Switch. If set, shows available Jira transitions and lets you pick one.
#   -Repo       : Restrict the GitHub activity summary to one repo. Default: all repos
#                 you've been active in recently.
#   -SinceDays  : How many days back to look for PR/commit activity. Default 1 (yesterday
#                 onward), since "today" alone often misses work merged the day before.
#                 The summary lists each PR plus its real commit messages (excluding
#                 merge commits) so it reflects actual technical work done, not just titles.

param(
    [string]$TicketKey,
    [string]$Comment,
    [switch]$Transition,
    [string]$Repo,
    [int]$SinceDays = 1
)

. "$PSScriptRoot\JiraHelpers.ps1"

# ---- 1. Work out which ticket we're updating ----
if (-not $TicketKey) {
    try {
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        if ($branch -match '([A-Z]+-\d+)') {
            $TicketKey = $Matches[1]
            Write-Host "Detected ticket from branch name: $TicketKey" -ForegroundColor DarkGray
        }
    } catch {}
}
if (-not $TicketKey) {
    $TicketKey = Read-Host "Enter Jira ticket key to update (e.g. CHA-4138)"
}
if (-not $TicketKey) {
    Write-Host "No ticket key given, aborting." -ForegroundColor Red
    exit 1
}

# ---- 1b. Guard: never update Backlog tickets — only current-sprint work ----
try {
    $issue = Get-JiraIssue -Key $TicketKey
    $statusName = $issue.fields.status.name
    if ($statusName -match '^(Backlog|To Do)$') {
        Write-Host "`n$TicketKey is in '$statusName' (not in the current sprint)." -ForegroundColor Red
        Write-Host "This tool only updates tickets that are actively in progress this sprint. Aborting." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Could not verify $TicketKey status before updating: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ---- 2. Build an auto-summary of recent GitHub activity, based on actual
#         commit messages (not just PR titles), across the last $SinceDays day(s) ----
$since = (Get-Date).Date.AddDays(-$SinceDays).ToString("yyyy-MM-dd")
$summaryLines = @()

if ($Repo) {
    $commits = gh api "repos/$Repo/commits?author=@me&since=$($since)T00:00:00Z" --jq '.[].commit.message' 2>$null
    if ($commits) { $summaryLines += ($commits | ForEach-Object { "- $_" -replace "`n.*", "" }) }
} else {
    $prsRecent = gh search prs --author=@me --updated ">=$since" --json repository,number,title,state,url --limit 50 | ConvertFrom-Json
    foreach ($p in $prsRecent) {
        $repoName = $p.repository.nameWithOwner
        $summaryLines += "- [$repoName #$($p.number)] $($p.title) ($($p.state)) - $($p.url)"

        # Pull the actual commit messages for this PR so the summary reflects
        # real technical detail (e.g. "added reusable workflow", "added security
        # scanning") instead of just repeating the PR title.
        $commitMsgs = gh pr view $p.number --repo $repoName --json commits --jq '.commits[].messageHeadline' 2>$null
        if ($commitMsgs) {
            foreach ($cm in $commitMsgs) {
                if ($cm -and $cm -notmatch '^Merge pull request') {
                    $summaryLines += "    - $cm"
                }
            }
        }
    }
}

Write-Host "`n--- Auto-generated summary of recent GitHub activity (last $SinceDays day(s)) ---" -ForegroundColor Yellow
if ($summaryLines.Count -eq 0) {
    Write-Host "(no GitHub activity detected today)"
} else {
    $summaryLines | ForEach-Object { Write-Host $_ }
}

# ---- 3. Ask for additional comment if not passed as a parameter ----
if (-not $PSBoundParameters.ContainsKey('Comment')) {
    $Comment = Read-Host "`nAdd any additional comment for the ticket (press Enter to skip)"
}

# ---- 4. Compose final comment ----
$today = Get-Date -Format "yyyy-MM-dd"
$body = "Daily update ($today):`n"
if ($summaryLines.Count -gt 0) {
    $body += ($summaryLines -join "`n") + "`n"
}
if ($Comment) {
    $body += "`nNote: $Comment"
}

Write-Host "`n--- Comment to be posted to $TicketKey ---" -ForegroundColor Cyan
Write-Host $body
$confirm = Read-Host "`nPost this to Jira? (y/N)"
if ($confirm -ne 'y') {
    Write-Host "Cancelled. Nothing was posted." -ForegroundColor Red
    exit 0
}

try {
    Add-JiraComment -Key $TicketKey -Comment $body | Out-Null
    Write-Host "Comment posted to $TicketKey." -ForegroundColor Green
} catch {
    Write-Host "Failed to post comment: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ---- 5. Optional: transition the ticket's status ----
if ($Transition) {
    $transitions = Get-JiraTransitions -Key $TicketKey
    Write-Host "`nAvailable transitions for $TicketKey :" -ForegroundColor Yellow
    for ($i = 0; $i -lt $transitions.Count; $i++) {
        Write-Host "  [$i] $($transitions[$i].name)"
    }
    $choice = Read-Host "Pick a transition number (or Enter to skip)"
    if ($choice -match '^\d+$' -and [int]$choice -lt $transitions.Count) {
        Set-JiraTransition -Key $TicketKey -TransitionId $transitions[[int]$choice].id
        Write-Host "$TicketKey moved to '$($transitions[[int]$choice].name)'." -ForegroundColor Green
    }
}
