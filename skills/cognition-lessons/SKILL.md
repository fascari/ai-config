---
name: cognition-lessons
description: Extract lessons from review failures and load them in future sessions. Harness learns from mistakes. Zero tokens on load, minimal on extract.
---

# Cognition Lessons

Extract compact lessons when code review fails, and load relevant lessons at session start. The harness learns from mistakes without expensive LLM-as-judge loops.

## When to use

### Extract (after BLOCKED)
- When `reviewing-code` returns BLOCKED with specific violations
- After a repair cycle fails to address review feedback
- When the same violation appears multiple times

### Load (at session start)
- During `recall` skill execution
- When starting implementation on a project with prior lessons
- When the user asks to load project context

## Lesson Format

Each lesson is a compact entry with:

```markdown
### {trigger}
- **Anti-pattern**: {what was done wrong}
- **Preferred pattern**: {what to do instead}
- **Priority**: high | medium | low
- **Occurrences**: {count}
- **Last seen**: {date}
```

Example:

```markdown
### Using interface{} instead of any
- **Anti-pattern**: `func Process(data interface{}) error`
- **Preferred pattern**: `func Process(data any) error`
- **Priority**: high
- **Occurrences**: 3
- **Last seen**: 2026-07-05
```

## Storage

Lessons are stored per-project:

```
~/.ai-config/cognition-lessons/
├── {project-name}.md
├── {another-project}.md
└── ...
```

## Extract Flow

When `reviewing-code` returns BLOCKED:

1. Parse the BLOCKED reasons (file:line, rule violated, description)
2. For each violation, extract a lesson:
   - **Trigger**: the rule or pattern that was violated
   - **Anti-pattern**: what the code did wrong
   - **Preferred pattern**: what the rule requires
3. Check if lesson already exists in `{project}.md`:
   - If yes: increment `Occurrences`, update `Last seen`
   - If no: append new lesson at end of file
4. Save updated file

## Load Flow

At session start (during `recall`):

1. Check if `~/.ai-config/cognition-lessons/{project}.md` exists
2. If exists: read all lessons
3. Filter to high-priority lessons (or all if < 10 total)
4. Present to user:

```markdown
## Cognition Lessons for {project}

Loaded {N} lessons from prior review failures:

1. **{trigger}** (high, {occurrences}x)
   - Anti-pattern: {description}
   - Preferred: {description}

2. **{trigger}** (medium, {occurrences}x)
   - Anti-pattern: {description}
   - Preferred: {description}

...

These lessons will be checked during implementation.
```

## Integration with reviewing-code

When `reviewing-code` runs:

1. Load project lessons (if any)
2. Include high-priority lessons in review prompt:

```
## Prior Lessons (check these first)

- {trigger}: avoid {anti-pattern}, use {preferred pattern}
- {trigger}: avoid {anti-pattern}, use {preferred pattern}

## Standard Rules

{normal rules from rules/*.md}
```

3. If review passes: no lesson extraction needed
4. If review fails with same violation: increment occurrence count
5. If review fails with new violation: extract new lesson

## Rules

- **Extract only on BLOCKED** — never extract on APPROVED
- **Compact format** — lessons must be scannable in < 30 seconds
- **Per-project storage** — lessons are project-specific
- **Append-only** — never delete lessons, only update occurrence count
- **Priority-based filtering** — load high-priority first, medium if space allows

## Token Cost

- **Load**: ~500 tokens (read + present)
- **Extract**: ~200 tokens per lesson (parse + write)
- **Total per session**: ~500-1000 tokens vs ~50-100k with LLM-as-judge
