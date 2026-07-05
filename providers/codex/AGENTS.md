# AGENTS.md

> Template for `AGENTS.md` in target repositories.
> Fill in project-specific sections and install via `install-provider-rules.sh`.

Keep this file short and use it as the index for repo-specific rules.

## Shared rules

Read the relevant files under `~/.ai-config/rules/` before making code
changes:

- Go production code: `~/.ai-config/rules/go-style.md`
- Go tests: `~/.ai-config/rules/testing.md`
- Package boundaries and naming: `~/.ai-config/rules/package-design.md`
- Error handling: `~/.ai-config/rules/error-handling.md`
- Clean architecture and dependency direction: `~/.ai-config/rules/clean-architecture.md`

## Repo architecture

Before changing package boundaries or adding a new module, read `docs/architecture.md`.

Working shape of this repo:

- `cmd/api/` wires the application and HTTP modules.
- `internal/app/{domain}/` contains domain-specific code.
- `internal/app/{domain}/domain/` holds domain types and business concepts.
- `internal/app/{domain}/usecase/{action}/` holds application logic.
- `internal/app/{domain}/handler/{action}/` adapts HTTP requests into use cases.
- `internal/app/{domain}/repository/` holds persistence adapters.
- `internal/bootstrap/` and `internal/config/` are startup and configuration layers.
- `pkg/` is only for truly shared technical utilities, not domain behavior.

When adding new behavior, extend the existing domain slice instead of introducing
new top-level patterns.

## Testing

Before changing tests or adding coverage, read `docs/testing.md` and
`~/.ai-config/rules/testing.md`.

- Use case tests must stay isolated and use mocks.
- Regenerate mocks with `mise run mocks` when interfaces change.
- Integration tests live under `internal/testing/` and use the `integration` build tag.

## Commands

Before finishing, run the narrowest relevant checks:

- `mise run test`
- `mise run lint`
- `mise run integration` for integration-path changes
- `mise run mocks` after interface changes

For setup and day-to-day commands, read `docs/development.md`.
