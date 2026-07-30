---
name: push-mywork-changes
description: Commits and pushes any pending code/file changes in the "mywork" repo (github.com:Kasunmadura/kassa-ai-tools, branch main - the copilot-daily toolkit itself) to origin. Use this whenever the assistant has just created/edited files under the mywork folder (scripts, skills, agents, instructions, hooks, docs), or when the user asks to "push my changes", "push mywork", "sync this to github", "commit and push", or similar.
license: MIT
allowed-tools: powershell
---

# Push MyWork Changes

This skill keeps the `mywork` repo (https://github.com/Kasunmadura/kassa-ai-tools,
branch `main`) in sync with local edits. The `mywork` folder is a real,
independent git repo (separate from the parent OneDrive folder structure),
with `origin` pointing at `git@github.com:Kasunmadura/kassa-ai-tools.git` over
SSH (key: `~/.ssh/id_ed25519_kasunmadura`, configured as the default identity
for `github.com` in `~/.ssh/config`).

## When to run this
- **Automatically, right after making any code change** to files under
  `mywork\` (e.g. editing a tool script, updating SKILL.md/agent.md/instructions,
  adding a new tool or hook) as part of finishing that task - don't leave
  local edits unpushed.
- **On explicit request** - "push my changes", "push mywork", "sync to github",
  "commit and push".
- **Automatically at the end of every Copilot CLI session**, via a
  `sessionEnd` hook (`..\..\hooks\session-end-push-mywork.json`, registered in
  `~\.copilot\hooks\` through the same directory junction used by the other
  hooks). This is a safety net that catches any pending edits that weren't
  explicitly pushed mid-session. Manual/explicit runs above are still useful
  when the user wants an immediate push instead of waiting for session end.

## How to run it
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-folder>\..\..\tools\Push-MyWorkChanges.ps1"
```

Optional parameters:
- `-Message "..."` - custom commit message (otherwise an auto-summary of
  changed files is used).
- `-WhatIf` - just show pending changes without committing/pushing (use this
  first if unsure, or to preview before an automatic push).

The script:
1. Confirms `mywork` is a git repo.
2. Exits cleanly (no-op) if the working tree is already clean.
3. Shows `git status --short` for visibility.
4. Stages everything (`git add -A`), commits, and pushes to `origin main`.

## Safety rules
- Never push if `git status` shows nothing changed (script already handles
  this as a no-op).
- Never bypass `.gitignore` protections (`secrets.env`, `*.env`, `*token*`,
  etc. are already excluded at the repo root - do not `git add -f` those).
- If `git push` fails (e.g. remote has diverged commits), do not force-push -
  report the failure to the user and ask how they want to resolve it
  (typically `git pull --rebase` then re-run).
- Show the user a short summary of what was committed/pushed after success.
