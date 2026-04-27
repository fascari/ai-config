---
name: copying-to-clipboard
description: Use when the user needs to copy generated text to the macOS clipboard for pasting into forms, browsers, or external apps without terminal line-break artifacts
---

# Copying to Clipboard

## Overview

Use `pbcopy` to place text directly in the macOS clipboard. Avoids the line-break and wrapping artifacts that occur when the user manually selects and copies terminal output.

## When to use

- User will paste the generated text into a web form, email, or external app
- Text has multiple paragraphs and copying from terminal would corrupt formatting
- User asks to "copy", "put in clipboard", or "let me paste this"

## When NOT to use

- User only needs to read the text in the terminal
- Text is a file path or command the user will type manually

## Pattern

```bash
cat <<'EOF' | pbcopy
Paragraph one text here.

Paragraph two text here.

Paragraph three text here.
EOF
echo "Copied to clipboard"
```

Use `<<'EOF'` (quoted) so the heredoc does not expand variables or escape sequences inside the text.

## Quick reference

| Need | Command |
|---|---|
| Multi-paragraph text | `cat <<'EOF' \| pbcopy` … `EOF` |
| Single line | `echo "text" \| pbcopy` |
| File contents | `cat file.txt \| pbcopy` |
| Confirm copy | Add `echo "Copied to clipboard"` after |

## Common mistakes

- Using `<<EOF` (unquoted) when text contains `$`, backticks, or backslashes — always quote the delimiter: `<<'EOF'`
- Forgetting the confirmation echo — user has no feedback that the copy succeeded
- Copying raw terminal markdown (bold `**`, backticks) into plain-text forms — sanitize first if needed
