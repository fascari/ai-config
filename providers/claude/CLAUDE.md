# CLAUDE.md

Keep this file short and use it as the index for repo-specific rules. Before
editing code, read only the rule files and docs relevant to the area you will
change.

## Shared Rules

Read the relevant files under `__AI_CONFIG_RULES_DIR__/` before making code
changes:

- Go production code: `__AI_CONFIG_RULES_DIR__/go-style.md`
- Go tests: `__AI_CONFIG_RULES_DIR__/testing.md`
- Package boundaries and naming: `__AI_CONFIG_RULES_DIR__/package-design.md`
- Error handling: `__AI_CONFIG_RULES_DIR__/error-handling.md`
- Clean architecture and dependency direction: `__AI_CONFIG_RULES_DIR__/clean-architecture.md`

## Repo Architecture

Before changing package boundaries or adding a new module, read `docs/architecture.md`.

Working shape for generated Go services:

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
`__AI_CONFIG_RULES_DIR__/testing.md`.

- Use case tests must stay isolated and use mocks.
- Regenerate mocks with `mise run mocks` when interfaces change.
- Integration tests live under `internal/testing/` and use the `integration`
  build tag.

## Commands

Before finishing, run the narrowest relevant checks:

- `mise run test`
- `mise run lint`
- `mise run integration` for integration-path changes
- `mise run mocks` after interface changes

For setup and day-to-day commands, read `docs/development.md`.
