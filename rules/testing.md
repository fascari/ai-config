---
applyTo: "**/*_test.go,**/testdata/**/*.go,**/factory/**/*.go"
---

# Testing

## Test Quality Properties (FIRST)

Every unit test must satisfy all five FIRST properties:

| Property | Rule |
|---|---|
| **Fast** | Unit tests run in milliseconds. No I/O, no sleep, no real HTTP calls. If a test needs a database, it is an integration test (tag with `//go:build integration`) |
| **Independent** | Tests do not share state. Each test arranges its own mocks and data. Execution order must not matter |
| **Repeatable** | Same result every run, regardless of time, environment, or external systems. Use testdata factories and inject clocks — never call `time.Now()` in production code under test |
| **Self-validating** | Test passes or fails automatically. No human inspection of output. `require` (not `assert`) stops on first failure |
| **Timely** | Tests are written with the code, not after |

```go
// Bad: not fast (sleeps), not repeatable (real clock)
func TestPrice_ShouldApplyDiscount(t *testing.T) {
    time.Sleep(100 * time.Millisecond)
    result := calculateDiscount(time.Now())
    require.Equal(t, 0.15, result)
}

// Good: fast, deterministic, injectable clock
func TestPrice_ShouldApplyDiscount(t *testing.T) {
    fixedTime := time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC)
    result := calculateDiscount(fixedTime)
    require.Equal(t, 0.15, result)
}
```

## Identifiers and Naming

**Never use ticket IDs (e.g. `PROJ-1234`, `TASK-5678`) as identifiers in test code, fixtures, or test data.** Tickets are transient project-management metadata; test names and seeds must describe the *behavior* or *scenario* under test so they remain meaningful long after the ticket is closed.

Forbidden:
- Test function or sub-test names: `TestPROJ52012BaselineGuard`, `"should fix TASK-1234 bug"`
- Fixture identifiers: `id: PROJ52012-ORDER-A`, `name: "PROJ-52012 Regression Order"`
- Payload filenames: `update-input-proj52012-status-change.json`
- Variable/constant names: `proj52012Order`, `PROJ52012OrderID`

Correct:
- Use scenario descriptors: `TestUpdateOrderStatusBaselineGuard`, `"should not create a new draft when latest version is withdrawn"`
- Fixture identifiers describe the role: `id: SCENARIO-ORDER-A`, `name: "Baseline Guard Regression Order"`
- Payload filenames describe the scenario: `update-input-baseline-guard-status.json`

If a real-world identifier (SKU, account, order) is essential to reproduce the scenario, put it in a code comment near the fixture, not in the identifier itself.

### Real-world identifier formats (domain fields)

When a test sets a domain field that has a known production format, use that format. Generic placeholders (`"party-A"`, `"source-1"`, `"acct-X"`, `"id-1"`, `"foo"`) are forbidden when a production format exists — they read as alien to anyone debugging a real incident and make the test ungreppable against production logs.

Distinguish rows with a numeric or descriptive suffix that preserves the format.

| Field | Production format | OK | NOT OK |
|---|---|---|---|
| `order_id`, foreign refs | UUID (RFC 4122) | `00000000-0000-0000-0000-000000000001`, `...000000000002` | `id-1`, `order-A` |
| `account_id` | `ACCT` + digits | `ACCT001`, `ACCT002` | `acct-A`, `account-1` |
| `customer_id` | `CUST` + digits | `CUST001`, `CUST002` | `cust-X`, `customer-1` |
| Mocked UUIDs | RFC 4122 | `00000000-0000-0000-0000-000000000001` | `uuid-1`, `id-X` |

This rule is distinct from scenario descriptors (`SCENARIO-ORDER-A`): scenario descriptors are explicit tags for fixture rows used only by tests and have no production counterpart, so the rule above does not apply to them. If unsure whether a field has a production format, grep the codebase for a populated example before inventing a placeholder.

### Numeric primary key values

Bare integer literals as primary keys, foreign keys, or any DB-mapped ID are forbidden. Use a named constant or derive the value from the factory output.

| OK | NOT OK |
|---|---|
| `EntityID: testdata.OrderID` | `EntityID: 77` |
| `VersionID: ruleset.Versions[0].ID` | `VersionID: 99` |
| `ParentID: int(entity.Parent.ID)` | `ParentID: 55` |

