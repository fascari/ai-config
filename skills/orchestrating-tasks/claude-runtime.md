# Claude Code Runtime Compatibility

> Sub-file of `skills/orchestrating-tasks/SKILL.md`. Read SKILL.md first for Critical Rules and Pre-Dispatch Checklist.

These skills were originally written for a Copilot-style harness exposing one
call, `task(skill: "implementing-feature", agent_type: "go-implementer", ...)`,
that resolves the skill's instructions and the worker in a single dispatch.
Claude Code does not expose that call. It exposes two separate primitives that
must be chained by hand every time:

- **`Skill`** — loads a named skill's `SKILL.md` (and whatever sub-files that
  skill's own instructions tell you to open) into the *current* context. It
  does not spawn anything; the calling agent is now the one following those
  instructions.
- **`Agent`** — actually dispatches a subagent, selected by `subagent_type`,
  with its own context window and tool access. This is the real worker.

So the orchestrator's real sequence for, say, `implementing-feature` is:
`Skill(skill: "implementing-feature")` → read what comes back → **then**
`Agent(subagent_type: "go-implementer", prompt: "...")`. Skipping the `Skill`
call and going straight to `Agent(subagent_type: "go-implementer", ...)` is
the exact anti-pattern `task-types.md` warns against ("NEVER dispatch
`go-implementer`/`go-tester` directly") — the difference here is that the
correct fix is a `Skill` call first, not a `task(skill:...)` call that does
not exist in this runtime.

This is **closer to Copilot native than to the generic "Claude managed"
fallback** `provider-dispatch.md` currently describes. Claude Code has real,
distinct subagent types with their own tool access and system prompts — not
just one generic worker. Treat `provider-dispatch.md`'s "Claude managed"
section as the degraded path for bare-API integrations with no `Skill`/`Agent`
tools at all; if you have both tools, use this file instead.

## Runtime Detection

The canonical 4-way classification (native harness / Claude Code native / Codex
managed / local manual) lives in `dispatching.md`'s "Provider Runtime Override"
table — this file only adds what's specific to the Claude Code row: confirm
`Skill` and `Agent` tools both exist before treating this as your profile,
otherwise fall back to `provider-dispatch.md`'s "Claude managed (degraded)"
shape.

Confirm the actual available `subagent_type` list for the current session —
it is **session- and project-specific** (a `<system-reminder>` lists it, and
projects can add custom types under `.claude/agents/*.md`). Do not hardcode a
list from a prior session; agent availability drifts as projects add or
rename custom agents.

## Call shape

```
Skill(skill: "implementing-feature")
# → returns the skill's own SKILL.md content; follow it in the current turn

Agent(
  subagent_type: "go-implementer",         # or "general-purpose" for non-Go / no matching type
  description: "{short imperative description}",
  prompt: "{full task prompt, see dispatching.md for the required payload}",
  run_in_background: false,                # false when you need the result before continuing this turn
  model: "sonnet" | "opus" | "haiku" | "fable"   # optional; omit to inherit session model
)
```

`run_in_background: true` (the `Agent` tool default) queues the dispatch and
notifies later — correct for independent, parallelizable phases. Set it
`false` for a phase whose result gates the very next action (e.g. you must
read the completion report before deciding phase 2's dispatch prompt).

**Never fabricate a backgrounded agent's result.** If you dispatched in the
background, the result is not known until the task notification arrives. Say
so if asked; do not guess.

## Logical role → subagent_type mapping (verify against the live list each session)

| Logical role | subagent_type (typical) | Notes |
|---|---|---|
| `go-implementer` | `go-implementer` | Only for Go production files |
| `go-tester` | `go-tester` | Only for Go test files |
| `general-purpose` (research, planning, review, non-Go impl) | `general-purpose` | Default fallback when no specialized type exists |
| Pure read-only codebase search | `Explore` | Faster/cheaper than `general-purpose` for "find X" questions; cannot Edit/Write |
| Architecture/implementation planning | `Plan` | Cannot Edit/Write — return plan text, orchestrator writes the file |

If a logical role has no matching `subagent_type` in the current session,
dispatch `general-purpose` and bind the role explicitly in the prompt
(`Logical role: go-implementer` + the canonical rule bundle), same principle
as the Copilot missing-native-agent fallback in `provider-dispatch.md`.

## Cross-Vendor Rule — does not hold in Claude Code, here is the actual substitute

`dispatching.md`'s Cross-Vendor Rule assumes multi-provider routing
(DeepSeek/Kimi/GLM/OpenAI/Google alongside Anthropic). **Claude Code's `Agent`
tool only ever dispatches Claude-family models** (`sonnet`, `opus`, `haiku`,
`fable` — confirm current names against the session's model info, they change).
There is no way to satisfy "different vendor" literally in this runtime.

Do not silently skip the spirit of the rule. Substitute, in order of
preference:

1. **Same-vendor, different-tier, adversarial framing.** Producer uses the
   default/Balanced model; the judge/critic uses a higher tier (Opus, or
   Sonnet at higher reasoning effort) with an explicit instruction to try to
   refute rather than confirm ("default to `refuted: true` if uncertain" — see
   the Workflow tool's Adversarial-verify pattern). This is weaker than true
   cross-vendor (correlated blind spots remain) but stronger than a same-tier
   rubber stamp.
2. **Multiple independent same-vendor judges, majority vote**, when the stakes
   justify the extra dispatches (e.g. 3 judges, kill on ≥2 refutations) —
   partially compensates for correlated blind spots through independent
   sampling, still not true vendor diversity.
3. **State the limitation in the gate's own output, every time it runs.**
   Any Critique Gate or Output Judge report produced in Claude Code must
   include a line: `Cross-vendor: NOT AVAILABLE (Claude Code, same-vendor
   judge only)`. Never present a same-vendor judge's PASS as if it carried
   the same guarantee the written rule describes — the user (or a future
   session) needs to know the guarantee is weaker before trusting it blindly.

If a project genuinely has multi-provider access configured (e.g. an MCP
server exposing another vendor's API), that satisfies the rule literally —
check `ToolSearch`/connected MCP tools before assuming it is unavailable.

## progress.md ownership

`implementing-feature`/`testing-implementation`'s own "Per Phase" steps say
the dispatched agent updates `progress.md` directly. In Claude Code this does
not work well: each `Agent` dispatch is a fresh, stateless context with no
guaranteed continuity of the vault's file history or the exact phrasing
convention already established earlier in `progress.md` by the orchestrator or
by prior phases.

**In Claude Code, the orchestrator (main session) owns all `progress.md`
writes.** Require every `implementing-feature`/`testing-implementation`
completion report to end with a structured block the orchestrator transcribes
directly, not paraphrases:

```
## Progress Update
Phase: {N} — {title}
Files created: {list}
Files modified: {list}
Gates: gofmt={PASS/FAIL} vet={PASS/FAIL} revive={PASS/FAIL} build/test={PASS/FAIL}
Blockers: {none | description}
```

The orchestrator still independently re-runs the deterministic gates before
trusting a subagent's self-reported PASS (see "Independent re-verification"
below) — the structured block is for accurate record-keeping, not a substitute
for verification.

## Independent re-verification (do this, do not skip it)

Because a dispatched agent's report is a claim, not a fact, re-run the
deterministic gates yourself in the main session after any
`implementing-feature`/`testing-implementation` dispatch, scoped to the files
touched:

```bash
gofmt -l {changed-dir}/
go vet ./{changed-dir}/...
go tool revive -set_exit_status ./{changed-dir}/...   # or the project's real lint entrypoint — see below
go test ./{changed-dir}/... -count=1
git status --porcelain                                 # confirm only the expected files changed
```

**Do not assume `golangci-lint` is the project's linter.** `dispatching.md`
and `implementing-feature/SKILL.md` default to `golangci-lint run`, which is a
Copilot-repo-family assumption. Check the actual project first (a `.golangci.yml`,
a documented `tools/bin/check.sh`, a `Makefile` target) and use the gate the
project actually runs in CI — a passing `golangci-lint` run means nothing if
CI never invokes it.

## Architecture Gate — run it even when a waiver is already documented

`gates.md` says a documented waiver means "should not be run as a blocker."
That is a statement about *blocking*, not about *running*. Run the
deterministic `conformance.sh` script regardless — it is zero-cost — and read
its output:

- If it produces the exact ERRORs the waiver already names: confirms nothing
  new broke, proceed.
- If it produces something the waiver does not name, or a clean pass where a
  waiver was expected: that is new information, surface it before proceeding.

Skipping the run entirely because a waiver exists turns a verifiable fact into
an assumption.
