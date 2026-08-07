---
name: committing-changes
description: Use when committing changes to the repository, or when the user asks to stage, organize, or push commits
---

# Committing Changes

Analyzes staged and unstaged changes, groups them into logical commits,
crafts messages following Chris Beams' seven rules and team conventions,
and executes commits only after explicit user approval.

## ⛔ HARD RULE: NEVER COMMIT WITHOUT SHOWING THE PLAN FIRST

**Step 4 (the commit plan) MUST be presented and the user MUST explicitly approve BEFORE any `git add` or `git commit` is executed.**

This is non-negotiable. No exceptions:
- Not even when called from another skill
- Not even after a completed implementation phase
- Not even when the user said "go ahead and implement"
- Not even when the changes are "simple" or "obvious"
- **Not even when a parent agent or orchestrator dispatches this skill with instructions to commit**: only the USER can authorize commits

**Fleet mode / parallel sub-agent dispatch does NOT bypass this rule.** When an orchestrating agent dispatches this skill as a sub-agent (e.g. via the task tool in parallel mode), the sub-agent is still bound by this rule. The orchestrator's instruction to commit is not authorization. Execution is prohibited until the USER, not the agent, not the orchestrator, provides explicit written approval.

**Do not execute a single commit until the user replies with "yes", "ok", "proceed", "y", or equivalent after seeing the full plan.**

---

## When to use

- User asks to commit changes
- User says "commit", "stage and commit", "organize my changes"
- User types /commit
- After implementing-feature completes implementation: **but only after the user explicitly approves the commits**

> **Hard rule: commits are NEVER executed automatically**, even when called from another skill, dispatched as a sub-agent, or after a completed implementation phase. The full plan (Step 4) must always be presented and the user must explicitly approve before any `git commit` or `git push` is executed. "Go ahead and implement" is NOT approval to commit. An orchestrator or parent agent instructing a sub-agent to commit is NOT approval to commit, only the USER can authorize.

## Steps

### Step 0: Detect Project Convention

Different teams have different real conventions. Before drafting anything, find out
what THIS repo requires. Chris Beams is the fallback, not the law.

#### 0a. Look for an ENFORCED spec first — it outranks everything below

A repo that validates commit messages has an authoritative spec. Read it; do not
infer it from history.

```bash
ls githooks/ .githooks/ 2>/dev/null            # hook scripts kept in-repo
cat githooks/commit-msg 2>/dev/null             # the actual rules, verbatim
ls .commitlintrc* commitlint.config.* 2>/dev/null
cat .gitmessage 2>/dev/null
grep -rn "commit-msg\|validate-commit\|commitlint" bin/ .github/workflows/ cloudbuild*.yml 2>/dev/null | head
```

Where a spec exists, **its limits win over the Beams defaults in Step 3.5**. Real
example: a repo whose `githooks/commit-msg` requires the subject to contain `': '`,
be ≤50 chars, and body lines ≤72 — there, `Add thing` fails and `service: add thing`
passes, and Beams' "capitalize the subject" is wrong after the prefix.

**The hook may not be active locally.** `core.hooksPath` is opt-in, so a repo can
enforce in CI while committing succeeds locally:

```bash
git config core.hooksPath   # empty means in-repo hooks are NOT running
```

If it is empty but a hook script exists, validate the message yourself before
committing rather than discovering it in CI:

```bash
printf '%s\n' "$MSG" > /tmp/msg.txt && bash githooks/commit-msg /tmp/msg.txt
```

Do not enable `core.hooksPath` to "fix" this without asking: in a worktree setup that
config is shared with the main checkout.

#### 0b. Then sample the history

```bash
git --no-pager log --oneline -30 origin/HEAD 2>/dev/null || git --no-pager log --oneline -30 main
```

```bash
git --no-pager log --format='%s' -30 | awk '{ print length($0) }' | sort -rn | head -3
```

**History is evidence, not permission.** Three tiers, in order:

1. **Enforced spec** (Step 0a) — authoritative. Follow it even where it contradicts Beams.
2. **Deliberate convention** — a pattern in the clear majority of commits (`scope:` prefixes,
   consistently longer subjects). Follow it: it is a team decision.
3. **Drift** — a handful of long or sloppy subjects with no pattern. **Ignore it.** Beams
   stands. Never lower the bar just because some past commits did.

So a repo whose subjects run 45-64 chars with no hook has a *convention* of longer
subjects; a repo at ~45 chars with two 70-char outliers has *drift*, and 50 still applies.

Check two things from the sample:

