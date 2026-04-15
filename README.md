# ai-config

Shared configuration, coding instructions, and workflow skills for AI-assisted software development. Designed to be added as a submodule (at `.github/`) in any project repository.


## What This Repo Contains

```
ai-config/
├── copilot-instructions.md   # GitHub Copilot project-level instructions template
├── instructions/              # Coding standards auto-injected by file pattern
├── skills/                    # Workflow skills for AI agents
└── claude/                    # Claude-specific configuration and templates
```


## Quick Start

### As a Git Submodule

Add this repo as a submodule at `.github/` in any project:

```bash
git submodule add <repo-url> .github
```

Copilot and other AI tools read files from `.github/instructions/` and `.github/skills/` automatically.

### For Claude Projects

Attach the relevant instruction files from `instructions/` as project knowledge. See [`claude/README.md`](claude/README.md) for details.


## Instructions

Coding standards and conventions that AI tools auto-inject when editing matching files. Each file declares an `applyTo` glob pattern in its frontmatter.

| File | Applies to | Summary |
|---|---|---|
| `go-style` | `**/*.go` | Google Go Style Guide + project-specific naming, formatting, and control flow rules |
| `clean-architecture` | `internal/app/**/*.go` | Layer rules, DI, domain isolation, and bounded context boundaries |
| `testing` | `**/*_test.go` | Table-driven tests, mockery, integration suites, naming conventions |
| `error-handling` | `**/*.go` | Domain error codes, wrapping strategy, no log-and-return |
| `package-design` | `**/*.go` | Package philosophy based on Bill Kennedy's guidelines |
| `sanitizing-text` | `**/*.md`, `**/*.txt` | Remove AI-sounding language and normalize formatting before saving |

These files are language-agnostic in structure. Add new instruction files for other languages or frameworks as needed.


## Skills

Workflow skills that guide AI agents through multi-step software engineering tasks. Each skill lives in `skills/{name}/SKILL.md`.

**Entry point:** Use **orchestrating-tasks** to start any task involving codebase analysis or changes. It detects complexity and delegates to the right skill chain.

Standard workflow:

```text
User Request
  -> orchestrating-tasks
    -> researching-codebase
    -> analyzing-system-design
    -> planning-implementation
    -> implementing-feature
    -> testing-implementation
    -> reviewing-code
    -> sanitizing-text
    -> committing-changes
    -> creating-pull-request
```

See [`skills/README.md`](skills/README.md) for the full catalog organized by category.


## Copilot Instructions Template

`copilot-instructions.md` is a project-level template for GitHub Copilot. Copy it to the target project and fill in the project-specific sections (language, entrypoints, architecture). It includes plan conventions, terminal safety rules, commit standards, and skill references.


## Claude Configuration

The `claude/` directory contains:

- **`project-instructions-template.md`** - Starting point for `CLAUDE.md` in any project. Claude reads this file automatically when it exists in the working directory.
- **`README.md`** - Setup guide for Claude Projects and `CLAUDE.md` usage.


## Persistent Memory (Obsidian + Graphify)

AI agents lose all context when a session ends. This setup solves that with two layers of persistent memory, adapted from [lucasrosati/claude-code-memory-setup](https://github.com/lucasrosati/claude-code-memory-setup) for GitHub Copilot.

### Architecture

```text
Session Start                          Session End
     |                                      |
  recall skill                        checkpoint skill
     |                                      |
     v                                      v
+------------------+               +------------------+
|  Obsidian Vault  | <------------ |  Session Context |
|  (long-term)     |               |  (decisions,     |
+------------------+               |   pending items) |
     |                             +------------------+
     v
+------------------+
|  Graphify Graph  |
|  (code structure)|
+------------------+
```

### Obsidian Vault

Location: `~/dev/tools/vault-obs/`

The vault stores knowledge using Zettelkasten principles (atomic notes, wikilinks, mandatory frontmatter). Each project gets its own folder with session logs, architecture decisions, and domain notes.

```text
vault-obs/
├── permanent/              # consolidated atomic notes
├── inbox/                  # raw capture (ideas, drafts)
├── fleeting/               # quick temporary notes
├── templates/              # note templates
├── logs/                   # global session logs
├── references/             # reference material
├── {project}/              # per-project knowledge
│   ├── architecture/       # decisions and conventions
│   ├── pipeline/           # data flows, APIs
│   ├── data/               # schema, data model
│   ├── features/           # planned and implemented features
│   └── logs/               # project session logs
├── graphify/               # codebase knowledge graphs
│   └── {project}/          # Graphify-generated notes
└── session-captures/       # compressed session summaries
```

### Graphify (Code Knowledge Graph)

Graphify turns a codebase into a navigable knowledge graph with community detection. The graph persists at `~/.copilot/graphify/{project}/` and is symlinked into each project root as `graphify-out/`.

Key outputs:
- `graph.json` - full graph with nodes, edges, and communities
- `GRAPH_REPORT.md` - plain-language summary of architecture, god nodes, and communities
- Interactive HTML visualization

Edges are tagged as EXTRACTED, INFERRED, or AMBIGUOUS so the agent knows what was found in the code versus what was inferred.

### 3-Layer Context Query Rule

When an agent needs to understand a codebase, it follows this priority order:

1. **Graphify graph first.** Query `graphify-out/graph.json` or `GRAPH_REPORT.md` for code structure and connections.
2. **Obsidian vault second.** Query the vault for architecture decisions, progress, and project context from prior sessions.
3. **Source code last.** Read source files only when editing or when the first two layers do not have the answer.

This avoids re-reading the entire codebase every session.

### Session Lifecycle Skills

Two global skills (installed at `~/.copilot/skills/`) manage the session lifecycle:

| Skill | Trigger | Purpose |
|---|---|---|
| **recall** | Session start, "recall" | Loads recent session logs, architecture decisions, Graphify report, git state, and active plans. Read-only. |
| **checkpoint** | Session end, "checkpoint" | Writes a session log to the vault with completed items, decisions, and pending work. Appends to architecture decisions if any were made. |

The global Copilot instructions (`~/.copilot/copilot-instructions.md`) trigger `recall` automatically on every new session.

### Setup

1. Create the vault directory structure at `~/dev/tools/vault-obs/`.
2. Install `recall` and `checkpoint` skills to `~/.copilot/skills/`.
3. Install Graphify (`pip install graphifyy`).
4. Add vault structure and session skills to `~/.copilot/copilot-instructions.md` (see `copilot-instructions.md` in this repo as a reference for the global instructions format).
5. Run `graphify .` on a project to generate the initial graph, then symlink `graphify-out/` at the project root.


## Adapting to a New Project

1. Add this repo as a submodule at `.github/`.
2. Copy `copilot-instructions.md` to the project root and fill in the blanks.
3. Add or update files in `instructions/` with project-specific conventions.
4. Run `graphify .` to generate the code knowledge graph.
5. Run `checkpoint` at the end of the first session to initialize the vault folder.
6. Skills apply the rules automatically during each phase.

For projects that do not use Go, remove the Go-specific instruction files and add equivalents for the target language.
