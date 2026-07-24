---
name: testing-implementation
description: Use when implementing-feature delegates testing, when validating test coverage for a feature, or when any prompt mentions tests, test files, assertions, mocks, or test adjustments
---

# Testing Implementation

Writes and executes tests, validates coverage, and ensures the implementation meets the success criteria defined in the plan. Works after implementing-feature completes each phase.

## Execution Model

When dispatched by `orchestrating-tasks`, detect the stack first, then choose the logical role. Render the actual call using `skills/orchestrating-tasks/provider-dispatch.md`.

### Stack Detection

```bash
# Detect the stack for THIS phase from the test files it targets, not a single
# repo-wide flag. A mixed repo (Go engine + React UI) has single-stack phases;
# route each by the files it touches. Any *_test.go in scope means Go governs,
# so the canonical Go test rules always load for Go work.
#
# PHASE_FILES MUST be populated before detection. Derive it now, in order, from:
#   1. the target test file paths named in the dispatch prompt, or
#   2. the test files for the current phase in
#      {plan_root}/{slug}/implementation-plan.md (read that phase now).
# Example: PHASE_FILES="internal/feedclient/client_test.go"
PHASE_FILES="${PHASE_FILES:-}"

STACK="unknown"
for f in $PHASE_FILES; do
  case "$f" in
    *.go)                  STACK="go"; break ;;   # a Go test file in scope wins outright
    *.ts|*.tsx|*.js|*.jsx) STACK="typescript" ;;
    *.py)                  STACK="python" ;;
  esac
done

# Empty scope is only safe in a single-manifest repo. In a mixed repo do NOT
# guess from a root manifest: a Go module plus a root package.json would wrongly
# force Go onto a React test phase. Fail closed and request the target files.
if [ "$STACK" = "unknown" ]; then
  manifests=0
  [ -f "go.mod" ] && manifests=$((manifests + 1))
  [ -f "package.json" ] && manifests=$((manifests + 1))
  { [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; } && manifests=$((manifests + 1))
  if [ "$manifests" -gt 1 ]; then
    echo "stack=ambiguous: populate PHASE_FILES from the phase scope (multi-manifest repo)" >&2
    exit 1
  fi
  [ -f "go.mod" ] && STACK="go"
  [ "$STACK" = "unknown" ] && [ -f "package.json" ] && STACK="typescript"
  [ "$STACK" = "unknown" ] && { [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; } && STACK="python"
fi
echo "stack=$STACK"
```

### Dispatch by stack

| Stack | Logical role | Why |
|---|---|---|
| Go | `go-tester` | Dedicated test agent, explicitly forbidden from touching production files |
| TypeScript / JavaScript | `general` | Run `npm test` + `npx jest` scoped to changed files |
| Python | `general` | Run `pytest` scoped to changed packages |
| Other / unknown | `general` | Fall back to project's own test command |

### Hard rule

**Never dispatch `go-tester` for non-Go stacks.** The Go test commands and mock conventions only apply when `STACK=go`. For any other stack, skip the Go-specific sections below.

In Copilot native mode, `go-tester` maps to an `agent_type` only when that agent is actually installed. When it is **not** an available native `agent_type`, do not fail and do not silently drop the Go rules: dispatch a real Copilot agent type (`general-purpose`), bind the logical role in the prompt (`Logical role: go-tester`), and front-load the canonical contract from `~/.ai-config/agents/go-tester.md` so the full Go test rule set still applies. In Codex managed mode prefer a matching custom agent from `~/.codex/agents/` or `.codex/agents/`; otherwise bind the logical role in the prompt and treat the worker output as untrusted until the orchestrator accepts it.

## When to use

- implementing-feature delegates testing after a phase is complete
- User asks to write tests for a specific package or feature
- User asks to validate test coverage
- **Any prompt that mentions tests, test files, assertions, mocks, or test adjustments**

---

## Steps

### Step 1: Context Bootstrap

1. Run availability checks:
   ```bash
   [ -f "graphify-out/GRAPH_REPORT.md" ] && GRAPHIFY_AVAILABLE=true || GRAPHIFY_AVAILABLE=false
    [ -n "${AI_MEMORY_HOME:-}" ] && VAULT_AVAILABLE=true || VAULT_AVAILABLE=false
   ```
   - If `GRAPHIFY_AVAILABLE=true`: scan the graph for the domains and packages being tested to understand dependencies and existing test patterns.
   - If `VAULT_AVAILABLE=true`: read domain notes for prior decisions on testing patterns.
   - If neither exists, proceed directly.

2. Use the `{plan_root}` provided by `orchestrating-tasks`. If running standalone, resolve `{plan_root}` with the same rule: use `$AI_MEMORY_HOME/{project}/plans/`; then create or refresh `.plans` as a symlink to `{plan_root}`.
3. Read `{plan_root}/{slug}/implementation-plan.md` to understand success criteria for the current phase.
4. Read the active provider-native project instruction files for project testing conventions and any repo-local docs they explicitly route you to.
5. Analyze existing test files for the affected packages. Identify patterns, mock setup, factory functions.

   **Go only:** check whether the target code starts goroutines.

6. Write unit tests following the stack's conventions:
   - Cover happy path + each error case + edge cases.
   - Test data via factory/fixture helpers: never inline complex structs.

   **Go:** table-driven, fail-fast assertions (`require`), project's mock strategy (e.g. `EXPECT()` builder for testify/mockery).

   **TypeScript:** fail-fast assertions (`expect`), project's mock strategy (e.g. `jest.fn()`, `mocks/`).

   **Python:** fail-fast assertions (`assert`), project's mock strategy (e.g. `pytest-mock`, `unittest.mock`).

