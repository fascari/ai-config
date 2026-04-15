# Persistent Memory for AI Agents

Step-by-step guide to set up long-term memory for GitHub Copilot (or any AI coding agent) using an Obsidian vault for knowledge and Graphify for codebase understanding.


## Problem

AI coding agents start every session with zero context. They re-read the same files, re-discover the same architecture, and forget every decision made in previous sessions. This setup solves that with two persistence layers:

- **Obsidian vault** - stores session logs, architecture decisions, and domain knowledge across sessions
- **Graphify** - generates a persistent knowledge graph of the codebase so the agent understands code structure without re-reading every file


## Prerequisites

- GitHub Copilot CLI (or any agent that supports custom skills and global instructions)
- Python 3.10+ (for Graphify)
- An Obsidian vault (or just a directory, Obsidian is optional for viewing)


## Step 1 - Create the Vault

Create the directory structure for the Obsidian vault:

```bash
VAULT_DIR="<your-vault-path>"

mkdir -p "$VAULT_DIR"/{permanent,inbox,fleeting,templates,logs,references,session-captures}
```

This is the global vault. Each project gets its own folder created automatically when you run `checkpoint` for the first time.

### Vault Structure

Top-level directories:

- `permanent/` - atomic Zettelkasten notes (1 concept per note)
- `inbox/` - raw ideas and drafts
- `fleeting/` - quick temporary notes
- `templates/` - note templates (session log, default note)
- `logs/` - global session logs
- `references/` - reference material
- `session-captures/` - compressed session summaries
- `graphify/{project}/` - Graphify-generated vault notes

Each project gets its own folder with these subdirectories:

- `architecture/` - decisions and conventions
- `pipeline/` - data flows, APIs
- `data/` - schema, data model
- `features/` - planned and implemented features
- `logs/` - project session logs

### Create Templates

Session log template at `$VAULT_DIR/templates/session-log.md`:

```markdown
---
title: {{title}}
tags: [session-log]
created: {{date}}
updated: {{date}}
status: active
type: log
project: {{project}}
---

# {{title}}

## What Was Done

## Decisions Made

## Pending Items

## Related Notes
```

Default note template at `$VAULT_DIR/templates/default-note.md`:

```markdown
---
title: {{title}}
tags: []
created: {{date}}
updated: {{date}}
status: draft
type: permanent
---

# {{title}}

## Context

## Details

## Related Links
```

### Zettelkasten Rules

All notes in the vault follow these rules:

- Use wikilinks `[[note-name]]` for internal references (not markdown links)
- Mandatory YAML frontmatter on every note
- Filenames in kebab-case: `auth-flow.md`, not `Auth Flow.md`
- 1 concept per permanent note (atomicity)
- Minimum 2 wikilinks per permanent note


## Step 2 - Install the Session Skills

Two global skills manage the session lifecycle. Install them at `~/.copilot/skills/`.

```bash
mkdir -p ~/.copilot/skills/{recall,checkpoint}
```

### recall skill

Create `~/.copilot/skills/recall/SKILL.md`:

This skill runs at the start of every session. It reads from the vault and presents a summary of the last session, pending items, architecture decisions, and current git state. It is strictly read-only and never modifies the vault.

What it loads:
- 3 most recent session logs from `{vault}/{project}/logs/`
- Architecture decisions from `{vault}/{project}/architecture/decisions.md`
- Graphify report from `graphify-out/GRAPH_REPORT.md` (if available)
- Current branch, recent commits, and working tree status
- Active plans with their progress

It identifies the project by the git repository name:

```bash
REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
```

If no vault folder exists for the project, it reports that and suggests running `checkpoint` after the first session.

### checkpoint skill

Create `~/.copilot/skills/checkpoint/SKILL.md`:

This skill runs at the end of a session (or at milestones). It writes to the vault.

What it does:
1. Creates a session log at `{vault}/{project}/logs/{YYYY-MM-DD}-{short-description}.md` with what was done, decisions made, and pending items
2. Appends to `{vault}/{project}/architecture/decisions.md` if any architectural decisions were made (never overwrites existing entries)
3. Creates new vault notes if new domain knowledge or business rules were discovered, following Zettelkasten rules

The skill ensures project directories exist before writing:

```bash
VAULT_DIR="<your-vault-path>/{project}"
mkdir -p "$VAULT_DIR/logs" "$VAULT_DIR/architecture"
```

Log filenames are date-prefixed for chronological sorting. The short description is max 5 words in kebab-case.


## Step 3 - Install Graphify

Graphify turns a codebase into a knowledge graph with community detection, stored as JSON.

```bash
pip install graphifyy
```

### Generate the Graph for a Project