If the test does not care about the specific ID value, leave it zero — do not invent magic numbers. `1`, `2`, `55`, `77` as IDs are the integer equivalent of `"id-1"` or `"acct-A"`: ungreppable, semantically void, and they hide whether the test actually asserts something meaningful about the value or just stamped a placeholder.

## Test Naming Convention

```go
func TestUseCaseName_ShouldDescribeExpectedBehavior(t *testing.T) { ... }
// subtests: "should return error when entity not found"
```

### Table-driven predicate must hold for every row

The parent function's `ShouldVerb` must be true for ALL subtests in the table. If the table contains rows asserting opposite behaviors (one preserves, another overwrites; one creates, another skips), the predicate is invalid — either:

- Split into two separate test functions (`Test_ShouldPreserveX`, `Test_ShouldOverwriteX`)
- Or use a neutral predicate that holds for all rows (e.g. `Test_ShouldDispatchByAvailability`, `Test_ShouldHandleX`)

Bad: `TestProcessOrders_ShouldUpdateStatusFields` with one row that preserves and another that overwrites — "ShouldUpdate" is false for the preserve row.

Good: `TestProcessOrders_ShouldDispatchByAvailability` covering both branches, OR two separate functions.

## Modern Go in tests — Boy Scout rule

When editing a `*_test.go` file, replace any `writing-modern-go` violation you encounter in the file (even pre-existing) in the same edit. The canonical list lives in the `writing-modern-go` skill — do NOT duplicate it here. Read that skill once before the first test edit and apply every "Before → After" entry to the file you are touching.

Leaving obsolete idioms in a file you just touched signals you didn't read the project's Go version and degrades the readability of the diff for reviewers comparing your new code to the surrounding style.

## Test File Placement

**Rule: match the test file to its source file; never invent feature-named test files.**

| Source file | Existing test file | Correct approach |
|---|---|---|
| `foo.go` | none | `foo_test.go` (`package foo` or `package foo_test` as appropriate) |
| `foo.go` | `foo_test.go` is `package foo_test` and you need whitebox access | add an `export_test.go` (`package foo`) that re-exports the internal symbol as a package-level var; test it from `foo_test.go` |
| `foo.go` | `foo_test.go` is `package foo` | add to `foo_test.go` — **do not create a new file** |

**`export_test.go` pattern (Go stdlib convention):**
```go
// export_test.go — compiled only during `go test`
package foo

var ExportedForTest = internalFunc
```

**Forbidden patterns:**
- Creating `fooguard_test.go`, `foofixup_test.go`, or any file whose name encodes a feature, ticket, or implementation detail rather than the source file being tested.
- Creating a new `_test.go` file when an existing file in the same package already covers the same source file.
- Using `_internal_test.go` as a suffix — this is NOT a Go community convention; it has no stdlib precedent.

**Why:** feature-named test files fracture test suites, orphan after refactors, and signal to reviewers that the author didn't know the `export_test.go` pattern.

### Short, semantic names

The predicate (`ShouldVerb`) must describe the observable outcome — not re-state what the subject already encodes, not add trailing qualifiers the group makes obvious.

**Remove:**
- Context implied by the test group: `ForHighPriority`, `WhenPriorityAndVIPCustomer`, `WhenScopesProvided`, `ForValidStatuses`
- Impl-detail leakage: `ShouldCallFilteredRepoMethod`, `ShouldRouteThroughSaveOrder`
- Double-negatives and filler: `EvenWhen`, `Chronologically`
- Structural double-`Should`: `TestShouldSkip_ShouldEvaluate` → `TestSkip_ShouldEvaluate`

**Rename examples:**

| Too long | Correct |
|---|---|
| `TestCreateOrder_ShouldCreatePriorityOrderWhenFlagSetAndCustomerIsVIP` | `TestCreateOrder_ShouldCreatePriorityOrder` |
| `TestProcessOrders_ShouldCallFilteredQueryWhenScopesProvided` | `TestProcessOrders_ShouldUseFilteredQuery` |
| `TestFindLatestVersion_ShouldPreferChronologicallyLatestVersion` | `TestFindLatestVersion_ShouldPreferLatestVersion` |
| `TestRouteOrder_ShouldRouteToPriorityPathWhenOrderTypeIsPriority` | `TestRouteOrder_ShouldRouteToPriorityPath` |
| `TestShouldSkipOrder_ShouldEvaluateExclusionCriteria` | `TestSkipOrder_ShouldEvaluateCriteria` |

