---
name: developing-changes
description: Use as the entry point when starting or resuming a feature, bug fix, refactor, or any codebase change, especially one planned under a vault slug, or when the user asks to plan, implement, resume, continue, or ship planned work. Covers the whole change; implementing-feature and testing-implementation only govern delegated workers.
---

# Developing Changes

## Overview

One thread does the work: it researches, plans, implements, and verifies, keeping state in files under a slug. Subagents are the exception, used only where they measurably pay off. Commands decide pass or fail; an LLM verdict never replaces a test, build, or lint.

Why: multi-agent runs cost roughly 15x the tokens of a chat, and coding (shared context, interdependent edits) is a poor fit for them; single agents beat multi-agent variants on SWE-bench (Anthropic multi-agent research system; Cognition "Don't Build Multi-Agents"; Google/MIT agent scaling study).

## 1. Plan root and slug

`{plan_root}` is `$AI_MEMORY_HOME/{project}/plans/`, where `{project}` is the repo directory name. If `AI_MEMORY_HOME` is unset, stop and ask. Every other skill that says "the same rule as developing-changes" means this rule.

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"; PLAN_ROOT="$AI_MEMORY_HOME/${REPO_ROOT##*/}/plans"
mkdir -p "$PLAN_ROOT"
[ -e "$REPO_ROOT/.plans" ] && [ ! -L "$REPO_ROOT/.plans" ] && { echo ".plans is not a symlink, ask"; exit 1; }
ln -sfn "$PLAN_ROOT" "$REPO_ROOT/.plans"
grep -qx '.plans' "$REPO_ROOT/.git/info/exclude" || printf '\n.plans\n' >> "$REPO_ROOT/.git/info/exclude"
```

Plan artifacts live only in `{plan_root}/{slug}/` (nested slugs allowed, e.g. `epic/task-3`). Never create plan folders inside a repo or under `.github/plans`.

Slug: use the one the user names. Otherwise match the user's words against slug directory names; one clear match means use it and say so; several means ask. If nothing matches, read every `progress.md` under `{plan_root}`: exactly one `PROPOSED` or `IN_PROGRESS` means use it; several means ask; none means create a new kebab-case slug.

## 2. Size the task

| Size | Signal | What runs |
|---|---|---|
| Trivial | The diff fits in one sentence and the cause is known | No slug. For a bug, a failing test first; then the change, the gates, the report. |
| Planned | Anything else | The full flow below |

Risk raises rigor, not ceremony. Auth, money, migrations, concurrency, public contracts, or cross-service changes mean the plan gets an explicit Risks section and the independent review is mandatory.

## 3. Flow for planned work

1. **Brief.** Write `brief.md` (context, acceptance criteria as observable behavior, constraints, non-goals) and create `progress.md` with Status `PROPOSED`. Ask the user only questions whose answer changes behavior, contract, architecture, or acceptance.
2. **Research, in this thread.** Follow `researching-codebase` and write `research.md`, or one `research-{area}.md` per area, with `file:line` references. Use graphify if `graphify-out/` exists, otherwise targeted reads. For a bug, research means reproducing it with a command or a throwaway test, and confirming the root cause in code (`superpowers:systematic-debugging`), before any fix is planned; leave the tree as you found it, the real regression test comes in step 5. Delegate only per section 4.
3. **Plan, in this thread.** Follow `planning-implementation` and write `implementation-plan.md`; its compatibility question and its approval step are asked once, together, in step 4. It must name exact files, give phases that are each independently testable, list risks and open questions, and end with an end-to-end check (against the running stack when the change is a service, e.g. `validating-manual-flow`). For high-risk work, get one fresh-context review of the plan (section 4) before step 4.
4. **Approval checkpoint.** Summarize the phases, risks, and open questions, then wait for an explicit approval of the plan ("aprovado", "approved", "go"). Answering a question in the plan, or authorizing one side action, is not approval. On approval set `IN_PROGRESS`.
5. **Implement phase by phase, in this thread.** Before the first edit, read the language rules the user's instructions route to (for Go: the rules files and `writing-modern-go`), once per session. For each behavior: write the test, run it and see it fail for the expected reason, write the minimum code, see it pass. The failing run is the external check that the test is real, so never write the code first. Then run the gates (section 5), repair at most twice, update `progress.md`, and move on. Do not pause for approval between phases unless the plan or the user says so.
6. **Review.** One independent review of the whole diff (section 4), saved to `reviews/review.md` in the slug. Fix the blockers and re-run the gates. If the fixes touch a function or file the review did not flag, review the fix diff once more. Then set `REVIEW` and report, quoting the final gate results.
7. **Stop.** Never commit, push, open a PR, or write to an external system (issue tracker, chat) without its own explicit approval. `reviewing-code` sets `DONE` when the user approves the review.

Resuming: read `progress.md` first. `PROPOSED` means go to step 4; `IN_PROGRESS` means the plan is approved, so continue at the first unchecked phase after re-running the gates of the last completed one (the tree may have changed; a failure there is repaired like any phase failure); `REVIEW` means step 6 is done, so report and wait. Read other artifacts only as the next step needs them.

## 4. When a subagent is worth it

| Use a subagent | Do it in this thread |
|---|---|
| Broad read-only exploration whose raw output you won't need again (many files, another repo, a log trawl, web research). It writes its findings to the slug and returns a path plus a summary of 300 words or less. | Research of the code you are about to change. |
| Several such explorations that are independent of each other: launch them in parallel in one message. | Planning. The planner must have seen the code. |
| The review in step 6 (and the plan review for high-risk work): a fresh context, not a fork, since a fork shares your reasoning. Give it the `reviewing-code` skill, the full diff (`git diff <base>` plus untracked files, never `HEAD~1` on uncommitted work), the acceptance criteria, and the project's rules. Scope it to correctness, stated requirements, and the project's written rules, not personal taste. It writes findings to the slug and returns blockers first. | Every write. One writer at a time. |
| A phase so large that this thread's context is near its limit: hand the whole phase to one worker with the plan path. Load `implementing-feature` (production) and `testing-implementation` (tests) first, since they govern delegated workers, then re-run the gates yourself. | Sanitizing text, sizing, slug lookup, or any step a rule or command can do. |

In Claude Code: `Explore` or a fork for exploration (a fork reuses the prompt cache), `general-purpose` for the review. Keep the session model; ask for a cheaper model only on mechanical subagent work. Cross-vendor review is optional and only for high-risk work; a same-vendor reviewer in a fresh context, plus tests, is the default.

## 5. Gates

Gates are commands, run after every phase and before the review. Use the commands the project's CI actually runs (Makefile, `tools/bin/check.sh`, CI config); never assume `golangci-lint`. Typical set: format, build, vet or typecheck, lint, the scoped tests (`-race` when concurrency changed), and `style-gate`. Also `architecture-gate` when the repo follows the layout that skill checks. A check that matched zero files proves nothing: if a grep or script targets paths the repo does not have (e.g. `internal/app` in a `pkg/` repo), say so instead of reporting PASS. A gate that fails twice after repair goes to the user with the output; do not loop further.

## 6. progress.md

```markdown
## Status
PROPOSED | IN_PROGRESS | REVIEW | DONE

## Handoff
{3-5 lines: where things stand, next action, open questions. Rewritten at every phase boundary.}

## Phases
- [x] Phase 1: {name}. Gates: PASS. Files: {list}
- [ ] Phase 2: {name}

## Decisions
- {date}: {decision} ({who})
```

This thread owns every write to `progress.md`. Only `reviewing-code` sets `DONE`.

## Common mistakes

| Mistake | Fix |
|---|---|
| Dispatching research or planning agents for code you will edit | Do it here; the context is needed for the edit anyway |
| Re-loading skills every phase | Once per session |
| Loading `implementing-feature`/`testing-implementation` and following their dispatch and per-phase pause steps while working in this thread | Those govern delegated workers; in this thread follow the language rules and step 5 |
| Writing the code before its test has failed | Test first, watch it fail, then code |
| Fixing a bug whose cause was guessed | Reproduce it and confirm the cause first |
| Adding judges (critique gate, output judge, repeated reviews) | Only the reviews in steps 3 and 6; commands do the rest |
| Sending every message through a sanitizer agent | Apply `sanitizing-text` inline, only to text that leaves the session |
| Running `analyzing-system-design` by default | Only when the user asks for it |
| Treating a reply to a question as plan approval | Wait for explicit approval of the plan |
| Reviewing `HEAD~1` when nothing is committed | `git diff <base>` plus untracked files |
