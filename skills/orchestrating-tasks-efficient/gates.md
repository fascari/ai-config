# Orchestrating Tasks Efficient: Gates

> Sub-file of `skills/orchestrating-tasks-efficient/SKILL.md`. Read SKILL.md first for Critical Rules and Pre-Dispatch Checklist.

This file defines the deterministic Go gates that run in every mode, plus the conditional LLM gates used in Standard and High Assurance.

---

## Deterministic Go Gates (mandatory in every mode)

These gates are zero-token, command-based checks. They must pass before any LLM review or status transition.

### 1. Format

```bash
gofmt -l $(git diff --name-only --diff-filter=AM HEAD | grep '\.go$')
```

Pass: no files listed.

### 2. Compile

```bash
go build ./path/to/changed/...
```

Pass: exit code 0.

### 3. Lint

```bash
golangci-lint run ./path/to/changed/... | head -50
```

Pass: exit code 0, no issues.

### 4. Typecheck

```bash
go vet ./path/to/changed/...
```

Pass: exit code 0.

### 5. Relevant tests

```bash
# Unit tests
go test ./path/to/package/... -count=1 -timeout=60s

# Integration tests
grep -rl '//go:build integration' path/to/domain/ | xargs -I{} dirname {} | sort -u
# Run each package found
```

Pass: all tests pass, exit code 0.

### 6. Race detector

Run when the change touches goroutines, channels, `sync`, or concurrent access:

```bash
go test ./path/to/package/... -race -count=1 -timeout=120s
```

Pass: no race detected.

### 7. Style compliance greps

Run all four checks:

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

# Dead-code: every newly exported symbol must have an external caller
```

Pass: no output from any grep.

### 8. API compatibility check

When the diff changes exported functions, interfaces, or HTTP contracts:

- Verify no exported signature changed without a compatibility decision.
- Check that `context.Context` is propagated through new calls.
- Check that errors are wrapped with `%w` and compared with `errors.Is` / `errors.As`.

### 9. Package naming and structure

- No new `utils`, `helpers`, `common`, `misc`, `shared`, `base`, `core`, `types`, or `model` packages.
- Handler packages are per-operation (`handler/{operation}/`).
- Domain types have no `json`, `gorm`, or framework tags.
- Models stay inside `repository/` and do not leak.

---

## Completion Gate

Run all applicable deterministic gates in order. Stop at first failure.

```markdown
## Completion Gate Results
- gofmt: PASS / FAIL
- compile: PASS / FAIL
- lint: PASS / FAIL
- typecheck: PASS / FAIL
- tests: PASS / FAIL / SKIPPED
- race detector: PASS / FAIL / SKIPPED
- style greps: PASS / FAIL
- API compatibility: PASS / FAIL / N/A
- package structure: PASS / FAIL
```

On FAIL:

1. Present the exact failure to the user.
2. Update `progress.md` with the failed gate.
3. Wait for direction. Do not auto-dispatch a repair cycle.

On PASS:

1. Update `progress.md` with gate results.
2. In Lean: skip LLM review unless risk surfaced.
3. In Standard: proceed to the combined semantic review.
4. In High Assurance: proceed to Output Judge.

---

## Conditional LLM Gates

### Lean mode

- No LLM judge by default.
- Run a semantic review only when:
  - the change touches error handling, public API, or concurrency;
  - deterministic gates reveal a non-obvious issue;
  - the user explicitly asks for review.

### Standard mode

Combine Output Judge and `reviewing-code` into a single cross-vendor review.

Dispatch a `general-purpose` agent at Balanced tier (or Deep if risk is High). The agent must be from a different vendor than the implementer.

Prompt:

```unknown
You are a combined Output Judge and semantic reviewer. Do NOT act as a developer or helper.

## Context
slug: {slug}
plan dir: {plan_root}/{slug}/
context capsule: {plan_root}/{slug}/context-capsule.md

## Required steps
1. Read {plan_root}/{slug}/requirements.md (if it exists) and extract acceptance criteria.
2. Read {plan_root}/{slug}/context-capsule.md.
3. Run: git --no-pager diff HEAD~1 --stat
4. Run: git --no-pager diff HEAD~1
5. Run: git --no-pager diff --name-only HEAD~1.
   Flag as violation any modification to: `requirements.md`, `brief.md`.
   These files must only change during definition or planning with proper authorization.
6. For each AC, find explicit evidence in the diff: file path, function name, or test.
7. Check that modified files are within the scope in the capsule.
   Do not flag test files as out-of-scope violations; they are expected implementation evidence.
8. Review for semantic regressions, architecture violations, error handling, concurrency issues, and test quality.

## Output format

PASS
AC Coverage: N/N
Changed files: (list)
No blockers found.

OR

FAIL
Missing AC evidence:
- AC #N: "{ac text}": no implementation or test evidence found
Violations:
- {file} modified unexpectedly (protected or out-of-scope)
Blockers:
- [B1] {title}: {file} - {issue} - {fix}
```

On PASS:

1. Update `## Harness Gates` in `progress.md`: `Semantic Review: PASS`.
2. Transition `## Status` to `REVIEW`.

On FAIL:

1. Present the exact failure to the user.
2. Update `progress.md` with the blockers found.
3. Reset `## Status` to `IN_PROGRESS`.
4. Wait for explicit user direction: `retry`, `revise`, `skip`, or `abort`.
5. If the user chooses `retry`: dispatch a repair cycle to `implementing-feature` or `testing-implementation` as needed. Re-run the combined review after the fix. Max 2 repair cycles before escalation.
6. Do not auto-dispatch a repair cycle without user confirmation.

### High Assurance mode

Keep the gates from `skills/orchestrating-tasks/gates.md`:

- Critique gate before implementation (Deep, cross-vendor).
- Output Judge after implementation (Deep, cross-vendor).
- Semantic review after Output Judge (Deep, cross-vendor).

Each judge receives the diff and the capsule, not the full session history.

---

## Gate Avoidance Rules

- Do not run a Deep LLM gate when deterministic gates already cover the concern.
- Do not run `sanitizing-text` on gate results, lint output, or progress updates.
- Do not run AC coverage validation (equivalent to Output Judge) when `requirements.md` is absent. The semantic review component of the Standard combined review remains mandatory regardless: it still validates scope, architecture, regressions, error handling, concurrency, and test quality.
- Do not run the standalone Output Judge gate when `requirements.md` is absent in High Assurance. Proceed directly to semantic review.
- Do not run critique gate in Lean or Standard.

---

## Output Contract

Update `{plan_root}/{slug}/progress.md` after every gate run:

```markdown
## Harness Gates
- gofmt: PASS
- compile: PASS
- lint: PASS
- typecheck: PASS
- tests: PASS
- race detector: PASS / SKIPPED
- style greps: PASS
- API compatibility: PASS / N/A
- package structure: PASS
- Semantic Review: PASS / NOT_RUN / FAIL
- Output Judge: PASS / NOT_RUN / FAIL
- Critique Gate: PASS / NOT_RUN / FAIL
```

Only `orchestrating-tasks-efficient` updates `## Status` to `REVIEW` after all gates pass.
