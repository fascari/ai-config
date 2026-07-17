---
name: orchestrating-tasks-efficient
description: Cost-aware entry point for AI-assisted tasks. Preserves deterministic Go gates and cross-vendor review, but reduces dispatches, context repetition, and unnecessary Deep model usage.
---

# Orchestrating Tasks: Efficient

Cost-aware entry point for AI-assisted tasks. Preserves the deterministic Go gates, security controls, and cross-vendor review of `orchestrating-tasks`, but reduces dispatches, context repetition, and unnecessary Deep model usage.

Use this skill when speed and cost matter more than the full High Assurance ceremony. Keep using `orchestrating-tasks` when maximum assurance is required.

## When to use which orchestrator

| Goal | Use |
|---|---|
| Single-file change, config, docs, small refactor, fix under ~20 lines | `orchestrating-tasks-efficient` Lean |
| Standard bug fix, endpoint, small service, normal domain change | `orchestrating-tasks-efficient` Standard |
| Financial movement, ledger, idempotency, critical concurrency, migrations, public contracts, authn/authz, cryptography, cross-service change | `orchestrating-tasks` High Assurance |
| Team explicitly asked for the full workflow | `orchestrating-tasks` |

## Sub-files

Read this SKILL.md first for Critical Rules and Pre-Dispatch Checklist. Then open the sub-file for the current step:

| Sub-file | When to open |
|---|---|
| [`dispatching.md`](dispatching.md) | Model tier selection, dispatch contract, Style Reinforcement block, Codebase Search Rules |
| [`task-types.md`](task-types.md) | Complexity + risk classification, skill chain per mode, dispatch consolidation rules |
| [`gates.md`](gates.md) | Deterministic Go gates and conditional LLM gates |
| [`context-management.md`](context-management.md) | `context-capsule.md` format and reuse rules |
| [`provider-dispatch.md`](provider-dispatch.md) | Mapping logical roles to Copilot, Codex, Claude, and OpenCode call shapes |
| [`migration.md`](migration.md) | Differences from `orchestrating-tasks`, migration examples, cost testing strategy |

---

## Critical Rules

- **Never write production code, tests, or commits directly**: delegate to the appropriate skill.
- **Never propose, draft, or suggest commits**: commits and PRs require manual user commands only.
- **Never transition `progress.md` to `REVIEW` from inside a skill**: only this orchestrator does that after gates pass.
- **Always run deterministic Completion Gate before any LLM review**: lint, format, typecheck, relevant tests, and Go style greps must pass.
- **On gate failure**: present the failure to the user and wait for direction. Do not auto-dispatch a repair cycle.
- **Balanced first, Deep on risk or escalation**: see `dispatching.md`.
- **NEVER dispatch `go-implementer` or `go-tester` directly**: always dispatch the skills (`implementing-feature`, `testing-implementation`).
- **`implementing-feature` owns production code, `testing-implementation` owns tests**: each returns a completion report.
- **Cross-vendor rule applies to any judge/reviewer**: see `dispatching.md`.
- **Do not run `sanitizing-text` on internal handoffs**: use it only for public output, PR descriptions, docs, and user-facing reports.
- **This skill overrides `skills/sanitizing-text/SKILL.md` mandatory invocation points.** When `orchestrating-tasks-efficient` is active, `sanitizing-text` remains mandatory only for: PR descriptions, public content, documentation intended for publication, external messages, and final reports when the user requests polished text. Never run for: handoffs, progress updates, gate results, inter-agent communication, intermediate technical summaries, or internal reports.
- **Never skip user approval checkpoints**: commits, pushes, breaking changes, migrations, and external API writes require explicit approval.
- **Reuse `context-capsule.md`**: following agents read it first instead of re-reading full research and plans.
- **Graphify once**: run the main structured query once, save results in the capsule, and avoid repeated queries.

---

## Pre-Dispatch Checklist (mandatory before every `task` invocation)

Answer these questions explicitly before dispatching any subagent:

