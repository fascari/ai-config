---
name: recall
description: Use when resuming work on a project — loads vault context, recent logs, architecture decisions, and active plans
---

# Recall

Loads all persistent context from the Obsidian vault and Graphify graph to restore full session awareness. Read-only: never writes to vault or modifies any file.

## When to use

- Starting a new session on a project with prior history
- User says "recall" or "/recall" explicitly
- Resuming work after a long break

## Steps

### 1. Detect vault and project

```bash
REPO_NAME=$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null || echo "unknown")
echo "VAULT=${COPILOT_VAULT:-NO_VAULT}"
echo "REPO=$REPO_NAME"
```

Map the repo name to the vault project folder using the table in your personal copilot instructions. If `COPILOT_VAULT` is not set, skip all vault steps and note that no vault is configured.

### 2. Read recent session logs

Vault devs only. Read the 3 most recent files (sorted by name, descending) from:
`$COPILOT_VAULT/{project}/logs/`

If the directory does not exist: note "No prior sessions found" and continue.

### 3. Read architecture decisions

Vault devs only. Read:
`$COPILOT_VAULT/{project}/architecture/decisions.md`

If the file does not exist: skip silently.

### 4. Read active plans

All devs — read from `.github/plans/`:
- Scan all subdirectories
- For each, read `progress.md` if it exists
- Identify plans with status `IN_PROGRESS`

Vault devs — additionally read from `$COPILOT_VAULT/{project}/plans/` if it exists.

### 5. Read Graphify context

Always — read `graphify-out/GRAPH_REPORT.md` if it exists.

Vault devs — additionally read up to 5 relevant community files:
`$COPILOT_VAULT/graphify/{project}/_COMMUNITY_{name}.md`

Pick communities most relevant to the current branch name or active plan.

### 6. Check git state

```bash
git --no-pager log --oneline -10
git --no-pager status
```

### 7. Present recall summary

Present a concise summary (max 20 lines) covering:
- **Last session**: what was done, decisions made, pending items
- **Active plan**: current phase and next step
- **Codebase**: key modules from GRAPH_REPORT (if available)
- **Git state**: current branch and any uncommitted work

Conclude with: "Ready. What would you like to work on?"

## Constraints

- Never write to vault, create files, or modify any file
- Never ask the user for the vault path — it comes from `$COPILOT_VAULT`
- Never crash if vault or graphify files are missing — always degrade gracefully
- Keep summary under 20 lines — do not dump raw log content