**Target:** the full function name fits in ~70 characters without scrolling. If it doesn't, shorten the predicate.

## Table-Driven vs Individual Tests

Use table-driven tests when:

- Multiple cases share the same setup/act/assert structure and differ only in inputs and expected outputs
- You are testing a pure function or a method with a single code path that branches on input
- The test cases are independent and do not require unique setup logic per case

Use individual test functions when:

- Each case requires significantly different setup (different mocks, different dependencies, different state)
- The test exercises a complex flow where the arrange step is the main substance of the test
- A table would need fields like `setupFunc`, `mockBehavior`, and `customAssert` for most rows, making the table harder to read than separate functions
- You are testing distinct behaviors that happen to live in the same function (e.g., create vs update path in a single `Save` method)

The goal is readability. A table with 3 simple rows is clearer than 3 separate functions. A table with 15 rows where each row has a unique `setup` closure and custom assertions is harder to follow than 15 named functions.

```go
// Good: table-driven, cases differ only in input/output
func TestCalculateDiscount_ShouldApplyCorrectRate(t *testing.T) {
    tests := []struct {
        name     string
        quantity int
        want     float64
    }{
        {
            name:     "should return zero for small orders",
            quantity: 5,
            want:     0,
        },
        {
            name:     "should return 10% for medium orders",
            quantity: 50,
            want:     0.10,
        },
        {
            name:     "should return 15% for large orders",
            quantity: 200,
            want:     0.15,
        },
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := CalculateDiscount(tt.quantity)
            require.Equal(t, tt.want, got)
        })
    }
}

// Good: individual tests, each requires distinct setup
func TestPublishPost_ShouldPublishWhenValid(t *testing.T) {
    repo := mocks.NewRepository(t)
    repo.EXPECT().FindByID(mock.Anything, "post-1").Return(draftPost(), nil)
    repo.EXPECT().Save(mock.Anything, mock.Anything).Return(nil)
    notifier := mocks.NewNotifier(t)
    notifier.EXPECT().Notify(mock.Anything, mock.Anything).Return(nil)

    err := NewUseCase(repo, notifier).Execute(ctx, "post-1")
    require.NoError(t, err)
}

func TestPublishPost_ShouldRejectWhenAlreadyPublished(t *testing.T) {
    repo := mocks.NewRepository(t)
    repo.EXPECT().FindByID(mock.Anything, "post-1").Return(publishedPost(), nil)

    err := NewUseCase(repo, nil).Execute(ctx, "post-1")
    require.True(t, errors.Is(err, ErrAlreadyPublished))
}
```

## Table-Driven Tests

Every row in a table-driven test slice must be formatted as a multiline struct literal. Each field goes on its own line, fields are aligned, and the closing brace is on its own line. This applies to the outer test table and to any nested tables (e.g. modes, fixtures).

```go
// Good: multiline rows, fields aligned, no single-line literals
tests := []struct {
    name     string
    quantity int
    want     float64
}{
    {
        name:     "should return zero for small orders",
        quantity: 5,
        want:     0,
    },
    {
        name:     "should return 10% for medium orders",
        quantity: 50,
        want:     0.10,
    },
}
```

```go
// Bad: single-line literals, fields not aligned per row
tests := []struct {
    name     string
    quantity int
    want     float64
}{
    {name: "should return zero for small orders", quantity: 5, want: 0},
    {name: "should return 10% for medium orders", quantity: 50, want: 0.10},
}
```

This is a hard rule. Single-line row literals are prohibited in every table-driven test, including short rows with 1-2 fields. `gofmt` does not reformat single-line literals automatically, so this must be enforced in review and in the style-gate.

