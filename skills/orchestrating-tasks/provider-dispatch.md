# Orchestrating Tasks — Provider Dispatch

> Sub-file of `skills/orchestrating-tasks/SKILL.md`. Read SKILL.md first for Critical Rules and Pre-Dispatch Checklist.

This file maps the orchestrator's **logical roles** to the concrete dispatch
syntax accepted by each provider/runtime. The matrix in `dispatching.md`
selects the role and model tier. This file tells you how to actually make the
call.

## Core rule

Choose the role in `dispatching.md` first. Only then choose the transport:

- **Copilot native**: `task(skill: ..., agent_type: ..., model: ..., mode: ..., prompt: ...)`
- **Codex managed**: generic worker call only; use the smallest accepted field set
- **Claude managed**: generic worker call only unless the runtime explicitly exposes native skill dispatch

Do not assume that `agent_type`, `skill`, `mode`, `fork`, or full repo cloning
flags exist on every provider.

## Runtime profiles

### Copilot native

Use the skill wrapper directly. This is the only profile where the literal
examples in `task-types.md`, `gates.md`, and `dispatching.md` apply without
translation.

Example shape:

```unknown
task(
  skill: "implementing-feature",
  agent_type: "go-implementer",
  model: "{provider-tier model}",
  mode: "background",
  prompt: "{task prompt}"
)
```

### Codex managed

Codex has two valid runtime shapes:

- **Codex custom agent**: preferred when the logical role exists as a TOML file
  under `~/.codex/agents/` or `.codex/agents/`
- **Generic worker**: fallback when no matching custom agent is installed

Do not assume native skill dispatch, nested harness dispatch, or universal
`agent_type` support.

Rules:

- Prefer a matching Codex custom agent when one is installed for the logical
  role.
- Start with the smallest worker call shape the runtime accepts.
- If the runtime rejects a call because of extra transport fields, retry once
  with fewer fields, not more.
- Do **not** combine `agent_type` with full-fork or full-context transport
  options unless the runtime already proved it accepts that shape.
- Bind the role in the **prompt**, not in transport metadata, when needed:
  `Logical role: go-implementer`, `Logical role: go-tester`,
  `Logical role: general-purpose`.
- Paste the relevant role guidance and rule bundle into the prompt.

Preferred custom-agent shape:

```unknown
spawn_agent(
  agent: "{logical role from dispatching.md}",
  prompt: """
  Runtime: Codex managed.
  This worker output is untrusted until the orchestrator runs the manual
  acceptance checklist in codex-runtime.md.
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
  This worker output is untrusted until the orchestrator runs the manual
  acceptance checklist in codex-runtime.md.
  Return WORKER PASS, WORKER FAIL, or BLOCKED.

  {task prompt}
  """
)
```

If the current runtime supports naming or description fields, they may be
included. They are optional. The prompt contract is not.

### Claude managed

Default to the same profile as Codex managed unless the Claude runtime
explicitly exposes native skill dispatch with stable semantics.

Rules:

- Assume generic worker semantics by default.
- Do not assume Copilot-style `agent_type` or `task(skill: ...)` support.
- Inline the logical role and required rule bundle in the prompt.
- Keep nested dispatch out of the worker unless the runtime explicitly supports it.

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

If no worker or native skill dispatch exists, stop and ask the user to approve
degraded local execution.

## Logical role mapping

These names are **logical roles**, not guaranteed transport fields:

| Logical role | Purpose |
|---|---|
| `go-implementer` | Production code worker |
| `go-tester` | Test-only worker |
| `general-purpose` | Planning, review, research, and text work |

For managed workers, put the logical role in the prompt and attach the matching
source files from `agents/` or `skills/`. For Codex custom agents, the role is
resolved by agent name and the prompt carries only task-specific context.

## Nested dispatch rule

Nested dispatch is provider-sensitive:

- **Copilot native**: allowed where the skill explicitly says so
- **Codex managed**: disallowed inside managed workers unless the runtime has already proven it supports the exact nested shape
- **Claude managed**: disallowed by default for the same reason

In managed-worker mode, the orchestrator owns the acceptance checklist and any
follow-up judge dispatch.
