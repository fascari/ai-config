---
name: orchestrating-tasks
description: Use when starting or resuming any AI-assisted task — feature implementation, bug fix, codebase research, planning, code review, or any multi-skill workflow
---

# Orchestrating Tasks

Single entry point for all AI-assisted tasks. Detects task complexity, routes to the right skill chain, manages plan state, and checkpoints with the user. Never writes code, tests, or commits directly.

## Sub-files (READ AS NEEDED)

This skill is split into focused sub-files. Always read this SKILL.md first for Critical Rules and Pre-Dispatch Checklist. Then open the sub-file relevant to your current step:

| Sub-file | When to open |
|---|---|
| [`dispatching.md`](dispatching.md) | Selecting model tier + agent_type for a dispatch; building the `task` tool prompt; Style Reinforcement block; Codebase Search Rules |
| [`gates.md`](gates.md) | Running Critique Gate, Test Design Judge, or Output Judge Gate |
| [`task-types.md`](task-types.md) | Picking the skill chain for a task type; testing dispatch order; NEVER-dispatch-agents-directly rule |
| [`approval-and-output.md`](approval-and-output.md) | Approval checkpoints before external writes; expected artifact set in the external vault plan directory |

---

## Critical Rules

These rules always apply regardless of task type. Read them before anything else.

- **Never write production code, tests, or commits directly** — delegate to the appropriate skill
- **Never propose, draft, or suggest commits** — commits and PRs are manual user commands only; report final state and stop
- **Never transition `progress.md` to `REVIEW` from inside a skill** — only orchestrating-tasks does this after gates pass
- **Always run Completion Gate before `reviewing-code`** — lint + tests must pass; on FAIL dispatch `implementing-feature` for up to 2 repair cycles; escalate to user if still failing
- **Never dispatch `harness-gate` directly** — `implementing-feature` and `testing-implementation` each dispatch `validate-loop` internally; the orchestrator receives only `LOOP PASS` or `LOOP FAIL`
- **On `LOOP FAIL` with `escalate: true`** — present the escalation to the user and wait for direction; do not dispatch a repair cycle
- **All narrative prose passes through `sanitizing-text` before presentation**
- **Never skip user approval checkpoints** — commits, pushes, and any external API writes require explicit approval (see `approval-and-output.md`)
- **Never assume a plan exists** — always run plan discovery first
- **`implementing-feature` owns production code, `testing-implementation` owns tests** — never cross-assign; each returns `LOOP PASS/FAIL`. A phase that touches both production files AND test files MUST be split into two dispatches. (See `task-types.md`)
- **NEVER dispatch `go-implementer` or `go-tester` directly** — always dispatch the SKILLS (`implementing-feature`, `testing-implementation`). The skills are the wrappers that run `validate-loop`. Dispatching the agents directly bypasses the harness entirely. (See `task-types.md`)
- **`write_agent` is single-skill-scoped** — switching skill type requires a fresh `task()` dispatch
- **Dispatch model selection is mandatory** — for every task dispatch, consult `dispatching.md` Delegation Model Matrix. Run the Pre-Dispatch Checklist before every `task` invocation.
- **Subagent prompts MUST include Codebase Search Rules** — for any subagent that needs codebase exploration, paste the verbatim block from `dispatching.md` into the dispatch prompt. Trusting global instructions alone is not enough.
- **Judges and validators MUST use a different vendor than the producer** — see `dispatching.md` Cross-Vendor Rule. Same-vendor judging is a hard rule violation.

---

## Pre-Dispatch Checklist (mandatory before every `task` invocation)

Answer these questions explicitly in your reasoning BEFORE dispatching any subagent. If you cannot answer all of them, do not dispatch yet.

1. **Complexity tier?** Simple | Standard | Complex
2. **Model tier + agent_type?** From `dispatching.md` matrix; Deep override if Complex judge/reviewer.
3. **Subagent needs codebase exploration?** If yes (researching, critique, reviewing), inject the verbatim Codebase Search Rules block from `dispatching.md`.
4. **Approval needed before dispatch?** Check `approval-and-output.md` Approval Checkpoints table.
5. **Does the phase touch both production files AND test files?** If yes, SPLIT into two dispatches.
6. **Is this a judge/validator of another agent's output?** If yes, confirm the judge's vendor is DIFFERENT from the producer's vendor.

---

## Step 1 — Setup & Plan Discovery

1. Resolve the external plan root. Prefer `$AI_MEMORY_HOME/{project}/plans/`; if unset, use `$COPILOT_VAULT/{project}/plans/`. If neither is set, stop and ask the user to configure the Obsidian vault path.
2. Run `skills/plans-setup.md`: ensure `{plan_root}` exists and create or refresh the repo-local `.plans` symlink pointing to `{plan_root}`.
3. Do not create real repo-local plan folders, provider-specific AI configuration inside the project repository, or `.github/plans`.

When no slug is provided, scan the external plan root and read each `progress.md`:

