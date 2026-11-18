---
name: generating-flow-diagrams
description: Use when producing animated, step-through HTML diagrams that explain a business or system flow to a reader with no context, for example an order, payment, request, pipeline or integration flow. Provides a viewer template, a flow data format, a build validator and a Playwright capture check. Works for any project.
---

# Generating flow diagrams

Builds one self-contained HTML file with a tab per flow. Each flow is a JSON file. The template draws nodes, curved edges with moving dots, a numbered step timeline and a side panel with the caption and the source files of the current step.

## When to use

- Someone new to a codebase or business needs to see how a flow works, step by step.
- A set of related flows should share one look and live in one file.
- Not for static architecture posters or charts of data. Use a drawing tool for those.

## Files

- `template.html`: the viewer. `__TITLE__`, `__LANG__` and `"__DATA__"` are replaced by `build.mjs`.
- `build.mjs`: merges the flow files, validates ids, overlaps, canvas bounds and `src` paths, writes the HTML. Options: `--flows <dir>`, `--out <file>`, `--root <repo>`, `--title`, `--lang pt|en`.
- `capture.mjs`: opens the page with Playwright, visits every step, saves one screenshot per step, and fails on console errors, text overflowing a card and edge labels overlapping a card.
- `scripts/setup-playwright.sh`: installs Playwright and Chromium into a throwaway directory and prints the path for `--playwright`.
- `examples/01-checkout.json`: a neutral example flow. Run `node build.mjs --lang en` to see it.
- `references/flow-schema.md`: data format, grid and layout rules.
- `references/style-guide.md`: visual and writing rules.

## Workflow

1. Read `references/flow-schema.md`.
2. Verify the flow in the real system before drawing. Trace every step to a file or a document and put that path in `src`. Separate what exists today from what is only planned: use `tag` and `dashed` for the planned parts. Put every unverified claim in a step `note`.
3. Write one `NN-name.json` per flow in a flows directory that belongs to the project, not to this skill.
4. Build: `node build.mjs --flows <dir> --root <repo> --out <html> --title "<title>"`. Fix every `WARN`.
5. Capture: `PW=$(scripts/setup-playwright.sh)`, then `rm -rf <shots> && node capture.mjs <html> <shots> --playwright "$PW"`. Delete the shots directory first so stale files do not mislead.
6. Look at the screenshots of the busiest steps. The automatic checks do not catch crossing edges or crowded labels.
7. Run the prose through `sanitizing-text`.

## Rules

- Keep company or customer internals out of this skill and out of any shared repository. The flows of a real system stay in that project's own skill, vault or repository.
- No production data. Everything comes from code and documents.
- Never present a guess as fact.
- Third-party skills and packages: clone to a temporary directory, read the code, summarise what it runs, and install only after the user agrees.
- Ten to fourteen nodes per diagram is the readable range.
