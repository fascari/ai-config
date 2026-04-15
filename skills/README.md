# Skills

AI-assisted workflow skills for software engineering tasks. Each subdirectory contains a `SKILL.md` with the full instructions for that skill.


## Entry Point

Use **orchestrating-tasks** as the single entry point for any task involving codebase analysis or changes. It detects complexity, delegates to the right skills, and manages plan state.


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
| [implementing-feature](implementing-feature/) | Implements plans phase by phase with linter and test validation. Never commits directly. |
| [testing-implementation](testing-implementation/) | Writes and executes tests, validates coverage, and verifies that the implementation meets the success criteria defined in the plan. |
| [writing-modern-go](writing-modern-go/) | Enforces modern Go idioms (Go 1.18 through 1.26) instead of legacy patterns. Covers generics, `slices`, `maps`, `cmp`, `errors.AsType`, `new(val)`, `wg.Go`, and more. |

### Review, Quality, and Publishing

| Skill | Purpose |
|---|---|
| [reviewing-code](reviewing-code/) | Code review against all project rules and conventions. Categorizes findings as `BLOCKER` or `SUGGESTION`. Also performs requirements traceability reviews when an issue tracker ticket is provided. |
| [sanitizing-text](sanitizing-text/) | Post-processing pass that removes AI-sounding language, forbidden phrases, decorative punctuation, emojis, and formatting issues before text is written to files or sent to external systems. |
| [committing-changes](committing-changes/) | Analyses changes, groups them into logical commits following Chris Beams' seven rules, and executes only after explicit user approval. |
| [creating-pull-request](creating-pull-request/) | Gathers context from commits and changed files, generates a PR description following the project template, and opens the PR via GitHub CLI after approval. |

### Utilities

| Skill | Purpose |
|---|---|
| [reading-pdf](reading-pdf/) | Extracts text from PDF files page by page using `pypdf`. Text only, no OCR. |


## Standard Workflow

orchestrating-tasks -> researching-codebase -> analyzing-system-design -> planning-implementation -> implementing-feature -> testing-implementation -> reviewing-code -> sanitizing-text -> committing-changes -> creating-pull-request.


## Project Customization

Skills are language and framework agnostic. Project-specific rules live in `.github/instructions/` (coding style, architecture, testing conventions, anti-patterns).

To adapt to a new project:

1. Add or update files in `.github/instructions/` with project-specific rules.
2. Update `implementing-feature/references/anti-patterns.md` with codebase-specific patterns.
3. Skills apply your rules automatically during each phase.
