# Orchestrating Tasks: Provider Dispatch

> Sub-file of `skills/orchestrating-tasks/SKILL.md`. Read SKILL.md first for Critical Rules and Pre-Dispatch Checklist.

This file maps the orchestrator's **logical roles** to the concrete dispatch
syntax accepted by each provider/runtime. The matrix in `dispatching.md`
selects the role and model tier. This file tells you how to actually make the
call.

## Core rule

Choose the role in `dispatching.md` first. Only then choose the transport:

- **Copilot native**: `task(skill: ..., agent_type: ..., model: ..., mode: ..., prompt: ...)`
- **OpenCode native**: model selection is agent-based; dispatch via `task(subagent_type: "...", description: "...", prompt: "...")`. See `orchestrating-tasks-efficient/provider-dispatch.md` for the tier → agent mapping.
- **Codex managed**: generic worker call only; use the smallest accepted field set
- **Claude Code native**: `Skill(skill: "...")` to load the skill's instructions, THEN `Agent(subagent_type: "...", prompt: "...", run_in_background: bool, model: optional)` to dispatch the actual worker — two separate tool calls, not one. See `claude-runtime.md` for the full shape, the cross-vendor-judge fallback, and `progress.md` ownership. This is the profile to use whenever both `Skill` and `Agent` tools with distinct `subagent_type`s are available — **do not** fall through to "Claude managed" below just because the provider name matches; check for the actual tools first.
- **Claude managed (degraded)**: generic worker call only, no distinct `subagent_type`s exposed — this is the fallback for bare Claude API integrations with no `Skill`/`Agent` tooling, not the default for "any Claude-branded runtime"

Do not assume that `agent_type`, `skill`, `mode`, `fork`, or full repo cloning
flags exist on every provider.

## Runtime profiles

### Copilot native

Use the skill wrapper directly. This is the only profile where the literal
examples in `task-types.md`, `gates.md`, and `dispatching.md` apply without
translation.

Example shape (when the Go role is an installed native `agent_type`):

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
built-in Copilot `agent_type`s and may not be installed. When the Go role is
not an available native `agent_type`, do not fail and do not silently drop the
Go rules: dispatch `agent_type: "general-purpose"` and carry the role plus the
canonical contract in the prompt so the full Go rule set still loads:

```unknown
task(
  skill: "implementing-feature",
  agent_type: "general-purpose",
  mode: "background",
  prompt: """
  Logical role: go-implementer   # go-tester for testing-implementation
  Load and follow this canonical contract FIRST:
  ~/.ai-config/agents/go-implementer.md   # go-tester: ~/.ai-config/agents/go-tester.md
  The full Go rule set applies regardless of native agent availability.

  {task prompt}
  """
)
```

### OpenCode

OpenCode resolves models from agent definitions, not from dispatch calls. Each
agent has a `model` field in its config (JSON or Markdown frontmatter). The
orchestrator selects the agent by `subagent_type`; the model is implicit.

Tier → agent mapping and full dispatch shapes live in
`orchestrating-tasks-efficient/provider-dispatch.md`. This file reuses that
reference without duplication.

Dispatch shape:

```unknown
task(
  subagent_type: "{agent name from mapping}",
  description: "{short description}",
  prompt: "{task prompt}"
)
```

Do not pass `model:` in the Task tool call. It is not a supported parameter.

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

### Claude Code native

**Check for this profile first whenever the runtime is any Claude Code
surface (CLI, desktop app, web app, IDE extension).** Claude Code exposes two
separate tools, not one combined dispatch call — read `claude-runtime.md` in
full before dispatching, this section is only the quick reference.

1. `Skill(skill: "{skill-name}")` — loads that skill's own `SKILL.md` (and
   whatever sub-files it points to) as instructions for the *current* agent to
   follow. This is not a dispatch; nothing runs in the background from this
   call alone.
2. `Agent(subagent_type: "{logical role}", description: "...", prompt: "...",
   run_in_background: bool, model: optional)` — the actual worker dispatch,
   following the instructions `Skill` just loaded.

```unknown
Skill(skill: "implementing-feature")
# read the returned SKILL.md content, then:
Agent(
  subagent_type: "go-implementer",
  description: "{short imperative description}",
  prompt: "{full task prompt, per the Dispatch contract in dispatching.md}",
  run_in_background: false
)
```

Rules:

- Never call `Agent(subagent_type: "go-implementer" | "go-tester", ...)`
  without a preceding `Skill(skill: "implementing-feature" | "testing-implementation")`
  call in the same turn or an earlier one in this conversation — the skill is
  what injects the quality-gate instructions and rule bundle.
- `subagent_type` availability is session- and project-specific. Verify the
  live list (surfaced via a `<system-reminder>`, or `ToolSearch`) rather than
  assuming the mapping in `claude-runtime.md` is exhaustive for every project.
- No cross-vendor judge exists — `Agent` only dispatches Claude-family models.
  Follow `claude-runtime.md`'s Cross-Vendor Rule fallback and disclose the
  limitation in any gate's output.
- The orchestrator (main session), not the dispatched agent, owns writing
  `progress.md` — require a structured completion-report block instead of
  expecting the subagent to edit the vault file itself. See `claude-runtime.md`.
- Independently re-run the deterministic gates (`gofmt`, `vet`, the project's
  real lint entrypoint, `test`) after any `implementing-feature`/
  `testing-implementation` dispatch. A subagent's self-reported PASS is a
  claim, not a fact.

### Claude managed (degraded fallback)

Use this profile only when the runtime is Claude-branded but does **not**
expose `Skill`/`Agent` with distinct `subagent_type`s — e.g. a bare Claude API
integration with a single generic tool-use loop and no skill or subagent
concept. Do not default here just because the provider name is "Claude"; check
for the real tools first (see "Claude Code native" above), since Claude Code
itself is not this degraded case.

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
  Runtime: Claude managed (degraded, no distinct subagent types).
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
| `Explore` (Claude Code only) | Read-only codebase search, faster/cheaper than `general-purpose` for "find X" questions — cannot Edit/Write, do not use for phases that write files |
| `Plan` (Claude Code only) | Architecture/implementation planning — cannot Edit/Write either; have it return plan text and have the orchestrator write the file |

For managed workers, put the logical role in the prompt and attach the matching
source files from `agents/` or `skills/`. For Codex custom agents, the role is
resolved by agent name and the prompt carries only task-specific context. For
Claude Code, the role maps to a real `subagent_type` on the `Agent` tool when
one exists (see `claude-runtime.md`); otherwise fall back to `general-purpose`
with the role bound in the prompt, same principle as the other managed modes.

## Nested dispatch rule

Nested dispatch is provider-sensitive:

- **Copilot native**: allowed where the skill explicitly says so
- **Codex managed**: disallowed inside managed workers unless the runtime has already proven it supports the exact nested shape
- **Claude Code native**: disallowed by default — a dispatched `Agent` cannot itself call `Skill`/`Agent` in most configurations; the orchestrator (main session) owns all dispatch, gate execution, and judge follow-up
- **Claude managed (degraded)**: disallowed by default for the same reason

In managed-worker mode, the orchestrator owns the acceptance checklist and any
follow-up judge dispatch.
