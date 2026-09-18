# Codex Runtime Compatibility

> Sub-file of `skills/orchestrating-tasks/SKILL.md`. Read SKILL.md first for Critical Rules and Pre-Dispatch Checklist.

These skills were originally written for a Copilot-style harness that exposes native skill dispatch such as `task(skill: "implementing-feature")`. Codex may expose only generic subagent tools such as `multi_agent_v1.spawn_agent`. These are not equivalent.

## Runtime Detection

Before dispatching any implementation or testing phase, identify the runtime
mode using `dispatching.md`'s "Provider Runtime Override" table (the
canonical 4-way classification). For Codex specifically: if only generic
agents such as `spawn_agent` are available, treat this as Codex managed —
agents are untrusted workers, the orchestrator owns all gates manually. If the
user requested the full orchestrator workflow and native skill dispatch is
unavailable, say so before continuing. Do not imply that `spawn_agent`
provides the same harness guarantees.

## Call-shape fallback

Codex managed mode must be conservative about transport fields.

Rules:

- Prefer the smallest accepted worker call shape.
- If the runtime rejects a call because of extra fields such as `agent_type`,
  `mode`, or full-fork transport options, retry once with fewer fields.
- Do not retry with a broader or more complex call shape after a schema failure.
- Bind the intended role in the prompt: `Logical role: go-implementer`,
  `Logical role: go-tester`, or `Logical role: general-purpose`.
- Inline the necessary role guidance from `agents/` and the rule bundle in the prompt.

The runtime error in this mode is transport-specific, not workflow-specific.
Treat schema rejection as a signal to simplify the call shape, not to abandon
the phase logic.

## Codex Managed Mode

Generic Codex workers can help produce patches, but their completion report is only a worker claim. It is not accepted until the orchestrator validates it.

For every phase in Codex managed mode:

1. Run the Pre-Dispatch Checklist from `SKILL.md`.
2. Dispatch at most one skill scope per worker: production uses `implementing-feature`, tests use `testing-implementation`.
3. Include the full Style Reinforcement Block and Codebase Search Rules from `dispatching.md` in the worker prompt.
4. Treat worker output as untrusted until the orchestrator audits the changed files.
5. Run the manual acceptance checklist for the skill scope.
6. Update `progress.md` only after the manual checklist passes.

Do not advance from production to tests, or from one phase to the next, just because a generic worker returned a completion report.

## Rule Bundles

In Codex managed mode, the orchestrator must load the relevant bundle before dispatch and must include the same bundle list in the worker prompt. If a project-local installed path exists, prefer it. If it does not exist, read the source file from `ai-config`.

| Phase | Project-local files | Source files in ai-config |
|---|---|---|
| Go production | `AGENTS.md`, global `rules/go-style.md`, global `rules/package-design.md`, global `rules/error-handling.md`, global `rules/clean-architecture.md` | `providers/codex/AGENTS.md`, `rules/go-style.md`, `rules/package-design.md`, `rules/error-handling.md`, `rules/clean-architecture.md`, `agents/go-implementer.md`, `skills/implementing-feature/SKILL.md`, `skills/writing-modern-go/SKILL.md` |
| Go tests | `AGENTS.md`, global `rules/testing.md`, global `rules/go-style.md`, global `rules/error-handling.md` | `providers/codex/AGENTS.md`, `rules/testing.md`, `rules/go-style.md`, `rules/error-handling.md`, `agents/go-tester.md`, `skills/testing-implementation/SKILL.md`, `skills/writing-modern-go/SKILL.md` |
| Review/gates | `AGENTS.md`, all relevant global `rules/*.md` for changed file types | `skills/reviewing-code/SKILL.md`, `skills/orchestrating-tasks/gates.md`, all relevant `rules/*.md` |
| Narrative/docs | global `rules/sanitizing-text.md` when relevant | `rules/sanitizing-text.md`, `skills/sanitizing-text/SKILL.md` |

The orchestrator must not rely on the worker to discover these files. Missing files are reported explicitly in the dispatch summary:

```unknown
Runtime: Codex managed
Rule bundle: Go tests
Loaded project-local: AGENTS.md
Loaded global rules: /path/to/ai-config/rules/testing.md, /path/to/ai-config/rules/go-style.md
Loaded source fallback: agents/go-tester.md, skills/testing-implementation/SKILL.md, skills/writing-modern-go/SKILL.md
Missing: none
```

If a rule file is missing from both project-local and source fallback locations, stop and ask the user whether to continue degraded.

## Worker Prompt Contract

Every Codex managed worker prompt must include:

- Runtime statement: `Runtime: Codex managed`.
- Rule bundle name and exact files loaded.
- Approved write scope.
- Forbidden write scope.
- Expected status vocabulary: `WORKER PASS`, `WORKER FAIL`, or `BLOCKED`.
- Reminder that the worker must not claim final acceptance.
- The full Codebase Search Rules from `dispatching.md`.
- The relevant style/rule excerpts or attached skill/rule files.
- The intended logical role when no `agent_type` field is available.

Workers that edit production and tests in the same dispatch are invalid unless the phase is explicitly approved as a repair cycle. Split normal phases.

## Manual Acceptance Checklist

For production phases:

- Changed files are within the approved write scope.
- No test files were edited by the production worker.
- Naming and public API surface follow `writing-modern-go`.
- No forbidden legacy Go patterns are present.
- Scoped format, lint, and tests pass.
- Any generated docs or examples match the implemented behavior.
- The production rule bundle was loaded before dispatch and before acceptance.
- The diff is checked against `rules/go-style.md`, `rules/package-design.md`, `rules/error-handling.md`, and `rules/clean-architecture.md` when applicable.

For Go production phases, also check operation slicing from
`rules/clean-architecture.md`: every endpoint has its own
`handler/{operation}` package, DTOs live in that operation handler package,
domain definitions live in `domain/`, and scaffold-style generic
multi-endpoint handlers are rejected for implementation work.

For testing phases:

- Changed files are test-only unless a repair cycle was explicitly approved.
- Static fixtures and golden JSON/YAML live in `testdata/`. Go factories live in `*_fixtures_test.go` or a `<pkg>test` sibling, and only when reuse or complexity warrants them.
- Small one-off composite literals may stay inline. Do not put Go factory packages under `testdata/`.
- Tests cover happy path, error path, validation path, and relevant edge cases from the plan.
- Tests do not call external services unless the phase is explicitly an integration or smoke phase.
- Scoped format, lint, and tests pass.
- The testing rule bundle was loaded before dispatch and before acceptance.
- The diff is checked against `rules/testing.md`, especially naming, fixture lifecycle, comments, mock strategy, and async-test rules.

If any checklist item fails, mark the phase as not accepted and dispatch a repair cycle or stop for user direction.

## Status Reporting

When reporting Codex managed work, distinguish these states:

- `WORKER PASS`: a generic worker reported success.
- `ACCEPTED`: the orchestrator audited the output and all manual gates passed.
- `BLOCKED`: a gate failed or the runtime cannot provide the requested workflow.

Never report `WORKER PASS` to the user as final in Codex managed mode unless it is paired with an orchestrator `ACCEPTED` statement.
