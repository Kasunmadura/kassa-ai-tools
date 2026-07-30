# copilot-daily

Structured Copilot CLI setup for the daily Jira ticket + GitHub PR routine,
separated the proper Copilot CLI way:

```
copilot-daily/
├── skills/
│   └── daily-ticket-pr-routine/
│       └── SKILL.md              <- playbook: WHEN and HOW to run the tools
├── tools/
│   ├── JiraHelpers.ps1           <- shared Jira REST API functions
│   ├── List-MyTickets.ps1        <- the executable: quick standalone ticket list
│   ├── Invoke-MorningCheck.ps1   <- the executable: morning ticket/PR overview
│   ├── Invoke-EveningUpdate.ps1  <- the executable: evening Jira comment/status update
│   └── Set-JiraToken.ps1         <- (legacy) persistent user env var token setup
├── prep/
│   ├── Init-LocalSecrets.ps1     <- ONE-TIME: creates local secrets file outside OneDrive
│   ├── prep.ps1                  <- EVERY SESSION: dot-source to load creds (PowerShell)
│   └── prep.sh                   <- EVERY SESSION: source to load creds (bash/WSL)
├── agents/
│   ├── daily-ticket-pr-routine.agent.md   <- subagent dedicated to this routine
│   └── grammar-and-wording-fixer.agent.md <- example: proofreading/wording subagent
└── instructions/
    └── daily-ticket-pr-routine.instructions.md   <- always-on safety rules
```

- **skills/** — markdown guidance Copilot loads when it decides this routine is
  relevant (e.g. you say "run morning check").
- **tools/** — the actual PowerShell scripts that do the work (Jira REST calls,
  `gh` CLI calls). These are what the skill instructs Copilot to execute.
- **agents/** — dedicated subagents (`.agent.md`) that own a specific job end to
  end, run in their own context window, and can be invoked explicitly
  (`/agent daily-ticket-pr-routine`), by name in a prompt, or automatically when
  Copilot infers a match to the agent's `description`.
- **instructions/** — always-on rules (never print secrets, never auto-confirm
  the Jira post, etc.) that apply regardless of whether the skill was triggered.

## Wiring (already done)
- `~/.copilot/skills/daily-ticket-pr-routine` is a **directory junction** pointing
  to `skills/daily-ticket-pr-routine` here, so Copilot CLI discovers the skill
  from its personal skills location while the real files live in this repo folder.
- `~/.copilot/agents` is a **directory junction** pointing to `agents/` here, so
  both custom agents are discovered as personal (user-level) agents.
- The `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` environment variable is set to this
  `instructions/` folder, so Copilot CLI always loads the safety rules.
  (Open a new terminal for the env var to take effect.)

## Using the agents
- `/agent` in interactive mode → pick `daily-ticket-pr-routine` or
  `grammar-and-wording-fixer` from the list.
- Or just ask naturally: *"run morning check"*, *"proofread this PR description"*.
- Or explicitly: *"Use the grammar-and-wording-fixer agent on @notes.txt"*.

## One-time setup still required
1. `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
2. Rotate/generate a Jira Personal Access Token, then create your local,
   non-synced secrets file (lives at `C:\Users\<you>\.jira-daily\secrets.env`,
   **outside OneDrive**, never committed — see `prep\secrets.env.example` in
   this folder for the format reference only, never put real values there):
   ```powershell
   cd .\prep
   .\Init-LocalSecrets.ps1
   ```
   This prompts for the token with masked input and never prints/writes it
   anywhere except that one local file, restricted to your user account.
3. **Every new session**, load the creds into that session before using the
   other tools:
   ```powershell
   cd .\prep
   . .\prep.ps1        # PowerShell — note the leading ". "
   ```
   or, from bash/WSL/git-bash:
   ```bash
   source ./prep/prep.sh
   ```
4. Confirm `gh auth status` is logged in.

## Usage
In Copilot CLI, just say: *"run morning check"* or *"run evening update for CHA-4138"*.
Or run the tools directly:
```powershell
.\tools\Invoke-MorningCheck.ps1
.\tools\Invoke-EveningUpdate.ps1 -TicketKey CHA-4138 -Comment "PLAT env done"
```

## Security
- Credentials (`JIRA_PAT`, `JIRA_BASE_URL`) live **only** in user environment
  variables — set via `tools\Set-JiraToken.ps1`, which prompts with masked
  input and never writes the token to disk or prints it back out.
- No script in this folder hardcodes or logs a token/secret. If you ever add a
  local config/override file, follow the patterns in `.gitignore` (`*.env`,
  `*secret*`, `*token*`, `*credentials*`, `*.pat`, etc.) so it can never be
  committed by accident, even though this folder currently isn't committed.
- If a real token is ever pasted into a chat/log/terminal history by mistake,
  treat it as compromised immediately: revoke it in Jira and generate a new one.
