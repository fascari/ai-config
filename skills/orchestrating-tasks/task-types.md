# Orchestrating Tasks — Task Types & Workflow

> Sub-file of `skills/orchestrating-tasks/SKILL.md`. Read SKILL.md first for Critical Rules and Pre-Dispatch Checklist.

This file covers task type classification, the skill chain for each task type, and the testing dispatch rule.

---

## Task Type → Skill Matrix

| Task Type | Skills Invoked |
|---|---|
| New feature/endpoint | researching-codebase → planning-implementation → **[Phase N: implementing-feature → testing-implementation]** *(validate-loop internal per phase pair)* → **[Completion Gate]** → **[Output Judge]** → reviewing-code → sanitizing-text |
| Bug fix | researching-codebase → planning-implementation → **[Phase N: implementing-feature → testing-implementation]** *(validate-loop internal per phase pair)* → **[Completion Gate]** → **[Output Judge]** → reviewing-code → sanitizing-text |
| Research only | researching-codebase → sanitizing-text |
| Code review | reviewing-code → sanitizing-text |
| Commit only | committing-changes |

---

## Testing-Implementation Dispatch Rule

`implementing-feature` and `testing-implementation` each run `validate-loop` internally. The orchestrator dispatches only the skills — never `harness-gate` or the code agents directly.

**CRITICAL: NEVER dispatch `go-implementer` or `go-tester` directly for implementation work.**
These are the underlying agent types. The orchestrator MUST always dispatch the SKILLS
(`implementing-feature` → `go-implementer`, `testing-implementation` → `go-tester`).
The skills are the wrappers that integrate `validate-loop`. Bypassing the skills bypasses
the harness entirely — no receipt is written, no LLM-judge runs, no quality gate fires.

```
# WRONG — bypasses harness
task(agent_type: "go-implementer", ...)  ← direct agent, no validate-loop
task(agent_type: "go-tester", ...)       ← direct agent, no validate-loop

# CORRECT — goes through skill → validate-loop
task(skill: "implementing-feature", agent_type: "go-implementer", ...)
task(skill: "testing-implementation", agent_type: "go-tester", ...)
```

Dispatch order:

1. Orchestrator dispatches `implementing-feature`:
   - Skill runs its phases, then dispatches `validate-loop` with `phase: implementation` internally
   - Returns `LOOP PASS` (with `context_handoff`) or `LOOP FAIL` (with `escalate: true`)
   - If `LOOP FAIL`: present the escalation to the user and wait for direction. Do not dispatch a repair cycle — the loop already exhausted its retry budget.

2. After implementing-feature returns `LOOP PASS`:
   - Dispatch `testing-implementation` using the `context_handoff` from the LOOP PASS result
   - testing-implementation runs internally: Style Compliance Gate → `validate-loop` (lint + test) → **`test-design-judge`** (semantic judge — see `gates.md`)
   - Returns `LOOP PASS` only after BOTH validate-loop AND test-design-judge pass
   - If `LOOP FAIL`: present the escalation to the user and wait for direction.

3. After testing-implementation returns `LOOP PASS`: proceed to Completion Gate.

**Skip rule**: if the implementer produced zero new or modified test files AND the change is docs/config-only, skip `testing-implementation`.

**A phase that touches both production files AND test files MUST be split into two dispatches**: `implementing-feature` for production files, then `testing-implementation` for tests. Never bundle both into one prompt, even when they are tightly coupled.

**Multi-turn anti-pattern**: NEVER send a "now write the integration test" follow-up via `write_agent` to an `implementing-feature` agent that just finished production code, nor to a `testing-implementation` agent that just finished unit tests. Each test phase (unit, integration, e2e) is a separate `testing-implementation` dispatch.

---

## Error Recovery

- If a tool (MCP, CLI, etc.) is unavailable: inform the user and proceed with local-only context (plan files, codebase). Do not block the workflow.
- If a skill fails mid-execution: capture the error, update `progress.md` with the failure point, and present options to the user (retry, skip, abort).
