---
name: creating-pull-request
description: Use when opening a GitHub pull request for a branch that has commits ready for review
---

# Creating Pull Request

Analyzes the current branch, gathers context from commits and changed files,
generates a complete Pull Request description following the project template,
determines the correct assignee, labels, and target branch, then opens the PR
via GitHub CLI after explicit user approval.

## When to use

- User asks to open or create a PR
- User says "open a pull request", "create PR for this branch"
- User types /create_pr
- Branch is ready for review with commits pushed

## Steps

### Prerequisites

- GitHub CLI (`gh`) must be authenticated: `gh auth status`
- You must be on a feature branch, not the repo's default branch

### Step -1: Calibrate against this repo, do not assume

Conventions below are defaults, not truth. Before writing anything, read what this
repo actually does — every assumption in this skill has been wrong in some repo.

```bash
# default branch (may be master, main, develop, trunk...)
gh repo view --json defaultBranchRef --jq .defaultBranchRef.name

# the template this repo actually uses
cat .github/pull_request_template.md 2>/dev/null || ls .github/PULL_REQUEST_TEMPLATE* 2>/dev/null

# how long real PR bodies are, and how much the Test section gets
for n in $(gh pr list --state merged --limit 8 --json number --jq '.[].number'); do
  b=$(gh pr view $n --json body --jq .body)
  printf "#%-6s %3s lines (Test: %2s)\n" "$n" "$(echo "$b" | wc -l)" \
    "$(echo "$b" | sed -n '/## Test/,$p' | wc -l)"
done

# read two or three in full to catch tone and depth
gh pr view <n> --json body --jq .body

# labels that exist here
gh label list --limit 40
```

**Match the observed length.** If merged PRs run ~15 lines with a one-line Test
section, a 60-line body with a table is wrong no matter how good the content is.
Include only what a reviewer or merger needs and cannot get from the diff:
cross-repo merge ordering, silent behavioural changes, production risk. Cut
anything the diff already shows.

### Step -0.5: Issue tracker is not always JIRA

The template's tracker section may expect Asana, Linear, GitHub Issues, JIRA, or
nothing. Read the template heading and match the repo's own habit.

Trackers with a short human key (JIRA `PROJ-123`, Linear `ENG-45`) read well inline.
Trackers with a long numeric GID (Asana) do not — prefer a named link:

```markdown
## Asana

[task](https://app.asana.com/1/<workspace>/project/<project>/task/<gid>)
```

Ask the user if the repo's habit and this guidance disagree; do not silently
"improve" an established convention.



### Step 0: Verify Branch Name Is CI-Safe

Before naming a branch (or before pushing further work to one already named), check whether this repo's CI derives any artifact name directly from the branch name: Docker image tags, Kubernetes resource names, Cloud Build tags, etc.

```bash
grep -rn "BRANCH_NAME\|branch_name\|\$BRANCH" cloudbuild*.yml .github/workflows/ 2>/dev/null
```

If found, assume special characters are unsafe until proven otherwise. The most common failure: a branch name containing `/` gets embedded into a Docker tag, and Docker tags cannot contain `/` (only the repository/path portion before the final `:` can). A branch like `service/some-change` will build fine locally but fail in CI with `invalid reference format`.

If the current branch already has this problem (build fails with a tag/reference format error referencing the branch name):
1. Rename locally: `git branch -m new-name-without-slashes`
2. Push the renamed branch: `git push -u origin new-name-without-slashes`
3. GitHub does not let you change a PR's head branch. If a PR is already open on the old name, close it and open a new one on the renamed branch (only do this with zero review activity, see `committing-changes`'s Rebasing and Force-Push section); otherwise ask the user how they want to proceed.
4. Delete the orphaned old remote branch once the new PR is confirmed working: `git push origin --delete old-branch-name`.

When in doubt about the safe format for a given repo, use hyphens instead of slashes: it is universally safe and often matches the team's real convention anyway.

### Step 1: Gather Branch Context

```bash
git --no-pager branch --show-current
git --no-pager log main..HEAD --oneline
git --no-pager log develop..HEAD --oneline
git --no-pager diff main --stat
git --no-pager diff develop --stat
```

Substitute the real default branch from Step -1 for `main`/`develop` above.

**Branch naming is repo-specific.** A `feature/`-`bugfix/`-`hotfix/` scheme is one
convention among several; many repos use `service-topic` with no prefix, and some
**forbid** `/` outright because CI derives Docker tags from the branch name (Step 0).
Derive the type from the commits and the diff, not from a prefix that may not exist.

