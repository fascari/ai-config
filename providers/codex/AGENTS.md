# AGENTS.md

> Template for target repositories. Fill in project-specific sections.
> Install via `install-provider-rules.sh`.

Keep this file short. It is the index for repo-specific rules.

## Project

- **Language / Stack**: {e.g. Go 1.26, TypeScript, Python 3.12}
- **Entrypoints**: {e.g. `cmd/server/main.go`, `src/index.ts`}
- **Local Environment**: {e.g. `.env`, `mise`}

## Shared rules

Read relevant files from `~/.ai-config/rules/` before making changes:
- Go projects: `go-style.md`, `testing.md`, `error-handling.md`, `package-design.md`, `clean-architecture.md`
- Writing: `sanitizing-text.md`

## Architecture

> Fill in with the actual project layout.

```
src/             # Source code
tests/           # Tests
docs/            # Documentation
```

## Commands

> Fill in with the project's actual commands.

```sh
# mise run test     # Run tests
# mise run lint     # Lint
# mise run dev      # Start locally
```
