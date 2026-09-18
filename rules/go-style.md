---
applyTo: "**/*.go"
---

# Go Style

Follow the [Google Go Style Guide](https://google.github.io/styleguide/go/) as the baseline. The rules below are project-specific extensions and emphasis points.

## Naming

### File Names

- No underscores in file names. Concatenate words: `depositmonitor.go`, `errormapping.go`
- The only allowed `_` is the `_test.go` suffix: `depositmonitor_test.go`
- Exception: generated files (`mocks/`, `.pb.go`, `.gen.go`) follow their generator's convention

### Packages

- Lowercase, single word preferred: `handler`, `usecase`, `repository`, `domain`
- Multi-word packages stay unbroken in lowercase: `testsuite`, `featureflag`
- Never: `utils`, `helpers`, `common`, `misc`, `model`, `testhelper`
- Use meaningful names: `filter`, `paginator`, `money`, `clock`

### Exported Symbols

Avoid repeating the package name in the symbol:

```go
// Bad
widget.NewWidget()
db.LoadFromDatabase()

// Good
widget.New()
db.Load()
```

### Receivers

Short (1-2 letters), abbreviation of the type, consistent across all methods:

```go
func (r Repository) FindByID(ctx context.Context, id string) (Entity, error)
func (h Handler) Handle(c *gin.Context) error
func (u UseCase) Execute(ctx context.Context, input Input) (Output, error)
```

### Variables

Length proportional to scope. Omit type-like qualifiers unless disambiguation is needed:

```go
// Good
users, err := repo.FindAll(ctx)
count := len(users)

// Bad
userSlice, fetchErr := repo.FindAll(ctx)
userCount := len(userSlice)
```

### Functions

Prefer short names over long, descriptive ones — this is the Go community convention
(`gofmt`/stdlib idiom: name length should scale with distance between declaration and use,
not with how much the name can explain). This is a deliberate departure from Clean Code's
preference for long, self-documenting names; in Go, a short name plus a clear signature and
a tight scope beats a long, sentence-like name. Do not chain adjectives/qualifiers onto a
predicate name to describe every condition it checks — the implementation is the source of
truth for that.

```go
// Bad — long, describes every branch of the condition in the name itself
func isPriorityOrderEligibleForExpedited(order Order) bool { ... }

// Good — short, scope and doc comment (if exported) carry the precision
func isPriorityOrder(order Order) bool { ... }
```

Unexported helpers with a narrow, single-package scope should read close to a single word or
short phrase. Reserve longer, fully-qualified names for exported symbols whose callers are far
from the declaration and need the name alone to disambiguate.

### Constants & Initialisms

MixedCaps only. Never `ALL_CAPS` or `k`-prefix:

```go
const MaxRetries = 3     // Good
const MAX_RETRIES = 3    // Bad
const kMaxRetries = 3    // Bad
```

Initialisms keep consistent case: `ID`, `URL`, `HTTP`, `API`, `DB`, `SQS`, `DLQ`, `ARN`.

| Exported | Unexported |
|----------|------------|
| `UserID` | `userID` |
| `HTTPURL` | `httpURL` |
| `SQSAPI` | `sqsAPI` |
| `DLQ` | `dlq` |

### Methods

- No `Get`/`Set` prefixes: `Name()` not `GetName()`
- Use `Compute` or `Fetch` when the call is expensive or remote
- No `Get`/`Set` prefixes for methods

## Declaration Grouping

Group declarations that belong to the same semantic family:

```go
type (
    Status string
    Entity struct { ... }
)

const (
    StatusDraft  Status = "DRAFT"
    StatusActive Status = "ACTIVE"
)

var (
    ErrNotFound = errors.New("not found")
)
```

### Group by family, not by kind

The unit of grouping is the domain family, not the keyword. A file with two
unrelated types gets two blocks, or two plain declarations, never one block that
merges them because they happen to both be types.

The Uber Go Style Guide states the boundary explicitly under "Group Similar
Declarations": *"Only group related declarations. Do not group declarations that
are unrelated."* The Go standard library follows the same rule. Measured on Go
1.26.5, `cmd/compile/internal/syntax/nodes.go` carries four separate `type (`
blocks in one file, one per AST family (`Decl`, `Expr`, and so on). Merging
those four into one would pass a linter and lose the meaning.

### Enforcing with decorder

`decorder` is the linter for this section. Run it for `dec-order`, and disable
`dec-num-check`:

```bash
decorder -disable-dec-num-check ./...
```

`dec-order` gives the payoff, a predictable place to look for declarations in
every file. `dec-num-check` works against the rule above, because it allows one
`const`/`var`/`type` statement per file and so forces unrelated declarations
into a single block. `cmd/compile/internal/syntax/nodes.go` would fail it, and
it fails for doing the better thing. Turn that one check off and the linter
stops fighting the family rule.

Two limits to keep in mind when proposing this to a team that hasn't adopted it:

- It is a house convention, not a language rule. Neither Effective Go nor the
  Google Go Style Guide takes any position on grouping or ordering declarations.
  Google's guide covers import grouping only, and its rule for silence is that
  authors pick their own style unless the surrounding code has taken a
  consistent stance.
- Go itself doesn't follow `dec-order`. Measured on Go 1.26.5, 392 of 1542
  non-test files (25.4%) declare a top-level `func` before their first `type`.

So argue it on the readability payoff, never as "the language requires it", and
drop it in repos whose code has already settled on something else.

### Know the cost before grouping

A parenthesized block adds an indentation level, so moving a declaration in or
out rewrites every one of its lines. Git renders a re-indent instead of a move.
Measured: moving two declarations into a block produces 6 insertions and 4
deletions, and `git diff -w` still reports 4 and 2. A separate effect compounds
it, since `gofmt` realigns the whole block when a longer name arrives, which
turns one new type into 3 insertions and 2 deletions against 1 for the flat
form. Merge conflicts are unaffected, both forms conflict when two branches add
a declaration at the same position.

Group when the family is real, because the reader gains from seeing it. Skip the
block for one-off declarations, where the diff cost buys nothing.

## Struct Literals

Always name every field. Place each field on its own line:

```go
// Good
u := User{
    ID:    "abc",
    Email: "user@example.com",
}

// Bad: positional, breaks silently when fields are reordered
u := User{"abc", "user@example.com"}

// Bad: multiple fields on one line
u := User{ID: "abc", Email: "user@example.com"}
```

Single-field structs may stay on one line when the context is obvious:

```go
err := MyError{Code: "not_found"}
```

## Control Flow

No `else`. Early returns only:

```go
// Good
if err != nil {
    return err
}
doHappyPath()

// Bad
if err != nil {
    return err
} else {
    doHappyPath()
}
```

### Explanatory variables

When a conditional has more than one clause or encodes a business decision, extract it into a named boolean or a domain method. Never force the reader to reverse-engineer intent from raw comparisons.

```go
// Bad: reader must decode intent from raw comparisons
if order.Status == domain.StatusPending && order.ScheduledAt.Before(cutoff) && !order.IsCancelled {
    ...
}

// Good: intent is explicit via explanatory variable
isReadyForFulfillment := order.Status == domain.StatusPending &&
    order.ScheduledAt.Before(cutoff) &&
    !order.IsCancelled
if isReadyForFulfillment { ... }

// Better: extract to domain method when the rule belongs to the domain type
if order.IsReadyForFulfillment() { ... }
```

## Interfaces

- Define at the point of use (use case), not at the implementation
- Small, focused: prefer single-method over large contracts
- Accept interfaces, return structs:

```go
// Good
func NewUseCase(repo Repository) UseCase { return UseCase{repo: repo} }

// Bad
func NewUseCase() Repository { return &impl{} }
```

## Law of Demeter

A method should only call methods on: its own receiver, its direct fields,
its arguments, and objects it created. Chaining more than one navigation
(`a.B().C()`) couples the caller to the internal structure of distant types.

```go
// Bad: talks to a stranger's fields through a chain
func (h Handler) Handle(r *http.Request) error {
    userID := r.Context().Value(tokenKey).(TokenCtx).User.Profile.ID
    ...
}

// Good: ask your direct dependency, which encapsulates the navigation
func (h Handler) Handle(r *http.Request) error {
    userID, err := tokenmanager.UserIDFromContext(r.Context())
    ...
}
```

## Avoid Special Cases

> [Ousterhout — APSD] Special cases add cognitive overhead and are often a
> sign the abstraction is wrong. Handle them generically when possible; make
> the general path cover the edge case.

```go
// Bad: single-item fast path breaks the general flow
func applyDiscount(items []Item) []Item {
    if len(items) == 1 {
        return items
    }
    for i := range items {
        items[i].Price = calculateDiscounted(items[i])
    }
    return items
}

// Good: general path handles any length, including 1
func applyDiscount(items []Item) []Item {
    for i := range items {
        items[i].Price = calculateDiscounted(items[i])
    }
    return items
}
```

When you find yourself writing `if len == 0`, `if len == 1`, or `if
isFirstTime` to skip the general algorithm, first ask whether the algorithm
can be made to handle those inputs correctly instead.

## Error Comparison

```go
// Good
if errors.Is(err, ErrNotFound) { ... }

// Bad
if err == ErrNotFound { ... }
```

Use `any` instead of `interface{}`.

## Immutability & Value Receivers

Prefer value receivers. Pointers ONLY when:

1. Struct contains a `sync.Mutex` or must be mutated by design
2. Struct > 64 bytes AND copied frequently
3. `nil`/absence must be represented semantically

```go
// Good: value receiver
func (h Handler) Handle(c *gin.Context) error { ... }

// Good: return new value instead of mutating
func (c Config) WithTimeout(t int) Config { c.Timeout = t; return c }
```

## Pure Functions

Same input produces same output, no side effects. Prefer over impure functions:

```go
// Good: pure
func calculateTotal(items []Item) float64 {
    var total float64
    for _, item := range items {
        total += item.Price
    }
    return total
}

// Bad: impure, mutates external state
var globalTotal float64
func addToTotal(amount float64) { globalTotal += amount }
```

### Command-Query Separation

A function either **changes state** (command) or **returns a value**
(query), not both. A function named `Save` should not return the saved
entity; a function named `Find` must not mutate state.

```go
// Bad: ambiguous, does Activate return the updated entity or just confirm success?
func (r Repository) Activate(ctx context.Context, id string) (Entity, error)

// Good: command and query are separate
func (r Repository) Activate(ctx context.Context, id string) error                  // command
func (r Repository) FindByID(ctx context.Context, id string) (Entity, error)        // query
```

**Go-idiomatic exception:** returning a created entity from `Create` to get
the DB-assigned ID/timestamps back is acceptable, since the repository
cannot know the ID before insertion. State this explicitly in a doc comment
when a create method returns the entity (an explanation-of-intent comment,
see "Comments" below).

## Function Size & Abstraction

- Keep functions focused on one responsibility
- Inline logic when clear and not reused
- Extract only when logic is complex OR reused across callers
- Avoid tiny functions (< 5 lines) that create unnecessary indirection

### No flag arguments

A `bool` parameter that changes a function's behavior signals the function
does two things. Split it into two functions.

```go
// Bad: what does false mean at the call site?
repo.FindAll(ctx, false)

// Good: intent is explicit
func (r Repository) FindAll(ctx context.Context) ([]Entity, error)
func (r Repository) FindAllIncludingDeleted(ctx context.Context) ([]Entity, error)
```

## Comments

Default: no comments. Code should be self-explanatory through good naming. Per
Robert C. Martin's *Clean Code* (ch. 4): comments are always a failure to
express intent through code, tolerated only in narrow categories, never a
substitute for renaming or restructuring.

A comment is justified only when it falls into one of these three categories
(Martin's own taxonomy, not an open-ended "seems non-obvious" judgment call):

1. **Explanation of intent**: the code's WHY isn't derivable from its
   structure alone (a business rule, a deliberate trade-off, a decision that
   would look wrong without context).
2. **Warning of consequences**: doing it the "obvious" other way would break
   something non-local (concurrency, ordering, an external contract).
3. **Clarification of foreign or unchangeable code**: a call into a
   third-party/generated/legacy API whose behavior can't be renamed or
   restructured to be self-explanatory.

Everything else Martin classifies as a bad comment stays forbidden: redundant
comments, mandated comments ("every function needs one"), journal/changelog
comments (git already has this history), noise comments, position markers,
closing-brace comments, and comments compensating for code that should have
been rewritten instead.

- Never comment WHAT the code does; the code already says that
- Never comment HOW it does it; the code already says that
- Delete any comment that restates the function/variable name
- **NEVER write package doc comments.** Delete every `// Package x ...` comment, including one-line summaries. Not "keep them short" — remove them entirely. The package name is the documentation.
- **NEVER add a godoc just because a symbol is exported.** Being exported is not a reason to document; only one of the three categories above is.
- **No inline comments in function bodies** unless they fall into one of the three categories above.
- **Repo-specific override**: when the project's own linter forces a comment
  to exist regardless of content (e.g. revive's `package-comments`/`exported`
  rules with no config file, common in Go monorepos with no `.golangci.yml`),
  write the shortest comment that satisfies the lint check and, where
  possible, one of the three categories above. The linter checks existence,
  not quality: a comment that only restates the name is still a defect, not
  a compliant workaround.

```go
// Bad: obvious (restates name)
// FindByID finds entity by ID
func (r Repository) FindByID(ctx context.Context, id string) (Entity, error)

// Bad: obvious (godoc that restates params)
// Params configures the input for Run.
type Params struct { Input []int64 }

// Bad: documents what+how in body
func (r Repository) Save(ctx context.Context, input Entity) error {
    // Validate input
    if input.ID == "" {
        return errors.New("id is empty")
    }
    // Save to database
    return r.db.WithContext(ctx).Create(&model).Error
}

// Bad: package doc as narrative
// Package goroutines computes a sum by launching one goroutine per input
// element. It is designed for bounded pedagogical input and is not suitable
// for large inputs. Callers must not mutate the slice concurrently.
package goroutines

// Good: explains WHY: non-obvious business rule
// Apply institutional discount only for orders > 100 units (legacy rule from 2019 contract)
if product.Quantity > 100 { basePrice *= 0.85 }

// Good: godoc adds insight beyond the name
// Repository provides data access for user entities.
type Repository struct { ... }

// Good: no package doc comment at all
package goroutines
```

### Doc Comments on Exported Symbols

A godoc comment is justified **only when the name alone is insufficient to understand purpose or usage.** If the godoc merely restates the name, delete it; no comment is better than a redundant one.

```go
// Good: name alone is enough, no comment needed
type Params struct {
    Input []int64
}

// Good: name alone is enough
type Result struct {
    Sum int64
}

// Good: explains what "Execute" does in this context
// Execute sends a transfer request to the payment gateway.
func (u UseCase) Execute(ctx context.Context, input Input) (Output, error)
```

## Import Organization

Group imports in three blocks separated by blank lines:

```go
import (
    "context"
    "fmt"

    "github.com/gin-gonic/gin"
    "gorm.io/gorm"

    "github.com/your-org/your-project/internal/app/user/domain"
)
```

1. Standard library
2. Third-party packages
3. Internal packages

## Concurrency

Channels for coordination, mutexes for shared state:

```go
func (c Consumer) run(ctx context.Context) {
    for {
        select {
        case <-ctx.Done():
            return
        case msg := <-c.messages:
            c.handle(ctx, msg)
        }
    }
}
```

## Linting

Must pass: `golangci-lint` with `revive`, `staticcheck`, `gofumpt`, `errcheck`, `ineffassign`, `gocyclo`.
