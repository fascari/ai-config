# GitHub Copilot Instructions

## Global Skills & Rules

Skills, rules, and agents live in `~/.ai-config/`, installed globally by `install-global-skills.sh`.

| What | Where | Purpose |
|------|-------|---------|
| Rules | `~/.ai-config/rules/*.md` | Go style, design principles, testing, error handling, clean architecture |
| Skills | `~/.ai-config/skills/*/SKILL.md` | Workflow skills (orchestrating, implementing, testing, etc.) |
| Agents | `~/.ai-config/agents/*.md` | Provider-agnostic agent definitions |

Path-specific rules under `.github/instructions/*.instructions.md` are symlinks to `~/.ai-config/rules/`:

| Instruction file | Applies to |
|-----------------|------------|
| `go-style.instructions.md` | `**/*.go` |
| `design-principles.instructions.md` | `**/*.go` |
| `clean-architecture.instructions.md` | `internal/app/**/*.go` |
| `testing.instructions.md` | `**/*_test.go` |
| `error-handling.instructions.md` | `**/*.go` |
| `package-design.instructions.md` | `**/*.go` |

---

## Session Bootstrap

On first message of each session, load the **recall** skill from `~/.ai-config/skills/recall/SKILL.md`. It loads vault context, recent logs, architecture decisions, and active plans.

---

## Skill Invocation

Use `orchestrating-tasks` as the entry point for any codebase change when maximum assurance is required, or `orchestrating-tasks-efficient` when cost-aware quality is preferred. Invoke via `/skill:name` in Copilot chat.

| Task | Skill |
|------|-------|
| Codebase research | `/skill:researching-codebase` |
| Implementation | `/skill:implementing-feature` |
| Testing | `/skill:testing-implementation` |
| Code review | `/skill:reviewing-code` |
| Commit | `/skill:committing-changes` |
| Pull request | `/skill:creating-pull-request` |

---

## Hard Rules

- **Never log and return the same error**: choose one
- **Never commit directly.** Always invoke `/skill:committing-changes`. The skill requires explicit user approval before any `git commit` or `git push`.
- **No `else` blocks**: use early returns
- **No `assert` in tests**: use `require` (stops on failure)
- **No `interface{}`**: use `any`