1. **Complexity tier?** Simple | Standard | Complex
2. **Risk level?** Low | Medium | High | Critical
3. **Execution mode?** Lean | Standard | High Assurance
4. **Model tier + logical role?** From `dispatching.md`; default to Balanced.
5. **Does this task need a separate research/planning dispatch?** In Standard, consolidate research + planning into one dispatch unless High Assurance is required.
6. **Does the phase touch both production files AND test files?** If considering a combined Lean production + test dispatch, verify every condition in "Lean mode" under Step 4. If any condition fails, split into separate `implementing-feature` and `testing-implementation` dispatches.
7. **Is this a judge/validator of another agent's output?** If yes, confirm cross-vendor pairing.
8. **Runtime mode?** Copilot native | Codex managed | Claude managed | OpenCode | Local manual.

---

## Step 1: Setup & Plan Discovery

Use the same rules as `skills/orchestrating-tasks/plans-setup.md`:

1. Resolve `{plan_root}` from `$AI_MEMORY_HOME/{project}/plans/`. If unset, stop and ask the user to configure the vault path.
2. Create or refresh the repo-local `.plans` symlink pointing to `{plan_root}`.
3. Discover the active plan by reading `progress.md` files.

When no slug is provided:

| Situation | Action |
|---|---|
| User provided slug | Use directly |
| 1 plan with `IN_PROGRESS` | Use automatically, inform user |
| Multiple `IN_PROGRESS` | List and ask which to use |
| None found | Offer to create a new plan or reopen a `DONE` one |

---

## Step 2: Read Plan Status

Read `{plan_root}/{slug}/progress.md` and route:

| Status | Action |
|---|---|
| File absent or no `## Status` | Start from scratch |
| `IN_PROGRESS` | Resume from last completed phase; run gates if `## Harness Gates` shows `NOT_RUN` or `FAIL` |
| `REVIEW` | Check `## Harness Gates`; if PASS, proceed to review; else reset to `IN_PROGRESS` and run gates |
| `DONE` | Report complete. Ask "Reopen?" before proceeding |

---

## Step 3: Classify Complexity and Risk

Classify separately. Risk has priority over file count.

### Complexity

| Level | Criteria |
|---|---|
| Simple | Single file change, typo/config fix, guard condition, refactor without contract change. Entire production change fits in ~20 lines across 1-2 files and root cause is clear. |
| Standard | Bug fix touching 2-3 layers, new endpoint, new small service, normal domain or repository change. |
| Complex | New domain, cross-service change, migration + multiple layers, fixture/test changes that may cascade. |

### Risk

| Level | Examples |
|---|---|
| Low | Documentation, config, internal tooling, refactor without contract change, changes behind feature flags. |
| Medium | Standard business logic, new endpoints, non-financial domain changes, UI/adapter changes. |
| High | Concurrency, idempotency, migrations, public contracts, event schemas consumed by other systems, authn/authz. |
| Critical | Financial movement, ledger, cryptocurrency, smart contracts, destructive migrations, irreversible operations. |

### Mode selection

| Complexity | Risk | Mode |
|---|---|---|
| Simple | Low / Medium | Lean |
| Standard | Low / Medium | Standard |
| Complex | Low / Medium | Standard when confined to one module with no external behavioral change; High Assurance otherwise |
| Any | High / Critical | High Assurance |

Deterministic rules:

- Risk High or Critical always selects High Assurance.
- Cross-domain or cross-service changes always select High Assurance.
- Public, irreversible, or critical changes always select High Assurance.
- A large refactor confined to one module with no external behavioral change may use Standard.
- Record the choice and justification in `progress.md`.

---

## Step 4: Execute the Selected Mode

### Lean mode

Flow: `orchestrator -> implementation -> deterministic gates`

1. Skip separate research and system design when files are known.
2. Create or update `{plan_root}/{slug}/context-capsule.md` with objective, files, acceptance criteria, and constraints.
3. Dispatch `implementing-feature` (Balanced). For very small docs/config changes, a single combined production + test dispatch is allowed only when all these conditions are true:
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
   If any condition fails, split into separate `implementing-feature` and `testing-implementation` dispatches.
4. Run deterministic Completion Gate: gofmt, compile, lint, scoped tests, style greps.
5. Run LLM review only when semantic risk is identified.
6. Update `progress.md`.

### Standard mode

Flow: `discovery-and-planning -> implementation -> testing -> deterministic completion gate -> semantic review`

1. Consolidate `researching-codebase`, architectural analysis, and `planning-implementation` into a single dispatch.
   - This dispatch produces separately: `research.md`, `system-design-analysis.md` (only when needed), `implementation-plan.md`, and `context-capsule.md`.
   - Do not use one subagent per artifact.
