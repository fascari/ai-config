# Claude Instructions

This directory holds Claude-specific configuration for use with Claude Projects or as context in Claude conversations.

## How to Use

### Claude Projects

When creating a Claude Project for a codebase, attach the relevant files from `../instructions/` as project knowledge. They describe coding conventions and architectural rules in plain markdown. Claude reads them directly.

Suggested files to attach per project type:
- Go projects: `go-style.instructions.md`, `clean-architecture.instructions.md`, `testing.instructions.md`, `error-handling.instructions.md`, `package-design.instructions.md`
- Writing/articles: `sanitizing-text.instructions.md`

### CLAUDE.md

Copy `project-instructions-template.md` to the root of a project as `CLAUDE.md`. Claude reads this file automatically when it exists in the working directory.

## Contents

- `README.md` - this file
- `project-instructions-template.md` - starting point for `CLAUDE.md` in any project
