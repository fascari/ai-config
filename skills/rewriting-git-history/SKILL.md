---
name: rewriting-git-history
description: "Use when text, filenames, or files must be removed or replaced across the entire git history of a repository. Applies when `git commit --amend` or `git rebase` cannot reach the target commits, when scrubbing or purging content from every commit, when performing bulk metadata rewrites (author email, paths, encoding), or when redirected by another skill that detected the need for a full-history rewrite. Tool: `git filter-repo`."
model: claude-haiku-4.5
agent_type: general-purpose
---

# Rewriting Git History

Removes or replaces strings, filenames, or files across **every commit** in a repository's history using `git filter-repo`. Preserves author and committer dates by default, so the GitHub timeline ("2 days ago") is unaffected, and only SHAs and content change.

## Execution Model

**Required model**: `claude-haiku-4.5` · **Agent type**: `general-purpose`

When dispatched by another skill (typically `committing-changes` redirecting to this one), this skill MUST run as an isolated task agent. The caller must use the `task` tool with `model: "claude-haiku-4.5"` and `agent_type: "general-purpose"`. Rationale: the workflow is rule-based (verify install, locate occurrences, present plan, wait for approval, execute, verify), so Haiku is fast and sufficient. All judgment about *what* to rewrite is delegated to the user through the mandatory approval step.

## HARD RULE: never rewrite history without approval

Force-pushing a rewritten history is destructive and affects every other clone of the repository. The full plan (see Step 3) must be presented and the user must explicitly approve with "yes", "ok", "proceed", or equivalent before any `git filter-repo` or `git push --force` is executed.

## When to use

Invoke this skill when content needs to be removed or replaced across **every commit** in the repository, not just the most recent one. Typical triggers:

- The user reports that something committed previously must no longer exist in any commit.
- A full-history search (`git log -S"<term>"`) shows occurrences across multiple commits that all need to go.
- A bulk metadata change (author email, file path, encoding) must apply uniformly across history.

If the change is localized to the last commit or the last few commits on the current branch, do **not** use this skill. See the "When NOT to use" table below.

## When NOT to use

| Situation | Use instead |
|---|---|
| Fix a typo or lint issue in the last commit | `git commit --amend` |
| Squash a fixup into an earlier commit on the same branch | `git rebase --autosquash` (see `committing-changes` skill) |
| Reorder or edit the last N commits | `git rebase -i` |
| Edit only your local branch (not yet pushed) | `git rebase` |

`git filter-repo` is for **full-history** rewrites. If the change is localized to a few recent commits, rebase is faster, safer, and doesn't force every collaborator to re-clone.

## Why dates are preserved

`git filter-repo` keeps both **author date** and **committer date** intact across the rewrite. GitHub uses committer date for relative-time labels, so the timeline on the web UI stays identical, and only the underlying SHAs change.

## Steps

### Step 1: verify the tool is installed

```bash
git filter-repo --version
```

If the command fails with `git: 'filter-repo' is not a git command`, install it:

```bash
# macOS — Homebrew (preferred)
brew install git-filter-repo

# Fallback — pip (Python)
pip3 install --user --break-system-packages git-filter-repo
# Ensure the install directory printed by pip is on PATH
```

> Present the install snippet to the user and wait for approval before running it.

### Step 2: identify what to rewrite

Locate every occurrence of the target content. Use:

```bash
git --no-pager log --all -S"<string>" --oneline       # commits that added/removed the string
git --no-pager grep -n "<string>" $(git rev-list --all) | head -20  # all occurrences
```

Decide on replacement(s). Replacements must be safe. Verify that the new string doesn't introduce conflicts or change behavior. For example, renaming a documentation reference is harmless, but renaming a real source file requires updating its imports first.

### Step 3: present the rewrite plan (REQUIRED before execution)

```
History rewrite plan:

  Repo:        <repo>
  Branch:      <branch>
  Tool:        git filter-repo

  Replacements:
    - "<original>" → "<replacement>"
    - "<original>" → "<replacement>"

  Affected commits: <N>
  Action after rewrite: force-push to origin/<branch>

WARNING:
  - All commit SHAs will change
  - Other clones must run: git fetch && git reset --hard origin/<branch>
    (or re-clone the repository)
  - Old SHAs may persist briefly in GitHub caches, forks, and PR diffs
  - If the leaked content was a real credential, ROTATE IT regardless of the rewrite

Proceed? [Y/N]
```

**WAIT for explicit approval** before executing Step 4.

### Step 4: execute the rewrite

```bash
# 1. Write replacement rules — one per line, literal==>replacement
cat > /tmp/replace-rules.txt <<'EOF'
<original-string>==><replacement-string>
<original-filename>==><replacement-filename>
EOF

# 2. Rewrite history (must run from inside the repo working tree)
git filter-repo --replace-text /tmp/replace-rules.txt --force

# 3. filter-repo removes 'origin' as a safety measure — restore it
git remote add origin <original-remote-url>

# 4. Force-push the rewritten history
git push --force origin <branch>

# 5. Clean up
rm /tmp/replace-rules.txt
```

Other useful filter-repo modes:

```bash
# Remove a file from all history
git filter-repo --path path/to/file --invert-paths --force

# Strip a directory entirely
git filter-repo --path some-dir/ --invert-paths --force

# Rewrite author/committer emails
git filter-repo --email-callback '
  return email.replace(b"old@example.com", b"new@example.com")
' --force
```

### Step 5: verify

```bash
# Confirm the target content is gone from every commit
git --no-pager log --all -S"<original-string>" --oneline
# (empty output = success)

# Confirm dates are preserved
git --no-pager log --pretty=format:"%h %ai (author) | %ci (committer)" -5
```

### Step 6: post-rewrite communication

Tell the user:
- All collaborators must run `git fetch && git reset --hard origin/<branch>` (or re-clone).
- Any open PRs against the rewritten branch will need to be rebased or recreated.
- If the leaked content was a credential, **rotate the credential**. Rewriting history doesn't retroactively secure a value that was already exposed publicly.

## Quick reference

| Need | Command |
|---|---|
| Replace strings everywhere | `git filter-repo --replace-text <rules-file>` |
| Remove a file from history | `git filter-repo --path <file> --invert-paths` |
| Strip a directory | `git filter-repo --path <dir>/ --invert-paths` |
| Change author/committer email | `git filter-repo --email-callback <python-snippet>` |
| Limit to specific refs | `git filter-repo --refs <ref> --force` |

## Common mistakes

| Mistake | Fix |
|---|---|
| Running filter-repo and then `git push` (without `--force`) | filter-repo strips `origin`. Run `git remote add origin <url>` then `git push --force` |
| Assuming the rewrite secures a leaked credential | History is rewritten, but old SHAs may persist in caches/forks. **Rotate the credential anyway.** |
| Using filter-repo for a fixup in the last few commits | Use `git rebase --autosquash --committer-date-is-author-date` instead. Faster, and doesn't disrupt collaborators |
| Forgetting that other clones still have old SHAs | Notify all collaborators immediately after the force-push |
| Replacing a string without checking it doesn't break the build | Verify replacements are safe in context (e.g., renaming a real source file requires updating imports) |

## Anti-patterns

| Wrong | Correct |
|---|---|
| Force-push rewritten history without user approval | Always present the plan and wait for explicit "yes" |
| Use filter-repo to edit the last commit | Use `git commit --amend` |
| Use filter-repo to squash a fixup | Use `git rebase --autosquash` |
| Skip credential rotation because "history is rewritten" | Rotate any leaked credential regardless of the rewrite |
