# GitHub Copilot Instructions

> Template for `.github/copilot-instructions.md` in target repositories.
> Fill in project-specific sections and install via `install-provider-rules.sh`.

---

## Global Skills & Rules

Skills, rules, and agents live in `~/.ai-config/` — installed globally by `install-global-skills.sh`.

| What | Where | Purpose |
|------|-------|---------|
| Rules | `~/.ai-config/rules/*.md` | Go style, testing, error handling, clean architecture |
| Skills | `~/.ai-config/skills/*/SKILL.md` | Workflow skills (orchestrating, implementing, testing, etc.) |
| Agents | `~/.ai-config/agents/*.md` | Provider-agnostic agent definitions |

Path-specific rules under `.github/instructions/*.instructions.md` are symlinks to `~/.ai-config/rules/`:

| Instruction file | Applies to |
|-----------------|------------|
| `go-style.instructions.md` | `**/*.go` |
| `clean-architecture.instructions.md` | `internal/app/**/*.go` |
| `testing.instructions.md` | `**/*_test.go` |
| `error-handling.instructions.md` | `**/*.go` |
| `package-design.instructions.md` | `**/*.go` |

---

## Project Basics

> Fill in for each project.

- **Language / Stack**: {e.g. Go 1.26, Node.js 22, Python 3.12}
- **Entrypoints**: {e.g. `cmd/server/main.go`, `src/index.ts`}
- **Local Environment**: {e.g. `.env`, `mise`}

### Essential Commands

```sh
# mise run dev          # Start locally
# mise run test         # Run all tests
# mise run lint         # Lint the codebase
# mise run build        # Build artifacts
```

---

## Project Architecture

> Fill in for each project. Replace with actual directory layout.

```
/src/                   # Application source
/tests/                 # Test files
/docs/                  # Documentation
```

---

## Session Bootstrap

On first message of each session, load the **recall** skill from `~/.ai-config/skills/recall/SKILL.md`. It loads vault context, recent logs, architecture decisions, and active plans.

---

## Skill Invocation

Use `orchestrating-tasks` as the single entry point for any codebase change. Invoke via `/skill:name` in Copilot chat.

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

- **Never log and return the same error** — choose one
- **Never commit directly.** Always invoke `/skill:committing-changes`. The skill requires explicit user approval before any `git commit` or `git push`.
- **No `else` blocks** — use early returns
- **No `assert` in tests** — use `require` (stops on failure)
- **No `interface{}`** — use `any`