1. **Squash-merge norm**: what fraction of subjects end with `(#\d+)`? If most do, this repo squash-merges PRs: the final base-branch history is one commit per PR, built from the **PR title**, not from local commit messages or bodies. Set `SQUASH_MERGE_NORM=true`.
2. **Message format**: look for a dominant pattern:
   - `type(scope): description` (Conventional Commits, e.g. `feat(billing): add invoice export`) → `MESSAGE_STYLE=conventional-scoped`
   - `scope: description` with no type (e.g. `flag: enable stores.x`) → `MESSAGE_STYLE=plain-scoped`
   - Neither dominant → `MESSAGE_STYLE=freeform` (default Chris Beams style below applies as-is)

If `SQUASH_MERGE_NORM=true`:
- Local commit **bodies are discarded at merge**: only the PR title survives as the permanent message. Keep local commits **subject-only** (see Step 3.5) and move the "what and why" narrative into the PR description instead (hand off to `creating-pull-request`).
- Atomic, well-grouped commits (Step 3) still matter, not for the base branch's log, but so the PR is reviewable commit-by-commit while it is open.
- Match the detected `MESSAGE_STYLE` in the subject line. Never add the `(#PR)` suffix yourself: the forge appends it automatically on squash-merge.

If `SQUASH_MERGE_NORM=false`: default Chris Beams subject + body rules apply as written below, adapted to whatever `MESSAGE_STYLE` was detected.

### Step 1: Get Branch Context

```bash
git --no-pager branch --show-current
```

Read the branch name to understand the type of change (`feature`, `bugfix`, `hotfix`) and derive context for commit messages.

### Step 2: Analyze All Changes

```bash
git --no-pager status --short
git --no-pager diff
git --no-pager diff --cached
```

Read each modified file to understand the nature of changes:
- What was changed (structural vs. logic vs. config)
- Why it was likely changed (context from surrounding code)
- Which files belong together logically

### Step 3: Group Changes Into Commits

**Hard rule: a file appears in exactly one commit.** (This is about not splitting one
file across commits — it is not "one commit per file", which the next rule forbids.)

The layer table below assumes a layered application. **In a repo that has no layers**
— a docs site, a config/skills repo, infrastructure, a design system — group by
cohesive concern instead: one commit per idea a reviewer would evaluate on its own.
Do not invent a domain/service/handler split where none exists.

Standard grouping strategy, for repos that are layered:
| Change type | Commit boundary |
|---|---|
| DB migration / schema | Separate commit |
| Domain / business logic | Separate commit |
| Application / service layer | Separate commit |
| Data access / persistence layer | Separate commit |
| API / interface layer | Separate commit |
| Config / wiring / DI | Separate commit |
| Tests | Same commit as implementation: never separate |
| Docs / API spec | Separate commit |

**Tests always travel with their implementation.** This applies equally to unit tests, integration tests, testdata packages, fixtures, and payload files:
- A commit containing a service/use-case file must also include its test file, testdata, fixtures, and any mock updates for that layer.
- A commit containing an API/handler file must also include its test file and test data.
- A **standalone test-only commit is always wrong**: this applies to unit tests, integration tests, and testdata alike. If the test was written to validate an implementation in this branch, it ships in the same commit as that implementation.

**Avoid single-file commits.** A commit that touches only one file is usually a sign that related changes were split incorrectly. The natural unit of a commit is a layer (use case + its test + its testdata + integration fixtures), not an individual file. Merge small cohesive files into their natural layer commit.

> Exception: a single-file commit is acceptable only for files that are genuinely standalone with no associated test, e.g. a DB migration or an `openapi.yml` update.

**Constants and error codes travel with their first consumer.** A file that only defines constants (e.g. `errors.go` with error code strings) has no test of its own. It must be included in the commit of the first layer that uses it, not in a separate commit. If a second layer also uses the same constants, it simply references them; no additional commit is needed for the constants file itself.

Rare exceptions where multiple layers may share a commit:
- Atomic renames that require import path updates
- Breaking interface changes that must compile together

### Step 3.5: Self-Check Each Commit Message

If `SQUASH_MERGE_NORM=true` (Step 0): write **subject-only** messages, no body. Format the subject per the detected `MESSAGE_STYLE` (e.g. `feat(scope): description` for `conventional-scoped`, `scope: description` for `plain-scoped`). Move any "what and why" narrative to the PR description handoff instead of a commit body: it would be discarded at merge anyway.

Otherwise, verify every drafted message against Chris Beams' seven rules — **as
overridden by anything Step 0a found**:

