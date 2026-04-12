# Project Instructions

> Copy this file to the root of a project as `CLAUDE.md` and fill in the sections marked with `{...}`.
> Claude reads this file automatically when it exists in the working directory.

## Project

- **Language / Stack**: {e.g. Go 1.26, Node.js 22}
- **Entrypoints**: {e.g. `cmd/server/main.go`}
- **Local Environment**: {e.g. `.env`, `mise`}

## Essential Commands

```sh
# {add project commands here}
# mise run dev    # Start locally
# mise run test   # Run all tests
# mise run lint   # Lint
```

## Architecture

{Brief description of the directory layout and main layers.}

## Conventions

The coding conventions for this project follow the standards in `.github/instructions/` (if this project uses the ai-config submodule) or in the attached Claude Project knowledge files:

- `go-style.instructions.md` — naming, formatting, control flow
- `clean-architecture.instructions.md` — layer rules, DI, domain isolation
- `testing.instructions.md` — table-driven tests, mocks, assertions
- `error-handling.instructions.md` — domain errors, wrapping, HTTP mapping
- `package-design.instructions.md` — package naming, dependency direction

## Rules

- Never log and return the same error — choose one
- No cross-domain imports inside `internal/app/`
- Use `require` (not `assert`) in all test files
- Commit messages: subject max 50 chars, imperative mood, no period
- Never commit or push without explicit user confirmation