| Branch prefix, where the repo uses one | Base branch | Default label |
|---|---|---|
| `feature/` | default branch, or `develop` where that exists | `feature` |
| `bugfix/` | default branch, or `develop` where that exists | `bug` |
| `hotfix/` | default branch | `bug`, `hotfix` |
| no prefix | default branch | infer from the change |

If the base branch is ambiguous, compare divergence against each candidate:

```bash
for b in $(git branch -r --format='%(refname:short)' | grep -E 'origin/(main|master|develop|trunk)$'); do
  echo "$b: $(git rev-list --count HEAD ^$b)"
done
```

### Step 2: Analyze Commits and Changed Files

```bash
git --no-pager log develop..HEAD --format="%s%n%b" 2>/dev/null || git --no-pager log main..HEAD --format="%s%n%b"
git --no-pager diff develop --name-only 2>/dev/null || git --no-pager diff main --name-only
```

Read the most relevant changed files to understand:
- What domains/features were touched
- Whether new endpoints were added (→ API docs / permissions changed?)
- Whether migrations exist (→ note in description)
- Whether tests were added/updated

### Step 3: Determine PR Metadata

**Title**: a brief, imperative description of the change.
```
{brief description of the change}
```
Example: `Add get user endpoint`

**Assignee**: current git user
```bash
git --no-pager config user.email
gh api user --jq '.login'
```

**Labels**, choose ALL that apply (labels can be combined):

| Condition | Label(s) |
|---|---|
| Branch is `feature/` | `feature` |
| Branch is `bugfix/` | `bug` |
| Branch is `hotfix/` | `bug` + `hotfix` |
| New feature or improvement (not a bug) | `enhancement` |
| Auto-backport from main → develop | `backport` |
| Part of a versioned release | `release` |
| Only docs/config changed | `documentation` |
| Dependency file updated | `dependencies` |

Labels are **not mutually exclusive**, a `feature` PR that also improves existing behaviour should have both `feature` and `enhancement`.

**The table above is a suggestion, not an inventory.** Many repos have none of these
labels; some auto-apply labels by path with a bot (`go`, `javascript`, `dependencies`),
making manual ones redundant. Use `gh label list` from Step -1, apply only labels that
exist, and **apply none** when recent merged PRs carry none. Do not create labels to
satisfy this table.

**Reviewers**: do NOT set automatically, user will assign.

### Step 4: Generate PR Body

**Use the repo's own template, whatever its sections are.** Do not impose the
section names below; they are illustrative. Common shapes seen in the wild:

- `Description` / `Checklist` / `References`
- `Asana` / `Before` / `After` / `Test`
- no template at all — then match the shape of recent merged PRs

Write at the observed length from Step -1. Aim for high level: what problem this
solves, what changed, what a reviewer must watch for. The diff carries the detail;
the body carries the judgement.

**What earns space in a body:**

- Cross-repo or cross-PR **merge/deploy ordering**, when getting it wrong breaks production
- Behaviour that changes for someone **without their code changing** (name the owners)
- A measurement that justifies the change, when one exists
- Rollback caveats that are not obvious (e.g. "reverting this alone is unsafe")

**What does not:**

- Restating the diff file by file
- Test commands, when the repo's habit is "CI is enough"
- Tables and formatting the team never uses
- Implementation detail a reviewer reads faster in the code

**Checklist sections**, where the template has one: pre-check only items the analysis
actually verified. Leave the rest `[ ]` rather than checking optimistically — an
untruthful checklist is worse than an unchecked one.

**Test section**: match the repo's habit exactly. Many teams write one line
("CI is enough", "- Test suite"). Give real steps only when there is a UI or manual
flow a reviewer must exercise themselves.

### Step 5: Present Plan for Approval

Present the full PR plan before any action:

```
PR Plan:

  Title:       Add get user endpoint
  Base branch: main
  Assignee:    @me
  Labels:      feature, enhancement
  Draft:       No
  Push:        git push

  ── Body Preview ──────────────────────────────────────────

  ## Description
  This PR adds the get user endpoint that...
  ...

  ## Author' checklist
  * [x] Did I review my commit logs...
  ...

  ──────────────────────────────────────────────────────────

  Command to be executed:
  gh pr create \
    --title "Add get user endpoint" \
    --base main \
    --assignee "@me" \
    --label "feature" \
    --body-file /tmp/pr-body.md

Open this PR? [Y/N]: or type 'draft' to open as Draft PR
```

