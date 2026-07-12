---
applyTo: "**/*.go"
---

# Design Principles

Meta-principles that guide decomposition, commenting, and development workflow. Reconciles *A Philosophy of Software Design* (Ousterhout), *Clean Code* (Martin), the *Clean Go Article* (Pungyeon), and *Effective Go*.

These rules govern the orchestrator → planner → implementer workflow. Read before planning or implementing any non-trivial change.

## 1. Deep Modules, Not Shallow Ones

A module (function, type, package) is **deep** when it hides a lot of functionality behind a simple interface. Depth is the primary measure of decomposition quality — not line count.

```go
// Deep: one call replaces 50 lines of HTTP boilerplate
resp, err := client.Get(ctx, url)

// Shallow: the wrapper adds a name but hides nothing
func (s *Service) callDoSomething() { s.doSomething() }
```

**Extract when the interface is simpler than the implementation.** If the extracted function's signature is as complex as its body, the extraction adds indirection without reducing cognitive load. Do not extract.

## 2. Entanglement: The Decomposition Red Flag

Two functions are **entangled** when understanding one requires reading the other. If you find yourself flipping between function bodies to understand a single logical operation, merge them.

Red flags:
- Function A calls B which calls C, and all three must be loaded mentally to understand the operation
- A function has a hidden side effect that only becomes visible by reading its callees
- A function's correctness depends on a caller's loop invariant (e.g., monotonically increasing input)

```go
// Entangled: isPrime's correctness depends on checkOddNumbers' loop invariant
// (candidate must increase monotonically). Reader must hold both in mind.
func isPrime(candidate int) bool {
    return isNotMultipleOfAnyPreviousPrimeFactor(candidate)
}

// Better: keep the primality check and the loop together, or document
// the invariant in the interface comment of the extracted function.
```

When extraction would create entanglement, keep the code together. Entanglement defeats the purpose of decomposition.

## 3. Extraction Guardrails

Extract a function only when ALL of the following are true:

1. **The interface is simpler than the implementation** — the caller does not need to read the body
2. **The extracted logic is genuinely separable** — no entanglement with the caller's context
3. **At least one of:** reused across callers, the body is complex enough to benefit from a name, or the extraction creates a meaningful abstraction boundary

Do NOT extract:
- Single-line wrappers that add a name but no abstraction
- Functions that share mutable state so tightly that they must be read together
- Functions whose correctness depends on undocumented invariants of the caller

```go
// Bad: extraction adds indirection without abstraction
func (r Repository) save(ctx context.Context, e Entity) error {
    return r.db.WithContext(ctx).Create(e).Error
}
// Caller still needs to know it writes to DB, uses ctx, returns gorm error.
// The signature IS the implementation. No depth gained.

// Good: extraction hides a non-obvious detail
func (r Repository) Save(ctx context.Context, e Entity) error {
    model := toModel(e)           // hides domain→model mapping
    return r.db.WithContext(ctx).Create(&model).Error
}
```

## 4. Interface Comments Enable Abstraction

There are two categories of comments with opposite defaults:

| Category | Default | Purpose |
|----------|---------|---------|
| Implementation comments | **None** — only WHY, only when non-obvious | Explain a surprising decision inside a function body |
| Interface comments | **Required** when the signature is insufficient | Enable the caller to use the function WITHOUT reading its body |

An interface comment describes the **contract**: preconditions, side effects, ordering constraints, format expectations, error semantics. Without interface comments there is no abstraction — the reader is forced to read the implementation.

```go
// Bad: signature is insufficient, no comment — caller must read the body
func (s Store) Get(key string) (Item, error)

// Good: interface comment completes the abstraction
// Get retrieves the item for key. Returns ErrNotFound if the key does not
// exist. The returned Item is a copy; mutations do not affect the store.
func (s Store) Get(key string) (Item, error)
```

```go
// Good: interface comment documents a non-obvious precondition
// FindPrimes returns the first n primes. n must be > 0; panics otherwise.
// The returned slice is owned by the caller.
func FindPrimes(n int) []int
```

Rule of thumb: if a new developer would need to read the function body to use it correctly, it needs an interface comment. If the signature alone is sufficient (e.g., `len(s)` on a slice), no comment is needed.

