# AGENTS.md - go-concurrency-patterns

Go 1.26.1 (github.com/fascari/go-concurrency-patterns) (golangci-lint).

## Shared rules

Read relevant files from `~/.ai-config/rules/` before making changes:
- Go projects: `go-style.md`, `testing.md`, `error-handling.md`, `package-design.md`, `clean-architecture.md`
- Writing: `sanitizing-text.md`

## Architecture

```
concurrency/
cmd/
internal/
docs/
```

## Commands

- `mise run test` — Test
- `mise run lint` — Lint
- `mise run tidy` — Tidy
- `mise run build` — Build
- `mise run fmt` — Fmt
- `mise run db:up` — Db up
- `mise run wait:postgres` — Wait postgres
- `mise run db:migrate` — Db migrate
- `mise run db:status` — Db status
- `mise run db:diff` — Db diff
- `mise run db:reset` — Db reset
- `mise run integration` — Integration
- `mise run e2e:up` — E2e up
- `mise run e2e:down` — E2e down
- `mise run mocks` — Mocks

## Hard rules

- Never log and return the same error — choose one
- No cross-domain imports inside `internal/`
- No `else` — early returns only
- `require` not `assert` in tests
- **Never commit directly.** Always invoke `committing-changes` skill (`~/.ai-config/skills/committing-changes/SKILL.md`). The skill requires explicit user approval before any `git commit` or `git push`.
