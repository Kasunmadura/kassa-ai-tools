# JiraHelpers.ps1
# Shared functions for calling a self-hosted Jira (Server/Data Center) REST API
# using a Personal Access Token (Bearer auth).
#
# Setup (one-time):
#   1. Generate a PAT in Jira: Profile picture -> Personal Access Tokens -> Create token
#   2. Store it as a user environment variable (do NOT paste it into any script/chat):
#        setx JIRA_PAT "your-token-here"
#        setx JIRA_BASE_URL "https://tower.catchsoftware.net/jira"
#      Open a NEW terminal afterwards so the env vars are loaded.

function Get-JiraConfig {
    $base = $env:JIRA_BASE_URL
    $pat  = $env:JIRA_PAT
    if (-not $base) { $base = "https://tower.catchsoftware.net/jira" }
    if (-not $pat) {
        throw "JIRA_PAT environment variable is not set. Run: setx JIRA_PAT `"your-token`" then open a new terminal."
    }
    return @{ Base = $base.TrimEnd('/'); Headers = @{ Authorization = "Bearer $pat" } }
}

function Get-JiraIssue {
    param([Parameter(Mandatory)][string]$Key)
    $cfg = Get-JiraConfig
    $uri = "$($cfg.Base)/rest/api/2/issue/$Key"
    Invoke-RestMethod -Uri $uri -Headers $cfg.Headers -Method Get
}

function Get-JiraMyIssues {
    param([string]$ProjectKey = "CHA", [string]$Jql)
    $cfg = Get-JiraConfig
    if (-not $Jql) {
        $Jql = "project = $ProjectKey AND assignee = currentUser() AND statusCategory != Done ORDER BY updated DESC"
    }
    $uri = "$($cfg.Base)/rest/api/2/search"
    $body = @{ jql = $Jql; maxResults = 50; fields = @("summary","status","assignee") } | ConvertTo-Json
    Invoke-RestMethod -Uri $uri -Headers $cfg.Headers -Method Post -ContentType "application/json" -Body $body
}

function Add-JiraComment {
    param([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$Comment)
    $cfg = Get-JiraConfig
    $uri = "$($cfg.Base)/rest/api/2/issue/$Key/comment"
    $body = @{ body = $Comment } | ConvertTo-Json
    Invoke-RestMethod -Uri $uri -Headers $cfg.Headers -Method Post -ContentType "application/json" -Body $body
}

function Get-JiraComments {
    param([Parameter(Mandatory)][string]$Key)
    $cfg = Get-JiraConfig
    $uri = "$($cfg.Base)/rest/api/2/issue/$Key/comment"
    (Invoke-RestMethod -Uri $uri -Headers $cfg.Headers -Method Get).comments
}

function Update-JiraComment {
    param([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$CommentId, [Parameter(Mandatory)][string]$Comment)
    $cfg = Get-JiraConfig
    $uri = "$($cfg.Base)/rest/api/2/issue/$Key/comment/$CommentId"
    $body = @{ body = $Comment } | ConvertTo-Json
    Invoke-RestMethod -Uri $uri -Headers $cfg.Headers -Method Put -ContentType "application/json" -Body $body
}

function Get-JiraTransitions {
    param([Parameter(Mandatory)][string]$Key)
    $cfg = Get-JiraConfig
    $uri = "$($cfg.Base)/rest/api/2/issue/$Key/transitions"
    (Invoke-RestMethod -Uri $uri -Headers $cfg.Headers -Method Get).transitions
}

function Set-JiraTransition {
    param([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$TransitionId)
    $cfg = Get-JiraConfig
    $uri = "$($cfg.Base)/rest/api/2/issue/$Key/transitions"
    $body = @{ transition = @{ id = $TransitionId } } | ConvertTo-Json
    Invoke-RestMethod -Uri $uri -Headers $cfg.Headers -Method Post -ContentType "application/json" -Body $body
}
