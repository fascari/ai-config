# ai-config

Shared AI coding rules, workflow skills, and provider configurations for AI-assisted development. Portable across opencode, Codex CLI, Claude Code, and GitHub Copilot.

## Architecture

```
~/.ai-config/                     ← clone location (universal, Linux and macOS)
├── rules/                        ← SSOT coding rules (Go style, testing, etc.)
├── skills/                       ← SSOT workflow skills (SKILL.md per skill)
├── agents/                       ← provider-agnostic agent definitions
├── providers/                    ← thin entrypoint templates for each provider
├── .opencode/                    ← opencode config for working ON this repo
├── AGENTS.md                     ← codex entrypoint for working ON this repo
├── CLAUDE.md                     ← claude entrypoint for working ON this repo
└── install*.sh                   ← setup scripts
```

Each provider's entrypoint is a thin index that references `~/.ai-config/rules/` and `~/.ai-config/skills/`. No rules are duplicated inline.

## Fresh Machine Setup

```bash
# 1. Clone to fixed location
git clone git@github.com:user/ai-config.git ~/.ai-config

# 2. Run setup (symlinks skills globally, exports AI_CONFIG_HOME)
~/.ai-config/install.sh

# 3. Restart shell, then per project:
~/.ai-config/install-provider-rules.sh --provider all --target /path/to/project
```

## Per-Project Install

Each provider installs thin entrypoint files into the target repository:

| Provider | Entrypoint created | Rules |
|----------|-------------------|-------|
| Codex CLI | `AGENTS.md` | Referenced from `~/.ai-config/rules/` |
| Claude Code | `CLAUDE.md` | Referenced from `~/.ai-config/rules/` |
| Opencode | `AGENTS.md` + `.opencode/opencode.jsonc` | Referenced via `instructions` field |
| GitHub Copilot | `AGENTS.md` + `.github/copilot-instructions.md` + `.github/instructions/*.instructions.md` | Symlinked from `~/.ai-config/rules/` |

```bash
# Install all providers for a project
~/.ai-config/install-provider-rules.sh --provider all --target /path/to/project

# Or a single provider
~/.ai-config/install-provider-rules.sh --provider codex --target /path/to/project
```

## Global Skill Installation

Skills are symlinked globally so every project can use them without per-project setup:

```bash
~/.ai-config/install-global-skills.sh --provider all
```

| Provider | Location | Link name |
|----------|----------|-----------|
| Codex CLI | `~/.agents/skills/` | `atlas-ai-config-<skill>` |
| Codex agents | `~/.codex/agents/` | `atlas-ai-config-<agent>.toml` |
| GitHub Copilot | `~/.copilot/skills/` | `<skill>` |
| Claude Code | `~/.claude/skills/` | `<skill>` |
| Opencode | `~/.config/opencode/skills/` | `<skill>` |

Opencode also discovers skills from `~/.agents/skills/` and `~/.claude/skills/`.

## Rules

| File | Applies to | Summary |
|------|-----------|---------|
| `rules/go-style.md` | `**/*.go` | Google Go Style Guide + project conventions |
| `rules/clean-architecture.md` | `internal/app/**/*.go` | Layer rules, DI, domain isolation |
| `rules/testing.md` | `**/*_test.go` | Table-driven tests, mockery, integration |
| `rules/error-handling.md` | `**/*.go` | Domain errors, wrapping, no log-and-return |
| `rules/package-design.md` | `**/*.go` | Package boundaries, dependency direction |
| `rules/sanitizing-text.md` | `**/*.md, **/*.txt` | Remove AI-sounding language before save |

## Skills

Workflow skills in `skills/{name}/SKILL.md`. Entry point: **orchestrating-tasks**.

Standard workflow: orchestrating-tasks → researching-codebase → planning-implementation → implementing-feature → testing-implementation → reviewing-code → committing-changes → creating-pull-request.

See [`skills/README.md`](skills/README.md) for the full catalog.

## Persistent Memory

Two skills manage session persistence across AI providers:
- **recall** — loads vault context at session start
- **checkpoint** — saves decisions and progress at session end

See [`docs/persistent-memory.md`](docs/persistent-memory.md).

## Updating

```bash
cd ~/.ai-config && git pull
```

Symlinks stay valid — no re-install needed after a pull. Re-run `install-global-skills.sh` only when new skills are added.
