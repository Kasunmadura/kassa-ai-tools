# kassa-ai-tools

This repo is my personal **GitHub Copilot CLI toolkit** for running the two
things I do every single working day — chasing Jira tickets and keeping on
top of GitHub pull requests — without having to remember a dozen manual
steps or re-explain the same context to Copilot every session.

Instead of a folder of ad-hoc scripts, everything here is wired into
Copilot CLI's own extension points:

- **Skills** — step-by-step playbooks that tell Copilot *when* and *how* to
  run a tool (e.g. "when asked for a morning check, run these two scripts in
  this order").
- **Agents** — named subagents (`daily-ticket-pr-routine`,
  `grammar-and-wording-fixer`) that own a whole task end-to-end, each pinned
  to the model best suited to it (fast/cheap for mechanical work, stronger
  reasoning for judgment calls).
- **Instructions** — always-on guardrails Copilot must never violate, such
  as refusing to move or comment on Backlog/To Do Jira tickets.
- **Hooks** — automation that fires on its own at session start/end (sync
  all my repos before I start working, push anything left uncommitted when
  the session ends).
- **Tools** — the actual PowerShell scripts that talk to Jira and GitHub.

The net effect: I open Copilot CLI, say "run morning check" or "update
CHA-1234", and it handles the Jira/GitHub mechanics itself using the rules
and scripts defined in this repo — consistently, the same way, every time.

## What's in here

```
kassa-ai-tools/
├── .github/
│   └── copilot-instructions.md     <- repo-level Copilot instructions (architecture, conventions)
└── copilot-daily/                  <- the toolkit itself
    ├── skills/                     <- playbooks: WHEN/HOW to run each tool
    ├── agents/                     <- custom subagents (.agent.md) that own a task end-to-end
    ├── instructions/               <- always-on safety rules (e.g. never touch Backlog tickets)
    ├── hooks/                      <- Copilot CLI hooks (auto-run at session start/end)
    ├── tools/                      <- the actual PowerShell scripts doing the work
    └── prep/                       <- one-time/per-session credential setup (secrets never committed)
```

See `copilot-daily/README.md` for the full folder-by-folder breakdown and
setup instructions, and `.github/copilot-instructions.md` for the deeper
architecture notes Copilot itself reads.

## Capabilities at a glance

**Jira (project CHA, self-hosted at tower.catchsoftware.net):**
- List my current tickets
- Morning check — tickets + GitHub PRs needing attention
- Evening update — post a status comment to a ticket, auto-summarizing the
  day's commits/PRs, with a hard guard that refuses to touch Backlog/To Do
  tickets

**GitHub:**
- Review-requested and authored PRs across *all* repos, not just one
- `Update-AllRepos` — fetch + fast-forward every repo's default branch and my
  own working branches, skipping any repo with uncommitted changes
- `Push-MyWorkChanges` — commit and push any pending changes in this repo

**Automation (Copilot CLI hooks):**
- `sessionStart` → runs `Update-AllRepos` automatically so repos are fresh
  before the day's work starts
- `sessionEnd` → runs `Push-MyWorkChanges` automatically so edits made during
  the session are never left unpushed

**Agents** (`/agent <name>` or invoked automatically by description):
- `daily-ticket-pr-routine` (model: `sonnet`) — runs the Jira/PR routine
- `grammar-and-wording-fixer` (model: `haiku`) — proofreads text in a
  Principal DevOps Engineer voice

## Quick start
1. `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
2. Set up local Jira credentials (outside OneDrive, never committed):
   ```powershell
   cd copilot-daily\prep
   .\Init-LocalSecrets.ps1
   ```
3. Each session, load credentials: `. .\prep.ps1` (or `source ./prep/prep.sh`)
4. Confirm `gh auth status` is logged in
5. Ask Copilot CLI: *"run morning check"*, *"list my tickets"*, *"update my repos"*

## Security
- No secrets are ever committed — see `.gitignore` (`*.env`, `*secret*`,
  `*token*`, `*credentials*`, `*.pat`).
- Real Jira credentials live only at `~/.jira-daily/secrets.env`, outside any
  OneDrive-synced folder.
- Any token accidentally pasted into chat/logs is treated as compromised and
  rotated immediately.