7. Write integration tests where applicable (repository layer, external integrations): follow project conventions for test tagging, suites, and fixture files.

8. Run **only the affected tests**: never the full suite:

   **Go stack:**
   ```bash
   go test ./path/to/package/... -count=1 -timeout=60s

   # Integration tests: scan for tagged packages first, then run each
   grep -rl '//go:build integration' path/to/domain/ | xargs -I{} dirname {} | sort -u

   golangci-lint run ./path/to/changed/... | head -50
   ```

   **TypeScript stack:**
   ```bash
   npx jest --findRelatedTests path/to/changed/file.test.ts 2>&1 | head -50
   npx tsc --noEmit --strict 2>&1 | head -50
   ```

   **Python stack:**
   ```bash
   python -m pytest path/to/changed/test_file.py -x 2>&1 | head -50
   ```

   **Other / unknown stack:**
   ```bash
   # Use whatever test command the project documents
   # e.g. npm test, make test, cargo test
   ```

   > **Never run the full suite.** Target only the affected paths.
   > **(Go only)** For goroutine-based code, use the project's async synchronization pattern (`synctest.Test` + `synctest.Wait()` when available). Never use `sync.WaitGroup`, ad-hoc channels, or `time.Sleep` for test synchronization.

9. Update `{plan_root}/{slug}/progress.md` with test results.

> **Note:** Semantic validation (rules compliance, architecture, error handling) happens in `reviewing-code`, not here. This phase focuses on deterministic gates only (tests + lint).

---

## Output

Update `{plan_root}/{slug}/progress.md`:

```markdown
## Test Results: Phase {N}
- Unit tests: PASS ({N} tests)
- Integration tests: PASS / SKIPPED (no local env) / FAIL
- Lint: PASS / {issues}
```

---

## Canonical rules first (Go)

When `STACK=go`, load the complete canonical test rule set via the `go-tester` Pre-work
(`~/.ai-config/agents/go-tester.md`, which lists `testing`, `go-style`, `error-handling`, and
`writing-modern-go`) before writing tests. The patterns and checklist below are a fast working
reference, not a replacement. On any conflict the canonical rules win.

## Test naming

Follow the project's naming convention. General pattern:

```
TestSubject_ShouldDescribeExpectedBehavior
{ name: "should return error when id is empty" }
{ name: "should rollback transaction on save failure" }
```

No ticket IDs. No `And` chaining two behaviors in one name, split or rename.

## Mock pattern (Go)

When `STACK=go`, use testify/mockery:

```go
// Always EXPECT() builder
repo.EXPECT().FindByID(mock.Anything, "id-1").Return(entity, nil)
```

**Non-Go stacks:** use the project's native mocking strategy (e.g. `jest.fn()` for TypeScript, `pytest-mock` for Python). Follow local conventions; do not impose Go mock patterns.

## Async test pattern (Go only)

When `STACK=go` and the target code starts goroutines:

```go
// Good: deterministic async coordination
synctest.Test(t, func(t *testing.T) {
    ctx := t.Context()
    err := uc.Execute(ctx, input)
    require.NoError(t, err)
    synctest.Wait()
})

// Bad: orchestration primitives used only for test synchronization
var wg sync.WaitGroup
done := make(chan struct{})
time.Sleep(10 * time.Microsecond)
```

## Quality checklist

**Go stack:**
- [ ] Fail-fast assertions: never soft assertions
- [ ] Project mock builder (`EXPECT()`, never `mock.On()`)
- [ ] `//go:generate` or equivalent on all mocked interfaces
- [ ] Test names: `TestFoo_ShouldDoX` / `"should do x"`: predicate holds for ALL rows
- [ ] Test data via factory/fixture helpers: never inline complex structs
- [ ] No comments anywhere in test code or testdata/ packages
- [ ] No ticket IDs in test names, fixture identifiers, or payload filenames
- [ ] For goroutine-based code: `synctest.Test` + `synctest.Wait()` (when available)
- [ ] No `sync.WaitGroup`, ad-hoc channels, or `time.Sleep` for test synchronization
- [ ] No testing-oriented production code (hooks, flags, branches) added solely for tests
- [ ] Integration tests tagged appropriately (`//go:build integration` or project standard)
- [ ] All fixtures in `testdata/` or equivalent project fixture directory

**Non-Go stacks:**
- [ ] Fail-fast assertions
- [ ] Project's own mock/fixture strategy used
- [ ] Test data via factory/fixture helpers
- [ ] No ticket IDs in test names
- [ ] No testing-oriented production code added solely for tests
- [ ] Tests pass scoped to affected files (step 8)
- [ ] All fixtures in project's fixture directory

## Codex Runtime Override

When dispatched by `orchestrating-tasks` in Codex managed mode, a generic worker is not the testing harness. The worker may write tests, but its success is only `WORKER PASS`; the orchestrator must audit the diff with `orchestrating-tasks/codex-runtime.md` before accepting the phase.

Hard testing conventions that must be checked manually in Codex managed mode:

- Reusable fixtures, representative JSON payloads, and domain objects live under `testdata/` or the project fixture directory.
- Inline test values are limited to scalar inputs, expected constants, and trivial one-off assertions.
- Tests do not call external services unless the phase is explicitly an integration or smoke phase.
- Test workers do not edit production files unless a repair cycle is explicitly approved.

If any of these fail, report `BLOCKED` or dispatch a repair cycle. Do not report the phase as accepted.
