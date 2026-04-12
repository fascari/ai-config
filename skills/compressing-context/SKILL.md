---
name: compressing-context
description: Use when the session context reaches 70% or more, the user wants to resume later in a new chat, or explicitly asks to compress
---

# Context Compressor

Compresses the current conversation into a session-summary.md that allows
a new chat session to resume exactly where this one left off.

## When to use

- User types /compress or asks to compress the session
- User says "save context", "I want to resume later", or similar
- orchestrating-tasks or implementing-feature offers compression because /context shows 70%+ usage and user accepts
- User is about to start a new chat and wants to preserve state

## Steps

1. Ensure the plans symlink exists — run setup from `.github/skills/references/plans-setup.md`
2. Scan the conversation from the beginning. Collect: current state, completed work, key decisions, discoveries, open blockers, next steps.
3. **Resolve the plan slug**:
   a. Scan `.github/plans/` for a directory containing a `progress.md` with status `IN_PROGRESS`. Use that slug.
   b. If no `IN_PROGRESS` plan exists, derive a slug from the session topic (kebab-case, max 4 words, e.g. `cv-job-applications`, `api-auth-refactor`).
   c. Create the directory `.github/plans/{slug}/` if it does not exist.
   d. If creating a new plan directory, also create a minimal `progress.md`:
      ```markdown
      # {slug}
      **Status**: IN_PROGRESS
      **Type**: {session type — e.g. CV tailoring, research, implementation}
      ```
4. Read `.github/plans/{slug}/progress.md` and `.github/plans/{slug}/implementation-plan.md` if they exist, for accurate phase state.
5. Write `.github/plans/{slug}/session-summary.md` using the format below.
6. Confirm to the user with the path and the re-attach instruction.

## Output

Write to `.github/plans/{slug}/session-summary.md`. If the file already exists, replace it (each compression is a fresh snapshot). The slug comes from Step 3 above — either an existing IN_PROGRESS plan or a newly created one.

```markdown
# Session Summary — {slug}
**Date**: {YYYY-MM-DD}
**Phase reached**: Phase {N} — {phase name}
**Status**: {current progress.md status}

---

## Work completed this session

- [x] Phase 1 — {name}: {one-line summary of what was built}
- [x] Phase 2 — {name}: {one-line summary}
- [ ] Phase 3 — {name}: IN PROGRESS — {what sub-task is open}

## Key decisions

- **{decision title}**: {what was chosen} — {why; what was rejected}

## Codebase discoveries

- `{path/to/file.go}` — {pattern or behavior discovered that is not obvious}

## Open items

- [ ] {blocker or TODO}: {context}

## Next steps

1. {exact next action} — file: `{path}`, function: `{name}`
2. {next after that}

---

## Re-attach prompt

> Paste this into a new chat session to resume without losing context.

Read and follow .github/skills/orchestrating-tasks/SKILL.md, then resume plan {slug}.

Before doing anything, read these files for full context:
- .github/plans/{slug}/session-summary.md
- .github/plans/{slug}/progress.md
- .github/plans/{slug}/implementation-plan.md

Resume from: Phase {N} — {phase name}, sub-task: "{exact next task}".
```

## What to compress

| Category | What to include |
|----------|----------------|
| Current state | Which plan, which phase, which sub-task was in progress |
| Completed work | Phases done, files created/modified, tests added |
| Key decisions | Architecture choices made, alternatives rejected and why |
| Discoveries | Patterns found in the codebase, gotchas, non-obvious behavior |
| Open blockers | Unresolved questions, TODOs left in code, deferred tasks |
| Next steps | Exact next sub-task, files to touch, commands to run |

Do not include: full file contents (reference paths instead), long code snippets (describe the pattern, link the file), verbose prose (use bullet points).

## Proactive offer rule

The orchestrating-tasks and implementing-feature skills must offer compression when:
- `/context` shows 70% or more usage
- The session spans research + planning + coding (multi-skill)
- The user explicitly asks

Offer format (non-blocking, at the end of a phase summary):

```
Context is at {N}% — approaching the safe limit (70%). Compress now to avoid degradation?
Reply "yes" or use /compress. Or just say "continue" to skip.
```