| Situation | Action |
|-----------|--------|
| User provided slug | Use directly |
| 1 plan with `IN_PROGRESS` | Use automatically, inform user |
| Multiple `IN_PROGRESS` | List and ask which to use |
| None found | Offer to create a new plan or reopen a `DONE` one |

## Step 2 — Read Plan Status

Read `{plan_root}/{slug}/progress.md` and route:

| Status | Action |
|--------|--------|
| File absent or no `## Status` | Start from scratch — full workflow |
| `IN_PROGRESS` | Find last completed phase, resume from there. If `## Harness Gates` shows `NOT_RUN` or `FAIL`, run the gates before transitioning to `REVIEW`. |
| `REVIEW` | Check `## Harness Gates` first. If both PASS, proceed to reviewing-code. If any is `NOT_RUN` or `FAIL`, reset to `IN_PROGRESS` and run the gates. |
| `DONE` | Report complete. Ask "Reopen?" — do not proceed without confirmation |

When reopening: update `## Status` to `IN_PROGRESS`, ask where to restart.

## Step 3 — Classify & Delegate

Classify complexity, then delegate to the matching skill chain. See `task-types.md` for the full matrix. Apply the parallel dispatch rule — dispatch independent phases in parallel before proceeding.

| Level | Criteria | Skill chain |
|---|---|---|
| Simple | Single file, typo, config | implementing-feature only |
| Standard | New endpoint, bug fix (≤3 layers) | researching-codebase → planning-implementation → implementing-feature → testing-implementation → [Gates] → reviewing-code |
| Complex | New domain, cross-service, migrations | All skills, analyzing-system-design mandatory |

`analyzing-system-design` is not optional for Standard and Complex tasks. The implementer must not start until `system-design-analysis.md` is approved.

---

## Complexity Classification

| Level | Criteria |
|---|---|
| Simple | Single file change, typo/config fix, guard condition. Entire production change fits in ≤5 lines across 1 file AND root cause is fully documented. |
| Standard | Bug fix touching 2-3 layers, new endpoint, new service. |
| Complex | New domain, cross-service change, migration + multiple layers, fixture/test changes that may cascade. When in doubt between Standard and Complex, default to Standard and escalate after critique gate if needed. |

---

## State Management

Only `orchestrating-tasks` and the skills listed may write the `## Status` line in `progress.md`.

| From | To | Who | When |
|------|----|-----|------|
| _(absent)_ | `IN_PROGRESS` | orchestrating-tasks | brief.md created |
| `IN_PROGRESS` | `REVIEW` | orchestrating-tasks | After Output Judge PASS (or skipped per skip rules) |
| `REVIEW` | `IN_PROGRESS` | orchestrating-tasks | reviewing-code finds blockers |
| `REVIEW` | `DONE` | reviewing-code | User explicitly approves review |
| `DONE` | `IN_PROGRESS` | orchestrating-tasks | User explicitly asks to reopen |

```markdown
## Status
IN_PROGRESS

## Harness Gates
Output Judge: NOT_RUN

## Phase 1 — Domain Model (DONE)
- [x] Entity created
- [x] Tests passing

## Phase 2 — Use Case (IN PROGRESS)
- [x] UseCase struct
- [ ] Unit tests
```

Valid values: `IN_PROGRESS` | `REVIEW` | `DONE`

---

## Priority Rule: Parallel Agent Dispatch

**Whenever two or more sub-tasks are independent, dispatch them as background agents in parallel. Do not serialize work that can be parallelized.**

Before each phase: identify which sub-tasks don't depend on each other's output — dispatch those in parallel; run the rest in dependency order.

| Scenario | Wrong | Right |
|---|---|---|
| Research 3 services | Sequential, 3 turns | 3 `explore` agents, 1 turn |
| Implement domain + repository (no dependency) | Domain then repository | Both in parallel |

Failing to parallelize independent tasks is a performance violation.

---

## Context Compression

Offer compression at every user-facing checkpoint when: context ≥ 70%, or session spans research + planning + coding.

```
Context is at {N}% — compress now to resume cleanly in a new chat?
Reply "yes" or /compress.
```

Skill: `skills/compressing-context/SKILL.md`

---

## Common Mistakes

- Serializing independent phases: always check for parallelism before delegating a phase
- Skipping `analyzing-system-design` for Standard/Complex tasks: it is mandatory
- Treating review approval as commit authorization: they are separate checkpoints
- Assuming the active plan without reading `progress.md`: always discover first
- Writing code directly: this skill only routes; implementation goes to implementing-feature
- Reusing a live agent across skill types: each skill phase requires a fresh `task()` dispatch
- Dispatching `go-implementer` or `go-tester` directly: always dispatch the skills

## Permissions

- Invoke any skill
- Read any file
- Create and update `brief.md`, `progress.md`
- Update `## Status` in `progress.md`

Forbidden:
- Write production code or tests
- Commit without explicit user authorization
- Assume "proceed with implementation" covers commit authorization
- Skip any approval checkpoint
