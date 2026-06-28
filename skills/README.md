# Skills

AI-assisted workflow skills for software engineering tasks. Each subdirectory contains a `SKILL.md` with the full instructions for that skill.


## Entry Point

Use **orchestrating-tasks** as the single entry point for any task involving codebase analysis or changes. It detects complexity, delegates to the right skills, and manages plan state.

`orchestrating-tasks` is split into focused sub-files for maintainability. Read `orchestrating-tasks/SKILL.md` first, then open the relevant sub-file:

| Sub-file | Content |
|---|---|
| `dispatching.md` | Model tier matrix, cross-vendor rule, dispatch template, style reinforcement |
| `gates.md` | Critique gate, test-design-judge, output judge gate |
| `task-types.md` | Skill chain per task type, NEVER-dispatch-agents-directly rule |
| `approval-and-output.md` | Approval checkpoints, plan artifact contract |


## Skill Catalog

### Orchestration and Workflow

| Skill | Purpose |
|---|---|
| [orchestrating-tasks](orchestrating-tasks/) | Single entry point for all AI-assisted tasks. Detects complexity, routes to the right skill chain, manages plan state, and dispatches parallel agents when possible. |
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
| [implementing-feature](implementing-feature/) | Implements production code only, phase by phase, with linter + style gate + validate-loop. Never commits. Hands off to testing-implementation after each phase. |
| [testing-implementation](testing-implementation/) | Writes and executes tests, runs validate-loop (testing phase), and dispatches a cross-vendor test-design-judge before reporting back to the orchestrator. |
| [writing-modern-go](writing-modern-go/) | Enforces modern Go idioms (Go 1.18 through 1.26+) instead of legacy patterns. Covers generics, `slices`, `maps`, `cmp`, `errors.AsType`, `wg.Go`, and more. |

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

Projects can define custom agent types in an `agents/` directory. This repo ships templates for Go projects:

| Agent | Purpose |
|---|---|
| [`go-implementer`](../agents/go-implementer.md) | Go production code agent. Front-loads Go style rules, modern-go idioms, and architecture conventions. Never touches test files. |
| [`go-tester`](../agents/go-tester.md) | Go test agent. Front-loads testing conventions, fixture lifecycle rules, and assertion patterns. Never touches production files. |
| [`harness-gate`](../agents/harness-gate.md) | Runs `harness-validate.sh` for one phase and reports HARNESS PASS or FAIL. No implementation work. |
| [`validate-loop`](../agents/validate-loop.md) | Evaluator-optimizer loop. Runs code agent + harness-gate cycles until HARNESS PASS or max iterations. Returns only `LOOP PASS` or `LOOP FAIL` to the caller (~100 tokens). |

See [`../harness/README.md`](../harness/README.md) for the harness architecture and [`../harness/workflow.md`](../harness/workflow.md) for the enforcement flow diagram.


## Standard Workflow

orchestrating-tasks → researching-codebase → analyzing-system-design → planning-implementation → implementing-feature → validate-loop (implementation) → testing-implementation → validate-loop (testing) → test-design-judge → output-judge → reviewing-code → sanitizing-text → committing-changes → creating-pull-request


## Project Customization

Skills are language and framework agnostic. Project-specific rules should live in the active provider's native project instruction mechanism. Shared reusable rules belong in `rules/`.

To adapt to a new project:

1. Add or update `rules/` for shared rules, and install or update the provider-native project entrypoint for the target AI surface.
2. Update `implementing-feature/references/anti-patterns.md` with codebase-specific patterns.
3. Copy `agents/` templates into the project's `agents/` directory and adapt to the project's toolchain.
4. Implement the harness shell scripts in `.github/harness/` (see `harness/README.md`).
5. Skills apply your rules automatically during each phase.