This does not contradict `go-style.md`'s "default no comments" rule — that rule applies to **implementation** comments. Interface comments are the mechanism that makes abstraction possible.

## 5. Design-First, Then Test

The unit of development is a **design unit** (a function, a type, a small set of related operations), not a single test. The workflow is:

1. **Design** — think about the structure of the code you are about to write. What are the types? What are the function boundaries? What is the interface contract?
2. **Implement** — write the code for the design unit (tens to a few hundred lines)
3. **Test** — write comprehensive unit tests for the implemented code
4. **Refactor** — adjust based on what the tests and the implementation revealed

This is **bundling**, not strict TDD. Design comes before code, not after. Tests validate the design; they do not drive it.

```go
// Design-first: define the interface contract before implementing
//
// TransactionManager executes a unit of work atomically.
// If the callback returns an error, the transaction is rolled back.
type TransactionManager interface {
    WithTransaction(ctx context.Context, fn func(ctx context.Context) error) error
}

// Then implement, then test.
```

Anti-pattern: writing code test-by-test without any upfront design thinking, hoping a good design will "emerge" from refactoring. This produces tactical code that accumulates faster than refactoring can fix it.

**When you CAN write tests first:** when the design is already clear (a well-understood pattern, a small fix, reproducing a bug). In that case TDD and bundling converge.

## 6. Balance Every Tradeoff

Every design rule has a point of diminishing returns. One-sided rules ("always smaller", "never comment", "always test-first") are dangerous because they push in one direction with no guidance on when to stop.

| Rule | Good direction | Stop when... |
|------|---------------|--------------|
| Decompose into smaller functions | Reduces cognitive load | The interface is as complex as the body, or entanglement appears |
| Remove comments | Code is self-explanatory | The signature no longer communicates the contract |
| Write tests early | Catches bugs sooner | Design thinking is being postponed in favor of making the next test pass |
| Use interfaces | Decouples caller from impl | The interface has a single implementation and is never swapped |

If a rule has strong push in one direction but no guardrail in the other, it is incomplete. Add the missing guardrail.

## 7. Focus on What Matters

The goal of design is to make the system easy to understand and modify. Do not micro-optimize things that do not contribute to this goal at the expense of things that do.

Things that matter:
- Correctness and clarity of the core logic
- Interface contracts that allow callers to work without reading internals
- Test coverage that enables fearless refactoring
- Performance characteristics that affect real users

Things that do not matter enough to dominate design:
- Whether a 10-line function should be 5 lines
- Whether a function should be 3 lines or 2
- Whether a comment could theoretically be replaced by a longer name

If focusing on the unimportant causes you to miss the important (a performance regression, an entangled decomposition, a missing contract), you have made the system worse.

## 8. Scope Determines Specificity

### Functions: general at the top, specific deeper

```go
// Top level: short, general name
func Parse(filepath string) (Config, error) { ... }

// One level deeper: slightly more specific
func parseJSON(filepath string) (Config, error) { ... }

// Deepest: most specific
func parseJSONInto(buf *bytes.Buffer) error { ... }
```

### Variables: specific at the top, shorter deeper

```go
func BeerBrandListToBeerList(brands []BeerBrand) []Beer {
    var beers []Beer
    for _, brand := range brands {      // brand: specific enough for loop scope
        for _, b := range brand {        // b: short, scope is one line
            beers = append(beers, b)
        }
    }
    return beers
}
```

The larger the scope, the more descriptive the name. The smaller the scope, the shorter the name can be without losing clarity.

## 9. Function Signatures

Maximum 3 parameters. Beyond that, use an options struct:

```go
// Bad: positional bools are unreadable
func Declare(name string, durable, exclusive, noWait bool, args any) (Queue, error)

// Good: options struct with named fields
type DeclareOptions struct {
    Name      string
    Durable   bool
    Exclusive bool
    NoWait    bool
    Args      any
}

func Declare(opts DeclareOptions) (Queue, error)
```

The struct gives: named fields (no positional confusion), default zero values (omit what you don't need), and extensibility (add fields without breaking callers).
