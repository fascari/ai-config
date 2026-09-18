---
name: testing-implementation
description: Use when implementing-feature delegates testing, when validating test coverage for a feature, or when any prompt mentions tests, test files, assertions, mocks, or test adjustments
---

# Testing Implementation

Writes and executes tests, validates coverage, and ensures the implementation meets the success criteria defined in the plan. Works after implementing-feature completes each phase.

## Execution Model

When dispatched by `orchestrating-tasks`, detect the stack first, then choose the logical role. Render the actual call using `skills/orchestrating-tasks/provider-dispatch.md`.

### Stack Detection

Same `PHASE_FILES`/`STACK` detection logic as `implementing-feature`'s own
"Stack Detection" section — read it there rather than re-deriving it. The one
difference: populate `PHASE_FILES` from the phase's **test** file paths (e.g.
`PHASE_FILES="internal/feedclient/client_test.go"`), not its production files.
Any `*_test.go` in scope still wins outright and loads the Go rules, same as a
plain `.go` file does on the production side.

### Dispatch by stack

| Stack | Logical role | Why |
|---|---|---|
| Go | `go-tester` | Dedicated test agent, explicitly forbidden from touching production files |
| TypeScript / JavaScript | `general` | Run `npm test` + `npx jest` scoped to changed files |
| Python | `general` | Run `pytest` scoped to changed packages |
| Other / unknown | `general` | Fall back to project's own test command |

### Hard rule

**Never dispatch `go-tester` for non-Go stacks.** The Go test commands and mock conventions only apply when `STACK=go`. For any other stack, skip the Go-specific sections below.

In Copilot native mode, `go-tester` maps to an `agent_type` only when that agent is actually installed. When it is **not** an available native `agent_type`, do not fail and do not silently drop the Go rules: dispatch a real Copilot agent type (`general-purpose`), bind the logical role in the prompt (`Logical role: go-tester`), and front-load the canonical contract from `~/.ai-config/agents/go-tester.md` so the full Go test rule set still applies. In Codex managed mode prefer a matching custom agent from `~/.codex/agents/` or `.codex/agents/`; otherwise bind the logical role in the prompt and treat the worker output as untrusted until the orchestrator accepts it. **In Claude Code**, load this skill via `Skill(skill: "testing-implementation")` first, THEN dispatch `Agent(subagent_type: "go-tester", ...)` — two separate tool calls; fall back to `Agent(subagent_type: "general-purpose", ...)` with the logical role bound in the prompt if `go-tester` is not an available `subagent_type` this session. See `skills/orchestrating-tasks/claude-runtime.md`.

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
   - Test data via factory/fixture helpers when reuse or complexity warrants them; inline small literals otherwise.

   **Go:** table-driven, fail-fast assertions (`require`), project's mock strategy (e.g. `EXPECT()` builder for testify/mockery) — **but verify the project actually has `testify`/`mockery` configured first.** Grep `go.mod` for `stretchr/testify` as a direct (not indirect) dependency and check for any `go:generate` mockery directive before assuming this applies; real repos exist where neither is present at all, in which case the canonical rule does not silently disable — the deviation is exactly this: `if err != nil { t.Errorf(...) }` instead of `require`, and hand-written mocks instead of generated ones, stated as a documented deviation in the phase report, not applied quietly.

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
   # OR the project's real lint entrypoint if golangci-lint isn't configured —
   # check for .golangci.yml or a documented alternative (e.g. gofmt/go vet/revive
   # via a tools/bin/check.sh) before assuming golangci-lint applies.
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

9. Update `{plan_root}/{slug}/progress.md` with test results. **In Claude Code**, do this by including the structured completion-report block from the "Claude Code Runtime Note" below in your final report — the orchestrator transcribes it, since a fresh `Agent` dispatch doesn't reliably share the vault's write history. In native-harness modes with continuous file access, editing `progress.md` directly is fine.

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

## Test-suite strategy (cost/benefit)

Pick the cheapest tier that proves the behavior. Tokens and CI time are budgets:
most coverage should be fast unit tests; reserve heavier tiers for wiring and
external contracts. See `rules/architecture-blueprint.md` for the baseline.

| Tier | Proves | Cost | Use when |
|------|--------|------|----------|
| Unit | pure logic, one collaborator mocked | cheapest | default — the bulk of tests |
| Handler | HTTP parse → use case → response shape | cheap | every endpoint; real use case + mocked collaborators + `pkg/handlertest` + `go:embed` golden JSON |
| External-HTTP interception | a typed client against a recorded upstream | medium | any outbound HTTP; use an `httptest.Server` **upstream stub**, never `gock`/transport monkeypatching |
| Integration / e2e | assembled router + real DB/upstream | most | wiring and contracts; tag `//go:build integration`, drive golden request/response fixtures; DB uses YAML fixtures + an `assert/` sub-package |