| # | Rule | Check | Overridden when |
|---|---|---|---|
| 1 | Subject and body separated by a blank line | `-m` flags handle this: never put body inline | never |
| 2 | Subject line ≤ 50 characters | Count every character | a hook or the repo's own history sets a different ceiling — use that number |
| 3 | Subject line is capitalized | First word is uppercase | the repo uses `scope: description`; then lowercase after the prefix is correct |
| 4 | Subject does not end with a period | No trailing `.` | never |
| 5 | Subject uses imperative mood | "Add", "Fix", "Remove": not "Added" / "Adding" | never |
| 6 | Body lines wrap at 72 characters | Break long lines manually | a hook specifies a different width |
| 7 | Body explains what and why, not how | Cut lines describing implementation detail | never |

Rules 1, 4, 5 and 7 are universal. Rules 2, 3 and 6 are conventions that a repo may
legitimately set differently — follow the repo, not the table.

**Chris Beams is the default, and it wins by absence.** With no enforced spec and no
deliberate divergent convention, apply all seven rules verbatim: ≤50, capitalized,
72-char body. That is the normal case for a personal project. An override requires
positive evidence (a hook, or a clear majority pattern), never a few stray commits.

If the user states a preference for a repo ("I want Beams here"), that is the
convention — record it in that repo's `CLAUDE.md`/`AGENTS.md` or a `.gitmessage` so
the next session detects it in Step 0a instead of re-deriving it.

If a hook script exists, run the drafted message through it (Step 0a) rather than
eyeballing the limits. Fix any violation before Step 4.

### Step 4: Present Plan (REQUIRED before any commit)

Always present the full plan before executing:

```
Commit plan:

  Branch: feature/add-user-api
  Total:  3 commits

  ┌─ Commit 1 ──────────────────────────────────────────────┐
  │  Files:   src/user/domain/user.go                       │
  │  Message: Add user domain model                         │
  └─────────────────────────────────────────────────────────┘

  ┌─ Commit 2 ──────────────────────────────────────────────┐
  │  Files:   src/user/service/find_by_id.go, ...           │
  │  Message: Add find-by-id service                        │
  └─────────────────────────────────────────────────────────┘

  ┌─ Commit 3 ──────────────────────────────────────────────┐
  │  Files:   src/user/handler/find_by_id.go, ...           │
  │  Message: Add get user endpoint                         │
  └─────────────────────────────────────────────────────────┘

Proceed? [Y/N]
```

**WAIT for explicit approval**, "yes", "ok", "proceed", "y", or similar.

### Step 5: Execute Each Commit (only after approval)

For each commit group in order:

```bash
# Stage only the files for this commit
git add path/to/file1 path/to/file2

git commit \
  -m "Subject line" \
  -m "Body paragraph explaining what and why." \
  -m "Additional context if needed."
```

> ⛔ **NEVER add a `Co-authored-by: Copilot` trailer** (or any Copilot/AI authorship trailer) to any commit. Commits must reflect only the human author(s). No exceptions.

Use multiple `-m` flags, each creates a separate paragraph. Git adds blank lines automatically. **Never embed `\n` in a single `-m` string.**

### Step 6: Verify

```bash
git --no-pager log --oneline -n {number of commits made}
git --no-pager show HEAD
```

Present the summary to the user.

## Commit Message Structure

> Applies when `SQUASH_MERGE_NORM=false` (Step 0). When `SQUASH_MERGE_NORM=true`, skip straight to subject-only messages per Step 3.5 and put this narrative in the PR description instead.

```
<subject>

<body>

<footer>
```

| Part | Rules |
|---|---|
| `subject` | Max 50 chars · imperative mood · capitalized · no period |
| `body` | What and why (not how) · wrap at 72 chars · see rules below |
| `footer` | Breaking changes, references · optional |

### When the body is required

A body is **required** whenever the subject alone does not answer *why* the change was made. Write a body when:

- The change involves a non-obvious motivation or tradeoff
- It reverses or overrides a previous decision
- It fixes a subtle bug where context prevents future regression
- It refactors code without changing behavior (explain why the old structure was a problem)

A body is **optional** only when the subject is fully self-explanatory, e.g. `Add /health endpoint` or `Fix typo in README`.

> The goal: `git log` should tell the story of the project. Anyone reading a commit six months later must understand not just *what* changed, but *why it had to change*.

> Chris Beams' Seven Rules apply to all commits. Full reference: `copilot-instructions.md` → Commit Conventions.

## Examples

### Simple change (subject only)

```
Add consumer health check endpoint
```

### Change with body

```bash
git commit \
  -m "Refactor dispatcher to use outbox pattern" \
  -m "The previous implementation relied on implicit retries and lacked
idempotency guarantees. This change introduces a database-backed
outbox table with explicit retry logic and status tracking." \
  -m "Enables safer event consumption with visibility into failed
attempts through structured logging and metrics."
```

