---
name: reviewing-pull-requests
description: Use when asked to review, assess, or approve a teammate's pull request (a PR URL or number), or to check whether a PR delivers what its ticket asks. Not for reviewing your own uncommitted implementation against a plan, that is reviewing-code.
---

# Reviewing Pull Requests

## Overview

A PR review answers two questions: does this change do what its ticket and plan ask, no more and no less, and does it leave the codebase healthier? Approve when it does, not when it is perfect ([Google, The Standard of Code Review](https://google.github.io/eng-practices/review/reviewer/standard.html)).

Precision beats recall. Comments an author doesn't act on cost attention, and too many lead people to stop reading. Google retires automated checks whose findings go un-acted on more than 10% of the time (Sadowski et al., "Lessons from Building Static Analysis Tools at Google", CACM 2018). Fewer, verified, labelled findings beat a long list.

## Read-only by default

Never post, approve, request changes, comment on the tracker, or modify the working tree (no checkout, stash, reset). Read refs with `git fetch` + `git show <ref>:<path>` / `git diff`. Publishing the review is a separate step that needs the user's explicit approval of the exact text.

## Steps

1. **PR facts.** `gh pr view <n> --json title,body,baseRefName,headRefName,commits,files,reviews` plus `gh pr checks <n>`. Diff against the PR's **real base**, which may be another feature branch (stacked PR): `git diff origin/<base>...origin/<head>`. Only code in that diff is this PR's. Code inherited from the base is not.
2. **Existing threads.** `gh api repos/{owner}/{repo}/pulls/<n>/comments` and the review bodies. Raise nothing already raised. Do check that "addressed in <sha>" replies are actually addressed at head.
3. **Requirement sources: climb, don't stop at the leaf.** Read the linked ticket, then its parent, and the parent's Plan/spec (often a sibling task named "Plan"), including its comments, where decisions get changed. Extract:
   - **Goals / acceptance criteria**: what this PR must satisfy.
   - **Non-goals**: anything the PR does that is listed here is a question to the author. If you can't tell whether a non-goal is touched, ask; don't decide it silently.
   - **Sibling tasks**: work already ticketed elsewhere is out of scope. Do not report its absence as a gap.
   If the leaf ticket is thin (no criteria), say which source the criteria came from.
4. **Project conventions.** Read the instruction files that govern the touched paths: root and per-directory `AGENTS.md`/`CLAUDE.md`, the guideline docs and external conventions they link (API style, commit/title format), and the rules from the user's global instructions that cover the languages in the diff (skip rules for languages the PR doesn't touch). A finding of the form "violates convention X" must name the file that states X.
5. **Read in order** ([Google, Navigating a CL](https://google.github.io/eng-practices/review/reviewer/navigate.html)):
   1. The description: should this change exist in this shape?
   2. The core file: design problems first, since they reshape everything else.
   3. The remaining files and tests. Read whole functions and their callers, not just hunks.
6. **Look for** design fit, functionality and edge cases, user-visible behaviour, concurrency, error and fallback paths, rollout safety (flags, backward-compatible payloads and cache keys, migrations), security on every new entry point (input validation, authN/authZ, unauthenticated reachability, cost per request), tests that would fail on a plausible wrong implementation, and duplication of an existing helper. Leave style to the linter.
7. **Verify every finding before writing it.** Trace the path, read the callee, and search for existing handling elsewhere. A finding you could not confirm becomes a `question`, never an `issue`.
8. **Write the review** in the shape below to a file (e.g. `/tmp/pr-review-<n>.md`) and show it.

## Output contract

```markdown
# PR #<n> review: <title>

**Verdict:** Approve | Approve with comments | Request changes. <one sentence why>
**Merge prerequisites:** <stacked base PR, companion PRs, flags> or none

## Requirements traceability
Sources read: <ticket>, <parent>, <plan>, <siblings checked>
| # | Criterion (source) | Where in diff | Status |
|---|---|---|---|
| R1 | ... (Plan, Goals) | `path:line` | Met / Partial / Missing / Out of scope (sibling <task>) |
Non-goal touched: <item> or none
Beyond the ticket: <diff behaviour no source asks for> or none

## Findings
<!-- blocking first, then non-blocking; nits collapsed into one line at the end -->
**issue (blocking):** <subject> `path:line`
<why it matters, evidence, suggested direction>
Verified: <how: read code / ran it>

**question (non-blocking):** <subject> `path:line`
<what you couldn't confirm and what answer would resolve it>

**Nits:** <a; b; c>

## Not verified
<what you didn't run or read, e.g. tests, local stack, video>
```

Labels follow [Conventional Comments](https://conventionalcomments.org/): `issue`, `suggestion`, `question`, `todo`, `nitpick`, `praise`, each `(blocking)` or `(non-blocking)`. Only an `issue` or `todo` can block. Every finding cites `path:line` in the PR diff and says why, not just what.

## Common mistakes

| Mistake | Fix |
|---|---|
| Reading only the leaf ticket | Climb to parent, Plan and siblings (step 3) |
| Flagging something a sibling task owns ("no debounce") | Mark it Out of scope in traceability, not a finding |
| Diffing against `master` on a stacked PR | Diff against `baseRefName` |
| Repeating a point another reviewer raised | Read threads first. Only flag it if the fix didn't land |
| Unlabelled list mixing a title typo with a broken image | Label and order by severity, collapse nits |
| "Probably a bug" stated as an issue | Verify, or downgrade to `question` |
| Citing a convention from memory | Name the file that states it |
