---
applyTo: "internal/**/*.go,cmd/**/*.go"
---

# Architecture Blueprint

The canonical base shape every Go service must satisfy — whether hand-built or
generated from the scaffold. The construction harness
(`skills/architecture-gate/scripts/conformance.sh`) validates this contract at
scaffold time and after every build phase. Universal invariants ALWAYS hold;
objective-varying concerns are validated only when the project uses them.

## Universal invariants (always enforced)

These fail the gate. They do not depend on the project's objective.

| # | Invariant | Why |
|---|-----------|-----|
| U1 | `internal/bootstrap/` holds base wiring (config, router, server, logger) | one composition seam, not scattered `main.go` wiring |
| U2 | Composition via `cmd/{app}/modules/` (or uber/fx) | DI is explicit and testable, never inlined in `main` |
| U3 | Every `internal/app/{domain}/` has a `domain/` layer | plain business types, no framework tags |
| U4 | Use cases are per-operation: `usecase/{operation}/` (`usecase.go`, `types.go`, `errors.go`) | no monolithic `usecase/service.go` god-object |
| U5 | Handlers are per-operation: `handler/{operation}/` (`handler.go`, `dto.go`) — `dto.go` exposes a `toResponse(...)` mapper; `handler.go` never builds response structs inline | one endpoint, one package; mapping is a pure, testable function |
| U6 | Handlers hold the **concrete** use case — never a handler-local `service`/`UseCase` interface | interfaces to mock belong in the use case layer, not the handler |
| U7 | No hand-written `fake*/stub*/mock*` structs in tests — mocks come from **mockery** | generated doubles stay in sync with the interface |
| U8 | Handler tests assert the **whole** response object vs golden `testdata/` — no field-by-field float asserts | silently missing/extra fields are caught |
| U9 | No `gock`/`http.Transport` monkeypatching | use the httptest upstream stub (below) |

## Layout

```
cmd/{app}/
  main.go                 # references bootstrap.* and modules.* only
  modules/{domain}.go     # composes repo/usecases/handlers, registers routes
internal/
  bootstrap/              # router.go, server.go, logger.go, config
  app/{domain}/
    domain/               # entities, enums, errors.go — no json/gorm tags
    usecase/{operation}/  # usecase.go, types.go, errors.go, mocks/, testdata/
    handler/{operation}/  # handler.go, dto.go (toResponse), testdata/
    errormapping.go       # ONE domain error-code -> HTTP status map
    repository/           # (only when the objective needs persistence)
pkg/                      # reusable kit: httpjson, httpparam, apperror,
                          # httperror (Render), handlertest, logger, ...
```

## HTTP response and error rendering

Success and error paths both go through shared, reusable seams — no ad-hoc
JSON or status logic inside a handler.

- **Response mapping.** Each handler's `dto.go` exposes `toResponse(output ...) Response`
  (plus small `toXxxResponse` helpers using `pkg/slices.Map` when a list is
  involved). The handler calls `httpjson.Write(w, status, toResponse(output))`.
  Never construct the response struct inline in `handler.go`.
- **Cross-cutting HTTP concerns live in `pkg/`, never duplicated per handler:**
  `pkg/httpjson` (write JSON), `pkg/httpparam` (parse/bound query params, e.g.
  `BoundedInt(value, fallback, max)`), `pkg/apperror` (coded `AppError`),
  `pkg/httperror` (`Render(w, err, Mapping)`).
- **Error mapping is centralized per domain**, not per handler. One
  `errormapping.go` at the domain root holds a single `Mapping` (domain code ->
  HTTP status, default 500). Error paths call `httperror.Render(w, err, mapping)`.
  See `error-handling.md` for the full `apperror.New` / `apperror.As` / `Mapping`
  contract. A per-handler `errormapping.go` is a violation — it is duplication.

## Full-stack layout (web/)

When the objective ships a browser UI (React/SPA) served by the Go binary, the
frontend is a **self-contained subproject under `web/`** so the repo root stays
language-neutral (Go module + `web/` + `docs/` + config).

```
web/
  app/              # SPA source (index.html, src/)
  static/           # generated bundle (gitignored) — Go serves/embeds this
  package.json      # + package-lock.json, tsconfig*, vite/vitest config
  node_modules/     # gitignored
```

- No `package.json`, `tsconfig*`, `vite.config`, or `node_modules` at the repo root.
- The build tool's `root` points at `app`, `outDir` at `../static`; Go reads the
  same `web/static` path (config `STATIC_DIR`).
- Task runner invokes the frontend with a prefix (`npm --prefix web run ...`) so
  Go commands keep running from the repo root.

## Objective-varying concerns (validated only when present)

The harness auto-detects these; declare intent in the project's `AGENTS.md` so
reviewers know a choice is deliberate. When used, they must be wired correctly.

| Concern | Baseline expectation when the objective uses it |
|---------|--------------------------------------------------|
| HTTP router | `go-chi/chi` with a middleware chain (`RequestID`, structured `Logger`, `Recoverer`) wired in `bootstrap` |
| Logging | one structured logger (`log/slog`, zap, zerolog, or `pkg/logger`) |
| Dependency injection | `cmd/{app}/modules` constructor wiring, or uber/fx — consistent across domains |
| Persistence (DB) | `repository/` layer; repository tests are integration (`//go:build integration`) with YAML fixtures; DB side effects asserted via an `assert/` sub-package |
| External HTTP | a typed client in `internal/{svc}client`, tested through the httptest **upstream stub** integration suite with golden fixtures |
| Events / async | only when the objective requires it — never speculative |

## Test-suite baseline

Cost/benefit first: prefer the cheapest tier that proves the behavior. Unit
tests dominate; integration/e2e cover wiring and external contracts.

- **Unit** — pure/fast, mockery mocks for collaborators, `testdata/` factories,
  whole-object assertions. No I/O.
- **Handler** — real use case + mocked collaborators via a reusable
  `pkg/handlertest` suite; assert the whole JSON response against a
  `go:embed` golden file in `testdata/`.
- **External HTTP interception** — a local `httptest.Server` **upstream stub**
  that records requests and serves per-route golden bodies. This is the modern,
  dependency-free alternative to `gock`/transport monkeypatching, which the gate
  forbids (U9).
- **Integration/e2e** — a generic `internal/testing/integration` suite drives
  the assembled router against the upstream stub (and a real DB with YAML
  fixtures when persistence is in scope), comparing golden request/response
  files. Tag with `//go:build integration`.

## How the harness runs

```bash
bash "$AI_CONFIG_HOME/skills/architecture-gate/scripts/conformance.sh" .
```

Exit 0 = no universal invariant violated. Any ERROR blocks the phase. WARN lines
flag objective-varying gaps to confirm, not hard failures. See
`skills/architecture-gate/SKILL.md` for when to run it in the orchestrator flow.
