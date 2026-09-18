---
name: recall
description: Use when resuming work on a project, loads vault context, recent logs, architecture decisions, and active plans
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
echo "VAULT=${AI_MEMORY_HOME:-NO_VAULT}"
echo "REPO=$REPO_NAME"
```

Map the repo name to the vault project folder. If `AI_MEMORY_HOME` is not set,
this session has **no vault** — skip every step below marked "vault devs
only," and note that no vault is configured. Steps marked "all devs" run
regardless, since they don't depend on `AI_MEMORY_HOME`.

### 2. Load Cognition Lessons

**REQUIRED SUB-SKILL**: all devs — run `cognition-lessons`' Load Flow
(`$AI_CONFIG_HOME/skills/cognition-lessons/SKILL.md`, or `Skill(skill:
"cognition-lessons")` in Claude Code). It checks `$HOME/.ai-config/cognition-lessons/{project}.md`,
independent of the vault, and surfaces prior review lessons if any exist.

### 3. Read recent session logs

Vault devs only. Read the 3 most recent files (sorted by name, descending) from:
`$AI_MEMORY_HOME/{project}/logs/`

If the directory does not exist: note "No prior sessions found" and continue.

### 4. Read architecture decisions

Vault devs only. Read:
`$AI_MEMORY_HOME/{project}/architecture/decisions.md`

If the file does not exist: skip silently.

### 5. Read active plans

All devs: resolve the external `{plan_root}` with the same rule as `orchestrating-tasks`, then read from `{plan_root}/`:
- Scan all subdirectories
- For each, read `progress.md` if it exists
- Identify plans with status `IN_PROGRESS`

Vault devs: additionally read from `$AI_MEMORY_HOME/{project}/plans/` if it exists.

### 6. Read Graphify context

Always, read `graphify-out/GRAPH_REPORT.md` if it exists.

Vault devs: additionally read up to 5 relevant community files:
`$AI_MEMORY_HOME/graphify/{project}/_COMMUNITY_{name}.md`

Pick communities most relevant to the current branch name or active plan.

### 7. Check git state

```bash
git --no-pager log --oneline -10
git --no-pager status
```

### 8. Present recall summary

Present a concise summary (max 20 lines) covering:
- **Last session**: what was done, decisions made, pending items
- **Cognition lessons**: any high-priority lessons loaded in step 2
- **Active plan**: current phase and next step
- **Codebase**: key modules from GRAPH_REPORT (if available)
- **Git state**: current branch and any uncommitted work

Conclude with: "Ready. What would you like to work on?"

## Constraints

- Never write to vault, create files, or modify any file
- Never ask the user for the vault path; it comes from `AI_MEMORY_HOME`
- Never crash if vault or graphify files are missing: always degrade gracefully
- Keep summary under 20 lines: do not dump raw log content
