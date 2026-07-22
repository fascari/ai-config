---
name: implementing-feature
description: Use when implementing a plan, feature, or bug fix phase by phase in the codebase
---

# Implementing Feature

Implements **production code only**, phase by phase, validates with linter and style gate, then hands off to `testing-implementation`.

## Scope Boundary

| In scope | Out of scope |
|---|---|
| Production source files | Test files (`*_test.go`, `*.test.*`, etc.) |
| Linter, static analysis, fmt | Running tests |
| Style compliance gate | Writing or modifying testdata/fixtures |

**If a plan phase lists test files:** skip them, note them in the Testing Context Handoff, and proceed with production files only.

---

## Execution Model

When dispatched by `orchestrating-tasks`, detect the stack first, then choose the logical role. Render the actual call using `skills/orchestrating-tasks/provider-dispatch.md`.

### Stack Detection

```bash
STACK="unknown"
[ -f "go.mod" ] && STACK="go"
[ -f "package.json" ] && STACK="typescript"
[ -f "pyproject.toml" ] && STACK="python"
[ -f "setup.py" ] || [ -f "requirements.txt" ] && STACK="python"
echo "stack=$STACK"
```

### Dispatch by stack

| Stack | Logical role | Why |
|---|---|---|
| Go | `go-implementer` | Custom agent with Go conventions front-loaded. Go code rules and style gates apply. |
| TypeScript / JavaScript | `general` | Built-in general subagent. Deterministic gates (`tsc --strict`, `eslint`, `prettier`). |
| Python | `general` | Built-in general subagent. Deterministic gates (`mypy --strict`, `ruff check`). |
| Other / unknown | `general` | Fall back to project's own test/lint commands. Warn the orchestrator. |

### Hard rule

**Never dispatch `go-implementer` for non-Go stacks.** The Go code rules and style gates only apply when `STACK=go`. For any other stack, skip the Go-specific sections below and use only the non-Go gates.

In Copilot native mode `go-implementer` may map to `agent_type`. In Codex managed mode prefer a matching custom agent from `~/.codex/agents/` or `.codex/agents/`; otherwise bind the logical role in the prompt and treat the worker output as untrusted until the orchestrator accepts it.

---

## When to use

- User asks to implement a plan or feature
- orchestrating-tasks delegates implementation
- User says "implement", "code this", "start coding", "next phase", "proceed"

---

## Setup

1. Use the `{plan_root}` provided by `orchestrating-tasks`. If running standalone, resolve `{plan_root}` with the same rule: use `$AI_MEMORY_HOME/{project}/plans/`; then create or refresh `.plans` as a symlink to `{plan_root}`.
2. **Context Bootstrap**: skip entirely if the prompt contains `Violations:` (repair cycle):
   ```bash
   GRAPHIFY_AVAILABLE=false
   [ -f "graphify-out/GRAPH_REPORT.md" ] && GRAPHIFY_AVAILABLE=true
   VAULT_AVAILABLE=false
   [ -n "${AI_MEMORY_HOME:-}" ] && VAULT_AVAILABLE=true
   ```
   Resolve `{plan_root}` with the same rule as `orchestrating-tasks`: use `$AI_MEMORY_HOME/{project}/plans/`. If unset, stop and ask the user to configure an external plan root.
   - If `GRAPHIFY_AVAILABLE=true` **and** the plan_excerpt does NOT contain explicit file paths: use `graphify query` for domains/packages in the plan.
    - If `GRAPHIFY_AVAILABLE=true` **and** the plan already specifies exact files to edit: **skip graphify**: scope is known.
   - If `VAULT_AVAILABLE=true`: read architecture decisions relevant to the target area.

---

## Style References (load before first edit)

Read only the instruction files whose `applyTo` glob matches files you will change. Do not load all instructions unconditionally:

- the active provider-native project instruction files for the current repo
- `skills/writing-modern-go/SKILL.md` when the implementation touches Go and the repo expects modern Go idioms
- any explicitly referenced repo-local rule docs linked from those project instruction files

---

## Per Phase

