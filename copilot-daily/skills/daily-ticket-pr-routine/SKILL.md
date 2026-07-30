---
name: daily-ticket-pr-routine
description: Runs the user's daily morning and evening routine for managing Jira tickets (project CHA on the self-hosted Jira at tower.catchsoftware.net) and reviewing GitHub PRs across all repos. Use this when the user asks to "run morning check", "run my daily check", "check my tickets and PRs", "run evening update", "update my ticket", or similar daily standup / status-update requests.
license: MIT
allowed-tools: powershell
---

# Daily Ticket & PR Routine

This skill is the *playbook*: it tells Copilot when and how to invoke the actual
executable tools for this routine. The tools themselves (PowerShell scripts) live
in the sibling `tools/` folder, one level up from this skill folder:
`..\..\tools\`. Always-on safety rules for this routine live in
`..\..\instructions\daily-ticket-pr-routine.instructions.md`.

## Prerequisites (one-time, already documented for the user)
- `JIRA_PAT` and `JIRA_BASE_URL` environment variables must be set (Bearer PAT auth
  against the self-hosted Jira instance).
- `gh` CLI must be authenticated (`gh auth status`).
- PowerShell execution policy must allow local scripts
  (`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`).
If any of these are missing, tell the user what's missing rather than guessing.

## List my tickets — "list my tickets" / "what tickets do I have"
For a quick standalone ticket list (no PR info), execute:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-folder>\..\..\tools\List-MyTickets.ps1"
```

Optional parameters: `-ProjectKey <KEY>` (default `CHA`), `-Status "In Progress"`,
`-IncludeDone`, or a raw `-Jql "..."` override.

## Update all repos — "update my repos" / "pull latest for all repos"
Scans every git repo directly under the GitHub root folder, fetches, updates
each repo's default branch (main/master), and updates the user's own local
branches that track a remote — always returning each repo to whatever branch
it was on. Repos with uncommitted changes are skipped (never stashed/discarded
automatically).

**This now also runs automatically** via a Copilot CLI `sessionStart` hook (see
`..\..\hooks\session-start-repo-sync.json` +
`..\..\hooks\Invoke-SessionStartRepoSync.ps1`, registered in
`~\.copilot\hooks\` via a directory junction). It fires once per new
interactive CLI session and injects a repo-sync summary into context, so by
the time the user asks for the morning check, all repos are typically already
fresh. Manual invocation (below) is still useful mid-session or if the hook
was skipped (e.g. a resumed session).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-folder>\..\..\tools\Update-AllRepos.ps1"
```

Optional: `-WhatIf` to preview which repos/branches would be touched without
actually fetching/pulling. `-Root <path>` to point at a different folder
(defaults to the parent "GitHub" folder above this skill's location).

## Morning routine — "run morning check"
Execute the morning tool with the powershell tool and show the full output:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-folder>\..\..\tools\Invoke-MorningCheck.ps1"
```

This lists:
- Open Jira tickets in project CHA assigned to the user
- All GitHub PRs (across every repo the user can access) waiting on their review
- All of the user's own open GitHub PRs

## Evening routine — "run evening update" / "update my ticket"
Execute the evening tool. This tool is INTERACTIVE (it prompts for an optional
extra comment and asks for y/N confirmation before posting) — run it and relay
its prompts to the user:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-folder>\..\..\tools\Invoke-EveningUpdate.ps1" -TicketKey <KEY> -Comment "<free text comment>"
```

Optional switches:
- `-Transition` — after posting the comment, lets the user pick a new Jira status.
- `-Repo <owner/repo>` — restrict the auto-generated activity summary to one repo
  (default is a summary across all repos the user is active in today).
- `-SinceDays <n>` — how many days back to pull PR/commit activity from (default 1).

The tool refuses to update tickets whose status is Backlog or To Do (i.e. not
in the current sprint) — do not try to work around this by calling
`Add-JiraComment` directly on such a ticket.

If the user doesn't give a ticket key, the tool tries to detect it from the
current git branch name (pattern `[A-Z]+-\d+`); otherwise it prompts for one.
