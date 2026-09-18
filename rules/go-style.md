---
applyTo: "**/*.go"
---

# Go Style

Follow the [Google Go Style Guide](https://google.github.io/styleguide/go/) and the
[Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md) as the
baseline, in that order when they conflict. The rules below are project-specific
extensions and emphasis points; a rule cited from Uber's guide is noted inline so
its source stays traceable.

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

### Avoid built-in names

*(Uber Go Style Guide, "Avoid Using Built-In Names")* Reusing an identifier
like `len`, `min`, `max`, `new`, `error`, or `string` as a variable or
parameter name shadows the built-in within that scope and confuses code that
reads fine on its own but breaks once someone expects the built-in to still
be available.

```go
// Bad: shadows the built-in len within this function
func process(items []Item) {
    len := len(items)
    ...
}

// Good
func process(items []Item) {
    count := len(items)
    ...
}
```

### Error naming

*(Uber Go Style Guide, "Error Naming")* A sentinel error stored in a package
variable is prefixed `Err` when exported, `err` when not. This is what makes
`errors.Is(err, pkg.ErrNotFound)` read correctly at the call site.

```go
// Good
var ErrNotFound = errors.New("not found")   // exported
var errInvalidState = errors.New("invalid state")  // unexported

// Bad: no prefix, doesn't read as a sentinel at the call site
var NotFound = errors.New("not found")
```

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

### Start enums at one

*(Uber Go Style Guide, "Start Enums at One")* An uninitialized variable of a
numeric enum type is `0` by default. If a valid enum value can also be `0`,
there is no way to distinguish "explicitly set to the first value" from
"never set." Start numeric enums at `1` unless `0` is meant to represent a
real, meaningful zero state (e.g. `StatusUnknown`).

```go
// Bad: 0 is ambiguous, could be StatusPending or "never set"
type Status int
const (
    StatusPending Status = iota
    StatusActive
)

// Good: 0 is reserved for the zero-value case
type Status int
const (
    StatusUnknown Status = iota
    StatusPending
    StatusActive
)
```

## Struct Literals

*(Uber Go Style Guide, "Use Field Names to Initialize Structs")* Always name every field. Place each field on its own line:

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

### Never a pointer to an interface

*(Uber Go Style Guide, "Pointers to Interfaces")* An interface value is
already a two-word header (type, value); a pointer to it adds a layer of
indirection with no benefit. Pass the interface by value.

```go
// Bad
func Process(repo *Repository) { ... }

// Good
func Process(repo Repository) { ... }
```

### Verify interface compliance at compile time

*(Uber Go Style Guide, "Verify Interface Compliance")* When a concrete type
is meant to implement an interface but nothing in the code forces the
compiler to check it (the interface is only satisfied structurally, never
named at the assignment site), a `var _ Interface = (*Impl)(nil)` line turns
a silent runtime/test-time drift into a compile error the moment either side
changes.

```go
// handler.go
type Handler struct{}

var _ http.Handler = (*Handler)(nil)

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) { ... }
```

### Avoid embedding types in public structs

*(Uber Go Style Guide, "Avoid Embedding Types in Public Structs")* An
embedded type's exported methods and fields leak onto the embedding struct's
public API, so callers can start depending on a detail that was never a
deliberate design choice, and the embedded type can no longer change without
breaking them.

```go
// Bad: AbstractList's methods leak onto ConcreteList's public API
type ConcreteList struct {
    AbstractList
}

// Good: wrap explicitly, decide the public surface on purpose
type ConcreteList struct {
    list AbstractList
}

func (l *ConcreteList) Add(e Entity) { l.list.Add(e) }
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

### Always use the comma-ok idiom for type assertions

*(Uber Go Style Guide, "Handle Type Assertion Failures")* A bare type
assertion panics if the value is not of the asserted type. Always check the
second return value, even when the caller is confident about the type.

```go
// Bad: panics if t is not a string
s := t.(string)

// Good
s, ok := t.(string)
if !ok {
    return fmt.Errorf("expected string, got %T", t)
}
```

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

### Copy slices and maps at API boundaries

*(Uber Go Style Guide, "Copy Slices and Maps at Boundaries")* Slices and
maps hold a pointer to their backing data. Returning one from an exported
function, or accepting one as a constructor argument and storing it, hands
the caller (or the struct) a live reference to memory someone else can still
mutate, silently, after the call returns.

```go
// Bad: caller's slice is stored directly; mutating it later mutates d1 too
type D1 struct{ nums []int }
func (d *D1) SetNums(nums []int) { d.nums = nums }

// Good: copy on the way in
type D2 struct{ nums []int }
func (d *D2) SetNums(nums []int) {
    d.nums = make([]int, len(nums))
    copy(d.nums, nums)
}
```

Same risk in reverse: a getter that returns the internal slice/map directly
lets the caller mutate the struct's internal state from outside. Copy on the
way out too, unless the whole point of the method is to expose a mutable
view.

### `nil` is a valid, empty slice

*(Uber Go Style Guide, "nil is a valid slice")* `len(nil)`, `cap(nil)`, and
ranging over a `nil` slice all behave exactly like an empty slice. Returning
`[]T{}` instead of `nil` to mean "no results" is unnecessary allocation with
no behavioral difference for any well-behaved caller.

```go
// Bad: allocates for no reason
func FindAll() []Entity {
    if noResults {
        return []Entity{}
    }
    ...
}

// Good
func FindAll() []Entity {
    if noResults {
        return nil
    }
    ...
}
```

The one exception is a boundary that specifically distinguishes `null` from
`[]` in its JSON contract (some external APIs do). State that explicitly if
it applies; it is the exception, not the default.

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

### Avoid mutable globals

*(Uber Go Style Guide, "Avoid Mutable Globals")* A package-level `var` that
gets mutated at runtime is implicit shared state: every caller, in every
goroutine, is coupled to it, and tests can't run in isolation without
resetting it by hand. Prefer dependency injection, passing the dependency in
explicitly, over a global any code in the package can reach into and change.

```go
// Bad: any caller anywhere can mutate this, tests must reset it
var defaultClient = &http.Client{}

// Good: injected, each caller controls its own instance
type Service struct {
    client *http.Client
}
func NewService(client *http.Client) Service { return Service{client: client} }
```

A package-level `var` that is set once (config loaded at startup, a
compiled regex) and never mutated afterward is not what this rule targets;
the risk is mutation, not existence.

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

### Avoid naked parameters

*(Uber Go Style Guide, "Avoid Naked Parameters")* This generalizes "no flag
arguments" above: any unnamed literal at a call site that the reader can't
decode without opening the function signature hurts readability, not just
`bool`.

```go
// Bad: what do true, true mean at this call site?
printInfo("foo", true, true)

// Good: a comment names each one at the call site
printInfo("foo", true /* isLocal */, true /* done */)

// Better: named parameters via a struct, self-documenting without a comment
printInfo("foo", PrintOptions{IsLocal: true, Done: true})
```

### Functional options for optional/growing configuration

*(Uber Go Style Guide, "Patterns: Functional Options")* When a constructor
has several optional parameters that may grow over time, prefer functional
options over either a long parameter list or a struct the caller must fully
understand upfront. Each option is a function that mutates unexported
config; adding a new option is backward compatible for every existing
caller.

```go
type Option interface {
    apply(*options)
}

type options struct {
    timeout time.Duration
    caching bool
}

type timeoutOption time.Duration

func (t timeoutOption) apply(opts *options) { opts.timeout = time.Duration(t) }

func WithTimeout(t time.Duration) Option { return timeoutOption(t) }

func NewConnection(addr string, opts ...Option) (*Connection, error) {
    cfg := options{timeout: defaultTimeout}
    for _, opt := range opts {
        opt.apply(&cfg)
    }
    ...
}

// Call site: only specify what deviates from the default
conn, err := NewConnection("localhost", WithTimeout(5*time.Second))
```

Use a plain options struct (`design-principles.md`'s "Function Signatures"
rule) instead when the fields are all required or rarely grow, functional
options earn their extra indirection only when optionality and growth are
the actual problem being solved.

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

### Alias an import when the package name doesn't match its path

*(Uber Go Style Guide, "Import Aliasing")* Import aliasing is mandatory,
not optional, whenever the last path segment doesn't match the package's
actual declared name, and whenever two imports would otherwise collide.
Guessing the package name from the import path alone should always be
correct.

```go
// Bad: package name (yaml) doesn't match the path's last segment (go-yaml)
import "gopkg.in/yaml.v2"

// Good: alias makes the actual package name explicit
import yaml "gopkg.in/yaml.v2"
```

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

### Every goroutine needs a way to stop and be waited on

*(Uber Go Style Guide, "Don't fire-and-forget goroutines" / "Wait for
goroutines to exit" / "No goroutines in `init()`")* A goroutine started
with no channel, no `context.Context`, and no `sync.WaitGroup`/`errgroup`
tying it back to its caller is a leak the moment the caller returns; nothing
can observe whether it finished, panicked, or is still running. `init()` is
an especially bad place to start one: it runs before `main`, before flags
are parsed, before the program has decided whether it even wants that
goroutine running.

```go
// Bad: fire-and-forget, no way to know when (or if) this finishes
go worker.Run()

// Good: caller can wait for it, cancel it, and observe its error
g, ctx := errgroup.WithContext(ctx)
g.Go(func() error { return worker.Run(ctx) })
...
if err := g.Wait(); err != nil { ... }
```

### Avoid `init()`

*(Uber Go Style Guide, "Avoid init()")* Code in `init()` runs before `main`,
with no way for the caller to control ordering, inject configuration, or
skip it in a test. Prefer an explicit constructor the caller invokes when
it's actually ready. When `init()` truly is unavoidable (registering a
database driver, for example), it must be fully deterministic and touch
nothing outside the current process (no I/O, no network, no mutating shared
state, no depending on other packages' `init()` order).

### `os.Exit`/`log.Fatal` only in `main()`

*(Uber Go Style Guide, "Exit in Main")* Any function other than `main()`
should return an error and let the caller decide how to handle it; only
`main()` may call `os.Exit`/`log.Fatal*`, never a helper it calls into,
because those calls skip every deferred cleanup on the call stack, and a
helper function has no way to know whether the caller has cleanup pending.

Uber's companion "Exit Once" guidance (call it "at most once," on a single
final path) is stated as a preference, not an absolute ("if possible" in
their own text), and does not match this repo's real, deliberate convention:
every `cmd/*/main.go` in lego (`aiproxy`, `supportbot`, `mcps`, ...) calls
`panic`/`l.Fatal` at each distinct startup failure point (`env.Init` fails,
`log.Init` fails, `server.New` fails, `s.Listen` fails), not once at a
single collected path. This is safe here specifically because `main()`'s
only deferred cleanup (`defer cancel()`) is registered before any of those
checks and is not depended on for correctness after an early exit, the
process is terminating either way. Keep the multi-exit-point pattern; do not
"fix" it into a single trailing exit to match Uber's preference when nothing
here is actually placing a defer at risk.

## Linting

Must pass: `golangci-lint` with `revive`, `staticcheck`, `gofumpt`, `errcheck`, `ineffassign`, `gocyclo`.
