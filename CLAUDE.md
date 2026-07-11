# ai-config

Shared AI coding rules, workflow skills, and provider configurations for AI-assisted development.

## Rules

Before editing code, read the relevant files from `rules/`:

- `rules/go-style.md` — Go style, naming, control flow
- `rules/testing.md` — test conventions, table-driven, assertions
- `rules/error-handling.md` — domain errors, wrapping, HTTP mapping
- `rules/package-design.md` — package boundaries and dependency direction
- `rules/clean-architecture.md` — layer rules, DI, domain isolation
- `rules/sanitizing-text.md` — text formatting before save

## Skills

Workflow skills are in `skills/`. Use `orchestrating-tasks` as the entry point for any codebase change.

## Agents

Provider-agnostic agent definitions in `agents/`:
- `agents/go-implementer.md`, `agents/go-tester.md`

## Quick Start (new machine)

```bash
git clone git@github.com:user/ai-config.git ~/.ai-config
~/.ai-config/install.sh
```

See `README.md` for full setup guide.

## Hard Rules

- **Never commit directly.** Always invoke `committing-changes` skill. The skill requires explicit user approval before any `git commit` or `git push`.
