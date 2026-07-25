---
applyTo: "**/*.go"
---

# Error Handling

## Core Principle

> Never log and return the same error. Choose one: log it OR return it.

## Domain Error Codes

Define error code constants in `errors.go` at the domain package root. Use `apperror.AppError` for errors that carry a code and message:

```go
// internal/app/{domain}/errors.go
package domain

const (
    ErrCodeInvalidStatusTransition = "error_invalid_status_transition"
    ErrCodeEntityNotFound          = "error_entity_not_found"
    ErrCodeBusinessValidation      = "error_business_validation"
)
```

Create errors with `apperror.New`:

```go
import "github.com/your-org/your-project/pkg/apperror"

return apperror.New(domain.ErrCodeEntityNotFound, "entity %s not found", id)
```

Check errors with `apperror.As`:

```go
if apperror.As(err, domain.ErrCodeEntityNotFound) {
    // handle not found
}
```

## Struct-Based Domain Errors

For errors that carry typed data beyond code+message, use struct errors with `Is()`:

```go
type (
    ErrNotFound     struct{ ID string }
    ErrInvalidInput struct{ Message string }
)

func (e ErrNotFound) Error() string { return fmt.Sprintf("entity not found: %s", e.ID) }
func (e ErrNotFound) Is(target error) bool {
    _, ok := target.(ErrNotFound)
    return ok
}
```

Compare with `errors.Is()`, never `==`:

```go
if errors.Is(err, ErrNotFound{}) { ... }
```

## Error Wrapping

Always wrap with context describing the operation that failed:

```go
return fmt.Errorf("finding user by id %s: %w", id, err)
```

## Handler Error Mapping

Every domain has ONE error mapping from domain error codes to HTTP status codes, rendered through the reusable `pkg/httperror.Render` (kit). There is never a per-operation error-mapping file duplicated across `handler/{op}/` packages.

### Structure

File location depends on the handler layout:

- **Per-operation handlers** (`handler/{operation}/` packages): the single `Mapping` lives at the domain root, `internal/app/{domain}/errormapping.go`, in the domain's app package.
- **Single handler package**: `internal/app/{domain}/handler/error_mapping.go`.

```go
package handler

import (
    "net/http"

    "github.com/your-org/your-project/internal/app"
    "github.com/your-org/your-project/internal/app/{domain}/domain"
    "github.com/your-org/your-project/pkg/http/errorhandler"
)

var (
    ErrorMapping = errorhandler.ErrorMapping{
        // Domain-specific errors
        domain.ErrCodeEntityNotFound:          http.StatusNotFound,
        domain.ErrCodeBusinessValidation:      http.StatusUnprocessableEntity,
        domain.ErrCodeInvalidStatusTransition: http.StatusUnprocessableEntity,

        // Shared app errors
        app.ErrCodeBadRequest:    http.StatusBadRequest,
        app.ErrCodeRecordNotFound: http.StatusNotFound,
    }
)
```

### How Handlers Use It

Handlers call `errorhandler.Render` with the domain's `ErrorMapping`:

```go
func (h Handler) Handle(c *gin.Context, w http.ResponseWriter, r *http.Request) error {
    ctx := c.Request.Context()

    result, err := h.useCase.Execute(ctx, input)
    if err != nil {
        return errorhandler.Render(ctx, w, err, errorhandler.WithErrorMapping(handler.ErrorMapping))
    }

    return web.EncodeJSON(w, response, http.StatusOK)
}
```

### Resolution Order

`errorhandler.Render` resolves the HTTP status code in this order:

1. Built-in defaults: `RecordNotFound` → 404, `DuplicateEntry` → 409
2. Domain-specific mapping from the `ErrorMapping` map
3. Fallback: `500 Internal Server Error`

### HTTP Status Mapping Conventions

| Error category | HTTP status | When to use |
|---|---|---|
| Entity not found | `404 Not Found` | Resource does not exist |
| Validation failure | `400 Bad Request` | Invalid input, missing fields, bad format |
| Business rule violation | `422 Unprocessable Entity` | Valid syntax but violates domain rules |
| State conflict | `409 Conflict` | Duplicate, concurrent modification, invalid state transition |
| Audit/system failure | `500 Internal Server Error` | Missing request context, system errors |

### JSON Error Response

All errors produce a consistent JSON response:

```json
{
    "code": "error_entity_not_found",
    "message": "entity abc-123 not found"
}
```

Logging is handled by `errorhandler.Render`: 5xx errors log at ERROR level, 4xx at WARN.

### Adding a New Domain Error

