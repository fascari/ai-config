# Persistent Memory for AI Agents

Step-by-step guide to set up long-term memory for GitHub Copilot (or any AI coding agent) using an Obsidian vault for knowledge and Graphify for codebase understanding.


## Problem

AI coding agents start every session with zero context. They re-read the same files, re-discover the same architecture, and forget every decision made in previous sessions. This setup solves that with three layers:

- **`AGENTS.md`** — loaded natively by Copilot CLI each session. Triggers automatic session bootstrap without any user action.
- **Obsidian vault** — stores session logs, architecture decisions, and domain knowledge across sessions
- **Graphify** — generates a persistent knowledge graph of the codebase so the agent understands code structure without re-reading every file


## How It Works

### Session Start (automatic)

Copilot CLI loads `AGENTS.md` at the project root before processing the first user message. The bootstrap steps run automatically:
1. Detect vault path from `$COPILOT_VAULT` env var
2. Read 3 most recent session logs from the vault
3. Read architecture decisions
4. Read active plans (`.github/plans/` + vault)
5. Read `graphify-out/GRAPH_REPORT.md` for code structure
6. Check git state
7. Present a 20-line summary, then respond to the user

### During the Session

The agent follows the 3-layer context query rule:
1. **Graphify** — `graphify query "concept"` for code structure questions
2. **Vault** — check prior decisions and session history
3. **Source code** — read files only when editing or when layers 1–2 have no answer

### Session End (manual)

When the user says "checkpoint", the checkpoint skill writes a session log to the vault, appends architecture decisions if any were made, and creates new vault notes for discovered knowledge.

### Across Sessions

Session N+1 picks up where session N left off because `recall` loads the logs written by `checkpoint`. The agent knows what was done, what was decided, and what is pending without the user repeating anything.


## Prerequisites

- GitHub Copilot CLI (or any agent that supports custom skills and global instructions)
- Python 3.10+ (for Graphify)
- An Obsidian vault (or just a directory — Obsidian is optional for viewing)


## Step 1 - Set `$COPILOT_VAULT`

Add to `~/.zshrc` or `~/.bashrc`:

```bash
export COPILOT_VAULT="$HOME/path/to/your/obsidian-vault"
```

This is the only per-developer configuration required. The agent reads this variable to locate the vault. Developers without Obsidian can skip this step — all vault operations degrade gracefully when the variable is unset.


## Step 2 - Create the Vault

Create the directory structure for the Obsidian vault:

```bash
VAULT_DIR="$COPILOT_VAULT"

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

Each project gets its own folder at `$COPILOT_VAULT/{project}/` with these subdirectories:

- `architecture/` - decisions and conventions (`decisions.md`)
- `pipeline/` - data flows, APIs
- `data/` - schema, data model
- `features/` - planned and implemented features
- `logs/` - project session logs (date-prefixed, one per session)
- `plans/` - active implementation plans

### Create Templates

Session log template at `$COPILOT_VAULT/templates/session-log.md`:

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

Default note template at `$COPILOT_VAULT/templates/default-note.md`:

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


## Step 3 - Add `AGENTS.md` to Each Project

Copy `AGENTS.md` from this repo to the project root (or add this repo as `.github/` submodule — `AGENTS.md` lives at the submodule root and is symlinked or copied as needed).

Copilot CLI reads `AGENTS.md` natively at session start — no configuration required. The file triggers the automatic bootstrap described above.

The repo-to-vault-folder mapping lives in the developer's personal copilot instructions (`~/.copilot/copilot-instructions.md`):

```markdown
| Repository | Vault folder |
|---|---|
| my-long-repo-name | short-name |
```

For unmapped repositories, the agent uses the repository name as the vault folder name.


## Step 4 - Install the Session Skills

Two global skills manage the session lifecycle. Install them at `~/.copilot/skills/`.

```bash
mkdir -p ~/.copilot/skills/{recall,checkpoint}
```

Copy `skills/recall/SKILL.md` and `skills/checkpoint/SKILL.md` from this repo to those directories.

### recall skill

Runs when the user explicitly says "recall". Also triggered automatically by the AGENTS.md bootstrap. Loads:
- 3 most recent session logs from `$COPILOT_VAULT/{project}/logs/`
- Architecture decisions from `$COPILOT_VAULT/{project}/architecture/decisions.md`
- Active plans from `.github/plans/` and `$COPILOT_VAULT/{project}/plans/`
- Graphify report from `graphify-out/GRAPH_REPORT.md`
- Current branch, recent commits, and working tree status

Read-only — never modifies the vault.

### checkpoint skill

Runs when the user says "checkpoint". Writes to the vault:
1. Creates a session log at `$COPILOT_VAULT/{project}/logs/{YYYY-MM-DD}-{short-description}.md`
2. Appends to `$COPILOT_VAULT/{project}/architecture/decisions.md` if architectural decisions were made (never overwrites existing entries)
3. Creates new vault notes for discovered domain knowledge, following Zettelkasten rules


## Step 5 - Install Graphify

Graphify turns a codebase into a knowledge graph with community detection, stored as JSON.

```bash
pip install graphifyy
graphify install
```

### Generate the Graph for a Project

From the project root:

```bash
graphify .
```

Optionally export communities as vault notes:

```bash
graphify . --obsidian --obsidian-dir "$COPILOT_VAULT/graphify/{project}"
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

