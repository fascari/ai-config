# Orchestrating Tasks — Dispatching

> Sub-file of `skills/orchestrating-tasks/SKILL.md`. Read SKILL.md first for Critical Rules and Pre-Dispatch Checklist.

This file covers model/agent selection, the dispatch template, style reinforcement, and codebase search rules for subagents.

---

## Capability Tiers

Use these tier names when selecting models. The exact model depends on your AI provider — see the reference table below.

| Tier | Characteristics | When to use |
|---|---|---|
| **Fast** | Low latency, lower cost, rule-based tasks | Structured output: commit messages, PR bodies, text transformation |
| **Balanced** | Good reasoning at moderate cost | Standard implementation, planning, code generation |
| **Deep** | High reasoning, higher cost | Cross-cutting analysis, complex planning, adversarial review |

### Provider model reference (adapt to your provider)

| Tier | Anthropic (Claude) | OpenAI (Codex/GPT) | Google (Gemini) |
|---|---|---|---|
| **Fast** | claude-haiku-* | gpt-*-mini, o4-mini | gemini-flash-* |
| **Balanced** | claude-sonnet-* | gpt-*/codex (default) | gemini-pro-* |
| **Deep** | claude-opus-* (effort: high) | gpt-*/o-series (high effort) | gemini-pro-* (high effort) |

> These are examples. Use whichever current model version your provider offers at each tier.

---

## Delegation Model Matrix

Always use the `task` tool when dispatching a skill. Never invoke a skill inline in a multi-skill workflow.

**Source of truth**: each skill's frontmatter in `skills/{name}/SKILL.md` defines the intended behavior. The matrix below mirrors that. On any divergence, the frontmatter wins.

> **Note on agent_type**: values like `go-implementer`, `go-tester`, `validate-loop` refer to custom agents defined in the project's `agents/` directory (Copilot CLI). Adapt to your provider's equivalent mechanism. If no custom agents are available, use `general-purpose` and paste the agent's instructions into the prompt.

| Skill | Agent type | Tier | Rationale |
|---|---|---|---|
| `validate-loop` | `validate-loop` | Balanced | Loop agent: runs code agent + harness-gate cycles in isolated context. Caller receives only LOOP PASS/FAIL |
| `researching-codebase` | `general-purpose` | Deep | Search-heavy reasoning; needs to correctly map impact across layered architectures |
| `planning-implementation` | `general-purpose` | Deep | Plan quality directly determines implementation quality; deep reasoning reduces critique-gate cycles |
| `implementing-feature` | `go-implementer` | Balanced | Custom agent front-loads Go conventions in the system prompt |
| `testing-implementation` | `go-tester` | Balanced | Dedicated test agent — explicitly forbidden from touching production files |
| `reviewing-code` | `general-purpose` | Deep (**cross-vendor**) | Reviewer must use a different vendor than the implementer — see Cross-Vendor Rule |
| `test-design-judge` | `general-purpose` | Balanced (**cross-vendor**) | Internal dispatch by `testing-implementation` only. Never dispatched by orchestrator |
| `sanitizing-text` | `general-purpose` | Fast | Rule-based text transformation; no reasoning needed |
| `committing-changes` | `general-purpose` | Fast | Structured, rule-based task |
| `creating-pull-request` | `general-purpose` | Fast | Templated, structured task |

> **`critique-gate`** is not a named skill — it is an inline `task` dispatched by the orchestrator. **Cross-vendor rule applies.** Default: Deep tier (different vendor from planning-implementation). See `gates.md`.

---

## Cross-Vendor Rule for Judges and Validators

**Any agent that judges, validates, critiques, reviews, or scores the output of another agent MUST use a model from a different vendor than the agent that produced the output.**

Rationale: same-vendor judges share blind spots — they accept patterns their sibling models produced. Cross-vendor judging catches correlated errors at low extra cost.

### Vendor groups

| Vendor | Examples |
|---|---|
| **Anthropic** | claude-haiku-*, claude-sonnet-*, claude-opus-* |
| **OpenAI** | gpt-*-mini, gpt-*, o-series, codex-* |
| **Google** | gemini-flash-*, gemini-pro-* |

### Producer → judge pairing

