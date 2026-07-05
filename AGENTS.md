# ai-config

Shared AI coding rules, workflow skills, and provider configurations for AI-assisted development.

## Session Bootstrap

On the first message of every new session, load the **recall** skill (`skills/recall/SKILL.md`) before responding. Skip if the user invokes `recall` or `resuming-context` manually.

## Rules

Before editing code, read the relevant files from `rules/`:

- `rules/go-style.md` — Go style, naming, control flow
- `rules/testing.md` — test conventions, table-driven, assertions
- `rules/error-handling.md` — domain errors, wrapping, HTTP mapping
- `rules/package-design.md` — package boundaries and dependency direction
- `rules/clean-architecture.md` — layer rules, DI, domain isolation
- `rules/sanitizing-text.md` — text formatting before save

## Skills

Workflow skills are in `skills/`. Use `orchestrating-tasks` as the entry point for any codebase change or feature implementation.

## Agents

Provider-agnostic agent definitions in `agents/`:
- `agents/go-implementer.md`, `agents/go-tester.md`

## Vault

Session persistence uses `$AI_MEMORY_HOME` or `$COPILOT_VAULT`. When unset, vault steps are skipped.

## Commands

- `./install-global-skills.sh` — symlink skills for all providers
- `./install-provider-rules.sh` — install entrypoints into a target project
