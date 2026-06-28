# Quality Harness

The quality harness is a two-layer, receipt-based validation system that runs after each AI-assisted phase. It enforces coding standards without duplicating rules already captured in `.github/instructions/`.

## Purpose

AI agents operating in long contexts drift from style rules over time. The harness prevents this by validating every phase against the canonical instruction files, not against prose embedded in skill files. When a rule changes in `.github/instructions/`, the harness enforces it immediately with no script changes required.

## How to Run

`orchestrating-tasks` dispatches `harness-gate` as a dedicated isolated agent (via `validate-loop`) after each phase. You do not invoke it directly during normal AI-assisted workflows.

**Manual invocation** (for inspection or manual workflows):

```bash
# Validate the implementation phase
HARNESS_PLAN=<slug> bash .github/harness/harness-validate.sh --phase=implementation

# Validate the testing phase
HARNESS_PLAN=<slug> bash .github/harness/harness-validate.sh --phase=testing

# Gate: verify receipts exist before committing
HARNESS_PLAN=<slug> bash .github/harness/require-receipts.sh implementation testing
```

## How to Read Results

`harness-validate.sh` streams JSON lines to stdout during the run. To review results after the fact:

```bash
# Human-readable summary of a phase receipt
HARNESS_PLAN=<slug> bash .github/harness/harness-report.sh --phase=implementation
HARNESS_PLAN=<slug> bash .github/harness/harness-report.sh --phase=testing

# Most recent receipt (omit --phase)
HARNESS_PLAN=<slug> bash .github/harness/harness-report.sh
```

Example output:

```
═══════════════════════════════════════════════════
 Harness Receipt: implementation
 SHA: 86820a31  |  2026-06-02T17:49:24Z
 Plan: my-plan-slug
═══════════════════════════════════════════════════

Deterministic
  ✅ lint
  ✅ vet
  ✅ fmt

Semantic (LLM-judge)
  ✅ go-style
  ✅ clean-architecture
  ❌ error-handling
     • internal/app/foo/usecase.go:42: Always wrap errors with context [medium]
  ✅ modern-go
  ✅ package-design

Overall: FAIL
```

## Two-Layer Architecture

### Layer A: Deterministic

Wrappers over existing project tooling. Exit-code based, zero LLM cost.

| Check | What it runs |
|---|---|
| Lint | Project linter (e.g. `golangci-lint`, `eslint`, `ruff`) |
| Vet / static analysis | Language-level static analysis (e.g. `go vet`, `tsc --noEmit`) |
| Format | Formatter check (e.g. `gofmt -l`, `prettier --check`) |
| Unit tests | Scoped unit test suite |
| Integration tests | Scoped integration test suite (testing phase only) |

### Layer B: Semantic / LLM-as-judge

Each `.github/instructions/*.instructions.md` file is the **source of truth**. The harness reads the file, reads the diff scoped to the `applyTo` glob, and dispatches an LLM with a fixed JSON schema. No rule duplication in bash scripts. When a rule changes in an `.instructions.md` file, the harness enforces it automatically on the next run.

Requires the Copilot CLI or equivalent. On machines without it, all LLM-judge checks emit `"result":"skip"`. Skips never block the gate.

Each instruction file runs when the diff contains files matching its `applyTo` glob.

The phase → instructions mapping is configured in `lib/instructions-map.yaml`.

## Receipt Model

After each phase passes, the harness writes a receipt to `$PLAN_ROOT/{slug}/receipts/`:

```
$PLAN_ROOT/
└── {slug}/
    └── receipts/
        ├── implementation-<head-sha>.json
        └── testing-<head-sha>.json
```

A receipt is **valid** only when the HEAD sha and diff hash match the current working tree. Stale receipts are always rejected.

The `committing-changes` and `creating-pull-request` skills call `require-receipts.sh` as their first step when a harness is configured.

## Plan Root Resolution

The harness resolves `$PLAN_ROOT` using the same convention as `recall`/`checkpoint`:

1. If `$COPILOT_VAULT` (or `$AI_MEMORY_HOME`) is set and a `{project}/plans` directory exists there → use vault
2. Otherwise → `$HOME/ai-plans/{repo-name}`

See `lib/plan-root.sh` for the implementation.

## Active Plan Resolution

`lib/active-plan.sh` resolves the active plan using three strategies in order:

1. `HARNESS_PLAN=<slug>` env var override: explicit, always wins.
2. Current git branch: converts the branch name to a slug and matches against plan directories.
3. IN_PROGRESS scan: scans `$PLAN_ROOT/*/progress.md` for a single `IN_PROGRESS` plan.

## Adapting to a New Project

The harness shell scripts (`harness-validate.sh`, `require-receipts.sh`, `harness-report.sh`, and the `phases/`, `deterministic/`, `lib/` directories) are project-specific implementations. The agents in `agents/` (validate-loop, harness-gate) reference these scripts by convention.

To add the harness to a project:
1. Copy the harness shell script tree into `.github/harness/`
2. Adapt `phases/implementation.sh` and `phases/testing.sh` to the project's lint and test commands
3. Configure `lib/instructions-map.yaml` to map instruction files to their `applyTo` globs
4. The `validate-loop` and `harness-gate` agents work without modification
