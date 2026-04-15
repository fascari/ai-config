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

AI agents lose all context when a session ends. This setup adds two persistence layers: an Obsidian vault for knowledge and session history, and Graphify for codebase understanding.

Two global skills manage the lifecycle:
- **recall** runs at session start, loading recent logs, decisions, and the code graph
- **checkpoint** runs at session end, saving what was done, decided, and left pending

See [`docs/persistent-memory.md`](docs/persistent-memory.md) for the full setup guide.


## Adapting to a New Project

1. Add this repo as a submodule at `.github/`.
2. Copy `copilot-instructions.md` to the project root and fill in the blanks.
3. Add or update files in `instructions/` with project-specific conventions.
4. Run `graphify .` to generate the code knowledge graph.
5. Run `checkpoint` at the end of the first session to initialize the vault folder.
6. Skills apply the rules automatically during each phase.

For projects that do not use Go, remove the Go-specific instruction files and add equivalents for the target language.
