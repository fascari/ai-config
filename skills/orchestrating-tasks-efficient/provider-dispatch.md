# Orchestrating Tasks Efficient: Provider Dispatch

> Sub-file of `skills/orchestrating-tasks-efficient/SKILL.md`. Read SKILL.md first for Critical Rules and Pre-Dispatch Checklist.

This file maps logical roles to the concrete dispatch syntax accepted by each provider/runtime. Select the role and tier in `dispatching.md` first, then choose the transport here.

---

## Core rule

Choose the role in `dispatching.md` first. Only then choose the transport:

- **Copilot native**: `task(skill: ..., agent_type: ..., model: ..., mode: ..., prompt: ...)`
- **OpenCode native**: `skill(name: "...")` or `task(skill: "...", agent_type: "...", prompt: ...)`
- **Codex managed**: generic worker call only; use the smallest accepted field set
- **Claude managed**: generic worker call only unless the runtime explicitly exposes native skill dispatch

Do not assume that `agent_type`, `skill`, `mode`, `fork`, or full repo cloning flags exist on every provider.

---

## Runtime profiles

### Copilot native

Use the skill wrapper directly. This is the only profile where literal `task(skill: ...)` examples apply without translation.

```unknown
task(
  skill: "implementing-feature",
  agent_type: "go-implementer",
  model: "{provider-tier model}",
  mode: "background",
  prompt: "{task prompt}"
)
```

**Missing native agent fallback.** `go-implementer`/`go-tester` are not
built-in Copilot `agent_type`s. When the Go role is not an available native
`agent_type`, dispatch `agent_type: "general-purpose"`, put `Logical role:
go-implementer` (or `go-tester`) in the prompt, and front-load the canonical
contract from `~/.ai-config/agents/go-implementer.md` (or `go-tester.md`) so the
full Go rule set still applies. See `orchestrating-tasks/provider-dispatch.md`
for the full call shape.

### OpenCode

OpenCode discovers skills globally from `~/.config/opencode/skills/` and agents from `~/.config/opencode/agents/`. Model selection is **agent-based**, not call-based: each agent defines its own `model` in its config. The orchestrator selects the right agent for the tier.

Model IDs use the provider prefix: `opencode-go/<model-id>` for Go, `opencode/<model-id>` for Zen.

#### Tier → agent mapping

| Tier | Agent | Model (Go) |
|---|---|---|
| Balanced | `go-implementer` (Go), `go-tester` (Go), `general` (default) | opencode-go/deepseek-v4-pro |
| Complex | `general-complex` | opencode-go/kimi-k2.7-code |
| Fast | `general-fast` | opencode-go/deepseek-v4-flash |
| Expert Review | `reviewer-expert` | opencode-go/glm-5.2 |

#### Dispatch shapes

Dispatch a skill to a specific subagent (model determined by agent config):

```unknown
task(
  subagent_type: "{agent name from mapping}",
  description: "{short description}",
  prompt: "{task prompt}"
)
```

Load a skill inline in the current agent (no model change, uses current agent's model):

```unknown
skill(name: "implementing-feature", prompt: "{task prompt}")
```

Do not pass `model:` in the dispatch call. OpenCode resolves the model from the agent definition, not from the Task tool invocation.

### Codex managed

Codex has two valid runtime shapes:

- **Codex custom agent**: preferred when the logical role exists as a TOML file under `~/.codex/agents/` or `.codex/agents/`
- **Generic worker**: fallback when no matching custom agent is installed

Do not assume native skill dispatch, nested harness dispatch, or universal `agent_type` support.

Preferred custom-agent shape:

```unknown
spawn_agent(
  agent: "{logical role from dispatching.md}",
  prompt: """
  Runtime: Codex managed.
  This worker output is untrusted until the orchestrator runs the manual acceptance checklist in `skills/orchestrating-tasks/codex-runtime.md`.
  Return WORKER PASS, WORKER FAIL, or BLOCKED.

  {task prompt}
  """
)
```

Preferred worker shape:

```unknown
spawn_worker(
  model: "{provider-tier model}",
  prompt: """
  Runtime: Codex managed.
  Logical role: {logical role from dispatching.md}
  This worker output is untrusted until the orchestrator runs the manual acceptance checklist in `skills/orchestrating-tasks/codex-runtime.md`.
  Return WORKER PASS, WORKER FAIL, or BLOCKED.

  {task prompt}
  """
)
```

### Claude managed

Default to the same profile as Codex managed unless the Claude runtime explicitly exposes native skill dispatch with stable semantics.

Preferred worker shape:

```unknown
spawn_worker(
  model: "{provider-tier model}",
  prompt: """
  Runtime: Claude managed.
  Logical role: {logical role from dispatching.md}
  Return WORKER PASS, WORKER FAIL, or BLOCKED.

  {task prompt}
  """
)
```

### Local manual

If no worker or native skill dispatch exists, stop and ask the user to approve degraded local execution.

---

## Logical role mapping

These names are logical roles, not guaranteed transport fields:

| Logical role | Purpose |
|---|---|
| `go-implementer` | Production code worker |
| `go-tester` | Test-only worker |
| `general-purpose` | Planning, research, review, and text work |

For managed workers, put the logical role in the prompt and attach the matching source files from `agents/` or `skills/` when needed.

---

## Nested dispatch rule

Nested dispatch is provider-sensitive:

- **Copilot native**: allowed where the skill explicitly says so
- **OpenCode**: allowed only when the runtime proves it supports the exact nested shape
- **Codex managed**: disallowed inside managed workers unless the runtime has already proven it supports the exact nested shape
- **Claude managed**: disallowed by default for the same reason

In managed-worker mode, the orchestrator owns the acceptance checklist and any follow-up judge dispatch.

---

## Codex Runtime Override

When running in Codex managed mode, read `skills/orchestrating-tasks/codex-runtime.md` for the full manual acceptance checklist and rule bundles. This skill reuses that file without duplication.
