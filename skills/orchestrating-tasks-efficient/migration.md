# Orchestrating Tasks Efficient: Migration and Comparison

This document explains the differences between `orchestrating-tasks` and `orchestrating-tasks-efficient`, and how to choose between them.

---

## Quick comparison

| Aspect | `orchestrating-tasks` | `orchestrating-tasks-efficient` |
|---|---|---|
| Primary goal | Maximum assurance | Cost-aware quality |
| Modes | Simple, Standard, Complex | Lean, Standard, High Assurance |
| Risk classification | Implicit in complexity | Explicit Low/Medium/High/Critical |
| Research + planning | Separate dispatches | Consolidated in Standard |
| System design | Mandatory for Standard/Complex | Conditional in Standard, mandatory in High Assurance |
| Critique gate | Standard/Complex | Only High Assurance |
| Output Judge | Standard/Complex | Combined with review in Standard; separate in High Assurance |
| Semantic review | Separate | Combined with Output Judge in Standard |
| Deep model default | Research, planning, critique, review | Balanced first; Complex only for risk or escalation |
| Context reuse | Full artifact re-read | `context-capsule.md` between phases |
| Sanitizing text | Mandatory for all narrative | Only public/user-facing text |
| Checkpoints | Per phase | Batchable when plan is approved |

---

## When to use each

### Use `orchestrating-tasks` when

- the change involves money, ledger, or settlement;
- the change affects idempotency, critical concurrency, or distributed state;
- the change is a migration or destructive schema change;
- the change touches public contracts, authn/authz, or cryptography;
- the change is cross-service;
- the team explicitly asked for the full High Assurance workflow.

### Use `orchestrating-tasks-efficient` when

- the change is small and well understood (Lean);
- the change is a standard bug fix, endpoint, or small service (Standard);
- cost or speed is a priority and the risk is Low or Medium;
- the same deterministic gates are sufficient.

---

## Example: Lean flow

Scenario: fix a guard condition in a single file.

```
User: "Add a nil check in internal/app/user/usecase/create.go before calling repo.Save."

orchestrating-tasks-efficient:
  -> classify: Simple, Low Risk, Lean
  -> update context-capsule.md
  -> dispatch implementing-feature (Balanced)
  -> run deterministic gates
  -> update progress.md
  -> report: 1 dispatch, 0 Complex agents, gates passed
```

No separate research, no system design, no critique gate, no Output Judge, no LLM review unless risk surfaces.

---

## Example: Standard flow

Scenario: add a new endpoint for listing user orders.

```
User: "Add GET /api/users/{id}/orders endpoint."

orchestrating-tasks-efficient:
  -> classify: Standard, Medium Risk, Standard
  -> consolidated discovery-and-planning dispatch (Balanced)
     -> research.md
     -> system-design-analysis.md (skipped: no distributed concerns)
     -> implementation-plan.md
     -> context-capsule.md
  -> user approves plan
  -> dispatch implementing-feature (Balanced)
  -> dispatch testing-implementation (Balanced)
  -> run Completion Gate
  -> combined cross-vendor semantic review (Balanced)
  -> update progress.md
  -> report: 5 dispatches, 0 Complex agents, 1 LLM gate
```

In `orchestrating-tasks`, the same task would use: research (Deep) -> system design (Deep) -> planning (Deep) -> critique (Deep) -> implement -> test -> Output Judge (Deep) -> review (Deep) -> sanitize. The efficient version consolidates research/planning and merges Output Judge + review.

---

## Example: High Assurance flow

Scenario: fix idempotency in a payment processing consumer.

```
User: "The payment consumer must not double-charge on retry."

orchestrating-tasks-efficient:
  -> classify: Standard, High Risk, High Assurance
  -> dispatch researching-codebase (Complex)
  -> dispatch analyzing-system-design (Complex, mandatory)
  -> dispatch planning-implementation (Complex)
  -> run critique gate (Expert Review, cross-vendor)
  -> user approves plan
  -> dispatch implementing-feature (Balanced)
  -> dispatch testing-implementation (Balanced)
  -> run Completion Gate
  -> run Output Judge (Expert Review, cross-vendor)
  -> run semantic review (Expert Review, cross-vendor)
  -> update progress.md
  -> report: 8 dispatches, 5 Complex agents, 2 LLM gates
```

This matches the depth of `orchestrating-tasks` but still uses `context-capsule.md` to avoid re-reading full artifacts.

---

## Preserved gates

Both skills enforce the same deterministic gates:

- format
- compile
- lint
- typecheck
- relevant tests
- race detector when concurrency is present
- style compliance greps
- API compatibility check
- package naming and structure rules

These gates are never skipped in either skill.

---

## Cost testing strategy

To compare the two skills on real AI credit usage:

1. Pick a representative task for each mode.
2. Run the task with `orchestrating-tasks` and record:
   - number of dispatches;
   - number of Complex/Balanced/Fast agents;
   - Graphify queries;
   - LLM gate calls;
   - wall-clock time.
3. Run the same task with `orchestrating-tasks-efficient` and record the same metrics.
4. Compare the two in the `## AI Execution Metrics` section of the final report.

Do not invent token counts. Use provider-supplied metrics when available.

---

## Migration checklist

To migrate a project or workflow to `orchestrating-tasks-efficient`:

1. Confirm the project has deterministic gates in place (`style-gate`, `writing-modern-go` for Go projects).
2. Train the team on the risk classification table.
3. Update provider entrypoints to list `orchestrating-tasks-efficient` as an alternative entry point.
4. Start with Lean and Standard tasks. Reserve High Assurance for Critical/High Risk.
5. Monitor `## AI Execution Metrics` to validate cost reduction without quality loss.

---

## Incompatibilities

- `orchestrating-tasks-efficient` is not a drop-in replacement for the full High Assurance workflow. It can delegate to `orchestrating-tasks` for High Assurance mode.
- Some runtimes may not expose the exact same skill names. Use `provider-dispatch.md` to adapt the logical roles.
- The combined Output Judge + review in Standard may produce a single review file instead of separate files.