2. User approval of the plan is required before implementation.
3. Dispatch `implementing-feature` (Balanced).
4. Dispatch `testing-implementation` (Balanced).
5. Run deterministic Completion Gate.
6. Run one combined cross-vendor semantic review (Output Judge + `reviewing-code`).
7. Update `progress.md`.

### High Assurance mode

Flow: reuse the full `orchestrating-tasks` workflow.

1. Dispatch `researching-codebase` (Deep).
2. Dispatch `analyzing-system-design` (Deep, mandatory).
3. Dispatch `planning-implementation` (Deep).
4. Run critique gate (Deep, cross-vendor) before implementation.
5. Dispatch `implementing-feature` (Balanced or Deep for critical security/finance).
6. Dispatch `testing-implementation` (Balanced; Deep only when tests involve Critical risk, complex concurrency, financial calculation, security, cryptography, smart contracts, or cross-service behavior. Record the override justification in the dispatch or `progress.md`).
7. Run deterministic Completion Gate.
8. Run Output Judge (Deep, cross-vendor).
9. Run semantic review (Deep, cross-vendor).
10. Update `progress.md`.

In High Assurance, still reuse `context-capsule.md` instead of re-reading full artifacts.

---

## Context Capsule

Create and maintain `{plan_root}/{slug}/context-capsule.md`. It must stay under ~1,500 words.

Contents:

- objective of the change;
- summarized acceptance criteria;
- relevant files;
- interfaces and signatures;
- architectural decisions;
- existing patterns to follow;
- contracts that cannot break;
- risks;
- lint and test commands;
- current execution state;
- handoff for the next phase.

Following agents read the capsule first. They only open `research.md`, `implementation-plan.md`, full rules, or source files when the capsule lacks enough information.

See full format in `context-management.md`.

---

## Graphify Rules

- Run the main structured query once.
- Save relevant results in `context-capsule.md`.
- Subsequent agents do not repeat the same query.
- Run a new query only for genuinely new questions.
- Prefer a single research agent for related areas.
- Use parallel agents only for truly independent domains.

---

## RTK Rules

Continue using RTK for tests, lint, logs, git diff, and verbose commands.
Do not assume RTK reduces context duplication between subagents. Avoid re-running commands whose result is already in the handoff and still valid.

---

## Checkpoints and Approvals

Request explicit user approval before:

- breaking changes;
- external writes (commits, pushes, MCP API writes);
- contract changes;
- destructive migrations;
- implementation after a plan that has not been approved;
- transitions to High Assurance after a failed Standard attempt.

Do not pause after every small phase when the approved plan already authorizes continuation. Related phases may run in batch while `progress.md` is updated.

---

## AI Execution Metrics

Add a `## AI Execution Metrics` section to the final report:

- mode chosen;
- complexity and risk;
- number of dispatches;
- number of Deep agents used;
- number of Balanced agents used;
- Graphify queries executed;
- gates executed;
- LLM gates avoided;
- context capsule reused;
- repair cycles needed.

Do not invent token counts. The goal is to enable comparison between `orchestrating-tasks` and `orchestrating-tasks-efficient`.

---

## Common Mistakes

- Using Deep models for mechanical tasks (formatting, summaries, progress updates).
- Running `sanitizing-text` on handoffs, checkpoints, lint output, or progress updates.
- Dispatching `go-implementer` or `go-tester` directly instead of the skills.
- Re-reading full `research.md` or `implementation-plan.md` when `context-capsule.md` is sufficient.
- Parallelizing agents that share overlapping context just to save wall-clock time.
- Skipping deterministic Go gates in any mode.

## Permissions

- Invoke any skill.
- Read any file.
- Create and update `brief.md`, `requirements.md`, `context-capsule.md`, `progress.md`.
- Update `## Status` in `progress.md`.

### `requirements.md` ownership

- Created during definition or planning stage only.
- May be updated during planning with proper authorization.
- Implementers and testers have read-only access.
- Any modification during implementation is a violation.
- Reviewers may validate content but must not edit.

Forbidden:

- Write production code or tests directly.
- Commit without explicit user authorization.
- Skip deterministic gates.
