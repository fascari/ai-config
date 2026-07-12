# Persistent Memory for AI Agents

Guide to set up long-term memory for AI coding agents using an Obsidian vault for knowledge and Graphify for codebase understanding. Works with any provider (opencode, Codex CLI, Claude Code, GitHub Copilot).

## Problem

AI coding agents start every session with zero context. They re-read the same files, re-discover the same architecture, and forget every decision made in previous sessions. This setup solves that with three layers:

- **Project entrypoint** (`AGENTS.md`, `CLAUDE.md`, or `.opencode/opencode.jsonc`) - loaded natively by the provider at session start. Triggers automatic session bootstrap without any user action.
- **Obsidian vault** - stores session logs, architecture decisions, and domain knowledge across sessions
- **Graphify** - generates a persistent knowledge graph of the codebase so the agent understands code structure without re-reading every file

## How It Works

### Session Start (automatic)

The provider loads the project entrypoint before processing the first user message. The bootstrap steps run automatically:

1. Detect vault path from `$AI_MEMORY_HOME`
2. Read 3 most recent session logs from the vault
3. Read architecture decisions
4. Read active plans (`.github/plans/` + vault)
5. Read `graphify-out/GRAPH_REPORT.md` for code structure
6. Check git state
7. Present a 20-line summary, then respond to the user

### During the Session

The agent follows the 3-layer context query rule:
1. **Graphify** - `graphify query "concept"` for code structure questions
2. **Vault** - check prior decisions and session history
3. **Source code** - read files only when editing or when layers 1-2 have no answer

### Session End (manual)

When the user says "checkpoint", the checkpoint skill writes a session log to the vault, appends architecture decisions if any were made, and creates new vault notes for discovered knowledge.

### Across Sessions

Session N+1 picks up where session N left off because `recall` loads the logs written by `checkpoint`. The agent knows what was done, what was decided, and what is pending without the user repeating anything.

## Prerequisites

- An AI coding agent that supports custom skills and global instructions (opencode, Codex CLI, Claude Code, or GitHub Copilot)
- Python 3.10+ (for Graphify)
- An Obsidian vault (or just a directory; Obsidian is optional for viewing)

## Step 1 - Set `$AI_MEMORY_HOME`

Add to `~/.zshrc` or `~/.bashrc`:

```bash
export AI_MEMORY_HOME="$HOME/.ai-memory"
```

This is the only per-developer configuration required. The agent reads this variable to locate the vault. Developers without a vault can skip this step; all vault operations degrade gracefully when the variable is unset.

## Step 2 - Create the Vault

Create the directory structure:

```bash
VAULT_DIR="$AI_MEMORY_HOME"

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

Each project gets its own folder at `$AI_MEMORY_HOME/{project}/` with these subdirectories:

- `architecture/` - decisions and conventions (`decisions.md`)
- `pipeline/` - data flows, APIs
- `data/` - schema, data model
- `features/` - planned and implemented features
- `logs/` - project session logs (date-prefixed, one per session)
- `plans/` - active implementation plans

### Create Templates

Session log template at `$AI_MEMORY_HOME/templates/session-log.md`:

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

Default note template at `$AI_MEMORY_HOME/templates/default-note.md`:

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

## Step 3 - Add Entry point to Each Project

Copy the appropriate entrypoint template from `~/.ai-config/providers/` to the project root:

```bash
# Codex CLI
cp ~/.ai-config/providers/codex/AGENTS.md /path/to/project/AGENTS.md

# Claude Code
cp ~/.ai-config/providers/claude/CLAUDE.md /path/to/project/CLAUDE.md

# Opencode
cp ~/.ai-config/providers/codex/AGENTS.md /path/to/project/AGENTS.md
mkdir -p /path/to/project/.opencode
cp ~/.ai-config/providers/opencode/opencode.jsonc /path/to/project/.opencode/opencode.jsonc

# GitHub Copilot
mkdir -p /path/to/project/.github/instructions
cp ~/.ai-config/providers/copilot/copilot-instructions.md /path/to/project/.github/copilot-instructions.md
ln -s ~/.ai-config/rules/*.md /path/to/project/.github/instructions/
```

The entrypoint triggers the automatic bootstrap described above. The provider reads it natively at session start; no extra configuration required.

## Step 4 - Install the Session Skills

Two global skills manage the session lifecycle. Install them via `install-global-skills.sh`:

```bash
~/.ai-config/install-global-skills.sh --provider all
```

This symlinks `recall` and `checkpoint` into the provider-specific skill directories:

| Provider | Skill location |
|---|---|
| Codex CLI | `~/.agents/skills/` |
| GitHub Copilot | `~/.copilot/skills/` |
| Claude Code | `~/.claude/skills/` |
| Opencode | `~/.config/opencode/skills/` |

### recall skill

Runs when the user explicitly says "recall". Also triggered automatically by the entrypoint bootstrap. Loads:
- 3 most recent session logs from `$AI_MEMORY_HOME/{project}/logs/`
- Architecture decisions from `$AI_MEMORY_HOME/{project}/architecture/decisions.md`
- Active plans from `.github/plans/` and `$AI_MEMORY_HOME/{project}/plans/`
- Graphify report from `graphify-out/GRAPH_REPORT.md`
- Current branch, recent commits, and working tree status

Read-only; never modifies the vault.

### checkpoint skill

Runs when the user says "checkpoint". Writes to the vault:
1. Creates a session log at `$AI_MEMORY_HOME/{project}/logs/{YYYY-MM-DD}-{short-description}.md`
2. Appends to `$AI_MEMORY_HOME/{project}/architecture/decisions.md` if architectural decisions were made (never overwrites existing entries)
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
graphify . --obsidian --obsidian-dir "$AI_MEMORY_HOME/graphify/{project}"
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
mkdir -p ~/.ai-memory/graphify/{project-name}

# Run graphify, then move output to persistent location
mv graphify-out/* ~/.ai-memory/graphify/{project-name}/

# Symlink back into the project root
ln -s ~/.ai-memory/graphify/{project-name} graphify-out
```

Add `graphify-out` to the project `.gitignore`.

### Incremental Updates

After structural changes (new modules, major refactors):

```bash
graphify . --update
```

There is no need to rebuild the graph every session.

### Querying the Graph

Never read `graph.json` directly; use the CLI:

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

## Step 6 - Verify the Setup

### Test bootstrap

Start a new session in any project. The agent should automatically:
1. Detect `$AI_MEMORY_HOME` and the project name
2. Look for session logs in the vault (none yet; expected)
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
