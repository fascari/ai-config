# Orchestrating Tasks Efficient: Dispatching

> Sub-file of `skills/orchestrating-tasks-efficient/SKILL.md`. Read SKILL.md first for Critical Rules and Pre-Dispatch Checklist.

This file covers model tier selection, dispatch contract, Style Reinforcement block, and Codebase Search Rules. Concrete provider syntax lives in `provider-dispatch.md`.

---

## Capability Tiers

| Tier | Characteristics | When to use |
|---|---|---|
| **Fast** | Low latency, lowest cost | Sanitization, formatting, summaries, progress updates, text transformation |
| **Balanced** | Good reasoning at moderate cost | Default for research, planning, implementation, tests, and low-risk review |
| **Complex** | High reasoning, higher cost | Unfamiliar codebases, large refactors, multi-domain changes, unclear root cause, complex concurrency, security, finance, migrations, escalation |
| **Expert Review** | Maximum reasoning, highest cost | Architecture validation, cross-domain critique, critical semantic review |

### Provider model reference

| Tier | OpenCode (Go) | Anthropic (Claude) | OpenAI | Google (Gemini) |
|---|---|---|---|---|
| **Fast** | deepseek-v4-flash, mimo-v2.5 | claude-haiku-* | gpt-*-mini, o4-mini | gemini-flash-* |
| **Balanced** | deepseek-v4-pro (default) | claude-sonnet-* | gpt-*/codex (default) | gemini-pro-* |
| **Complex** | kimi-k2.7-code | claude-opus-* | gpt-*/o-series | gemini-pro-* |
| **Expert Review** | glm-5.2 | — (use cross-vendor) | — (use cross-vendor) | — (use cross-vendor) |

> Tier names and model assignments follow `providers/opencode/docs/model-routing.md`.
> OpenCode Go provides `opencode-go/<model-id>`. OpenCode Zen provides `opencode/<model-id>`. Models listed are the Go variants.

---

## Core Model Rule

**Balanced first, Complex on risk or escalation.**

Except for explicit High Assurance, unknown-root-cause, or escalation overrides, do not use Complex by default for research, planning, implementation, or testing. Complex is reserved for:

- High Assurance critique;
- High-risk semantic review;
- Security, finance, migrations, and critical concurrency;
- Escalation after a Balanced model misses a semantic issue or fails a gate.

---

## Delegation Model Matrix

Select a logical role here. Render the actual call using `provider-dispatch.md`. Never invoke a skill inline in a multi-skill workflow.

For OpenCode, select the agent name from the tier → agent mapping in `provider-dispatch.md`. The model is configured on the agent, not passed per call.

| Skill / Gate | Logical role | Default tier | Override |
|---|---|---|---|
| `researching-codebase` | `general-purpose` | Balanced | Complex for High Assurance or unclear root cause |
| `planning-implementation` | `general-purpose` | Balanced | Complex for High Assurance or cross-domain architecture |
| Consolidated discovery + planning (Standard) | `general-purpose` | Balanced | Complex when system design is required; see template below |
| `implementing-feature` | `go-implementer` (Go) / `general-purpose` (non-Go) | Balanced | Complex for finance/security/critical concurrency |
| `testing-implementation` | `go-tester` (Go) / `general-purpose` (non-Go) | Balanced | Complex for finance/security/critical concurrency tests |
| `reviewing-code` (semantic review) | `general-purpose` | Balanced | Expert Review for High Risk/Critical or cross-domain |
| Standard combined review (Output Judge + semantic review) | `general-purpose` | Balanced | Expert Review when risk is High or Balanced is insufficient |
| HA critique gate | `general-purpose` judge | Expert Review | Cross-vendor mandatory |
| HA Output Judge | `general-purpose` judge | Expert Review | Cross-vendor mandatory |
| HA semantic review | `general-purpose` | Expert Review | Cross-vendor mandatory |
| `sanitizing-text` | `general-purpose` | Fast | - |
| `committing-changes` | `general-purpose` | Fast | - |
| `creating-pull-request` | `general-purpose` | Fast | - |