```go
func TestUseCase_ShouldReturnEntity(t *testing.T) {
    tests := []struct {
        name    string
        setup   func(*mocks.Repository)
        wantErr error
    }{
        {
            name: "should return entity when found",
            setup: func(m *mocks.Repository) {
                m.EXPECT().FindByID(mock.Anything, "123").Return(domain.Entity{ID: "123"}, nil)
            },
        },
        {
            name: "should return error when not found",
            setup: func(m *mocks.Repository) {
                m.EXPECT().FindByID(mock.Anything, "999").Return(domain.Entity{}, ErrNotFound)
            },
            wantErr: ErrNotFound,
        },
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            repo := mocks.NewRepository(t)
            tt.setup(repo)
            got, err := NewUseCase(repo).Execute(context.Background(), tt.input)
            if tt.wantErr != nil {
                require.Error(t, err)
                require.True(t, errors.Is(err, tt.wantErr))
                return
            }
            require.NoError(t, err)
            require.Equal(t, tt.want, got)
        })
    }
}
```

## Mock Generation

Mockery is configured with a single minimal root `.mockery.yaml` holding only global
defaults. Do **not** enumerate packages or interfaces in it, and do **not** set per-package
`dir`/`outpkg`. Each package that owns interfaces declares its own co-located directive, so
adding an interface never requires editing central config.

Root `.mockery.yaml` (the whole file):

```yaml
with-expecter: true
case: snake
disable-version-string: true
issue-845-fix: true
```

Co-located directive at the top of the file that declares the interface(s):

```go
//go:generate mockery --all --case=snake --disable-version-string --with-expecter
```

- One directive per interface-owning file. `--all` mocks every interface in that package
  into a local `mocks/` subpackage (`package mocks`).
- Generate with `go generate ./...` (wire it as the `mocks` task; never a bespoke
  `mockery` invocation that re-parses a `packages:` block).
- This legacy `--all` mode names mocks **without** a `Mock` prefix and files in snake_case:
  interface `Snapshotter` → `mocks/snapshotter.go`, type `mocks.Snapshotter`, constructor
  `mocks.NewSnapshotter(t)`. Reference tests accordingly (`mocks.NewSnapshotter`, not
  `mocks.NewMockSnapshotter`).
- Always use `EXPECT()` builder: **never** `mock.On()`
- Use `mock.Anything` for context parameters

## Assertions

- `require` for ALL assertions in standalone tests: stops test on failure
- **Never** use `assert` in standalone tests: test continues after failure and cascades panics
- **In testify suite tests**, use `cs.NoError`, `cs.Equal`, `cs.Require()`, etc. — suite methods internally call `require` and stop on failure. `cs.*` assertion methods are the correct pattern for integration suites and are NOT violations.

```go
// Correct — standalone tests
require.NoError(t, err)
require.Equal(t, want, got)
require.True(t, errors.Is(err, tt.wantErr))
require.Len(t, results, 3)
require.Empty(t, results)

// Correct — testify suite tests
cs.NoError(err)
cs.Equal(want, got)
cs.Require().Equal(want, got)
```

```go
// Wrong; must never appear in any test file
assert.Equal(t, want, got)   // ← test continues even when this fails
assert.NoError(t, err)       // ← subsequent lines may panic on nil dereference
```

This rule is absolute: **no exceptions, no `assert` anywhere in test files**, including handler tests, table-driven loops, and suite subtests.

### Assert against full objects, not field by field

Compare results against a complete expected value from `testdata/`. Field-by-field assertions are a test smell: they silently miss new fields, produce noisy failure messages, and obscure intent.

```go
// Wrong — field-by-field assertions hide missing fields
require.Len(t, result, 1)
require.Equal(t, "order-1", result[0].ID)
require.Equal(t, 103.5, result[0].TotalPrice)
require.Equal(t, "PENDING", result[0].Status)

// Correct — assert the full slice/object in one call
require.Equal(t, []domain.Order{testdata.PendingOrder()}, result)
```

This applies to all returned values: entities, DTOs, slices, and maps. Define the expected value in `testdata/` so it is reusable and self-documenting.

## Test Data

**HARD RULE — `testdata/` is mandatory, always.** Every test package that
constructs a domain entity, DTO, message, or any composite value MUST build it
through a `testdata/` factory package. Defining that data inline inside a
`*_test.go` file is a violation, regardless of the layer under test — domain,
engine, actor/state, use case, handler, or integration. This applies even when
the test is a single function or a table-driven test. There is no "small enough
to inline" exception for composite types.

The only values permitted inline are trivial scalars with no domain meaning
(e.g. a loop bound, a single `int`/`string`/`bool` flag). The moment a test
needs a struct literal for a domain type, that literal belongs in a factory
function under `testdata/`, named after the state it represents.