| Producer (skill) | Suggested judge vendor | Example pairing |
|---|---|---|
| planning-implementation (Anthropic) | OpenAI or Google | critique-gate |
| implementing-feature (Anthropic) | OpenAI or Google | reviewing-code, harness LLM-judge |
| testing-implementation (Anthropic) | OpenAI or Google | test-design-judge |

**If you change a producer's vendor, every downstream judge for that skill MUST be re-checked.** Verify the pairing whenever the model matrix changes.

This rule applies ONLY to judges/validators/reviewers. Producer tasks (researching, planning, implementing, testing) are unconstrained by vendor.

---

## Complexity Tier Model Overrides

For Complex tasks, override certain skills from Balanced to Deep. This is the empirically-derived "Balanced first, Deep on gates" pattern.

| Skill | Default (Simple/Standard) | Override for Complex | Why |
|---|---|---|---|
| `critique-gate` | Deep (cross-vendor) | Deep + high effort | Adversarial plan review |
| `reviewing-code` | Deep (cross-vendor) | Deep + high effort | Semantic regression catching |
| `researching-codebase` | Deep | — | Already Deep by default |

**Rationale**: Balanced models excel at structured validation (file paths, AC mapping, syntax). Deep models are required to catch semantic regressions, cross-test interactions, and design-level simplifications. The cost premium is paid back when it prevents a re-plan or post-merge incident on Complex work.

---

## Task Dispatch Template

```
task(
  name: "{skill-name}",
  description: "{3-5 word description}",
  agent_type: "{agent_type from matrix}",
  model: "{model at appropriate tier for your provider}",
  mode: "background",
  prompt: """
    Read and follow: skills/{skill}/SKILL.md

    ## Context
    slug: {slug}
    plan dir: {plan_root}/{slug}/
    graphify-out/: available only if graphify-out/GRAPH_REPORT.md exists
    $COPILOT_VAULT / $AI_MEMORY_HOME: available only if set
    current phase: {phase name and number, if applicable}

    ## Task
    {Specific instructions: which phase, what to do, constraints or overrides}
  """
)
```

Wait for each background task to complete before dispatching the next dependent skill. Never dispatch two dependent skills simultaneously.

---

## Style Reinforcement Block (Go projects)

When dispatching `implementing-feature`, `testing-implementation`, or `reviewing-code` and the diff touches `.go` files, append the following block verbatim to the prompt **after the Task section**. Auto-injected instruction files are not enough in long contexts — regression to over-documenting and legacy idioms is common.

```
## Style Reinforcement (Go — non-negotiable)

Re-read these BEFORE the first edit:
- .github/instructions/go-style.instructions.md (file naming, comment discipline)
- .github/instructions/modern-go.instructions.md + skills/writing-modern-go/SKILL.md (modern Go idioms)
- .github/instructions/testing.instructions.md (no-comment default, table-driven)
- Any other .github/instructions/*.instructions.md whose applyTo matches files you will edit

Hard rules:
- File names: NO underscores except the _test.go suffix
- Tests: NO comments by default — no // TestFoo verifies, // Arrange/Act/Assert
- Production code: comments explain WHY only, never WHAT; godoc must add insight beyond the signature
- Modern Go: wg.Go (not wg.Add(1)+go func), any (not interface{}), slices.SortFunc (not sort.Slice), for i := range n, t.Context() in tests, time.Since(start)
- Every newly exported symbol must have a caller or a godoc explaining why it stays exported
- Run the Style Compliance Gate (4 greps) before declaring any phase done — see implementing-feature/SKILL.md
```

---

## Codebase Search in Subagent Prompts

When dispatching ANY subagent that needs to explore the codebase (researching-codebase, critique-gate, reviewing-code, planning-implementation when verifying claims), ALWAYS include this verbatim block in the dispatch prompt:

```
## Codebase Search Rules (mandatory)

Use Graphify instead of grep/find when available:
- `graphify query "<concept>"` — BFS traversal, ~2k tokens of relevant context
- `graphify path "<A>" "<B>"` — shortest path between two concepts
- `graphify explain "<NodeName>"` — node details + neighbors

If Graphify is not available, use targeted file reads. Read source files only when you need exact line context for a finding.
```

Without this explicit instruction in the prompt, subagents fall back to grep even when Graphify is available.
