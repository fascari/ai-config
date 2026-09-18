# Orchestrating Tasks: Dispatching

> Sub-file of `skills/orchestrating-tasks/SKILL.md`. Read SKILL.md first for Critical Rules and Pre-Dispatch Checklist.

This file covers model and logical-role selection, plus the style reinforcement
and codebase search rules for subagents. Concrete dispatch syntax lives in
`provider-dispatch.md`.

---

## Capability Tiers

| Tier | Characteristics | When to use |
|---|---|---|
| **Fast** | Low latency, lowest cost | Structured output: commit messages, PR bodies, text transformation |
| **Balanced** | Good reasoning at moderate cost | Standard implementation, planning, code generation, daily development |
| **Complex** | High reasoning, higher cost | Cross-cutting analysis, unfamiliar codebases, large refactors, multi-domain changes |
| **Expert Review** | Maximum reasoning, highest cost | Architecture validation, security analysis, critical business logic review, adversarial review |

> Tier names and model assignments follow `providers/opencode/docs/model-routing.md`.
> **Complex** replaces the old **Deep** tier name. **Expert Review** replaces the old **Deep (cross-vendor)** pattern.
> Core principle: use the cheapest model capable of safely completing the task.

### Provider model reference (adapt to your provider)

| Tier | OpenCode (Go) | Anthropic (Claude, generic) | Claude Code (`Agent` tool `model:` param) | OpenAI | Google (Gemini) |
|---|---|---|---|---|---|
| **Fast** | deepseek-v4-flash, mimo-v2.5 | claude-haiku-* | `model: "haiku"` | gpt-*-mini, o4-mini | gemini-flash-* |
| **Balanced** | deepseek-v4-pro (default) | claude-sonnet-* | omit `model:` (inherits session model, normally Sonnet) | gpt-*/codex (default) | gemini-pro-* |
| **Complex** | kimi-k2.7-code | claude-opus-* (high effort) | `model: "opus"`, or omit `model:` and set higher reasoning effort on the dispatch | gpt-*/o-series (high effort) | gemini-pro-* (high effort) |
| **Expert Review** | glm-5.2 | — (use cross-vendor) | `model: "opus"` at high effort — **same-vendor only, not a cross-vendor substitute**, see the Claude Code fallback below | — (use cross-vendor) | — (use cross-vendor) |

> The OpenCode tier names (Fast, Balanced, Complex, Expert Review) come from `providers/opencode/docs/model-routing.md`.
> **Complex** replaces the old **Deep** tier. **Expert Review** is the cross-vendor reviewer tier.
> Core principle from model-routing: use the cheapest model capable of safely completing the task. Escalate only when complexity, risk, or uncertainty demands it.
> OpenCode Go provides `opencode-go/<model-id>`. OpenCode Zen provides `opencode/<model-id>`. Models listed are the Go variants.
> Claude Code's `Agent` tool `model:` values are literal strings (`"sonnet"`, `"opus"`, `"haiku"`, `"fable"`), not model-family globs — confirm the current mapping against the session's own model info before relying on it, these names track whatever generation is live. Default to omitting `model:` unless you are confident a different tier is correct for the task; when unsure, inherit.

---

## Delegation Model Matrix

Select a logical role here. Render the actual call shape using
`provider-dispatch.md`. Never invoke a skill inline in a multi-skill workflow.

**Source of truth**: each skill's frontmatter in `skills/{name}/SKILL.md` defines the intended behavior. The matrix below mirrors that. On any divergence, the frontmatter wins.

| Skill | Logical role | Tier | Rationale |
|---|---|---|---|
| `researching-codebase` | `general-purpose` | Complex | Search-heavy reasoning; needs to correctly map impact across layered architectures |
| `planning-implementation` | `general-purpose` | Complex | Plan quality directly determines implementation quality; complex reasoning reduces critique-gate cycles |
| `implementing-feature` | `go-implementer` (Go) / `general` (non-Go) | Balanced | Stack is detected at dispatch time: Go gets the custom agent with conventions front-loaded; non-Go falls back to general with deterministic gates |
| `testing-implementation` | `go-tester` (Go) / `general` (non-Go) | Balanced | Same stack detection: Go gets the dedicated test agent; non-Go falls back to general |
| `reviewing-code` | `general-purpose` | Expert Review (**cross-vendor**) | Reviewer must use a different vendor than the implementer |
| `sanitizing-text` | `general-purpose` | Fast | Rule-based text transformation; no reasoning needed |
| `committing-changes` | `general-purpose` | Fast | Structured, rule-based task |
| `creating-pull-request` | `general-purpose` | Fast | Templated, structured task |

