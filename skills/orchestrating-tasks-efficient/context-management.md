# Orchestrating Tasks Efficient: Context Management

> Sub-file of `skills/orchestrating-tasks-efficient/SKILL.md`. Read SKILL.md first for Critical Rules and Pre-Dispatch Checklist.

This file defines the `context-capsule.md` artifact and the rules for reusing context between phases.

---

## Purpose

`context-capsule.md` is a short handoff document that replaces repeated re-reading of `research.md`, `implementation-plan.md`, full rule files, and source files. It is owned and updated by the orchestrator between phases.

Agents read the capsule first. They only open larger artifacts when the capsule does not contain enough information.

---

## Location

```
{plan_root}/{slug}/context-capsule.md
```

---

## Size

Keep it under ~1,500 words. If it grows larger, split rarely-needed details into referenced files and link them from the capsule.

---

## Format

```markdown
# Context Capsule: {slug}

## Objective
One or two sentences describing the change.

## Acceptance Criteria
- {summarized AC 1}
- {summarized AC 2}

## Relevant Files
| File | Action | Layer | Notes |
|---|---|---|---|
| `path/to/file.go` | MODIFY | domain | add validation |
| `path/to/new.go` | CREATE | usecase | new operation |

## Interfaces and Signatures
```go
func NewUseCase(repo Repository) UseCase
func (u UseCase) Execute(ctx context.Context, input Input) (Output, error)
```

## Architectural Decisions
- {decision 1 and rationale}
- {decision 2 and rationale}

## Patterns to Follow
- {existing pattern 1}
- {existing pattern 2}

## Contracts That Cannot Break
- {exported API}
- {database column}
- {message schema}

## Risks
- {risk 1}
- {risk 2}

## Lint and Test Commands
```bash
gofmt -l path/to/changed
go test ./path/to/package/... -count=1 -timeout=60s
golangci-lint run ./path/to/changed/...
```

## Current State
- Phase: {name}
- Last completed: {step}
- Next: {step}
- Blockers: {none or list}

## Handoff to Next Phase
{What the next agent must know and do}
```

---

## Update Rules

Update `context-capsule.md` whenever:

- a phase completes;
- the plan changes;
- new risks or decisions emerge;
- file scope changes.

Do NOT copy entire sections from `research.md` or `implementation-plan.md`. Summarize and link.

---

## Agent Reading Order

1. Read `context-capsule.md`.
2. If more detail is needed, read `implementation-plan.md` for the current phase.
3. If still unclear, read `research.md` for file:line references.
4. Read full rule files only when the capsule explicitly flags a rule conflict.
5. Read source files only for exact line context.

---

## Context Compression

When the session context reaches ~70%, or when research + planning + coding have all run, offer compression before continuing:

```
Context is at {N}%. Compress now to resume cleanly in a new chat?
Reply "yes" or /compress.
```

Skill: `skills/compressing-context/SKILL.md`.

---

## Avoid Context Duplication

- Do not paste the full research output into implementation prompts.
- Do not paste the full implementation plan into review prompts.
- Do not include full Style Reinforcement block in every dispatch unless conditions from `dispatching.md` are met.
- Do not repeat Graphify query results in multiple prompts; reference the capsule.

---

## Example: Lean handoff

```markdown
## Handoff to Next Phase
Production change is complete. Run deterministic gates and update progress.md. No LLM review needed unless a semantic issue is found.
```

## Example: Standard handoff to review

```markdown
## Handoff to Next Phase
Implementation and tests are complete. Completion Gate passed. Run the combined cross-vendor semantic review. Check acceptance criteria coverage, scope, architecture, regressions, and test quality.
```