1. Read only the current phase section from `{plan_root}/{slug}/implementation-plan.md`.
2. Load targeted context: `graphify query "{domain}"` if available; otherwise read the `## File Map` from `research.md`.
3. **Pre-flight**: files marked MODIFY must exist; files marked CREATE must not exist (unless plan says overwrite).
4. **Compatibility gate**: stop and ask before modifying any existing:
   - HTTP request/response shape visible to callers
   - Exported interface that other packages implement
   - Database column (drop, rename, type change)
   - Message schema consumed by external systems

   If no `## Compatibility Decision` in the plan:
   ```
   Potential breaking change: {description}
   A) Backward compatible approach
   B) Accept breaking change
   ```
5. Implement following all project coding rules from the active provider-native project instruction files and any repo docs they explicitly route you to.
6. After EVERY file edit, compile-check immediately and fix all issues.
7. **Style compliance gate** (run ALL that apply to the detected stack before step 8):

   **Go stack (`STACK=go`):**

   a. File-name audit (Go):
   ```bash
   git diff --name-only --diff-filter=A HEAD | grep -E '\.go$' | grep -E '_.+_' | grep -v '_test\.go$'
   ```

   b. Comment hygiene:
   ```bash
   for f in $(git diff --name-only --diff-filter=AM HEAD | grep '\.go$'); do
     awk -v f="$f" 'BEGIN{c=0;t=0} /^[[:space:]]*\/\//{c++} {t++} END{ if (t>0 && c*100/t > 15) printf "%s: %d%% comment density\n", f, c*100/t }' "$f"
   done
   ```
   Forbidden: plan-reference comments in production code, godoc that restates the signature.

   c. Modern-Go scan:
   ```bash
   git diff --name-only --diff-filter=AM HEAD | grep '\.go$' | xargs grep -nE \
     'wg\.Add\(1\)|interface\{\}|errors\.As\(|sort\.Slice\(|time\.Now\(\)\.Sub\(|for [a-z]+ := 0; [a-z]+ <|context\.Background\(\) *$' 2>/dev/null
   ```

   d. Dead-code: every newly exported symbol must have an external caller.

   **Non-Go stacks (TypeScript, Python, other):**

   Skip a-d above. Instead:
   - Run the stack's own compile/lint/format commands (see step 8).
   - Trust the stack's community tooling (ESLint, Prettier, mypy, ruff) for style.
   - Do not apply Go naming or style conventions to non-Go code.

8. **HARD GATE: compile + lint + format must pass before handoff.**

   **Go stack:**
   ```bash
   golangci-lint run ./path/to/changed/... | head -50
   ```

   **TypeScript stack:**
   ```bash
   # Always run: compile check (tsc is a devDependency in every TS project)
   npx tsc --noEmit --strict 2>&1 | head -50
   ```
   Then detect and run only the tools that are configured:
   ```bash
   # ESLint: run only if configured
   if [ -f ".eslintrc" ] || [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] || \
      [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ] || \
      grep -q '"eslint"' package.json 2>/dev/null; then
     npx eslint src/ 2>&1 | head -50
   else
     echo "SKIPPED: eslint not configured in this project"
   fi
   # Prettier: run only if configured
   if [ -f ".prettierrc" ] || [ -f ".prettierrc.js" ] || [ -f ".prettierrc.json" ] || \
      [ -f "prettier.config.js" ] || grep -q '"prettier"' package.json 2>/dev/null; then
     npx prettier --check src/ 2>&1 | head -50
   else
     echo "SKIPPED: prettier not configured in this project"
   fi
   ```
   **Mandatory: `tsc --strict` + `npm test`.** ESLint and Prettier are skipped with a warning when not configured.

   **Python stack:**
   ```bash
   # Run only what is installed and configured
   python -m mypy src/ --strict 2>&1 | head -50 2>/dev/null || echo "SKIPPED: mypy not available"
   python -m ruff check src/ 2>&1 | head -50 2>/dev/null || echo "SKIPPED: ruff not available"
   python -m ruff format --check src/ 2>&1 | head -50 2>/dev/null || echo "SKIPPED: ruff not available"
   ```
   At least one gate must pass. If all tools are unavailable, escalate to the user.

   **Other / unknown stack:**
   ```bash
   # Use whatever test/lint command the project documents
   # e.g. npm test, make check, cargo test
   ```
   Only proceed when mandatory commands return 0. Skipped gates (tool not configured) do not block. Escalate if no gate passes at all.

   > **Note:** Semantic validation (rules compliance, architecture, error handling) happens in `reviewing-code`, not here. This phase focuses on deterministic gates only (compile + lint + format).

