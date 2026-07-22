# Orchestrating Tasks: Task Types & Workflow

> Sub-file of `skills/orchestrating-tasks/SKILL.md`. Read SKILL.md first for Critical Rules and Pre-Dispatch Checklist.

This file covers task type classification, the skill chain for each task type, and the testing dispatch rule.

---

## Task Type → Skill Matrix

| Task Type | Skills Invoked |
|---|---|
| New feature/endpoint | researching-codebase → planning-implementation → **[Phase N: implementing-feature → testing-implementation]** → **[Completion Gate]** → **[Output Judge]** → reviewing-code → sanitizing-text |
| Bug fix | researching-codebase → planning-implementation → **[Phase N: implementing-feature → testing-implementation]** → **[Completion Gate]** → **[Output Judge]** → reviewing-code → sanitizing-text |
| Research only | researching-codebase → sanitizing-text |
| Code review | reviewing-code → sanitizing-text |
| Commit only | committing-changes |

---

## Testing-Implementation Dispatch Rule

`implementing-feature` and `testing-implementation` each run deterministic gates internally (lint + style greps). The orchestrator dispatches only the skills, never the code agents directly.

**CRITICAL: NEVER dispatch `go-implementer` or `go-tester` directly for implementation work.**
These are underlying logical roles for **Go stacks only**. The orchestrator MUST always dispatch the SKILLS
(`implementing-feature`, `testing-implementation`). The skills detect the stack and decide the logical role:
`go-implementer`/`go-tester` for Go, `general-purpose` for TypeScript, Python, or unknown stacks.
The skills are the wrappers that enforce quality gates. Bypassing the skills bypasses
the quality checks entirely.

```unknown
# WRONG - bypasses quality gates
task(agent_type: "go-implementer", ...)     <- direct agent, no quality gates
task(agent_type: "go-tester", ...)          <- direct agent, no quality gates
task(agent_type: "go-tester", ...)          <- dispatched for non-Go stack (hard rule violation)
spawn_worker(prompt: "act like go-implementer", ...) <- managed worker accepted as final without orchestrator review

# CORRECT - choose by runtime. implementer role is stack-dependent.
Copilot native:
# Go stack
task(skill: "implementing-feature", agent_type: "go-implementer", ...)
task(skill: "testing-implementation", agent_type: "go-tester", ...)
# Non-Go stack (TypeScript, Python, etc.)
task(skill: "implementing-feature", agent_type: "general-purpose", ...)
task(skill: "testing-implementation", agent_type: "general-purpose", ...)

Codex/Claude managed:
# Go stack
spawn_agent(agent: "go-implementer", prompt: "...")  <- when a matching Codex custom agent exists
spawn_agent(agent: "go-tester", prompt: "...")       <- when a matching Codex custom agent exists
# Non-Go stack
spawn_worker(prompt: "Logical role: general-purpose ...", ...) <- fallback
orchestrator manual acceptance checklist
```

Dispatch order:

1. Orchestrator dispatches `implementing-feature`:
   - Skill runs its phases with deterministic gates (lint + style greps)
   - Returns completion report with context_handoff
   - If gates fail: present the issues to the user and wait for direction.

2. After implementing-feature completes:
   - Dispatch `testing-implementation` using the `context_handoff` from the completion report
   - testing-implementation runs internally: write tests → run tests → lint
   - Returns completion report
   - If gates fail: present the issues to the user and wait for direction.

3. After testing-implementation completes: proceed to Completion Gate.

**Skip rule**: if the implementer produced zero new or modified test files AND the change is docs/config-only, skip `testing-implementation`.

**A phase that touches both production files AND test files MUST be split into two dispatches**: `implementing-feature` for production files, then `testing-implementation` for tests. Never bundle both into one prompt, even when they are tightly coupled.

**Multi-turn anti-pattern**: NEVER send a "now write the integration test" follow-up via `write_agent` to an `implementing-feature` agent that just finished production code, nor to a `testing-implementation` agent that just finished unit tests. Each test phase (unit, integration, e2e) is a separate `testing-implementation` dispatch.

---

## Error Recovery

- If a tool (MCP, CLI, etc.) is unavailable: inform the user and proceed with local-only context (plan files, codebase). Do not block the workflow.
- If a skill fails mid-execution: capture the error, update `progress.md` with the failure point, and present options to the user (retry, skip, abort).

## Provider Runtime Override

Native harness mode remains the preferred path for Copilot-style runtimes:

```unknown
# The skill detects the stack internally
task(skill: "implementing-feature", agent_type: "go-implementer", ...)  # Go stack
task(skill: "implementing-feature", agent_type: "general-purpose", ...) # non-Go stack
task(skill: "testing-implementation", agent_type: "go-tester", ...)     # Go stack
task(skill: "testing-implementation", agent_type: "general-purpose", ...) # non-Go stack
```

Codex managed mode is different:

```unknown
spawn_agent(...)                          <- generic worker only, no native harness
orchestrator manual acceptance checklist  <- required before accepting output
```

If only `spawn_agent` or another generic worker tool is available, read `codex-runtime.md`. Do not call the workflow phase complete until the orchestrator has run the manual acceptance checklist and reported `ACCEPTED`.
