# prep.ps1
# Dot-source this at the start of a PowerShell session to load Jira creds
# for that session only, from a local file OUTSIDE OneDrive
# (C:\Users\<you>\.jira-daily\secrets.env, never synced, never committed).
#
# Usage:
#   . .\prep.ps1
#
# One-time setup first: .\Init-LocalSecrets.ps1

$secretsFile = Join-Path $env:USERPROFILE ".jira-daily\secrets.env"

if (-not (Test-Path $secretsFile)) {
    Write-Host "Secrets file not found: $secretsFile" -ForegroundColor Red
    Write-Host "Run '.\Init-LocalSecrets.ps1' first (one-time setup)." -ForegroundColor Yellow
    return
}

Get-Content $secretsFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
    $name, $value = $_.Split('=', 2)
    Set-Item -Path "Env:$name" -Value $value
}

if ($env:JIRA_PAT) {
    Write-Host "Jira credentials loaded for this session (JIRA_BASE_URL=$env:JIRA_BASE_URL)." -ForegroundColor Green
} else {
    Write-Host "JIRA_PAT was not found in $secretsFile." -ForegroundColor Red
}