Never define test data inline in test files.

### testdata/ package (per feature)

For **every** test package (domain, engine, state, use case, handler,
integration alike), create `testdata/` within the package. Each file is named after the domain entity it constructs, **never by role** (`inputs.go`, `expected.go`, `errors.go` are wrong):

```
pkg/{feature}/
├── feature.go
├── feature_test.go
└── testdata/
    ├── user.go       ← all User factory functions
    ├── purchase.go   ← all Purchase factory functions
    └── cashback.go   ← all Cashback factory functions
```

Each entity file:
- Contains every factory function for that entity covering all states needed by the tests
- Groups constants (IDs, mock timestamps) with the entity that primarily owns them
- Uses no artificial split between "inputs" and "expected outputs"; both live in the same file

Function names describe the **specific state** of the entity, not just the type:

```go
// testdata/cashback.go
package testdata

import cashdomain "github.com/example/internal/app/cashback/domain"

const (
    CashbackID int64 = 1
    UserID     int64 = 10
)

func ApprovedCashback() cashdomain.Cashback {
    return cashdomain.Cashback{ID: CashbackID, UserID: UserID, Status: cashdomain.StatusApproved}
}

func PendingCashback() cashdomain.Cashback {
    return cashdomain.Cashback{ID: CashbackID, UserID: UserID, Status: cashdomain.StatusPending}
}
```

```go
// testdata/user.go
package testdata

import userdomain "github.com/example/internal/app/user/domain"

func FoundUser() userdomain.User {
    return userdomain.User{ID: UserID, Email: "user@example.com"}
}

func CreatedUser() userdomain.User {
    return userdomain.User{ID: UserID, Email: "user@example.com", WalletAddress: "0xABC"}
}
```

One file per entity is the default. Split into multiple files for the same entity (e.g., `offer.go`, `offer_phc.go`) only when the file grows large or the variants are conceptually distinct.

### internal/test/factory/ (shared across domains)

For entities reused across multiple domains, use the shared factory:

```
internal/test/factory/
├── user.go
├── order.go
└── product.go
```

## Integration Tests

Tag every file:

```go
//go:build integration
```

Use `pkg/testsuite` suite + YAML fixtures:

```go
//go:build integration

type RepositorySuite struct {
    testsuite.Suite
    repo repository.Repository
}

func TestRepositorySuite(t *testing.T) { testsuite.Run(t, &RepositorySuite{}) }

func (s *RepositorySuite) SetupSuite() {
    s.Suite.SetupSuite()
    s.Suite.ConfigureFixtures("default")
    s.repo = repository.NewRepository(s.DB)
}

func (s *RepositorySuite) TestFindByID_ShouldReturnEntityWhenExists() {
    result, err := s.repo.FindByID(context.Background(), "2a8fa59d-...")
    s.Require().NoError(err)
    s.Require().Equal("USR001", result.UserID)
}
```

### Fixture lifecycle (CRITICAL)

`Suite.SetupTest()` reloads YAML fixtures **per `Test...` suite method**, NOT per `cs.Run` subtest. This means:

- ✅ Each `Test{Name}` method starts with a clean DB state.
- ❌ `cs.Run` subtests inside the same `Test...` method share state — mutations from row N persist into row N+1.

**Implication for table-driven tests over mutating operations** (Create / Update / Delete):

- Do NOT use a single `Test...` method with a table that mutates the same rows across iterations. The 2nd row will see the mutated state from the 1st row.
- Either:
  1. **Split into separate `Test...` methods** — one per scenario. Each gets fresh fixtures and can reuse the same fixture rows.
  2. **Keep table-driven only when each row targets isolated rows** (different IDs, different codes, different regions). Cross-row independence must be explicit.
- Read-only and rejected (errored) cases are safe in tables: they don't mutate state.

```go
// ❌ Wrong — table mutates the same record across rows; needs per-case isolation
func (s *Suite) TestUpdate_ShouldAdjustRelatedRecord() {
    tests := []struct{ ... }{
        {input: updateOrderUS()},  // mutates US record
        {input: updateOrderCA()},  // forced to CA only because US is dirty
        {input: updateOrderMX()},  // forced to MX only because US/CA are dirty
    }
    for _, tt := range tests { s.Run(tt.name, func() { ... }) }
}

// ✅ Correct — separate methods, fresh fixtures, all reuse the same rows
func (s *Suite) TestUpdate_ShouldAdjustWhenOverlapping()    { ... }
func (s *Suite) TestUpdate_ShouldAdjustWhenAdjacent()       { ... }
func (s *Suite) TestUpdate_ShouldNotAdjustWhenNoConflict()  { ... }
```

