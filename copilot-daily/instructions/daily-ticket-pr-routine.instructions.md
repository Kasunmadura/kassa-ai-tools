---
applyTo: "**"
---

# Daily Ticket & PR Routine — Safety Rules

These rules always apply whenever the `daily-ticket-pr-routine` skill or its
tools (`tools/Invoke-MorningCheck.ps1`, `tools/Invoke-EveningUpdate.ps1`,
`tools/JiraHelpers.ps1`) are used:

- Never print, log, or repeat the value of `JIRA_PAT`, `JIRA_BASE_URL` credentials,
  or any other token/secret, even partially.
- Never fabricate a "yes" confirmation on the user's behalf. The evening tool
  gates posting a Jira comment behind an explicit y/N prompt — always let the
  real user answer it; do not bypass or auto-confirm it.
- Do not auto-post PR review comments on GitHub. This routine only lists PRs
  needing attention (authored by / review-requested for the user) — the user
  reviews and comments manually.
- If a real secret/token is ever pasted into chat by mistake, tell the user to
  treat it as compromised and rotate/revoke it immediately — do not reuse it.
- If `JIRA_PAT`, `JIRA_BASE_URL`, or `gh auth` are missing/invalid, report the
  missing prerequisite clearly instead of guessing values or silently failing.
- Never post a status/comment update to a ticket that is in Backlog / To Do
  (not in the current sprint). Only update tickets that are actively in
  progress (or otherwise past Backlog) this sprint. `Invoke-EveningUpdate.ps1`
  enforces this itself, but never bypass it or update a Backlog ticket manually
  via `Add-JiraComment`/`Update-JiraComment` either.
