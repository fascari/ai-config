---
name: orchestrating-single-loop
description: Use when implementing a production feature or bug fix where a bounded single workflow is preferred over multi-agent orchestration.
---

# Orchestrating a Single Loop

## Overview

Run **one** production loop directly in the main conversation: research, approve
one plan, execute test-first, verify, and review. Invoke once; it continues
automatically except at defined human-decision points.

This is the **single-loop** counterpart to `orchestrating-tasks` /
`orchestrating-tasks-efficient`. Prefer it whenever an unbounded, multi-stage
agent pipeline (research agent → planning agent → design agent → critique
agent, each potentially re-running) would add more coordination risk than the
production change warrants.

Keep the work to one deliverable vertical slice. If the requested scope
cannot be completed safely as one slice, propose a smaller slice before
planning. Do not silently expand scope to compensate.

Pause only for unresolved human decisions: competing active plans, blocking
requirements, plan approval, scope or contract changes, and failures that
cannot be repaired within the defined repair limit.

## When to use this over orchestrating-tasks / orchestrating-tasks-efficient

| Situation | Use |
|---|---|
| One production feature or bug fix with a bounded vertical slice | `orchestrating-single-loop` |
| Complex change requiring independent research, design, or review agents | `orchestrating-tasks` |
| Standard change where cost-aware delegation is appropriate | `orchestrating-tasks-efficient` |

## Control flow

| Phase | Required action | Pause only when |
|---|---|---|
| Discover | Resume a matching active plan or choose a slug. | Multiple plans match. |
| Research | Load applicable instructions and rules, then read scripts, request-path code, and tests directly (no dispatched research agent); run the baseline. | A blocking requirement is ambiguous. |
| Plan | Create or resume the vault-backed `.plans/<slug>.md` plan, including its phases and artifacts (see `plans.md`). | Always: await approval. |
| Execute | Mark `IN_PROGRESS`; use RED-GREEN-REFACTOR per behavior. | Dependency, contract, or scope must change. |
| Gate | Run the relevant test, typecheck/lint, and build commands; repair regressions. | Still failing after two repair attempts, or a product decision is required. |
| Review | Mark `REVIEW`; read the diff against the plan, fix findings, rerun gates, then mark `DONE`. | A finding changes behavior or scope. |

## Research and planning rules

- Before Discover, require `$COPILOT_VAULT`. In the target project being changed, resolve the plan
  root as `$COPILOT_VAULT/<repository>/plans/`, create it when missing, and create or refresh that
  project's `.plans` symlink to the directory. Do not create `.plans` in the repository that
  distributes this skill. If the vault variable is unavailable, stop and request configuration
  instead of falling back to in-conversation state.
- Keep the plan and all phase artifacts in the vault-backed plan directory. Do not create a
  repository-local plan directory.
- Before reading source code, discover and load the target project's applicable instructions:
  root and nested `AGENTS.md`, `CLAUDE.md`, provider instruction files, and any path-specific
  instruction files for the files being changed.
- Follow the shared rules referenced by those instructions. When the target is a Go project, load
  the available Go style, design, testing, error-handling, package-design, and clean-architecture
  rules from the configured shared rules directory. Load text-sanitization rules before changing
  Markdown or text.
- Record the instruction files and shared rules loaded, plus any expected but unavailable rules, in
  the plan. If the target has no project-specific instructions, do not invent conventions: use the
  available shared provider rules and the repository's existing patterns.
- Ask only questions that change behavior, architecture, contract, or acceptance criteria.
- Inspect the codebase directly. Do **not** dispatch a separate research/explore agent for this —
  the round-trip cost defeats the purpose of a single bounded loop. Reserve sub-agents (if any)
  for one narrow, read-only lookup in an unfamiliar codebase, never for open-ended exploration.
- Keep stable behavior explicit; known gaps stay out of scope unless required by the task.
- A plan is not approval. Do not edit production or test files while its status is `PROPOSED`.
- Prompt in one language for the whole session (English recommended for AI prompts) — switching
  languages mid-session adds translation overhead at exactly the moment speed matters most.
- High-risk behavior (auth, money/pricing, migrations, concurrency, public contracts) requires
  explicit risks and boundary tests regardless of diff size, but do not let this expand into an
  exhaustive test matrix that blocks a first working slice — walking skeleton first, edge cases
  after it is demonstrably working end to end.

## Execution rules

For each behavior:

1. Add one focused test, run it, and inspect the result. It must fail because the requested
   behavior is missing, not because of a syntax, setup, or compilation error.
2. Implement the smallest production change that makes it pass.
3. Refactor only while tests remain green.

Follow local language/framework patterns and existing scripts. Do not add dependencies, broad
catches, unrelated cleanup, or silent fallbacks — every change should map back to the approved
plan.

## Bounded execution rules

- Set explicit checkpoints between phases: inspect actual output before continuing.
- If execution is not converging, stop, identify the blocker, and re-scope the change rather than
  allowing repeated planning or implementation loops.
- Prefer a complete, verified vertical slice over an expansive change with unverified edges.

## Review checklist

- Every changed line maps to approved scope and acceptance criteria.
- Tests prove behavior and boundaries; final gates pass.
- Contracts, errors, logs, and any pricing/financial semantics changed only as approved.
- No unnecessary dependency, type escape, silent failure, or unrelated refactor.

For genuinely high-risk behavior, do a single self-review pass reading the diff against the plan
before marking `DONE` — this replaces a dispatched independent-reviewer agent, which this skill
deliberately avoids when the change does not require independent review. Report delivered behavior, changed
files, and remaining risks. Never commit or push without a separate explicit request.