**WAIT for explicit approval**: "yes", "ok", "y", "proceed", or "draft".

### Step 6: Write Body to Temp File and Open PR

**ALWAYS use the file-writing tool** (`Write`, `create_file`, or whatever the harness
calls it) to write the PR body. Never use a shell heredoc (`cat > file << 'EOF'`) or
inline Python: heredocs lock the terminal and corrupt multi-line content in zsh.

#### Body formatting rules

- Every Markdown section (`## Title`) must be preceded by a **blank line**
- Every paragraph must be separated by a **blank line**
- Each sentence/paragraph must be on a **single unbroken line**: no mid-sentence line wraps
- Blockquotes (`>`) must have a blank line before and after them
- Checklist items must have a blank line after their section header

#### Example: correct body file content

```markdown
## Description

This PR adds the get user endpoint that retrieves a user profile by ID.

The new handler reads the user ID from the request path and delegates lookup to the service layer.

> **Note:** any relevant side-effect or cherry-pick note goes here as a single line.
```

The section names come from **that repo's** template. A repo using
`Asana / Before / After / Test` gets those headings instead, with the same formatting
rules applied.

#### Workflow

1. Push the branch before creating the PR:
   - If the user passed `--no-verify` → `git push --no-verify`
   - If the project has pre-push validation hooks (linting, API spec validation, etc.) → `git push` (no `--no-verify`) so hooks run
   - Otherwise → `git push`
2. Use the file-writing tool to write the body to `/tmp/pr-body.md`
3. Then run:

```bash
# Open the PR
PAGER=cat gh pr create \
  --title "{title}" \
  --base {base-branch} \
  --assignee "@me" \
  --label "{label1}" \
  --label "{label2}" \
  --body-file /tmp/pr-body.md
```

If user typed `draft`, add `--draft` flag.

> **Note on labels**: Labels must already exist in the GitHub repository. If a label does not exist, `gh pr create` will return an error. In that case, create the PR without the missing label and inform the user:
> ```bash
> PAGER=cat gh label create "migration" --color "#0075ca" --description "Contains DB migration"
> ```

### Step 7: Verify and Present Result

```bash
gh pr view --web   # opens in browser (optional, ask user)
gh pr view         # shows PR summary in terminal
```

Present the PR URL and a summary to the user.

## PR Body Template

Read the project PR template via `read_file`: `.github/pull_request_template.md`

Use that template structure when generating the body. Fill in each section based on branch context,
commits, and changed files. Pre-check only checklist items the analysis actually verified.

## Labels

Use `PAGER=cat gh label list` to discover available labels. Choose ALL that apply:

| Branch prefix | Default label(s) |
|---|---|
| `feature/` | `feature` |
| `bugfix/` | `bug` |
| `hotfix/` | `bug` + `hotfix` |

Labels are not mutually exclusive, combine freely (e.g., `feature` + `enhancement`).

## Anti-patterns (never do these)

| Wrong | Correct |
|---|---|
| Open PR without user approval | Always show plan and wait for `[Y/N]` |
| Hardcode reviewer usernames | Never set reviewers automatically |
| Use shell heredoc for body (`<< 'EOF'`) | Use the file-writing tool to write `/tmp/pr-body.md` |
| Use inline Python one-liner to write body | Use the file-writing tool to write `/tmp/pr-body.md` |
| Paragraphs without blank lines between them | Every paragraph separated by one blank line |
| Mid-sentence line breaks in description | Each sentence/paragraph on a single unbroken line |
| Run `gh` commands without `PAGER=cat` | Always prefix `gh` with `PAGER=cat` |
| Guess labels that don't exist | Check label existence, create if missing |
| Skip checklist items silently | Mark unchecked items with `[ ]` + note why |
| Run `git push` for pure docs/config changes when pre-push hooks don't apply | `git push --no-verify`: hooks are not relevant |
| Use `--no-verify` when project validation hooks must run | Always `git push` (no `--no-verify`) when hooks are mandatory |
| Add `Co-authored-by: Copilot` to the PR body | The `Co-authored-by` trailer belongs only in **git commit messages**: never in the PR description or any GitHub comment |
| Assume any branch name is CI-safe | Run Step 0: check whether CI derives Docker tags or other artifact names from the branch name before naming or pushing |





