---
name: checkpoint
description: Use when ending a session or reaching a milestone — saves decisions, progress, and pending items to the Obsidian vault for future recall
---

# Checkpoint

Saves session output to the Obsidian vault so the next session picks up exactly where this one left off. Write-only: reads existing vault files only to avoid overwriting, never to load context.

## When to use

- User says "checkpoint"
- Reaching a significant milestone mid-session
- Before compressing or ending a long session

## Prerequisites

`COPILOT_VAULT` must be set. If it is not, inform the user and stop:
> "COPILOT_VAULT is not set. Add `export COPILOT_VAULT=\"$HOME/path/to/vault\"` to ~/.zshrc and restart the shell."

## Steps

### 1. Identify project and ensure directories exist

```bash
REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
PROJECT_VAULT="$COPILOT_VAULT/$REPO_NAME"   # or mapped name from personal instructions
mkdir -p "$PROJECT_VAULT/logs" "$PROJECT_VAULT/architecture" "$PROJECT_VAULT/plans"
```

Use the repo-to-vault-folder mapping from personal copilot instructions when applicable.

### 2. Gather session content

Before writing, ask the user (or infer from conversation):
- What was done this session?
- What decisions were made?
- What is pending for next session?

If the user says "checkpoint" without providing detail, summarize from the conversation history.

### 3. Write session log

Create a new file at:
`$COPILOT_VAULT/{project}/logs/{YYYY-MM-DD}-{short-description}.md`

- Date: today's date in `YYYY-MM-DD` format
- Short description: max 5 words in kebab-case, derived from the main topic of the session
- Never overwrite an existing file — append a `-2`, `-3` suffix if a conflict exists

Log format:

```markdown
---
title: {short description}
tags: [session-log]
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
status: active
type: log
project: {project}
---

# {short description}

## What Was Done

## Decisions Made

## Pending Items

## Related Notes
```

### 4. Append to architecture decisions (if applicable)

If any architectural or design decisions were made this session, append to:
`$COPILOT_VAULT/{project}/architecture/decisions.md`

Append only — never overwrite or reorder existing entries. Format each entry as:

```markdown
### {YYYY-MM-DD}: {decision title}

{1-3 sentence explanation of what was decided and why.}
```

If the file does not exist, create it with a top-level heading first:
```markdown
# Architecture Decisions
```

### 5. Create vault notes for new knowledge (if applicable)

If new domain knowledge, business rules, or patterns were discovered, create permanent notes in `$COPILOT_VAULT/{project}/`:

Follow Zettelkasten rules:
- One concept per file
- YAML frontmatter with `title`, `tags`, `created`, `updated`, `status: active`, `type: permanent`
- Filename in kebab-case
- Minimum 2 wikilinks `[[note-name]]` per note

### 6. Confirm what was saved

Present a concise summary:
- Log file path and key points saved
- Whether decisions.md was updated
- Any new vault notes created
- Pending items for next session
