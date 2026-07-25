---
name: architecture-gate
description: Use when scaffolding a new Go service or finishing any build phase, to validate the whole domain conforms to the base architecture blueprint (structure, layering, DDD, test suite). Deterministic, zero LLM tokens.
---

# Architecture Gate

The construction harness. A deterministic, zero-token check that a Go service
conforms to `rules/architecture-blueprint.md` — structure, layering, use-case
and handler shape, mock strategy, and test-suite baseline. It is the macro
counterpart to `style-gate` (which checks micro style on changed files).

## When to run

- **At scaffold time** — right after generating a project from the scaffold,
  before writing any feature. Proves the skeleton is conformant from line one.
- **After each production or test phase** — before handing off, to prove no
  drift was introduced (monolithic use case, handler-local interface,
  hand-written fakes, field-by-field asserts, missing testdata, gock).
- **Before a cross-vendor review** — so the reviewer spends judgment on logic,
  not mechanical shape the harness already guarantees.

Run `style-gate` on changed files every phase (fast subset); run this full
harness when validating a whole domain or a fresh scaffold.

## Scope

This gate enforces Go backend architecture only (`rules/architecture-blueprint.md`
is Go-specific). The single frontend-touching check (`checks-frontend.sh`, W8)
is a repo-layout convention only: it confirms `web/` holds a self-contained
frontend project, nothing about React code quality. There is no React/frontend
conformance rule set or gate yet; do not read a PASS here as validating
frontend code.

## How to run

```bash
bash "$AI_CONFIG_HOME/skills/architecture-gate/scripts/conformance.sh" [REPO_ROOT]
```

Exit `0` = no universal invariant violated. Exit `1` = at least one ERROR.

## Reading the report

- **ERROR** — a universal invariant (U1–U10 in the blueprint) is violated. Blocks
  the phase. Fix by re-dispatching the offending files through `go-implementer`
  (production) or `go-tester` (tests) — never patch in the main conversation.
- **WARN** — an objective-varying concern (router/logger/DI/DB/external-HTTP/
  testdata) looks missing. Confirm it is intentional (the objective does not use
  it) or wire it per the blueprint. WARN never fails the gate.
- **PASS** — invariant satisfied.

## Cost/benefit

Mechanical conformance is checked here for zero LLM tokens — always run it before
spending model tokens on an LLM review. Reserve LLM judgment for what a grep
cannot decide (design tradeoffs, naming intent, behavior). Quality and economy:
the harness catches the cheap, recurring drift so reviews stay focused and short.

## Extending

Add a check only after a RED-GREEN test: confirm the new grep fires on a known
violating tree and stays silent on a conformant one. Keep universal invariants as
ERROR; keep objective-varying detections as WARN. See `writing-skills` for the
TDD-for-tooling discipline.
