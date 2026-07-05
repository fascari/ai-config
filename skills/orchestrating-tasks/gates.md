# Orchestrating Tasks — Gates

> Sub-file of `skills/orchestrating-tasks/SKILL.md`. Read SKILL.md first for Critical Rules and Pre-Dispatch Checklist.

This file covers the two quality gates the orchestrator runs at specific points in the workflow: Critique Gate and Output Judge Gate.

---

## Critique Gate

After `planning-implementation` completes and before `implementing-feature` starts:

- Simple tasks: skip.
- Standard tasks: offer the gate to the user; proceed if they skip.
- Complex tasks: run the gate (mandatory).

Dispatch a **general-purpose judge role** using the provider-specific shape from `provider-dispatch.md`. **Cross-vendor rule applies** - planning-implementation runs at Balanced/Deep (typically Anthropic); critique-gate MUST use a different vendor (OpenAI or Google). See `dispatching.md`.

Include the Codebase Search Rules block (from `dispatching.md`) in the prompt — critique-gates need to verify claims against the code.

Prompt:

```
Read and follow the project instructions. Apply adversarial review only.

## Context
slug: {slug}
plan dir: {plan_root}/{slug}/

## Review scope
1. Do all file paths in implementation-plan.md exist when marked MODIFY?
2. Do phases respect the project's architectural layering order?
3. Are breaking changes covered by a ## Compatibility Decision section?
4. Does every phase trace to at least one AC from requirements.md?
5. Is every AC covered by at least one phase?

Do not comment on style or naming. Output APPROVED or BLOCKED with specific issues.
```

If BLOCKED, present the issues to the user and send the plan back to `planning-implementation`. Do not dispatch implementation until the critique passes or the user explicitly skips it for a Standard task.

---

## Output Judge Gate

After both `implementing-feature` and `testing-implementation` complete, run an adversarial LLM judge using a **different vendor** from the implementing agent. See `dispatching.md` Cross-Vendor Rule.

**Skip rules:**

| Task level | Code changes? | Output Judge |
|---|---|---|
| Simple | docs-only | skip |
| Simple | code changes | skip |
| Standard | any | **run** |
| Complex | any | **run** |

**Only runs when `requirements.md` exists.** If absent, skip and proceed to `reviewing-code`.

Dispatch a **general-purpose judge role**, Deep tier, **cross-vendor**, using the provider-specific shape from `provider-dispatch.md`:

```
You are an adversarial Output Judge. Do NOT act as a developer or helper.
Your sole job: verify that every AC in requirements.md has explicit evidence in the implementation.

## Context
slug: {slug}
plan dir: {plan_root}/{slug}/
retry count: {N} (0-indexed; max 2 before escalation)

## Required steps
1. Read {plan_root}/{slug}/requirements.md — extract all acceptance criteria (ACs)
2. Run: git --no-pager diff HEAD~1 --stat
3. Run: git --no-pager diff HEAD~1 (read actual changes)
4. For each AC, find EXPLICIT evidence in the diff: specific file path, function name, or test
5. Run: git --no-pager diff --name-only HEAD~1
   Flag as violation any modification to: requirements.md, brief.md
   Do NOT flag test file modifications as violations — they are expected implementation evidence
6. Check: are modified files within scope described in implementation-plan.md?
   Flag unexpected files that are not test files and not in the plan

## Output format — must be exactly one of:

PASS
AC Coverage: N/N
Changed files: (list)

OR:

FAIL
Missing AC evidence:
- AC #N: "{ac text}" — no implementation or test evidence found
Violations:
- {file} modified unexpectedly (protected or out-of-scope)

Be conservative: prefer FAIL over ambiguous PASS.
Evidence must be explicit from the diff, not inferred from comments or variable names.
```

**On PASS:**
- Update `## Harness Gates` in `progress.md`: `Output Judge: PASS`
- Transition `## Status` to `REVIEW`
- Proceed to `reviewing-code`

**On FAIL:**
- Present the specific gaps to the user
- Send gaps as targeted fix instructions to a new `implementing-feature` dispatch
- Re-run Output Judge after fix (counts as one repair cycle; max 2 before escalation)
  - Ask: retry | revise plan/requirements | skip judge (explicit user consent required) | abort
