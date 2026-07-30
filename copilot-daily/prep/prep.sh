#!/usr/bin/env bash
# prep.sh
# Source this at the start of a bash/WSL/git-bash session to load Jira creds
# for that session only, from a local file OUTSIDE OneDrive
# (~/.jira-daily/secrets.env on Linux/WSL, or /mnt/c/Users/<you>/.jira-daily/secrets.env
# when accessing the Windows home dir from WSL).
#
# Usage:
#   source ./prep.sh
#
# One-time setup first (from PowerShell): ./Init-LocalSecrets.ps1

SECRETS_FILE="$HOME/.jira-daily/secrets.env"

# Fallback: if running under WSL and the Windows-side file exists, use that instead.
if [ ! -f "$SECRETS_FILE" ] && [ -n "$WSL_DISTRO_NAME" ]; then
    WIN_USER="$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')"
    if [ -n "$WIN_USER" ] && [ -f "/mnt/c/Users/$WIN_USER/.jira-daily/secrets.env" ]; then
        SECRETS_FILE="/mnt/c/Users/$WIN_USER/.jira-daily/secrets.env"
    fi
fi

if [ ! -f "$SECRETS_FILE" ]; then
    echo "Secrets file not found: $SECRETS_FILE"
    echo "Run './Init-LocalSecrets.ps1' first (one-time setup, from PowerShell)."
    return 1 2>/dev/null || exit 1
fi

set -a
# shellcheck disable=SC1090
source "$SECRETS_FILE"
set +a

if [ -n "$JIRA_PAT" ]; then
    echo "Jira credentials loaded for this session (JIRA_BASE_URL=$JIRA_BASE_URL)."
else
    echo "JIRA_PAT was not found in $SECRETS_FILE."
fi