1. Define the error code constant in `internal/app/{domain}/errors.go`
2. Use `apperror.New(code, message)` where the error is raised
3. Add the mapping entry in `internal/app/{domain}/handler/error_mapping.go`
4. The handler already passes `ErrorMapping` to `errorhandler.Render`, so new codes are picked up automatically

## What NOT To Do

```go
// Bad: log AND return
log.Error("failed to find entity", "error", err)
return err

// Good: return only (errorhandler.Render logs it)
return fmt.Errorf("finding entity: %w", err)

// Good: OR log only (fire and forget, e.g., background jobs)
log.Error("background job failed", "error", err)
```

## Never Return Silent Zero Values

If a function's contract guarantees a result when `err == nil`, never return `Entity{}, nil` in a code path that should be `ErrNotFound`. Go's zero-value structs are structurally identical to a valid empty entity — returning one silently forces defensive nil/zero-checking everywhere downstream and creates a class of bugs the compiler cannot catch.

```go
// Bad: caller cannot distinguish "not found" from "valid empty entity"
func (r Repository) FindByID(ctx context.Context, id string) (domain.Order, error) {
    order, err := r.store.FindByID(ctx, id)
    if errors.Is(err, store.ErrRecordNotFound) {
        return domain.Order{}, nil // ← silent zero value
    }
    return order, err
}

// Good: explicit sentinel error
func (r Repository) FindByID(ctx context.Context, id string) (domain.Order, error) {
    order, err := r.store.FindByID(ctx, id)
    if errors.Is(err, store.ErrRecordNotFound) {
        return domain.Order{}, apperror.New(domain.ErrCodeEntityNotFound, "order %s not found", id)
    }
    return order, err
}
```

The rule: **when `err == nil`, the returned value must always be valid and usable.** Never make the caller guess.

## Validate Numeric Input Before Narrowing at a Trust Boundary

A **trust boundary** is any point where a value crosses from a source you do not control (an external feed, an HTTP request body, a message queue payload, a config file) into code that assumes the value is well-formed. Whenever such a value is about to undergo an **unchecked narrowing conversion** (`float64` → `int64`, `float64` → `int`, `int64` → `int32`, or any similar lossy/overflowing cast), validate it as finite and in range *before* the conversion, not after.

An unchecked narrowing conversion silently produces garbage instead of failing loudly:

- `NaN` and `+/-Inf` convert to implementation-defined or wraparound values, not an error
- A magnitude that overflows the target type wraps or saturates silently
- Negative values narrow into a type that later assumes non-negativity, corrupting downstream invariants (e.g., a value used as a map key, an array index, or a monotonic counter)

```go
// Bad: unchecked narrowing at the boundary. NaN, +/-Inf, negative, or an
// overflowing value silently corrupts whatever this key feeds into.
func levelKey(price float64) int64 {
    return int64(math.Round(price * scale))
}

// Good: an exported pure predicate validates before the narrowing happens.
// Representable reports whether price can be safely narrowed to the
// internal key type: it must be finite, non-negative, and its scaled,
// rounded value must fit in int64.
func Representable(price float64) bool {
    if math.IsNaN(price) || math.IsInf(price, 0) || price < 0 {
        return false
    }
    scaled := math.Round(price * scale)
    return scaled >= -math.MaxInt64 && scaled <= math.MaxInt64
}

func levelKey(price float64) int64 {
    return int64(math.Round(price * scale)) // caller already validated
}
```

### Where to Enforce It

Call the predicate **at the trust boundary that owns rejection**, not inside the narrow, deep function that performs the conversion:

- If the codebase already has a rejection mechanism for other malformed inputs at that boundary (an actor that rejects invalid messages, a handler that returns `400 Bad Request`, a decoder that returns a mapping error), reuse it. A new validation reason is usually a one-line addition next to the existing ones, not a new mechanism.
- Do not push the check down into the deep function itself (e.g., changing its signature to return `(key, bool)` or `(key, error)` everywhere it's called). That spreads a boundary concern into code that should be able to assume its input is already valid, and forces every internal caller to re-handle a case that can only ever occur once, at the edge.
- Do not defer the check "for later" once the unchecked path is identified. An unvalidated float-to-int narrowing at a trust boundary is a correctness bug, not a style nit — it can silently corrupt in-memory state with no error, no log, and no test failure until the corrupted state is read back.

This generalizes beyond prices: any external numeric input that will be rounded, scaled, hashed into a key, used as a size/count/index, or otherwise narrowed into a smaller or integer type needs the same finite-and-in-range check before the narrowing, validated once at the boundary and trusted everywhere after.