### Database assertions in integration tests

Never write raw DB queries inline inside a test function. Any assertion that requires querying the database to verify side effects belongs in a dedicated `assert/` sub-package under `testdata/`:

```
internal/app/{domain}/repository/testdata/
├── fixtures/
├── inputs.go
└── assert/
    └── {entity}.go   ← database assertion helpers
```

Each function in `assert/` must:
- Accept `t *testing.T` and `db *gorm.DB` as first parameters
- Call `t.Helper()` as the first statement
- Use `require` (never `assert`) for all assertions
- Have a descriptive name that reads as a sentence: `OrderCancelled`, `UserDeactivated`

```go
//go:build integration

package assert

import (
    "testing"

    "github.com/stretchr/testify/require"
    "gorm.io/gorm"

    "github.com/your-org/your-project/internal/app/order/domain"
)

func OrderCancelled(t *testing.T, db *gorm.DB, orderID string) {
    t.Helper()
    var status string
    err := db.Raw("SELECT status FROM orders WHERE id = ?", orderID).Scan(&status).Error
    require.NoError(t, err, "should query order without error")
    require.Equal(t, string(domain.StatusCancelled), status, "order %s should be CANCELLED", orderID)
}
```

Call helpers directly from the test body or from a closure in a table field; the choice depends on whether the case fits naturally in the table:

```go
// Individual test; when the DB assertion makes this case distinct enough to stand alone
func (cs *Suite) TestCancelOrder_ShouldCancelConflictingActiveOrder() {
    result, err := cs.repository.CancelOrder(cs.ctx, testdata.OrderID)

    cs.Require().NoError(err)
    cs.Require().Equal(testdata.CancelledOrder(), result)
    orderassert.OrderCancelled(cs.T(), cs.DB, testdata.OrderID)
}
```

```go
// Table field; when the case fits naturally alongside other cases in the table
{
    name: "Should cancel active order",
    ...
    assert: func() {
        orderassert.OrderCancelled(cs.T(), cs.DB, testdata.OrderID)
    },
},
```

The non-negotiable rule is: **never inline raw DB queries in the test**. Always delegate to a helper in `assert/`. Whether you call that helper from an individual test or from a table closure is a readability judgment.



```yaml
# testdata/fixtures/default/users.yaml
- id: '2a8fa59d-cab7-47d8-ad07-c45b4d1d1279'
  user_id: USR001
  status: active
  email: user@example.com
```

## End-to-End (HTTP) Tests

An E2E test drives the assembled HTTP router (real handlers, real use cases, a real
downstream client) against a stubbed upstream. It exercises the full request path that a
production caller sees; it never reaches into actor/service internals to assert state.

**Location is per-operation**, one package per HTTP operation, never one monolithic suite file:

```
internal/app/{domain}/test/
├── {domain}suite/
│   └── suite.go              ← domain suite: wires the router + upstream stub + drive helpers
└── e2e/
    └── {operation}/
        ├── {operation}_test.go
        └── testdata/
            ├── upstream/     ← what the stubbed upstream serves
            ├── response/     ← golden HTTP response body
            └── payload/      ← request body, for write operations
```

A generic, dependency-free harness lives once per repository under
`internal/testing/integration/suite/{suite.go,upstream.go}` and is reused by every domain
suite. It wraps `net/http/httptest` with an upstream stub server (`Stub`, `StubHandler`,
`LastRequest`) plus an API server (`StartAPI`), and exposes `GET`/`POST` helpers returning a
`Response{Status, Body}`, and `RequireJSON(status, goldenBody, response)` for the assertion.
Do not add `gavv/httpexpect` or any other HTTP-assertion library: the shared harness absorbs
the boilerplate so stdlib stays as terse as a fluent client, while remaining transparent and
free of a new dependency (see U9 in the architecture gate).

Every file in this tree is tagged:

```go
//go:build integration
```