From the project root:

```bash
graphify .
```

This creates a `graphify-out/` directory with:

| File | Purpose |
|---|---|
| `graph.json` | Full graph with nodes, edges, and communities |
| `GRAPH_REPORT.md` | Plain-language summary of architecture, god nodes, and clusters |
| `cache/` | Extraction cache for incremental updates |

For large codebases, the first run takes a few minutes. Subsequent runs with `graphify . --update` only process changed files.

### Persist the Graph Across Projects

Store graphs centrally and symlink into each project:

```bash
mkdir -p ~/.copilot/graphify/{project-name}

# Run graphify, then move output to persistent location
mv graphify-out/* ~/.copilot/graphify/{project-name}/

# Symlink back into the project root
ln -s ~/.copilot/graphify/{project-name} graphify-out
```

Add `graphify-out` to the project `.gitignore`.

### Incremental Updates

After structural changes (new modules, major refactors):

```bash
graphify . --update
```

There is no need to rebuild the graph every session.

### Edge Audit Trail

Every edge in the graph is tagged:

- **EXTRACTED** - found directly in the code
- **INFERRED** - deduced from patterns (e.g., a function calls another through an interface)
- **AMBIGUOUS** - uncertain relationship

The agent can distinguish what was found versus what was inferred.


## Step 4 - Configure Global Instructions

Add the vault and Graphify configuration to `~/.copilot/copilot-instructions.md` so every session picks it up automatically.

### Vault Section

Tell the agent where the vault is and how to navigate it:

```markdown
## Obsidian Vault (Persistent Memory)

The vault at `<your-vault-path>` is the long-term memory across sessions.

### Identify Current Project

To determine the project folder in the vault, use the git repository name:

REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")

Repository to vault folder mapping:

| Repository | Vault folder |
|---|---|
| my-long-repo-name | short-name |

For unmapped projects, create the folder using the repository name.
```

### Graphify Section

Tell the agent how to query the graph and when to rebuild:

```markdown
## Context Navigation (Graphify)

Graphify graphs live at `~/.copilot/graphify/{project}/` and are accessible
via symlink `graphify-out/` at each project root.

### 3-Layer Context Query Rule
1. First: query graphify-out/graph.json or graphify-out/GRAPH_REPORT.md
2. Second: query the Obsidian vault for decisions, progress, and project context
3. Third: only read source code files when editing or when the first two layers
   do not have the answer
```

### Session Skills Section

Register the skills and enable automatic recall:

```markdown
## Session Skills

| Command | Skill | Purpose |
|---|---|---|
| recall | ~/.copilot/skills/recall/ | Load vault context at session start |
| checkpoint | ~/.copilot/skills/checkpoint/ | Save decisions and progress at session end |

## Automatic Session Bootstrap

On the first user message of every new session, automatically invoke the recall
skill before responding.
```


## Step 5 - Verify the Setup

### Test recall

Start a new Copilot session in any project. The agent should automatically:
1. Identify the project by git repo name
2. Look for session logs in the vault (none yet, and that is expected)
3. Show git state and report that no prior sessions exist

### Test checkpoint

At the end of a session, say "checkpoint". The agent should:
1. Create the project folder in the vault if it does not exist
2. Write a session log with what was done
3. Confirm the log path and any pending items

### Test Graphify

Run `graphify .` on a project, then in a new session ask the agent about the codebase architecture. It should query `GRAPH_REPORT.md` before reading source files.


## How It Works in Practice

### Session Start (automatic)

When the agent receives the first message, the recall skill triggers automatically. It reads the last 3 session logs from `vault/{project}/logs/`, the architecture decisions, the Graphify report from `graphify-out/GRAPH_REPORT.md`, and the current git log and status. It then presents a 30-line summary before responding to the user message with full context.

### During the Session

The agent follows the 3-layer query rule:
1. Check Graphify graph for code structure questions
2. Check vault for prior decisions and context
3. Read source code only when editing or when layers 1-2 have no answer

### Session End (manual)

When the user says "checkpoint", the checkpoint skill triggers. It writes a session log to the vault, appends architecture decisions if any were made, creates new vault notes for discovered knowledge, and confirms what was saved.

### Across Sessions

Session N+1 picks up where session N left off because `recall` loads the logs written by `checkpoint`. The agent knows what was done, what was decided, and what is pending without the user repeating anything.


## Maintenance

- **Vault cleanup**: periodically move resolved pending items out of logs, consolidate repeated decisions into permanent notes
- **Graph rebuild**: run `graphify . --update` after major refactors or new module additions
- **Repo mapping**: update the mapping table in global instructions when adding new projects with non-obvious vault folder names
