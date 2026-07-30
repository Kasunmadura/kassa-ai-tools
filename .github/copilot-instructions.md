# Copilot instructions for this repository

This repo (`mywork`) contains **`copilot-daily`**: a personal Copilot CLI skill
+ agent + tool setup for a daily Jira ticket / GitHub PR routine. There is no
application source code here — everything is Copilot CLI tooling and
PowerShell scripts. `mywork` itself is not a standalone git repo (its `.git`
root resolves to the parent user profile directory), so avoid assuming normal
repo-root git behavior.

## Architecture

`copilot-daily/` is deliberately split into four roles that Copilot CLI treats
differently — when adding a new daily-routine capability, decide which of
these it belongs in rather than lumping logic into one file:

- `skills/daily-ticket-pr-routine/SKILL.md` — the playbook: *when* to trigger
  and *which* tool to call. Contains no executable logic itself.
- `tools/*.ps1` — the actual executables (Jira REST calls via `JiraHelpers.ps1`,
  `gh` CLI calls). `JiraHelpers.ps1` is dot-sourced by every other tool script
  (`Invoke-MorningCheck.ps1`, `Invoke-EveningUpdate.ps1`, `List-MyTickets.ps1`)
  for its `Get-JiraConfig` / `Add-JiraComment` / `Get-JiraTransitions` /
  `Set-JiraTransition` functions — it is never run directly.
- `agents/*.agent.md` — subagents that own a task end-to-end in their own
  context window (`daily-ticket-pr-routine`, `grammar-and-wording-fixer`).
- `instructions/*.instructions.md` — always-on safety rules, loaded via the
  `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` env var (not a well-known instructions
  path), independent of whether the skill/agent was triggered.

Discovery is wired through **directory junctions**, not copies:
`~/.copilot/skills/daily-ticket-pr-routine` → `copilot-daily/skills/daily-ticket-pr-routine`,
and `~/.copilot/agents` → `copilot-daily/agents`. The real files live only in
this repo folder; editing the junction target is the same as editing the
"registered" copy. There is no build step — CLI discovery just re-reads these
directories.

## Credential handling (critical, non-obvious)

This whole folder lives inside a **OneDrive-synced** path. Any plaintext
secret saved under `copilot-daily/` auto-uploads to OneDrive the instant it's
saved, regardless of `.gitignore`. Because of this, credentials are
deliberately kept **outside** the repo:

- Real Jira credentials live at `C:\Users\<user>\.jira-daily\secrets.env`
  (outside OneDrive, `KEY=VALUE` lines: `JIRA_PAT`, `JIRA_BASE_URL`).
- `prep/Init-LocalSecrets.ps1` creates that file with masked input (never
  echoes/writes the token elsewhere); `prep/prep.ps1` (dot-source) /
  `prep/prep.sh` (source) load it into the current shell session only.
- `prep/secrets.env.example` in this repo is a template only — never put real
  values in anything under `copilot-daily/`.
- `tools/Set-JiraToken.ps1` is an older, still-functional alternative that
  stores the token as a persistent Windows user env var instead of a file.
- If a real token ever ends up pasted in chat or committed, treat it as
  compromised and rotate it in Jira immediately — don't just delete the copy.

## Conventions specific to these scripts

- All Jira REST calls target a self-hosted Jira Server/Data Center instance
  (`https://tower.catchsoftware.net/jira`, project key `CHA`), authenticated
  with **Bearer PAT** (`Authorization: Bearer $env:JIRA_PAT`) via
  `Invoke-RestMethod` against `rest/api/2/...` endpoints — not Atlassian Cloud
  Basic auth.
- GitHub data comes from the `gh` CLI (`gh search prs`, `gh api`), not a
  GitHub App/token — it relies on the user's existing `gh auth login` session.
- `Invoke-EveningUpdate.ps1` auto-detects the Jira ticket key from the current
  git branch name (regex `[A-Z]+-\d+`) if `-TicketKey` isn't passed, and always
  gates the actual Jira POST behind an interactive `y/N` confirmation — never
  bypass or auto-answer this prompt when driving the script programmatically.
- Every script is written to run standalone via
  `powershell -NoProfile -ExecutionPolicy Bypass -File <script>` since the
  user's default execution policy may block scripts.

## Running the tools

There is no test suite or build/lint config in this repo. To exercise a
script, run it directly, e.g.:
```powershell
. .\copilot-daily\prep\prep.ps1        # load creds for this session first
.\copilot-daily\tools\List-MyTickets.ps1 -ProjectKey CHA
.\copilot-daily\tools\Invoke-MorningCheck.ps1
.\copilot-daily\tools\Invoke-EveningUpdate.ps1 -TicketKey CHA-4138 -Comment "..."
```
Syntax-only validation (no execution, works even when the execution policy
blocks running scripts) uses the PowerShell parser directly:
```powershell
[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)
```
