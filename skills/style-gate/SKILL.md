---
name: style-gate
description: Deterministic quality gates (lint, format, typecheck, tests, style greps). Zero LLM tokens. Called by implementing-feature and testing-implementation after code changes.
---

# Style Gate

Deterministic quality gates that run after code changes. Zero LLM tokens, all checks are local commands with exit codes.

## When to use

- After implementing-feature writes production code
- After testing-implementation writes tests
- Before handing off to the next phase

## Gates

### 1. Lint

Run the project's linter scoped to changed paths:

```bash
# Go example
golangci-lint run ./path/to/changed/... | head -50

# TypeScript example
eslint src/changed/**/*.ts

# Python example
ruff check src/changed/
```

**Pass criteria**: exit code 0, no issues reported.

### 2. Format

Check that code is properly formatted:

```bash
# Go
gofmt -l $(git diff --name-only --diff-filter=AM HEAD | grep '\.go$')

# TypeScript
prettier --check src/changed/**/*.ts

# Python
black --check src/changed/
```

**Pass criteria**: no files listed (all formatted).

### 3. Typecheck

Run type checking if applicable:

```bash
# Go
go vet ./path/to/changed/...

# TypeScript
tsc --noEmit

# Python
mypy src/changed/
```

**Pass criteria**: exit code 0.

### 4. Tests (testing phase only)

Run scoped tests:

```bash
# Unit tests
go test ./path/to/package/... -count=1 -timeout=60s

# Integration tests
grep -rl '//go:build integration' path/to/domain/ | xargs -I{} dirname {} | sort -u
# Run each package found
```

**Pass criteria**: all tests pass, exit code 0.

### 5. Style Greps (Go-specific)

Run deterministic style checks:

```bash
# File-name audit: no underscores except _test.go
git diff --name-only --diff-filter=A HEAD | grep -E '\.go$' | grep -E '_.+_' | grep -v '_test\.go$'

# Comment density check (warn if >15%)
for f in $(git diff --name-only --diff-filter=AM HEAD | grep '\.go$'); do
  awk -v f="$f" 'BEGIN{c=0;t=0} /^[[:space:]]*\/\//{c++} {t++} END{ if (t>0 && c*100/t > 15) printf "%s: %d%% comment density\n", f, c*100/t }' "$f"
done

# Modern-Go patterns scan
git diff --name-only --diff-filter=AM HEAD | grep '\.go$' | xargs grep -nE \
  'wg\.Add\(1\)|interface\{\}|errors\.As\(|sort\.Slice\(|time\.Now\(\)\.Sub\(|for [a-z]+ := 0; [a-z]+ <|context\.Background\(\) *$' 2>/dev/null
```

**Pass criteria**: no output from any grep.

## Execution

Run gates in order. Stop at first failure:

1. Lint → if fail, fix and re-run
2. Format → if fail, format and re-run
3. Typecheck → if fail, fix and re-run
4. Style greps → if fail, fix and re-run
5. Tests (testing phase) → if fail, fix and re-run

## Output

Report gate results:

```markdown
## Style Gate Results
- Lint: PASS / FAIL ({issues})
- Format: PASS / FAIL ({files})
- Typecheck: PASS / FAIL ({errors})
- Style greps: PASS / FAIL ({patterns})
- Tests: PASS / FAIL ({count}) / SKIPPED
```

## Rules

- **Never skip gates**: all must pass before handoff
- **Fix before handoff**: do not pass broken code to the next phase
- **Scoped only**: run checks on changed paths, not full suite
- **Zero LLM tokens**: all checks are deterministic commands