```go
//go:build integration

package quote_test

type QuoteSuite struct {
    quotesuite.Suite
}

func TestQuoteSuite(t *testing.T) { suite.Run(t, new(QuoteSuite)) }

func (s *QuoteSuite) TestQuote_ShouldReturnQuote() {
    s.UpstreamServes(s.ReadFile("testdata/upstream/rate.json"))

    resp := s.GET("/v1/quote?in=NEX&out=ETH&amount=10")

    s.RequireJSON(http.StatusOK, s.ReadFile("testdata/response/quote.json"), resp)
}
```

**Assert the whole HTTP body against a `testdata/response/` golden, never field by field.**
This is the same rule as [Assert against full objects, not field by field](#assert-against-full-objects-not-field-by-field),
applied at the HTTP boundary instead of a return value. A test that reads a domain snapshot or
in-memory state to check individual fields has bypassed the handler/DTO layer and is not an E2E
test. Move that assertion into a unit test of the layer it actually exercises.

For an async pipeline (a poller, a queue consumer) driving the state under test, wait at the
HTTP boundary too: poll a read endpoint until it reflects the expected state, bounded by a
deadline, using a ticker, never a fixed `time.Sleep`.

An E2E suite for a domain whose behavior includes replaying or retrying upstream messages must
include an idempotent-replay test: re-deliver the same upstream payload and assert the
observable HTTP response is unchanged (no duplicate side effect).

## Comments in Tests

Test code is self-describing. The function name, subtest strings, and variable names are the documentation.

**Default: no comments.** This applies equally to `*_test.go` files and `testdata/` packages.

Forbidden:
- Function-level doc comments (`// TestFoo verifies that...`)
- `// Arrange / Act / Assert` section markers
- Inline comments restating assertions (`require.Empty(t, result) // should be empty`)
- Var-level doc comments on exported testdata variables

```go
// Bad
// TestFoo_ShouldReturnError verifies that an error is returned when not found.
func TestFoo_ShouldReturnError(t *testing.T) { ... }

// Good
func TestFoo_ShouldReturnErrorWhenNotFound(t *testing.T) { ... }
```

**Exception: use a comment only when ALL three conditions are true:**

1. The behavior is non-obvious and cannot be expressed by renaming
2. The comment explains WHY the test is structured that way
3. Removing the comment would force the reader to trace business logic

```go
// Good: explains non-obvious domain constraint
func TestActivateSubscription_ShouldSkipWhenTrialActive(t *testing.T) {
    // Trial subscriptions bypass the activation flow: they are already active
    // by definition and skipping prevents a duplicate activation error.
    ...
}
```

## What to Test

- Happy path
- Error cases (each error type)
- Edge cases (empty, nil, zero values)
- Transaction rollback scenarios (for write operations)

## What NOT to Test

**Tautology tests** — tests that assert a value equals itself via a constant or that a library
function works as documented. They add zero regression value and must never be written.

### Enum round-trip tests (forbidden)

Any test that verifies `ParseX("pending")` returns `StatusPending` is a tautology: you are
asserting that a string constant is equal to itself. These tests do not protect against real
bugs; if the E2E or integration tests run, any parse failure is caught there.

```go
// FORBIDDEN — tautology test, adds no value
func TestParseOrderStatus_ShouldAcceptAllValidStatuses(t *testing.T) {
    tests := []struct {
        input string
        want  domain.OrderStatus
    }{
        {input: "pending",   want: domain.Pending},
        {input: "completed", want: domain.Completed},
        // ...
    }
    // This just verifies string("pending") == "pending" via the constant. Remove it.
}
```

The only valid reason to test a `ParseX` function is when it does non-trivial transformation
beyond membership validation (e.g., case normalization, alias resolution, format parsing).
Membership-only validators (`enum.Validate(...)`) are not worth testing in isolation.

### Library behavior tests (forbidden)

Do not test that standard library or project-utility behavior works as documented. Tests must
cover **your** code's logic, not the library's contract.

```go
// FORBIDDEN — tests that json.Unmarshal populates a struct, not your logic
// FORBIDDEN — tests that a database driver correctly saves a record you passed to it
// FORBIDDEN — tests that a mockery mock returns what you told it to return
```

### Anti-pattern signal

If a test would still pass even if you replaced the entire implementation with a stub that
returns the hardcoded expected value, the test is a tautology. Delete it.
