# AGENTS.md

## Rules

Read relevant files from `~/.ai-config/rules/` before making changes:
- `go-style.md` — naming, formatting, control flow
- `testing.md` — table-driven tests, mocks, assertions
- `error-handling.md` — domain errors, wrapping, HTTP mapping
- `package-design.md` — package naming, dependency direction
- `clean-architecture.md` — layer rules, DI, domain isolation

## Hard Rule

- **Never commit directly.** Always invoke `committing-changes` skill (`~/.ai-config/skills/committing-changes/SKILL.md`). The skill requires explicit user approval before any `git commit` or `git push`.
