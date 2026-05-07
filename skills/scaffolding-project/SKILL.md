---
name: scaffolding-project
description: Use when bootstrapping a new repository from scratch — sets up git remote, ai-config submodule, plans symlink, language tooling, mise tasks, and base files following the standard pattern across personal projects. Triggers on "scaffold project", "bootstrap repo", "new project setup", "configurar repo do zero".
---

# Scaffolding Project

Bootstraps a new repository following the standard convention used across personal projects (atlas, cashback-platform, kv-store, etc). Interactive: asks the user for project type and language, then creates the minimum viable structure without entering implementation.

## When to Use

- A fresh clone exists with only `.git/` (or an empty directory) and the user wants the standard scaffold applied
- User says "scaffold this", "configura esse repo", "bootstrap", "set up the project"
- Before any feature work on a brand-new repo

## Hard Rules

- **Never overwrite existing files.** If `README.md`, `AGENTS.md`, `.gitignore`, or any other file already exists, skip that step and report it.
- **Personal account only.** All git remotes use the SSH alias `github.com-personal:fascari/<repo>.git`. The `github-personal.com` form is wrong (real public domain that hangs ssh).
- **Never enter implementation.** Stop after the scaffold is in place and the initial commit is pushed.
- **Confirm before pushing.** The initial commit is created locally; ask the user before `git push`.
- **Plans symlink lives inside `.github/`** (the ai-config submodule). The `plans/` path is in ai-config's `.gitignore`, so it doesn't dirty the submodule.

## Inputs to Gather

Use `ask_user` with a single form to collect everything up front:

1. **Repository name** — defaults to the current directory's basename.
2. **Language** — `go`, `node`, `python`, `generic`.
3. **Project type:**
   - `library` — flat, no `cmd/`
   - `single-service` — `cmd/`, `internal/`, optional `pkg/`
   - `multi-service workspace` — `services/`, optional `contracts/`, `proto/`, `scripts/`
   - `study/tutorial` — flat or numbered units, no enforced layout
4. **Module path** (Go only) — defaults to `github.com/fascari/<repo>`.
5. **Has special agent rules?** — boolean. Controls whether root `AGENTS.md` is created. Defaults to `false` — most repos inherit bootstrap from `.github/AGENTS.md`.
6. **Push initial commit?** — boolean, default `true`.

## Steps

### 1. Verify clean state

```bash
git rev-parse --show-toplevel >/dev/null 2>&1 || git init
```

If the directory has uncommitted files beyond `.git`, list them and ask the user whether to proceed.

### 2. Configure remote

```bash
REPO_NAME="<repo>"
REMOTE="git@github.com-personal:fascari/${REPO_NAME}.git"
git remote get-url origin >/dev/null 2>&1 \
  && git remote set-url origin "$REMOTE" \
  || git remote add origin "$REMOTE"
git remote -v
```

Verify the output uses `github.com-personal` (with dot-hyphen). If not, stop and warn.

### 3. Add `.github` submodule (ai-config)

Skip if `.github/` already exists.

```bash
git submodule add git@github.com-personal:fascari/ai-config.git .github
```

### 4. Create plans symlink

```bash
mkdir -p "$HOME/ai-plans/${REPO_NAME}"
[ -L .github/plans ] || ln -s "$HOME/ai-plans/${REPO_NAME}" .github/plans
```

Confirm `git -C .github status` is clean — `plans/` must be in ai-config's `.gitignore`. If it's dirty, stop and report.

### 5. Create `.gitignore`

Skip if exists. Use the template matching the language:

**Go:**
```gitignore
# Binaries
*.exe
*.out
bin/

# Test cache
*.test
coverage.out

# Go workspace
go.work
go.work.sum

# IDE
.idea/
.vscode/
.DS_Store
```

**Node:**
```gitignore
node_modules/
dist/
.env
.env.local
npm-debug.log*
.idea/
.vscode/
.DS_Store
```

**Python:**
```gitignore
__pycache__/
*.py[cod]
.venv/
venv/
.pytest_cache/
dist/
build/
*.egg-info/
.idea/
.vscode/
.DS_Store
```

**Generic:**
```gitignore
.idea/
.vscode/
.DS_Store
```

### 6. Create `README.md`

Skip if exists. Minimal template:

```markdown
# {repo-name}

{one-line description, ask the user}

## Run

{TBD — language-specific commands once tooling is set up}
```

