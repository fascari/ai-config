# Plan state

Use one flat file per change: `.plans/<slug>.md`.

## Setup

Always use the vault for plan storage. If `$COPILOT_VAULT` is unset, stop and ask the user to
configure it before starting the workflow.

Run this setup from the target project being changed. The repository root must not be the
repository that only distributes this skill.

```bash
if [ -z "${COPILOT_VAULT:-}" ]; then
  echo "COPILOT_VAULT must be configured for orchestrating-single-loop." >&2
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
project="${repo_root##*/}"
plan_root="$COPILOT_VAULT/$project/plans"
mkdir -p "$plan_root"
if [ -e "$repo_root/.plans" ] && [ ! -L "$repo_root/.plans" ]; then
  echo "$repo_root/.plans exists and is not a symlink." >&2
  exit 1
fi
ln -sfn "$plan_root" "$repo_root/.plans"
grep -qxF ".plans" "$repo_root/.git/info/exclude" ||
  printf "\n.plans\n" >> "$repo_root/.git/info/exclude"
```

The workflow must not continue with an in-conversation plan. A real `.plans` directory is not
accepted because it would bypass the shared vault.

## Lifecycle

`PROPOSED` -> `IN_PROGRESS` -> `REVIEW` -> `DONE`

- `PROPOSED`: research and plan complete; no code edits allowed.
- `IN_PROGRESS`: human approved the plan; implementation may begin.
- `REVIEW`: implementation and deterministic gates are complete.
- `DONE`: diff review is complete and findings are resolved.

Resume a matching `PROPOSED`, `IN_PROGRESS`, or `REVIEW` file rather than creating a duplicate. Ask
when multiple active plans could match the request.

## Template

```markdown
---
title: <slug>
status: PROPOSED
type: plan
---

## Problem
<current behavior and requested outcome>

## Decisions
<resolved behavior and alternatives rejected>

## Phases

| Phase | Objective | Required artifacts in this plan | Gate |
|---|---|---|---|
| Discover | Select or resume the matching plan and inspect repository context. | Problem, scope, and constraints | Scope and active plan are identified. |
| Research | Load applicable instructions and rules, then read code, scripts, and tests; run the baseline. | Loaded instructions, research findings, and baseline evidence | Current behavior and constraints are documented. |
| Plan | Define the bounded vertical slice and implementation sequence. | Decisions, acceptance criteria, and phase steps | User approves the plan. |
| Execute | Implement each behavior with RED-GREEN-REFACTOR. | Changed files and execution notes | Focused tests pass after each behavior. |
| Gate | Run tests, typecheck, lint, and build commands required by the repository. | Gate commands and results | All required deterministic gates pass. |
| Review | Compare the diff with the plan and resolve findings. | Review findings and final result | Review is complete and status becomes `DONE`. |

## Acceptance criteria
- <observable outcome>

## Instructions
- Target project instructions: <paths loaded>
- Shared rules loaded: <paths loaded>
- Expected but unavailable rules: <paths or `none`>

## Scope
- Files: <expected files>
- Tests: <focused cases and boundaries>
- Out of scope: <explicit exclusions>

## Research
<relevant rules, codebase findings, and baseline evidence>

## Execution notes
<changed files, RED-GREEN-REFACTOR checkpoints, and decisions made during implementation>

## Gate results
<commands run and their results>

## Review
<diff findings and their resolution>

## Risks
<contract, financial, privacy, migration, concurrency, or operational risks; omit if none>

## Result
<fill when DONE: delivered behavior and remaining risks>
```
