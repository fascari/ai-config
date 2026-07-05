# CLAUDE.md

> Template for `CLAUDE.md` in target repositories.
> Fill in project-specific sections and install via `install-provider-rules.sh`.

---

## Project

- **Language / Stack**: {e.g. Go 1.26, Node.js 22}
- **Entrypoints**: {e.g. `cmd/server/main.go`}
- **Local Environment**: {e.g. `.env`, `mise`}

## Commands

```sh
# mise run test   # Run all tests
# mise run lint   # Lint
# mise run dev    # Start locally
```

## Shared Rules

Read the relevant files under `~/.ai-config/rules/` before making code changes:

- `~/.ai-config/rules/go-style.md` — naming, formatting, control flow
- `~/.ai-config/rules/clean-architecture.md` — layer rules, DI, domain isolation
- `~/.ai-config/rules/testing.md` — table-driven tests, mocks, assertions
- `~/.ai-config/rules/error-handling.md` — domain errors, wrapping, HTTP mapping
- `~/.ai-config/rules/package-design.md` — package naming, dependency direction

## Architecture

> Fill in with the actual project layout.

```
cmd/                     # Entrypoints
internal/app/{domain}/   # Business domains
internal/                # Infrastructure
pkg/                     # Shared utilities
```

## Hard Rules

- Never log and return the same error — choose one
- No cross-domain imports inside `internal/app/`
- Never commit or push without explicit user confirmation
