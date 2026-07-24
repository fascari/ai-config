# Orchestrating Tasks Efficient: Task Types & Workflow

> Sub-file of `skills/orchestrating-tasks-efficient/SKILL.md`. Read SKILL.md first for Critical Rules and Pre-Dispatch Checklist.

This file maps task types and risk profiles to the right mode, skill chain, and dispatch consolidation strategy.

---

## Task Type -> Mode Matrix

| Task Type | Typical Complexity | Typical Risk | Mode |
|---|---|---|---|
| Documentation update | Simple | Low | Lean |
| Config change | Simple | Low | Lean |
| Typo or guard condition | Simple | Low | Lean |
| Local refactor without contract change | Simple/Standard | Low | Lean or Standard |
| Bug fix touching 2-3 layers | Standard | Medium | Standard |
| New endpoint | Standard | Medium | Standard |
| New small service | Standard | Medium | Standard |
| Domain or repository change | Standard | Medium | Standard |
| Financial movement or ledger | Simple/Standard | Critical | High Assurance |
| Idempotency fix | Simple/Standard | High | High Assurance |
| Concurrency-critical change | Standard | High | High Assurance |
| Migration | Standard/Complex | High | High Assurance |
| Public contract change | Standard | High | High Assurance |
| Authn/Authz | Standard | High | High Assurance |
| Cryptography or blockchain | Standard/Complex | Critical | High Assurance |
| Cross-service change | Complex | High | High Assurance |

Risk overrides complexity. A 10-line balance calculation change is Simple in size but Critical in risk, so it uses High Assurance.

---

## Mode Flows

### Lean

```
orchestrator
  -> create context-capsule.md
  -> dispatch implementing-feature (Balanced)
     -> deterministic gates (format, compile, lint, style greps, scoped tests)
  -> [optional] semantic review if risk surfaces
  -> update progress.md
```

Rules:

- No separate research agent when files are already known.
- No system design.
- No critique gate.
- No Output Judge.
- Combined production + test dispatch allowed only when ALL these conditions are true:
  - the target is not a Go project (Go always splits production and test into separate `implementing-feature` and `testing-implementation` dispatches so `go-tester` governs every `*_test.go`);
  - Low Risk;
  - at most 1 production file;
  - at most 1 test file;
  - estimated total change of approximately 20 lines or less;
  - exact file paths pre-defined in the capsule;
  - no exported interface changed;
  - no HTTP contract changed;
  - no database schema changed;
  - no message or event contract changed;
  - no concurrency;
  - no financial calculation;
  - no authentication or security change;
  - no externally observable error handling change;
  - all deterministic gates remain mandatory.
- If any condition fails, split into separate `implementing-feature` and `testing-implementation` dispatches.
- Every `implementing-feature` / `testing-implementation` dispatch prompt MUST list the phase's exact target file paths so the worker sets `PHASE_FILES` and detects the stack per phase (never from a root manifest). An empty scope in a multi-manifest repo fails closed.

### Standard

```
orchestrator
  -> consolidated discovery-and-planning dispatch (Balanced)
     -> produces research.md
     -> produces system-design-analysis.md (conditional)
     -> produces implementation-plan.md
     -> produces context-capsule.md
  -> user approves plan
  -> dispatch implementing-feature (Balanced)
  -> dispatch testing-implementation (Balanced)
  -> deterministic Completion Gate
  -> combined cross-vendor semantic review (Output Judge + reviewing-code)
  -> update progress.md
```

Rules:

- Research, planning, and conditional system design happen in one dispatch.
- One combined LLM review at the end.
- No separate critique gate.
- Expert Review used only for the final review when risk is High within Standard.

### High Assurance

```
orchestrator
  -> dispatch researching-codebase (Complex)
  -> dispatch analyzing-system-design (Complex, mandatory)
  -> dispatch planning-implementation (Complex)
  -> critique gate (Expert Review, cross-vendor)
  -> user approves plan
  -> dispatch implementing-feature (Balanced or Complex)
  -> dispatch testing-implementation (Balanced; Complex only when tests involve Critical risk, complex concurrency, financial calculation, security, cryptography, smart contracts, or cross-service behavior. Record the override justification in the dispatch or progress.md.)
  -> deterministic Completion Gate
  -> Output Judge (Expert Review, cross-vendor)
  -> semantic review (Expert Review, cross-vendor)
  -> update progress.md
```

Rules:

- Reuse context-capsule.md between phases instead of re-reading full artifacts.
- Do not parallelize agents that need the same code areas.
- Do not use Complex for mechanical tasks.

---

## Testing Dispatch Skip Rules

- Docs-only changes: do not dispatch `testing-implementation`. Run document validators relevant to the file type.
- Config-only changes without executable code: do not dispatch `testing-implementation`. Run config validators.
- Executable code changes require existing or new tests as applicable.
- If the implementer produced zero new or modified test files AND the change is docs/config-only, skip `testing-implementation` entirely.

---

## Dispatch Consolidation Rules

### Consolidate into one dispatch

- Research + architectural analysis + planning in Standard mode.
- Output Judge + semantic review in Standard mode.
- Small production + test changes in Lean mode (with restrictions).

### Keep separate dispatches

- Production (`implementing-feature`) and tests (`testing-implementation`) in Standard and High Assurance.
- Research and critique in High Assurance (critique must be cross-vendor and adversarial).
- Output Judge and semantic review in High Assurance.

---

## NEVER-dispatch-agents-directly Rule

Always dispatch the SKILLS, not the underlying agents:

- `implementing-feature`, not `go-implementer`.
- `testing-implementation`, not `go-tester`.

The skills enforce deterministic gates. Direct agent dispatch bypasses them.

---

## Error Recovery

- If a skill fails mid-execution, capture the error, update `progress.md` with the failure point, and present options (retry, skip, abort).
- If a tool is unavailable, inform the user and proceed with local-only context.
- If a Balanced model fails a semantic gate, escalate to Complex once. If Complex also fails, stop for user direction.
