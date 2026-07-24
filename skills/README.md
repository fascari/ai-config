# Skills

AI-assisted workflow skills for software engineering tasks. Each subdirectory contains a `SKILL.md` with the full instructions for that skill.


## Entry Points

Use **orchestrating-tasks** as the single entry point when maximum assurance is required, **orchestrating-tasks-efficient** when cost-aware quality is preferred, or **orchestrating-single-loop** for a bounded production vertical slice.

`orchestrating-tasks` is split into focused sub-files for maintainability. Read `orchestrating-tasks/SKILL.md` first, then open the relevant sub-file:

| Sub-file | Content |
|---|---|
| `dispatching.md` | Model tier matrix, cross-vendor rule, dispatch template, style reinforcement |
| `gates.md` | Critique gate, test-design-judge, output judge gate |
| `task-types.md` | Skill chain per task type, NEVER-dispatch-agents-directly rule |
| `approval-and-output.md` | Approval checkpoints, plan artifact contract |

`orchestrating-tasks-efficient` offers Lean, Standard, and High Assurance modes. Read `orchestrating-tasks-efficient/SKILL.md` first, then open the relevant sub-file:

| Sub-file | Content |
|---|---|
| `dispatching.md` | Cost-aware model tier matrix, dispatch contract |
| `task-types.md` | Complexity + risk classification, mode selection |
| `gates.md` | Deterministic Go gates and conditional LLM gates |
| `context-management.md` | `context-capsule.md` format and reuse rules |
| `provider-dispatch.md` | Multi-provider call shapes |
| `migration.md` | Comparison with `orchestrating-tasks` and migration guide |


## Skill Catalog

### Orchestration and Workflow

| Skill | Purpose |
|---|---|
| [orchestrating-tasks](orchestrating-tasks/) | Single entry point for all AI-assisted tasks. Detects complexity, routes to the right skill chain, manages plan state, and dispatches parallel agents when possible. High Assurance reference. |
| [orchestrating-tasks-efficient](orchestrating-tasks-efficient/) | Cost-aware entry point that preserves deterministic gates and cross-vendor review, but reduces dispatches, context repetition, and unnecessary Complex model usage. Offers Lean, Standard, and High Assurance modes. |
| [orchestrating-single-loop](orchestrating-single-loop/) | Bounded workflow for production features and bug fixes that do not need a multi-agent pipeline. |
| [compressing-context](compressing-context/) | Compresses the current session into `session-summary.md` so a new chat can resume where this one left off. Triggered manually or when context reaches 70%+. |
| [resuming-context](resuming-context/) | Restores full working context from a compressed session summary and hands off to the correct skill to continue. |

### Research and Planning

| Skill | Purpose |
|---|---|
| [researching-codebase](researching-codebase/) | Read-only codebase analysis. Documents how and where things are implemented, with `file:line` references. Never suggests improvements. |
| [planning-implementation](planning-implementation/) | Translates research findings into a phased, verifiable implementation plan. Does not write code. |
| [analyzing-system-design](analyzing-system-design/) | Analyses atomicity, idempotency, consistency, concurrency, resilience, and architectural patterns. Produces `system-design-analysis.md` before any code is written. Mandatory for Standard and Complex tasks. |
| [system-design-advisor](system-design-advisor/) | Analyses implementation phases through the lens of distributed systems correctness, data integrity, and production reliability. Presents trade-offs with concrete proposals and optional Mermaid diagrams. |

### Implementation and Testing

| Skill | Purpose |
|---|---|
| [implementing-feature](implementing-feature/) | Implements production code only, phase by phase, with linter + style gate. Never commits. Hands off to testing-implementation after each phase. |
| [testing-implementation](testing-implementation/) | Writes and executes tests, runs scoped tests and lint. Reports back to the orchestrator. |
| [writing-modern-go](writing-modern-go/) | Enforces modern Go idioms (Go 1.18 through 1.26+) instead of legacy patterns. Covers generics, `slices`, `maps`, `cmp`, `errors.AsType`, `wg.Go`, and more. |
| [style-gate](style-gate/) | Deterministic quality gates (lint, format, typecheck, tests, style greps). Zero LLM tokens. Called by implementing-feature and testing-implementation. |
| [cognition-lessons](cognition-lessons/) | Extracts lessons from review failures and loads them in future sessions. Harness learns from mistakes. |

### Review, Quality, and Publishing

| Skill | Purpose |
|---|---|
| [reviewing-code](reviewing-code/) | Code review against all project rules and conventions. Categorizes findings as `BLOCKER` or `SUGGESTION`. Uses a cross-vendor model (different vendor from the implementer). |
| [sanitizing-text](sanitizing-text/) | Post-processing pass that removes AI-sounding language, forbidden phrases, decorative punctuation, emojis, and formatting issues before text is written to files or sent to external systems. |
| [committing-changes](committing-changes/) | Analyses changes, groups them into logical commits following Chris Beams' seven rules, and executes only after explicit user approval. |
| [creating-pull-request](creating-pull-request/) | Gathers context from commits and changed files, generates a PR description following the project template, and opens the PR via GitHub CLI after approval. |

### Utilities

| Skill | Purpose |
|---|---|
| [copying-to-clipboard](copying-to-clipboard/) | Places text directly in the macOS clipboard via `pbcopy`, avoiding line-break artifacts when pasting into forms or external apps. |
| [reading-pdf](reading-pdf/) | Extracts text from PDF files page by page using `pypdf`. Text only, no OCR. |


## Custom Agents

This repo keeps agent definitions in three formats:

| Format | Location | Installed to |
|---|---|---|
| Provider-agnostic markdown | `agents/*.md` | Referenced by orchestrating-tasks |
| Codex TOML | `providers/codex/agents/*.toml` | `~/.codex/agents/` via `install-global-skills.sh` |
| Opencode markdown | `providers/opencode/agents/*.md` | `~/.config/opencode/agents/` via `install-global-skills.sh` |

Provider-neutral templates for Go projects:

| Agent | Purpose |
|---|---|
| [`go-implementer`](../agents/go-implementer.md) | Go production code agent. Front-loads Go style rules, modern-go idioms, and architecture conventions. Never touches test files. |
| [`go-tester`](../agents/go-tester.md) | Go test agent. Front-loads testing conventions, fixture lifecycle rules, and assertion patterns. Never touches production files. |


## Standard Workflow

orchestrating-tasks → researching-codebase → analyzing-system-design → planning-implementation → implementing-feature → testing-implementation → reviewing-code → sanitizing-text → committing-changes → creating-pull-request


## Project Customization

Skills are language and framework agnostic. Project-specific rules should live in the active provider's native project instruction mechanism. Shared reusable rules belong in `rules/`.

To adapt to a new project:

1. Add or update `rules/` for shared rules, and install or update the provider-native project entrypoint for the target AI surface.
2. Update `implementing-feature/references/anti-patterns.md` with codebase-specific patterns.
3. Copy `agents/` templates into the project's provider-specific location and adapt to the project's toolchain.
4. For Codex, install or check in the TOML files from `providers/codex/agents/`.
5. Skills apply your rules automatically during each phase.
