---
name: testing-implementation
description: Use when implementing-feature delegates testing, when validating test coverage for a feature, or when any prompt mentions tests, test files, assertions, mocks, or test adjustments
---

# Testing Implementation

Writes and executes tests, validates coverage, and ensures the implementation meets the success criteria defined in the plan. Works after implementing-feature completes each phase.

## Execution Model

When dispatched by `orchestrating-tasks`, choose the logical role first, then render the actual call using `skills/orchestrating-tasks/provider-dispatch.md`.

- Go test work -> logical role `go-tester`
- Non-Go test work -> logical role `general-purpose`

In Copilot native mode this may map to `agent_type`. In Codex managed mode prefer a matching custom agent from `~/.codex/agents/` or `.codex/agents/`; otherwise bind the logical role in the prompt and treat the worker output as untrusted until the orchestrator accepts it.

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
5. Analyze existing test files for the affected packages. Identify patterns, mock setup, factory functions, and whether the target code starts goroutines.
6. Write unit tests: table-driven, fail-fast assertions, project's mock strategy (e.g. `EXPECT()` builder for testify/mockery). Cover happy path + each error case + edge cases. Test data via factory/fixture helpers: never inline complex structs.
7. Write integration tests where applicable (repository layer, external integrations): follow project conventions for test tagging, suites, and fixture files.
8. Run **only the affected tests**: never the full suite:

   ```bash
   # Unit tests: target the specific package(s) changed
   go test ./path/to/package/... -count=1 -timeout=60s

   # Integration tests: scan for tagged packages first, then run each
   grep -rl '//go:build integration' path/to/domain/ | xargs -I{} dirname {} | sort -u
   # Run each package found

   # Lint: scoped to changed paths
   golangci-lint run ./path/to/changed/... | head -50
   ```

   > **Never run the full suite.** Target only the affected paths.
   > For goroutine-based code, use the project's async synchronization pattern (`synctest.Test` + `synctest.Wait()` when available). Never use `sync.WaitGroup`, ad-hoc channels, or `time.Sleep` for test synchronization.

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

## Test naming

Follow the project's naming convention. General pattern:

```
TestSubject_ShouldDescribeExpectedBehavior
{ name: "should return error when id is empty" }
{ name: "should rollback transaction on save failure" }
```

No ticket IDs. No `And` chaining two behaviors in one name, split or rename.

## Mock pattern

Use the project's mocking strategy. Example for testify/mockery (Go):

```go
// Always EXPECT() builder
repo.EXPECT().FindByID(mock.Anything, "id-1").Return(entity, nil)
```

## Async test pattern

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
time.Sleep(10 * time.Millisecond)
```

## Quality checklist

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

## Codex Runtime Override

When dispatched by `orchestrating-tasks` in Codex managed mode, a generic worker is not the testing harness. The worker may write tests, but its success is only `WORKER PASS`; the orchestrator must audit the diff with `orchestrating-tasks/codex-runtime.md` before accepting the phase.

Hard testing conventions that must be checked manually in Codex managed mode:

- Reusable fixtures, representative JSON payloads, and domain objects live under `testdata/` or the project fixture directory.
- Inline test values are limited to scalar inputs, expected constants, and trivial one-off assertions.
- Tests do not call external services unless the phase is explicitly an integration or smoke phase.
- Test workers do not edit production files unless a repair cycle is explicitly approved.

If any of these fail, report `BLOCKED` or dispatch a repair cycle. Do not report the phase as accepted.