### Querying the Graph

Never read `graph.json` directly — use the CLI:

| Need | Command | Output size |
|---|---|---|
| Broad context | `graphify query "concept"` | ~2k tokens (BFS traversal) |
| Trace connection | `graphify path "A" "B"` | Path between nodes |
| Node details | `graphify explain "NodeName"` | Single node with neighbors |

### Edge Audit Trail

Every edge in the graph is tagged:

- **EXTRACTED** - found directly in the code
- **INFERRED** - deduced from patterns (e.g., a function calls another through an interface)
- **AMBIGUOUS** - uncertain relationship

The agent can distinguish what was found versus what was inferred.


## Step 6 - Configure Personal Instructions

Add the vault and Graphify configuration to `~/.copilot/copilot-instructions.md` so every session picks it up automatically.

### Vault Section

```markdown
## Obsidian Vault (Persistent Memory)

The vault at `$COPILOT_VAULT` is the long-term memory across sessions.

### Identify Current Project

To determine the project folder in the vault, use the git repository name:

REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")

Repository to vault folder mapping:

| Repository | Vault folder |
|---|---|
| my-long-repo-name | short-name |

For unmapped projects, create the folder using the repository name.
```

### Graphify and Session Skills Section

```markdown
## Context Navigation (Graphify)

### 3-Layer Context Query Rule
1. First: `graphify query "concept"` or `graphify-out/GRAPH_REPORT.md`
2. Second: query the Obsidian vault for decisions, progress, and project context
3. Third: only read source code files when editing or when the first two layers don't have the answer

Never use grep or find to explore the codebase.

## Session Skills

| Command | Skill | Purpose |
|---|---|---|
| recall | ~/.copilot/skills/recall/ | Load vault context at session start |
| checkpoint | ~/.copilot/skills/checkpoint/ | Save decisions and progress at session end |

## Automatic Session Bootstrap

On the first user message of every new session, automatically execute the bootstrap steps in AGENTS.md before responding.
```


## Step 7 - Verify the Setup

### Test bootstrap

Start a new Copilot session in any project. The agent should automatically:
1. Detect `$COPILOT_VAULT` and the project name
2. Look for session logs in the vault (none yet — expected)
3. Show git state and report no prior sessions

### Test checkpoint

At the end of a session, say "checkpoint". The agent should:
1. Create the project folder in the vault if it does not exist
2. Write a session log with what was done
3. Confirm the log path and any pending items

### Test Graphify

Run `graphify .` on a project, then ask the agent about the codebase architecture. It should run `graphify query` or read `GRAPH_REPORT.md` before reading any source file.


## Maintenance

- **Vault cleanup**: periodically move resolved pending items out of logs, consolidate repeated decisions into permanent notes
- **Graph rebuild**: run `graphify . --update` after major refactors or new module additions
- **Repo mapping**: update the mapping table in personal instructions when adding new projects with non-obvious vault folder names

