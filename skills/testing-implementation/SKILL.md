---
name: testing-implementation
description: Use when implementing-feature delegates testing, when validating test coverage for a feature, or when any prompt mentions tests, test files, assertions, mocks, or test adjustments
---

# Testing Implementation

Writes and executes tests, validates coverage, and ensures the implementation meets the success criteria defined in the plan. Works after implementing-feature completes each phase.

## Execution Model

When dispatched by `orchestrating-tasks`, use `agent_type: "go-tester"` if the repo defines that agent at `agents/go-tester.md`. Its system prompt front-loads all testing conventions at the system level, keeping testing rules at high attention. For non-Go work, use `agent_type: "general-purpose"`.

## When to use

- implementing-feature delegates testing after a phase is complete
- User asks to write tests for a specific package or feature
- User asks to validate test coverage
- **Any prompt that mentions tests, test files, assertions, mocks, or test adjustments**

---

## Steps

### Step 1 — Context Bootstrap

1. Run availability checks:
   ```bash
   [ -f "graphify-out/GRAPH_REPORT.md" ] && GRAPHIFY_AVAILABLE=true || GRAPHIFY_AVAILABLE=false
   [ -n "${COPILOT_VAULT:-${AI_MEMORY_HOME:-}}" ] && VAULT_AVAILABLE=true || VAULT_AVAILABLE=false
   ```
   - If `GRAPHIFY_AVAILABLE=true`: scan the graph for the domains and packages being tested to understand dependencies and existing test patterns.
   - If `VAULT_AVAILABLE=true`: read domain notes for prior decisions on testing patterns.
   - If neither exists, proceed directly.

2. Use the `{plan_root}` provided by `orchestrating-tasks`. If running standalone, resolve `{plan_root}` with the same rule: prefer `$AI_MEMORY_HOME/{project}/plans/`; if unset, use `$COPILOT_VAULT/{project}/plans/`; then create or refresh `.plans` as a symlink to `{plan_root}`.
3. Read `{plan_root}/{slug}/implementation-plan.md` to understand success criteria for the current phase.
4. Read the active provider-native project instruction files for project testing conventions and any repo-local docs they explicitly route you to.
5. Analyze existing test files for the affected packages. Identify patterns, mock setup, factory functions, and whether the target code starts goroutines.
6. Write unit tests: table-driven, fail-fast assertions, project's mock strategy (e.g. `EXPECT()` builder for testify/mockery). Cover happy path + each error case + edge cases. Test data via factory/fixture helpers — never inline complex structs.
7. Write integration tests where applicable (repository layer, external integrations): follow project conventions for test tagging, suites, and fixture files.
8. Run **only the affected tests** — never the full suite:

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

### Step 2 — Dispatch validate-loop

After tests pass locally, dispatch validate-loop for the testing phase:

| Parameter | Value |
|---|---|
| `agent_type` | `"validate-loop"` |
| `mode` | `"background"` |
| `prompt` | `slug: {slug}\nphase: testing\nmax_iterations: 2\nplan_excerpt: {current phase section}` |

> **Hard cap: max_iterations: 2.** After 2 repair cycles without HARNESS PASS, the loop returns `LOOP FAIL (escalate: true)` — never continue past 2 cycles.

- If `LOOP PASS`: proceed to Step 3 (test-design-judge).
- If `LOOP FAIL` (`escalate: true`): present failures and iteration count to the user and wait for direction.

### Step 3 — test-design-judge (mandatory after LOOP PASS)

`validate-loop` enforces structural quality (compile, lint, test pass). It cannot enforce semantic design rules:
- Test name predicates that don't hold for all table rows
- Magic literal values in ID fields
- Comments inside test files
- Pre-existing modern-Go violations the Boy Scout rule requires fixing

Dispatch a semantic judge using a **different vendor** from the test author (cross-vendor rule — see `orchestrating-tasks/dispatching.md`):

| Parameter | Value |
|---|---|
| `agent_type` | `"general-purpose"` |
| `model` | Cross-vendor, Balanced tier |
| `mode` | `"background"` |

Prompt template:
```
You are a strict reviewer of test code design. Your only job is to score the
diff against documented project rules and output APPROVED or BLOCKED with
specific reasons. You do not propose fixes, you do not write code.

## Diff to review

Run `git diff HEAD -- '*_test.go' 'testdata/**'` to see all test changes.

## Documented rules (read these; do NOT rely on prior knowledge)

- active provider-native testing rules
- .github/skills/writing-modern-go/SKILL.md
- active provider-native Go style rules (if the repo defines them)

## Output format

Output EXACTLY one of:

APPROVED

or

BLOCKED
- {rule violated} ({doc path:section}) at {file:line}: {what is wrong, 1 sentence}
- ...

## Rules to enforce

1. Test names: TestX_ShouldY predicate must hold for ALL rows when table-driven.
   If subtests assert opposite outcomes, the parent predicate is invalid.
2. No magic literal primary keys or ID values — must derive from named constants or factory output.
3. No bare placeholders for fields with known production formats.
4. No comments anywhere in test files or testdata/ packages — no // Arrange/Act/Assert,
   no doc comments on exported symbols in testdata/. The linter does not catch this.
5. No ticket IDs anywhere in test code.
6. Boy Scout for modern-go: any pre-existing legacy pattern (interface{}, errors.As non-typed,
   context.Background() in tests, for i:=0; i<n) in a touched file must be replaced.
7. Fail-fast assertions (require, not assert); project mock builder (EXPECT(), not mock.On()).
8. t.Context() not context.Background() in tests.
```

- If judge returns `APPROVED`: proceed to Output.
- If judge returns `BLOCKED`: do ONE repair cycle — re-dispatch go-tester with the BLOCKED reasons as the only instructions, then re-run Step 3. If the second judge run is still BLOCKED, report `LOOP FAIL` to the orchestrator with the judge findings and stop.

---

## Output

Update `{plan_root}/{slug}/progress.md`:

```markdown
## Test Results — Phase {N}
- Unit tests: PASS ({N} tests)
- Integration tests: PASS / SKIPPED (no local env) / FAIL
- Lint: PASS / {issues}
- validate-loop: LOOP PASS
- test-design-judge: APPROVED
```

---

## Test naming

Follow the project's naming convention. General pattern:

```
TestSubject_ShouldDescribeExpectedBehavior
{ name: "should return error when id is empty" }
{ name: "should rollback transaction on save failure" }
```

No ticket IDs. No `And` chaining two behaviors in one name — split or rename.

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

- [ ] Fail-fast assertions — never soft assertions
- [ ] Project mock builder (`EXPECT()`, never `mock.On()`)
- [ ] `//go:generate` or equivalent on all mocked interfaces
- [ ] Test names: `TestFoo_ShouldDoX` / `"should do x"` — predicate holds for ALL rows
- [ ] Test data via factory/fixture helpers — never inline complex structs
- [ ] No comments anywhere in test code or testdata/ packages
- [ ] No ticket IDs in test names, fixture identifiers, or payload filenames
- [ ] For goroutine-based code: `synctest.Test` + `synctest.Wait()` (when available)
- [ ] No `sync.WaitGroup`, ad-hoc channels, or `time.Sleep` for test synchronization
- [ ] No testing-oriented production code (hooks, flags, branches) added solely for tests
- [ ] Integration tests tagged appropriately (`//go:build integration` or project standard)
- [ ] All fixtures in `testdata/` or equivalent project fixture directory
