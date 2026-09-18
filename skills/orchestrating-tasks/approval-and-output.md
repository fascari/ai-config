# Orchestrating Tasks: Approvals & Output Contract

> Sub-file of `skills/orchestrating-tasks/SKILL.md`. Read SKILL.md first for Critical Rules and Pre-Dispatch Checklist.

This file covers user approval checkpoints for external API writes and the output contract for plan artifacts.

---

## Approval Checkpoints

Never bypass. Always wait for explicit user approval before any write operation.

| Skill / transition | Requires approval before |
|---|---|
| `committing-changes` | Any `git commit` or `git push` |
| `creating-pull-request` | Any `gh pr create` or equivalent |
| Any MCP write tool | Any API write (issues, pages, tickets) |
| First `implementing-feature` dispatch for a task's implementation-plan | Explicit, unambiguous approval of **the plan itself** — see below |

**Plan approval is its own checkpoint, separate from everything else on the
plan.** A user answering a clarifying sub-question embedded in the plan (which
team owns a CODEOWNERS entry, which port to provision) or authorizing one
narrow adjacent action (create the branch, rename a phase) is answering
exactly that question — it is not "the plan is approved." Do not infer
blanket approval from the accumulation of small yeses. Ask directly ("plano
aprovado?" / "approve the plan?") and wait for an unambiguous word before the
first `implementing-feature` dispatch. This has caused real rework: an
orchestrator run inferred approval from adjacent answers twice in one session
before the user caught it and had to say "eu nunca disse isso" — treat that as
the standing failure mode to design against, not a one-off.

Approval rules:

1. Present a full preview of all actions before executing
2. Wait for written approval ("yes", "approve", "confirm", "ok", "y")
3. "Go ahead" or "do it" before seeing the preview is NOT approval, present the preview first
4. Each action type requires separate approval
5. If scope changes during execution, stop, present the change, and wait for approval

---

## Output Contract

For every new task, create:

```
{plan_root}/{slug}/
├── brief.md          ← orchestrating-tasks creates (raw request context)
├── requirements.md   ← optional, from requirements extraction (testable ACs)
└── progress.md       ← orchestrating-tasks creates with ## Status: IN_PROGRESS
```

For Standard/Complex tasks the typical artifact set grows to:

```
{plan_root}/{slug}/
├── brief.md
├── requirements.md
├── research.md             ← researching-codebase creates
├── implementation-plan.md  ← planning-implementation creates
└── progress.md
```

**`requirements.md` being absent is a legitimate, common outcome, not a gap to
apologize for** — plenty of tasks never run a separate requirements-extraction
step. What it changes is how the Output Judge sources its ACs (see `gates.md`:
falls back to `implementation-plan.md`'s per-phase Verification sections) —
it does not mean the gate silently never runs. If a Complex task's
`implementation-plan.md` has no phase-level Verification/safety content either
(rare — `planning-implementation`'s own template asks for it per phase), that
combination is the actual gap worth flagging to the user, not the missing
`requirements.md` file by itself.

**In Claude Code, `progress.md` is written by the orchestrator (main
session), not by dispatched `implementing-feature`/`testing-implementation`
subagents**, even though those skills' own "Per Phase" steps describe the
dispatched agent updating it directly. A Claude Code `Agent` dispatch is a
fresh, stateless context per call — it does not reliably share the vault's
prior phrasing conventions or file-write history with the orchestrator. Require
the subagent's completion report to end with the structured block from
`claude-runtime.md` ("## Progress Update"); the orchestrator transcribes that
into `progress.md` itself, after independently re-verifying the reported gate
results.

`progress.md` format:

```markdown
## Status
IN_PROGRESS

## Harness Gates
Output Judge: NOT_RUN

## Phase 1: Domain Model (DONE)
- [x] Created domain entity
- [x] Tests passing

## Phase 2: Use Case (IN PROGRESS)
- [x] UseCase struct
- [ ] Unit tests
```