> **`critique-gate`** is not a named skill, it is an inline `task` dispatched by the orchestrator. **Cross-vendor rule applies.** Default: Expert Review tier (different vendor from planning-implementation). See `gates.md`.

> **Note on logical role**: values like `go-implementer` and `go-tester` are Go-specific logical roles. They MUST NOT be dispatched for non-Go stacks. Stack detection happens in `implementing-feature` and `testing-implementation`. Non-Go stacks fall back to `general`. For OpenCode, the agent name comes from the tier → agent mapping in `orchestrating-tasks-efficient/provider-dispatch.md`.

---

## Cross-Vendor Rule for Judges and Validators

**Any agent that judges, validates, critiques, reviews, or scores the output of another agent MUST use a model from a different vendor than the agent that produced the output.**

Rationale: same-vendor judges share blind spots; they accept patterns their sibling models produced. Cross-vendor judging catches correlated errors at low extra cost.

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
| implementing-feature (DeepSeek V4 Pro) | GLM-5.2 | Kimi or GLM for review; DeepSeek + GLM is cross-vendor |
| implementing-feature (Kimi K2.7 Code) | GLM-5.2 | Complex impl reviewed by expert reviewer |
| testing-implementation (DeepSeek V4 Pro) | Kimi K2.7 Code or GLM-5.2 | Same cross-vendor logic |
| planning-implementation (Kimi K2.7 Code) | GLM-5.2 | Complex plan deserves expert review |

**If you change a producer's vendor, every downstream judge for that skill MUST be re-checked.** Verify the pairing whenever the model matrix changes.

This rule applies ONLY to judges/validators/reviewers. Producer tasks (researching, planning, implementing, testing) are unconstrained by vendor.

### Claude Code fallback — no cross-vendor is available

Claude Code's `Agent` tool only dispatches Claude-family models. There is no
`vendor` parameter and no other provider reachable through it. **This rule
cannot be satisfied literally in Claude Code.** Do not pretend otherwise by
picking a different Claude model and calling it "cross-vendor" — that is a
same-vendor substitution, not the guarantee the rule describes.

Full detail and rationale in `claude-runtime.md`. Summary:

1. Producer at the default/Balanced tier; judge at Opus/high-effort, with an
   explicit adversarial framing ("try to refute this, default to `refuted:
   true` if uncertain") — the framing compensates partially for the missing
   model diversity, the tier gap does not by itself.
2. For high-stakes judging, run 2-3 independent same-vendor judges and require
   a majority refutation to kill a finding, rather than trusting one.
3. **Every gate output produced this way must say so explicitly** —
   `Cross-vendor: NOT AVAILABLE (Claude Code, same-vendor judge only)` — so
   nobody downstream mistakes it for the full-strength guarantee.

Before falling back, check whether the current session actually has
multi-vendor access some other way (a connected MCP tool exposing another
provider's API, for instance) — if so, that satisfies the rule literally and
this fallback does not apply.

---

## Complexity Tier Model Overrides

For Complex tasks, override certain skills from Balanced to Complex or Expert Review. This aligns with model-routing.md's High Assurance Mode.

| Skill | Default (Simple/Standard) | Override for Complex | Why |
|---|---|---|---|
| `critique-gate` | Expert Review (cross-vendor) | GLM-5.2 | Adversarial plan review demands best reasoning |
| `reviewing-code` | Expert Review (cross-vendor) | GLM-5.2 | Semantic regression catching on high-impact work |
| `researching-codebase` | Complex | Kimi K2.7 Code | Unfamiliar or multi-domain codebase exploration |

**Rationale**: Balanced models (DeepSeek V4 Pro) excel at structured validation — file paths, AC mapping, syntax. Complex models (Kimi K2.7 Code) are required for unfamiliar codebases, large refactors, and catching semantic regressions or design-level simplifications. Expert Review models (GLM-5.2) catch cross-domain interactions and design-level issues that Complex misses. The cost premium is justified when the change spans multiple domains or carries high risk, and it pays back when it prevents a re-plan or post-merge incident.

---

## Dispatch contract

Build the prompt payload here, then render the actual provider-specific call
using `provider-dispatch.md`.

Required prompt payload:

```unknown
Read and follow: skills/{skill}/SKILL.md

## Context
slug: {slug}
plan dir: {plan_root}/{slug}/
graphify-out/: available only if graphify-out/GRAPH_REPORT.md exists
$AI_MEMORY_HOME: available only if set
current phase: {phase name and number, if applicable}

## Task
{Specific instructions: which phase, what to do, constraints or overrides}
```

Wait for each background task or worker to complete before dispatching the next
dependent skill. Never dispatch two dependent skills simultaneously.

---

## Style Reinforcement Block (Go projects only)

When dispatching `implementing-feature`, `testing-implementation`, or `reviewing-code` and **the stack is Go** (determined by `implementing-feature`'s stack detection), append the following block verbatim to the prompt **after the Task section**. Auto-injected instruction files are not enough in long contexts; regression to over-documenting and legacy idioms is common.

For non-Go stacks, skip this block. The style gate commands in `implementing-feature` and `testing-implementation` serve as the deterministic quality check instead.

```
## Style Reinforcement (Go, non-negotiable)

Re-read these BEFORE the first edit:
- the active provider-native project instruction files for the current working directory
- `skills/writing-modern-go/SKILL.md` when Go edits need explicit modern idioms
- any repo-local rule docs explicitly routed from those project instruction files

Hard rules:
- File names: NO underscores except the _test.go suffix
- Tests: NO comments by default, no // TestFoo verifies, // Arrange/Act/Assert
- Production code: comments explain WHY only, never WHAT; godoc must add insight beyond the signature
- Modern Go: wg.Go (not wg.Add(1)+go func), any (not interface{}), slices.SortFunc (not sort.Slice), for i := range n, t.Context() in tests, time.Since(start)
- Every newly exported symbol must have a caller or a godoc explaining why it stays exported
- Run the Style Compliance Gate (4 greps) before declaring any phase done, see implementing-feature/SKILL.md
```

**Repo-specific overrides go in a separate, clearly-labeled addendum appended
AFTER this block — never rewritten into it.** A real repo will sometimes
contradict a hard rule above for a documented, load-bearing reason (e.g. a
monorepo whose CI enforces `revive`'s `package-comments`/`exported` checks,
which requires the opposite of "godoc must add insight beyond the signature —
delete redundant ones"). When that happens:

```
## Repo-Specific Override

{Rule name}: {what the repo actually requires, and the concrete reason —
cite the CI check, lint config, or CODEOWNERS entry, not a guess}
```

This keeps the base block auditable and unchanged across dispatches while
still telling the worker the truth about the one repo it's in. Do not silently
edit the verbatim block itself to "fix" a conflict — that produces silent
drift between what this file says and what actually gets sent.

---

## Codebase Search in Subagent Prompts

When dispatching ANY subagent that needs to explore the codebase (researching-codebase, critique-gate, reviewing-code, planning-implementation when verifying claims), ALWAYS include this verbatim block in the dispatch prompt:

```
## Codebase Search Rules (mandatory)

Use Graphify instead of grep/find when available:
- `graphify query "<concept>"`: BFS traversal, ~2k tokens of relevant context
- `graphify path "<A>" "<B>"`: shortest path between two concepts
- `graphify explain "<NodeName>"`: node details + neighbors

If Graphify is not available, use targeted file reads. Read source files only when you need exact line context for a finding.
```

Without this explicit instruction in the prompt, subagents fall back to grep even when Graphify is available.

## Provider Runtime Override

These skills support multiple runtimes. Select behavior by capability, not by provider name alone.

| Capability | Mode | Dispatch rule |
|---|---|---|
| Native `task(skill: "...")` or equivalent single-call skill dispatch exists | Native harness (Copilot) | Use the native harness shape from `provider-dispatch.md`. The skill wrapper enforces quality gates. |
| `Skill` tool (loads instructions) + `Agent` tool (dispatches a worker with a distinct `subagent_type`) both exist | Claude Code native | Two-call chain: `Skill(skill: "...")` then `Agent(subagent_type: "...")`. See `claude-runtime.md`. This is NOT the same as "no native dispatch" — it has real quality-gate wrapping, it just takes two tool calls instead of one. |
| Only generic worker agents exist, such as Codex `spawn_agent` | Codex managed | Workers may produce bounded patches, but the orchestrator must run `codex-runtime.md` manual acceptance before accepting output. |
| No agent dispatch exists | Local manual | Stop and ask the user to approve degraded local execution. |

`spawn_agent`, `general-purpose`, or any generic worker prompt is not equivalent to native `task(skill: "...")`. In Codex managed mode, worker success is only `WORKER PASS`; the orchestrator must load the phase rule bundle from `codex-runtime.md`, audit the diff, run gates, and report `ACCEPTED` before the phase is complete. In Claude Code native mode, a `subagent_type` dispatch made without a preceding `Skill` call is the same failure — a real agent type does not by itself carry the quality-gate instructions.

When using Codex managed mode, every worker prompt must include:

```unknown
Runtime: Codex managed.
This worker output is untrusted until the orchestrator runs the manual acceptance checklist in codex-runtime.md.
Return WORKER PASS/FAIL, not final ACCEPTED.
```