### 7. Create root `AGENTS.md` (conditional)

Only if "special agent rules" was true. Template:

```markdown
# AGENTS.md — {repo-name}

{one-line context: what makes this repo special}

## Session bootstrap

{any project-specific bootstrap steps; otherwise refer to `.github/AGENTS.md`}

## Rules

- {repo-specific rule 1}
- {repo-specific rule 2}
```

If false, skip — bootstrap is inherited from the submodule.

### 8. Initialize language tooling

**Go:**
```bash
go mod init "${MODULE_PATH}"
```

If the project type is `study/tutorial` or `single-service` and the user wants common deps, ask which to add (e.g., `golang.org/x/sync`, `go.uber.org/goleak`, `github.com/stretchr/testify`). Default: none.

**Node:**
```bash
npm init -y
echo "<node-version>" > .nvmrc   # ask user, default to lts (e.g., "lts/*")
```

**Python:** ask whether to use `uv`, `poetry`, or plain `venv`. Set up the chosen tool.

**Generic:** skip.

### 9. Create `.mise.toml`

Skip if exists. Template by language. Ask the user for the language version.

**Go template:**
```toml
[tools]
go = "<version>"

[tasks.test]
description = "Run all tests with race detector"
run = "go test -race ./..."

[tasks.lint]
description = "Lint all packages"
run = "golangci-lint run"

[tasks.tidy]
description = "Tidy go.mod"
run = "go mod tidy"

[tasks.build]
description = "Build all packages"
run = "go build ./..."
```

**Node template:**
```toml
[tools]
node = "<version>"

[tasks.dev]
description = "Run dev server"
run = "npm run dev"

[tasks.test]
description = "Run tests"
run = "npm test"

[tasks.lint]
description = "Lint"
run = "npm run lint"
```

**Python template:**
```toml
[tools]
python = "<version>"

[tasks.test]
description = "Run tests"
run = "pytest"

[tasks.lint]
description = "Lint"
run = "ruff check ."
```

### 10. Create directory stubs by project type

Use `mkdir -p` and add a `.gitkeep` to keep empty dirs in git.

**library:**
- (no extra dirs; flat layout)

**single-service (Go):**
```
cmd/
internal/
```
Optional `pkg/` if user confirms.

**multi-service workspace (Go):**
```
services/
scripts/
```
Optional `contracts/`, `proto/` per user choice. Also create `go.work` if multiple modules are planned (ask).

**study/tutorial:**
- Ask the user for the list of unit names (e.g., `01-foundations`, `02-channels`); create each with `.gitkeep`.

### 11. Create vault folder (if `COPILOT_VAULT` is set)

```bash
[ -n "$COPILOT_VAULT" ] && mkdir -p \
  "$COPILOT_VAULT/${REPO_NAME}/logs" \
  "$COPILOT_VAULT/${REPO_NAME}/architecture" \
  "$COPILOT_VAULT/${REPO_NAME}/plans"
```

Map the repo name to the vault folder name when applicable (per personal copilot instructions).

### 12. Initial commit

```bash
git add -A
git status
git commit -m "chore: initial scaffold

- Add ai-config submodule and plans symlink
- Add base files: README, .gitignore, .mise.toml
- Initialize {language} tooling
"
```

Show the commit summary to the user.

### 13. Push (with confirmation)

If the repo doesn't exist on GitHub yet, ask the user to create it first
(`gh repo create fascari/<repo> --private --source=.`).

If "Push initial commit?" was true and the remote repo exists:
```bash
git push -u origin main
```

If the user prefers to push later, stop here and tell them how.

## Output

Report a summary:
- Files created
- Submodule and symlink set up
- Git remote configured
- Initial commit SHA
- Whether pushed
- Vault folder created (yes/no)
- Next suggested steps (e.g., "run `mise run test` to verify scaffolding")

## Anti-patterns

- ❌ Creating implementation code (handlers, business logic, domain types) — that's the next skill's job.
- ❌ Adding skill-specific files like `plan.md` unless the user explicitly provides one.
- ❌ Using `github.com:` (work account) for personal repos — always SSH alias `github.com-personal:`.
- ❌ Putting `plans/` outside `.github/` — the convention is the symlink inside the submodule, ignored by ai-config's `.gitignore`.
- ❌ Force-overwriting an existing `README.md` or `.gitignore`.