Implementation always uses Balanced or Complex. Fast is never allowed for writing production code. Fast is restricted to mechanical transformations, formatting, status updates, and final sanitization.

---

## Cross-Vendor Rule for Judges and Validators

Any agent that judges, validates, critiques, reviews, or scores the output of another agent MUST use a model from a different vendor than the agent that produced the output.

### Vendor groups

| Vendor | Models | Provider prefix |
|---|---|---|
| **DeepSeek** | deepseek-v4-pro, deepseek-v4-flash | opencode-go/deepseek-* |
| **Moonshot** | kimi-k2.7-code | opencode-go/kimi-* |
| **Zhipu** | glm-5.2 | opencode-go/glm-* |
| **MiniMax** | mimo-v2.5 | opencode-go/mimo-* |
| **Anthropic** | claude-sonnet-*, claude-haiku-*, claude-opus-* | anthropic/* |
| **OpenAI** | gpt-*, o-series, codex-* | openai/* |
| **Google** | gemini-flash-*, gemini-pro-* | google/* |

### Producer → judge pairing (OpenCode primary)

| Producer | Judge (different vendor) | Rationale |
|---|---|---|
| implementing-feature (DeepSeek V4 Pro) | GLM-5.2 | DeepSeek + GLM is cross-vendor |
| implementing-feature (Kimi K2.7 Code) | GLM-5.2 | Complex impl reviewed by expert reviewer |
| testing-implementation (DeepSeek V4 Pro) | Kimi K2.7 Code or GLM-5.2 | Same cross-vendor logic |
| planning-implementation (Kimi K2.7 Code) | GLM-5.2 | Complex plan deserves expert review |

If the producer's vendor changes, re-check every downstream judge.

---

## Dispatch Contract

Build the prompt payload here, then render the actual provider-specific call using `provider-dispatch.md`.

Required prompt payload:

```unknown
Read and follow: skills/{skill}/SKILL.md

## Context
slug: {slug}
plan dir: {plan_root}/{slug}/
context capsule: {plan_root}/{slug}/context-capsule.md (read this first)
graphify-out/: available only if graphify-out/GRAPH_REPORT.md exists
$AI_MEMORY_HOME: available only if set
current phase: {phase name and number, if applicable}
mode: {Lean | Standard | High Assurance}

## Task
{Specific instructions: which phase, what to do, constraints or overrides}
```

Wait for each background task or worker to complete before dispatching the next dependent skill. Never dispatch two dependent skills simultaneously.

---

## Consolidated Discovery-and-Planning Template (Standard mode)

Use this prompt when dispatching a single agent to perform research, architecture assessment, and planning sequentially. The agent must execute three sequential stages, not follow two skills simultaneously.

### Prompt template

```unknown
## Context
slug: {slug}
plan dir: {plan_root}/{slug}/
mode: Standard
graphify-out/: available only if graphify-out/GRAPH_REPORT.md exists

## Stages

Execute these stages in order. Complete each stage fully before starting the next.

### Stage 1: Research

Follow `skills/researching-codebase/SKILL.md` rules:
- Document only what exists in the codebase.
- Do not suggest improvements.
- Do not critique existing patterns.
- Use Graphify first for code discovery.
- Use file:line format for all references.
- Produce `{plan_root}/{slug}/research.md`.

Stage 1 constraints that EXPIRE after this stage: "never suggest improvements", "never critique existing patterns", read-only posture.

### Stage 2: Architecture Assessment

After Stage 1 is complete and `research.md` is written:
- Evaluate whether a detailed system design analysis is needed.
- Produce `{plan_root}/{slug}/system-design-analysis.md` when any of these are true:
  - data consistency spans multiple stores;
  - the change introduces concurrency or retry semantics;
  - the change touches message schemas or event contracts;
  - the change affects cross-service boundaries;
  - an idempotency, atomicity, or saga concern is present.
- When system design is NOT needed, record the justification in `{plan_root}/{slug}/context-capsule.md`.
- Follow `skills/analyzing-system-design/SKILL.md` when producing the analysis.

### Stage 3: Planning

After Stage 1 and Stage 2 are complete:
- Use the facts documented in `research.md`.
- Apply `skills/planning-implementation/SKILL.md` rules:
  - Perform compatibility analysis before designing phases.
  - Each phase must be independently testable.
  - Each task must reference exact file paths.
- Produce `{plan_root}/{slug}/implementation-plan.md`.
- Produce or update `{plan_root}/{slug}/context-capsule.md`.

### Outputs

Write these files in order:
1. `{plan_root}/{slug}/research.md`
2. `{plan_root}/{slug}/system-design-analysis.md` (only when needed)
3. `{plan_root}/{slug}/implementation-plan.md`
4. `{plan_root}/{slug}/context-capsule.md`

### Completion criteria
- `research.md` has file:line references for all affected code paths.
- `implementation-plan.md` has traceable phases with success criteria.
- `context-capsule.md` is under ~1,500 words and ready for the implementation agent.
```

---

## Style Reinforcement Block (Go projects)

When dispatching `implementing-feature`, `testing-implementation`, or review tasks that touch `.go` files, append this block after the Task section when:

- the runtime does not auto-load project instructions;
- the agent previously violated rules;
- the session is long;
- the mode is High Assurance;
- the diff touches historically problematic patterns.

For Lean and routine Standard dispatches, use the short reference instead of the full block:

```
Read and enforce skills/writing-modern-go/SKILL.md and matching project instructions.
```

Full block (use sparingly):

```
## Style Reinforcement (Go, non-negotiable)

Re-read these BEFORE the first edit:
- the active provider-native project instruction files for the current working directory
- skills/writing-modern-go/SKILL.md when Go edits need explicit modern idioms
- any repo-local rule docs explicitly routed from those project instruction files

Hard rules:
- File names: NO underscores except the _test.go suffix
- Tests: NO comments by default, no // TestFoo verifies, // Arrange/Act/Assert
- Production code: comments explain WHY only, never WHAT; godoc must add insight beyond the signature
- Modern Go: wg.Go (not wg.Add(1)+go func), any (not interface{}), slices.SortFunc (not sort.Slice), for i := range n, t.Context() in tests, time.Since(start)
- Every newly exported symbol must have a caller or a godoc explaining why it stays exported
- Run the Style Compliance Gate (4 greps) before declaring any phase done, see `skills/implementing-feature/SKILL.md`
```

---

## Codebase Search in Subagent Prompts

When dispatching ANY subagent that needs to explore the codebase, include this block once in the first dispatch that needs it. Subsequent agents receive the capsule instead.

```
## Codebase Search Rules (mandatory)

Use Graphify instead of grep/find when available:
- graphify query "<concept>": BFS traversal, ~2k tokens of relevant context
- graphify path "<A>" "<B>": shortest path between two concepts
- graphify explain "<NodeName>": node details + neighbors

If Graphify is not available, use targeted file reads. Read source files only when you need exact line context for a finding.
```

---

## Provider Runtime Override

| Capability | Mode | Dispatch rule |
|---|---|---|
| Native `task(skill: "...")` or equivalent skill dispatch exists | Native harness | Use the native harness shape from `provider-dispatch.md`. The skill wrapper enforces quality gates. |
| Only generic worker agents exist, such as Codex `spawn_agent` | Codex managed | Workers may produce bounded patches, but the orchestrator must run `skills/orchestrating-tasks/codex-runtime.md` manual acceptance before accepting output. |
| No agent dispatch exists | Local manual | Stop and ask the user to approve degraded local execution. |

`spawn_agent`, `general-purpose`, or any generic worker prompt is not equivalent to native `task(skill: "...")`. In Codex managed mode, worker success is only `WORKER PASS`; the orchestrator must load the phase rule bundle from `skills/orchestrating-tasks/codex-runtime.md`, audit the diff, run gates, and report `ACCEPTED` before the phase is complete.

When using Codex managed mode, every worker prompt must include:

```unknown
Runtime: Codex managed.
This worker output is untrusted until the orchestrator runs the manual acceptance checklist in `skills/orchestrating-tasks/codex-runtime.md`.
Return WORKER PASS/FAIL, not final ACCEPTED.
```