9. If a non-obvious domain, database, or architectural anti-pattern is discovered:
   - Surface it in the phase summary.
   - If `VAULT_AVAILABLE=true`, append to `$AI_MEMORY_HOME/{project}/architecture/anti-patterns.md`.

10. Update checkboxes in `implementation-plan.md`.
11. Update `progress.md`.
12. **Pause**: present results, wait for approval before next phase.

---

## Testing Context Handoff

After lint and style gate pass, prepare this handoff for `testing-implementation`. Include in the phase completion report:

- Plan slug and phase number
- New or changed function signatures (copy verbatim)
- Existing test file path, mock setup, and testdata factories found (read-only, do not edit)
- Test scenarios from the plan's Success Criteria section
- Exact paths for test files and testdata directories

---

## Go Code Rules (Go stack only)

When `STACK=go`, apply these rules. Skip this entire section for non-Go stacks.

- Grouped declarations: `type ( )`, `var ( )`, `const ( )`
- No `else`: early returns only
- `any` not `interface{}`
- `errors.Is()` / `errors.As()`: never `==`
- No `Get`/`Set` prefixes · lowercase single-word packages · no `utils`/`helpers`
- Accept interfaces, return structs
- Value receivers preferred: pointers only when mutation/nil/size required
- Unused receiver → convert to package-level function
- Pure functions over impure · inline logic when not reused
- Comments only for non-obvious WHY

### Context & Observability (Go)
- Propagate `ctx` through ALL calls
- Wrap errors: `fmt.Errorf("context: %w", err)`

### Non-Go stacks

No language-specific code rules are prescribed. Defer to:
- The stack's community linter defaults (e.g. ESLint recommended, ruff's E/F/I/N/W)
- The project's existing code patterns (follow local conventions, read neighboring files)
- The style gate (step 7-8) serves as the deterministic quality check

---

## Quality Checklist (before presenting code)

**Go stack:**
- [ ] Declarations grouped
- [ ] No `else` · early returns · context propagated
- [ ] Errors wrapped with `%w`
- [ ] No `Get`/`Set` prefixes
- [ ] Value receivers · pure functions where possible
- [ ] `errors.Is()`: never `==`
- [ ] No magic strings (typed constants)
- [ ] Backward compatibility verified

**Non-Go stacks:**
- [ ] Compile/lint/format gates pass (step 8)
- [ ] Existing project patterns respected (read neighboring files)
- [ ] No unnecessary dependencies or framework introductions
- [ ] Change is minimal (no unrelated refactors)
- [ ] Backward compatibility verified

---

## Other Rules

**Commits**: NEVER commit automatically. Report final state and stop.

**Docs**: show explanations in chat, never create `SOLUTION.md`, `TROUBLESHOOTING.md`, etc.

---

## Progress Tracking

Update `progress.md` after each phase. Mark only production file tasks:

```markdown
## Phase 1: Domain Model
- [x] Created domain entity
- [x] Linter: PASS
- [x] Style gate: PASS
```

**Do NOT update `## Status` to `REVIEW`**, that transition is owned exclusively by `orchestrating-tasks` after all gates pass. Leave `## Status` as `IN_PROGRESS` and update only the phase checkboxes.

## Codex Runtime Override

When dispatched by `orchestrating-tasks` in Codex managed mode, a generic worker is not the implementation harness. The worker may produce a bounded production patch, but its success is only `WORKER PASS`; the orchestrator must audit the diff with `orchestrating-tasks/codex-runtime.md` before accepting the phase.

Hard implementation conventions that must be checked manually in Codex managed mode:

- Changed files stay within the approved production write scope.
- Production workers do not edit test files.
- Naming and public API surface follow `writing-modern-go` and project standards.
- Scoped format, lint, and tests pass before the phase is accepted.

If any of these fail, report `BLOCKED` or dispatch a repair cycle. Do not report the phase as accepted.
