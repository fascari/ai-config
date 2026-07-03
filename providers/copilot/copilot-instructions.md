# GitHub Copilot Instructions - token-swap-workbench

Use `AGENTS.md` at the repository root as the primary repo-wide instructions for this repository.

Path-specific rules under `.github/instructions/*.instructions.md` are loaded automatically by Copilot for matching files. Treat those files as the authoritative source for Go style, testing conventions, package design, error handling, and clean architecture rules.

Repository docs that matter for most work:

- `docs/architecture.md` for package boundaries and module layout
- `docs/testing.md` for test structure and integration conventions
- `docs/development.md` for setup and day-to-day commands

If both `AGENTS.md` and a path-specific instruction apply, follow the more specific path-based rule and surface any conflict instead of guessing.
