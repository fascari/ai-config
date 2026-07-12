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

Always group related declarations:

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

## Function Size & Abstraction

- Keep functions focused on one responsibility
- Inline logic when clear and not reused
- Extract only when logic is complex OR reused across callers
- Avoid tiny functions (< 5 lines) that create unnecessary indirection

## Comments

Default: no comments. Code should be self-explanatory through good naming.

- Only comment when explaining WHY something exists or WHY a non-obvious decision was made
- Never comment WHAT the code does; the code already says that
- Never comment HOW it does it; the code already says that
- Delete any comment that restates the function/variable name
- **No package doc comments beyond 1-2 lines.** Delete narrative descriptions, contracts, or caller-guidance.
- **No inline comments in function bodies** unless the logic is genuinely surprising

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

// Good: 1-line package doc
// Package goroutines demonstrates concurrent sum via goroutines.
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
