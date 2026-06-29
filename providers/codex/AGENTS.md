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


<!-- headroom:rtk-instructions -->
# RTK (Rust Token Killer) - Token-Optimized Commands

When running shell commands, **always prefix with `rtk`**. This reduces context
usage by 60-90% with zero behavior change. If rtk has no filter for a command,
it passes through unchanged — so it is always safe to use.

## Key Commands
```bash
# Git (59-80% savings)
rtk git status          rtk git diff            rtk git log

# Files & Search (60-75% savings)
rtk ls <path>           rtk read <file>         rtk grep <pattern>
rtk find <pattern>      rtk diff <file>

# Test (90-99% savings) — shows failures only
rtk pytest tests/       rtk cargo test          rtk test <cmd>

# Build & Lint (80-90% savings) — shows errors only
rtk tsc                 rtk lint                rtk cargo build
rtk prettier --check    rtk mypy                rtk ruff check

# Analysis (70-90% savings)
rtk err <cmd>           rtk log <file>          rtk json <file>
rtk summary <cmd>       rtk deps                rtk env

# GitHub (26-87% savings)
rtk gh pr view <n>      rtk gh run list         rtk gh issue list

# Infrastructure (85% savings)
rtk docker ps           rtk kubectl get         rtk docker logs <c>

# Package managers (70-90% savings)
rtk pip list            rtk pnpm install        rtk npm run <script>
```

## Rules
- In command chains, prefix each segment: `rtk git add . && rtk git commit -m "msg"`
- For debugging, use raw command without rtk prefix
- `rtk proxy <cmd>` runs command without filtering but tracks usage
<!-- /headroom:rtk-instructions -->
