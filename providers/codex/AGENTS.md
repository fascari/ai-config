# AGENTS.md - token-swap-workbench

This is a Go 1.26 service. Keep this file short and use it as the index for
repo-specific rules. Before editing code, read only the rule files and docs
relevant to the area you will change.

## Shared rules

Read the relevant files under `.codex/rules/` before making code changes:

- Go production code: `.codex/rules/go-style.md`
- Go tests: `.codex/rules/testing.md`
- Package boundaries and naming: `.codex/rules/package-design.md`
- Error handling: `.codex/rules/error-handling.md`
- Clean architecture and dependency direction: `.codex/rules/clean-architecture.md`

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

Before changing tests or adding coverage, read `docs/testing.md` and `.codex/rules/testing.md`.

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
