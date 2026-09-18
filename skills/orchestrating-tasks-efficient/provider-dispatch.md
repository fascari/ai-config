# Orchestrating Tasks Efficient: Provider Dispatch

> Sub-file of `skills/orchestrating-tasks-efficient/SKILL.md`. Read SKILL.md first for Critical Rules and Pre-Dispatch Checklist.

This file maps logical roles to the concrete dispatch syntax accepted by each provider/runtime. Select the role and tier in `dispatching.md` first, then choose the transport here.

---

## Core rule

Choose the role in `dispatching.md` first. Only then choose the transport:

- **Copilot native**: `task(skill: ..., agent_type: ..., model: ..., mode: ..., prompt: ...)`
- **OpenCode native**: `skill(name: "...")` or `task(skill: "...", agent_type: "...", prompt: ...)`
- **Codex managed**: generic worker call only; use the smallest accepted field set
- **Claude Code native**: `Skill(skill: "...")` to load a skill's instructions, THEN `Agent(subagent_type: "...", prompt: "...")` to dispatch the worker — two separate tool calls. See `skills/orchestrating-tasks/claude-runtime.md` for the full contract (this skill reuses that file rather than duplicating it). Check for this profile whenever the runtime is Claude Code, before falling through to "Claude managed" below.
- **Claude managed (degraded)**: generic worker call only — the fallback for a bare Claude API integration with no `Skill`/`Agent` tooling, not the default for every Claude-branded runtime

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

### Claude Code native

Check for this profile first whenever the runtime is any Claude Code surface.
Full contract in `skills/orchestrating-tasks/claude-runtime.md` — quick
reference here:

```unknown
Skill(skill: "implementing-feature")
Agent(
  subagent_type: "go-implementer",
  description: "{short imperative description}",
  prompt: "{task prompt, per the Dispatch Contract above}",
  run_in_background: false
)
```

- Never dispatch `Agent(subagent_type: "go-implementer" | "go-tester", ...)`
  without a preceding `Skill(skill: "implementing-feature" | "testing-implementation")`
  call — the skill is what injects the quality-gate instructions.
- No cross-vendor judge exists in this runtime; `Agent` only dispatches
  Claude-family models. Follow the Cross-Vendor Rule's Claude Code fallback in
  `dispatching.md` (same-vendor, higher tier, adversarial framing + mandatory
  disclosure) for the combined semantic review and any High Assurance gate.
- The orchestrator, not the dispatched agent, owns `progress.md` and
  `context-capsule.md` writes — require a structured completion-report block
  from each dispatch instead of expecting the subagent to edit vault files
  directly.
- Verify the project's actual lint/format entrypoint before dispatching
  (`gates.md`'s `golangci-lint` default is a Copilot-repo-family assumption —
  check for a real `.golangci.yml`, a documented `check.sh`, or a `Makefile`
  target first).

### Claude managed (degraded fallback)

Use only when the runtime is Claude-branded but does NOT expose `Skill`/`Agent`
with distinct `subagent_type`s (e.g. a bare API integration). Claude Code
itself is not this case — check for the real tools first, above.

Preferred worker shape:

```unknown
spawn_worker(
  model: "{provider-tier model}",
  prompt: """
  Runtime: Claude managed (degraded, no distinct subagent types).
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
- **Claude Code native**: disallowed by default — a dispatched `Agent` generally cannot itself call `Skill`/`Agent`; the orchestrator owns all dispatch and judge follow-up
- **Claude managed (degraded)**: disallowed by default for the same reason

In managed-worker mode, the orchestrator owns the acceptance checklist and any follow-up judge dispatch.

---

## Codex Runtime Override

When running in Codex managed mode, read `skills/orchestrating-tasks/codex-runtime.md` for the full manual acceptance checklist and rule bundles. This skill reuses that file without duplication.