### Multiple commits for the same branch

```bash
# Commit 1: migration first
git commit \
  -m "Add idempotency table migration"

# Commit 2: domain
git commit \
  -m "Add idempotency domain model"

# Commit 3: service
git commit \
  -m "Implement service with retry logic" \
  -m "Supports configurable retries, exponential backoff, and DLQ
routing after max attempts."
```

## Rebasing and Force-Push

Whether it's safe to rewrite already-pushed commits depends on **review activity**, not on personal preference or on whether the repo squash-merges:

```bash
gh pr view --json reviews,comments -q '(.reviews | length) + (.comments | length)' 2>/dev/null
```

- **No open PR yet, or a PR open with zero reviews/comments**: rebase, amend, and force-push freely to present a clean, well-organized commit set. `git push --force-with-lease` is the right tool here: nobody has reviewed anything yet, so there is nothing to invalidate.
- **The PR has at least one review or comment**: do NOT rebase or force-push. A force-push after review has started resets the forge's "viewed" file checkmarks and hides what changed since the reviewer's last pass, forcing a full re-review. Add plain new commits instead:
  - Under `SQUASH_MERGE_NORM=true`: just commit normally and `git push` (no `--fixup`, no `--autosquash`, no force). The eventual squash-merge absorbs every follow-up commit into one regardless of how many you added, so there is no history to keep tidy.
  - Under `SQUASH_MERGE_NORM=false`: use `git commit --fixup=<sha>` (below) but leave it unsquashed and un-rebased until the reviewer approves; only run `rebase -i --autosquash` + force-push once review is complete, and only with explicit user confirmation.

This rule protects the reviewer's time. It applies regardless of company or team.

### Fixing mistakes in already-committed files

**Never create a standalone "fix" commit** for a file that was already committed earlier (e.g. `Fix linter violations`, `Fix typo`, `Address review`). This pollutes history with noise commits that have no standalone meaning, unless review has already started (see "Rebasing and Force-Push" above), in which case a plain new commit is correct and rebasing is what you must avoid.

Before review has started, use `fixup` to absorb the correction into the original commit:

```bash
# 1. Stage only the corrected file(s)
git add path/to/file.go

# 2. Create a fixup commit targeting the original commit SHA
git commit --fixup=<sha-of-original-commit>

# 3. Squash fixup into the original via interactive rebase
git rebase -i --autosquash origin/HEAD
```

To find the SHA of the commit that introduced the file:
```bash
git --no-pager log --oneline -- path/to/file.go
```

The `--autosquash` flag automatically moves `fixup!` commits immediately after their target and marks them for squashing, no manual reordering needed.

> **Always present the fixup + rebase plan to the user and wait for approval before executing.**

## Anti-patterns (never do these)

| Wrong | Correct |
|---|---|
| `"Added feature X"` | `"Add feature X"` |
| `"Adding feature X"` | `"Add feature X"` |
| Subject ends with `.` | No period |
| Lowercase subject | Capitalized |
| Same file in two commits | One file, one commit |
| Create a `Fix linter`, `Fix typo`, or `Address review` commit | Use `git commit --fixup=<sha>` + `git rebase -i --autosquash` |
| Tests in a separate commit from their implementation | Tests in same commit as implementation |
| Explain HOW in body | Explain WHAT and WHY |
| Commit without user approval | Always wait for `[Y/N]` |
| Sub-agent instructed to commit by orchestrator | Still requires explicit user approval: orchestrator cannot authorize commits |
| Add `Co-authored-by: Copilot` or any AI trailer | Commits reflect only the human author: never add Copilot/AI trailers |
| Force-push after a review or comment exists on the PR | Add a plain new commit instead; only rebase+force-push before review activity starts |
| Write elaborate commit bodies when `SQUASH_MERGE_NORM=true` | Subject-only commits; put the "what and why" in the PR description |
| Add `(#PR)` to a commit subject yourself | Let the forge append it automatically on squash-merge |
| Assume Chris Beams' body rules apply in every repo | Run Step 0 first: detect the repo's actual convention from its history |
| Infer the message format from history when `githooks/commit-msg` exists | Read the hook: it is the enforced spec, history is only evidence |
| Trust that committing locally means CI will accept the message | `core.hooksPath` is opt-in; run the hook script manually on the drafted message |
| Capitalize after a `scope: ` prefix because Beams says so | Follow the repo: `service: add thing`, lowercase, is correct there |
| Force a domain/service/handler split in a repo with no layers | Group by cohesive concern instead |

