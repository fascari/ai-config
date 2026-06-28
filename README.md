# ai-config

Shared configuration, coding instructions, and workflow skills for AI-assisted software development. It is meant to provide a project's shared `.github/` tree.


## What This Repo Contains

- `providers/` - provider-native project instruction entrypoints and adapters
- `rules/` - shared rules library reused by provider adapters
- `skills/` - workflow skills for AI agents
- `claude/` - Claude-specific configuration and templates
- `docs/` - guides and reference documentation


## Installation

Skills are installed globally for Codex and GitHub Copilot so every project can use them without per-project setup.

| Provider | Install location | Link name |
|---|---|---|
| Codex | `~/.codex/skills/` | `atlas-ai-config-<skill>` |
| GitHub Copilot | `~/.copilot/skills/` | `<skill>` |

```bash
# Install for both providers
mise run skills:install

# Or target a single provider
mise run skills:install:codex
mise run skills:install:copilot
```

### First-time setup (per machine)

```bash
git clone git@github.com:fascari/ai-config.git ~/path/of/your/choice
cd ~/path/of/your/choice && mise run skills:install
```

The script creates symlinks. If the machine uses a different SSH host alias, use the HTTPS URL instead.

### Keeping skills up to date

```bash
cd ~/path/of/your/choice && git pull
```

Symlinks stay valid — no re-install needed after a pull.

### Adding a new skill

After adding a new `skills/<name>/` directory, re-run the mise task:

```bash
mise run skills:install
```

### For Claude Projects

Attach the relevant files from `rules/` as project knowledge. See [`claude/README.md`](claude/README.md) for details.

### Using as a project `.github/` tree (legacy)

This repo separates shared rules from provider-native injection. Keep reusable rules in `rules/`, then install the right entrypoint for each AI provider into the consuming repo.


## Instructions

Coding rules and conventions that can be routed into different AI providers. Each file declares an `applyTo` glob pattern in its frontmatter when that metadata is useful to a provider or harness.

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

Standard workflow: orchestrating-tasks -> researching-codebase -> analyzing-system-design -> planning-implementation -> implementing-feature -> testing-implementation -> reviewing-code -> sanitizing-text -> committing-changes -> creating-pull-request.

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

1. Expose this repo as the project's `.github/` tree.
2. Copy `copilot-instructions.md` to the project root and fill in the blanks.
3. Add or update files in `rules/` when changing shared conventions, or in the consuming repo's provider-native instruction files when the rule is project-specific.

### Provider-native project setup

Install the shared Codex entrypoint into a target repository:

```bash
mise run project:install:codex -- --target /path/to/repo
```

This installs:

- `AGENTS.md` from `providers/codex/`
- `.codex/rules/` linked or copied from this repo
4. Run `graphify .` to generate the code knowledge graph.
5. Run `checkpoint` at the end of the first session to initialize the vault folder.
6. Skills apply the rules automatically during each phase.

For projects that do not use Go, remove the Go-specific instruction files and add equivalents for the target language.
