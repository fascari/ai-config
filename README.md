# ai-config

Shared AI coding rules, workflow skills, and provider configurations for AI-assisted development. Portable across opencode, Codex CLI, Claude Code, and GitHub Copilot.

## Architecture

```
ai-config/                        ← git clone (any location)
├── rules/                        ← SSOT coding rules
├── skills/                       ← SSOT workflow skills (SKILL.md per skill)
├── agents/                       ← provider-agnostic agent definitions
├── providers/                    ← thin entrypoint templates for each provider
├── .opencode/                    ← opencode config for working ON this repo
├── AGENTS.md                     ← codex entrypoint for working ON this repo
├── CLAUDE.md                     ← claude entrypoint for working ON this repo
├── install.sh                    ← setup script
└── install-global-skills.sh      ← global skill installer

~/.ai-config/                     ← staging dir (created by install.sh)
├── rules/                  → symlink → ai-config/rules/
├── skills/                 → symlink → ai-config/skills/
├── agents/                 → symlink → ai-config/agents/
├── providers/              → symlink → ai-config/providers/
├── install.sh              → symlink → ai-config/install.sh
└── install-global-skills.sh → symlink → ai-config/install-global-skills.sh
```

`install.sh` auto-detects the repo root from its own location and symlinks `rules/`, `skills/`, `agents/`, and `providers/` into `~/.ai-config/`. Provider configs and project entrypoints reference `~/.ai-config/rules/`, a single indirection that stays valid across `git pull` without re-install.

Each provider's entrypoint is a thin index that references `~/.ai-config/rules/` and `~/.ai-config/skills/`. No rules are duplicated inline.

## Fresh Machine Setup

```bash
# 1. Clone anywhere
git clone git@github.com:user/ai-config.git ~/dev/pessoal/ai-config

# 2. Run setup (symlinks rules/skills/agents into ~/.ai-config/, installs global skills)
~/dev/pessoal/ai-config/install.sh

# 3. Restart shell
```

## Per-Project Install

Copy the appropriate entrypoint template from `~/.ai-config/providers/` to your project root:

| Provider | Files to copy | Rules |
|----------|-------------|-------|
| Codex CLI | `providers/codex/AGENTS.md` → `AGENTS.md` | Referenced from `~/.ai-config/rules/` |
| Claude Code | `providers/claude/CLAUDE.md` → `CLAUDE.md` | Referenced from `~/.ai-config/rules/` |
| Opencode | `providers/codex/AGENTS.md` → `AGENTS.md` + `providers/opencode/opencode.jsonc` → `.opencode/opencode.jsonc` | Referenced via `instructions` field |
| GitHub Copilot | `providers/copilot/copilot-instructions.md` → `.github/copilot-instructions.md` + symlink `rules/` to `.github/instructions/` | Symlinked from `~/.ai-config/rules/` |

### Example: Codex CLI

```bash
cp ~/.ai-config/providers/codex/AGENTS.md /path/to/project/AGENTS.md
```

### Example: Opencode

```bash
cp ~/.ai-config/providers/codex/AGENTS.md /path/to/project/AGENTS.md
mkdir -p /path/to/project/.opencode
cp ~/.ai-config/providers/opencode/opencode.jsonc /path/to/project/.opencode/opencode.jsonc
```

Opencode agents are installed globally in `~/.config/opencode/agents/` via `install-global-skills.sh` and discovered automatically. No per-project duplication needed.

### Example: GitHub Copilot

```bash
mkdir -p /path/to/project/.github/instructions
cp ~/.ai-config/providers/copilot/copilot-instructions.md /path/to/project/.github/copilot-instructions.md
ln -s ~/.ai-config/rules/*.md /path/to/project/.github/instructions/
```

## Global Skill Installation

Skills are symlinked globally so every project can use them without per-project setup:

```bash
~/.ai-config/install-global-skills.sh --provider all
```

| Provider | Location | Link name |
|----------|----------|-----------|
| Codex CLI | `~/.agents/skills/` | `<skill>` |
| Codex agents | `~/.codex/agents/` | `<agent>.toml` |
| GitHub Copilot | `~/.copilot/skills/` | `<skill>` |
| Claude Code | `~/.claude/skills/` | `<skill>` |
| Opencode | `~/.config/opencode/skills/` | `<skill>` |

Opencode also discovers skills from `~/.agents/skills/` and `~/.claude/skills/`.

## Global Agent Installation

Opencode agents are symlinked globally via `install-global-skills.sh` so every project can use them without per-project setup:

```bash
~/.ai-config/install-global-skills.sh --provider opencode
```

| Provider | Location |
|----------|----------|
| Opencode | `~/.config/opencode/agents/` |

Opencode discovers agents from `~/.config/opencode/agents/` automatically. No per-project duplication needed.

## Rules

| File | Applies to | Summary |
|------|-----------|---------|
| `rules/go-style.md` | `**/*.go` | Google Go Style Guide + project conventions |
| `rules/design-principles.md` | `**/*.go` | Deep modules, entanglement, design-first, tradeoffs |
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
- **recall**: loads vault context at session start
- **checkpoint**: saves decisions and progress at session end

See [`docs/persistent-memory.md`](docs/persistent-memory.md).

## Quality Harness

Deterministic gates (zero tokens) + single LLM review (one call per cycle). Inspired by [copilot-tdd-harness](https://github.com/mrlarson2007/copilot-tdd-harness) and the 7 pillars of Harness Engineering.

- **style-gate**: lint, format, typecheck, tests, style greps (deterministic)
- **reviewing-code**: single LLM review of rules + diff
- **cognition-lessons**: extract lessons from failures, load in future sessions

## Updating

```bash
cd ~/dev/pessoal/ai-config && git pull
```

Symlinks in `~/.ai-config/` point to the repo, so a `git pull` is enough. No re-install needed. Re-run `install-global-skills.sh` only when new skills are added.