**Interception strategy:** the httptest upstream stub is the modern,
dependency-free default. It records requests and serves per-route golden bodies,
works with any client, and needs no `http.DefaultTransport` patching. Do not
introduce `gock`; the architecture gate fails on it (U9).

**When there is a database:** repository tests are integration tests backed by
YAML fixtures reloaded per suite method; never mock the DB; assert side effects
through a dedicated `assert/` sub-package, never raw inline queries.

Before reporting a phase done, run the deterministic gates: `style-gate`
architectural greps and, for a whole domain or fresh scaffold, the full
`skills/architecture-gate` harness. Any ERROR = not done.

## Test naming

Follow the project's naming convention. General pattern:

```
TestSubject_ShouldDescribeExpectedBehavior
{ name: "should return error when id is empty" }
{ name: "should rollback transaction on save failure" }
```

No ticket IDs. No `And` chaining two behaviors in one name, split or rename.

## Mock pattern (Go)

When `STACK=go` **and the project has `testify`/`mockery` actually configured** (see the verification step above), use it:

```go
// Always EXPECT() builder
repo.EXPECT().FindByID(mock.Anything, "id-1").Return(entity, nil)
```

**When the project has neither** (a real, documented, non-rare case — not an
excuse to skip checking): hand-write mocks as structs with func fields
satisfying a locally-declared interface, matching the neighboring package's
existing pattern if one exists, and use stdlib `if got != want { t.Errorf(...) }`
instead of `require`. State this as a deviation in the phase report, don't
silently downgrade without saying so.

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
- [ ] Mocks are mockery-generated when the project has `testify`/`mockery` configured; hand-written `fake*/stub*/mock*` structs only when it doesn't, with the deviation stated in the phase report (see "Mock pattern" above) — never hand-written as a shortcut when generation is actually available
- [ ] Handler tests assert the **whole** response object vs golden `testdata/` — no field-by-field or `InDelta`/`InEpsilon` float asserts
- [ ] External HTTP tested via an `httptest.Server` upstream stub — never `gock`/transport monkeypatching
- [ ] `//go:generate` or equivalent on all mocked interfaces
- [ ] Test names: `TestFoo_ShouldDoX` / `"should do x"`: predicate holds for ALL rows
- [ ] Test data via factory/fixture helpers when reuse or complexity warrants them
- [ ] No comments anywhere in test code or fixture helper packages
- [ ] No ticket IDs in test names, fixture identifiers, or payload filenames
- [ ] For goroutine-based code: `synctest.Test` + `synctest.Wait()` (when available)
- [ ] No `sync.WaitGroup`, ad-hoc channels, or `time.Sleep` for test synchronization
- [ ] No testing-oriented production code (hooks, flags, branches) added solely for tests
- [ ] Integration tests tagged appropriately (`//go:build integration` or project standard)
- [ ] Static fixtures (JSON, YAML, PDF) in `testdata/`; Go factories in `*_fixtures_test.go` or a `<pkg>test` sibling — never as a `testdata/` Go package

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

- Static fixtures and golden JSON/YAML live under `testdata/`. Go factories live in `*_fixtures_test.go` or a `<pkg>test` sibling, and only when reuse or complexity warrants them.
- Small one-off composite literals may stay inline in the test. Do not put Go factory packages under `testdata/`.
- Tests do not call external services unless the phase is explicitly an integration or smoke phase.
- Test workers do not edit production files unless a repair cycle is explicitly approved.

If any of these fail, report `BLOCKED` or dispatch a repair cycle. Do not report the phase as accepted.

## Claude Code Runtime Note

When dispatched via `Skill(skill: "testing-implementation")` → `Agent(subagent_type: "go-tester" | "general-purpose", ...)`, end your report with this block so the orchestrator can transcribe it into `progress.md`:

```
## Progress Update
Phase: {N} — {title}
Test files created: {list}
Test names: {list}
Gates: gofmt={PASS/FAIL} vet={PASS/FAIL} {project's real lint}={PASS/FAIL} test={PASS/FAIL}
Production files touched: none | {list, should be none}
Blockers: {none | description}
```

Expect the orchestrator to independently re-run the reported gates and confirm zero production-file changes before proceeding — a subagent's self-reported PASS is a claim, not a fact.
