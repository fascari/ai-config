---
name: writing-article
description: Use when writing a technical article about Go for publication on Medium
---

# Writing Article

Technical article writer for Go topics targeting intermediate to advanced engineers. Produces publication-ready Markdown for Medium.

## When to use

- User asks to write a technical article about a Go feature, runtime subsystem, or concept
- User provides a topic and wants a structured article ready for Medium
- User wants to document real codebase behavior in article form

## When NOT to use

- The topic is not Go or not technical
- No research source or codebase is available to verify claims
- User wants a blog post draft, not a structured Medium article

---

## Steps

### Step 1 — Gather required inputs

Before starting, confirm the following with the user if not provided:

| Field | Description |
|---|---|
| Topic | The Go feature, runtime subsystem, or concept to cover |
| Repository | Link to the demo repo, or "N/A" |
| Go version | The version the article targets |
| Series context | Previous article title and URL, or "N/A" |

### Step 2 — Research the codebase

Before writing a single word, inspect the codebase using grep and glob:

1. Use `grep_search` and `file_search` to locate handlers, use cases, domain types, endpoint definitions, response structs, and `json:"..."` field tags relevant to the topic.
2. Use `read_file` to read actual struct definitions and use case logic for every code path cited in the article.
3. Collect exact JSON field names from `json:"..."` tags. Do not invent or assume field names.
4. Collect real code snippets to use verbatim or with minimal adaptation in examples.

Do not proceed to writing until research is complete.

### Step 3 — Write the article

Apply all writing rules and structure rules below.

**Writing rules**

- Write in plain, direct English. Every sentence must say something concrete.
- Avoid filler phrases: "it is worth noting", "in this section we will explore", "now that we have seen X, let's move on to Y".
- Avoid vague claims without code or evidence to back them up.
- Prefer prose over bullet points when a flow of reasoning is involved.
- Each section must follow logically from the previous.
- Paragraphs within a section build on each other. They do not repeat or contradict.
- All technical claims must be accurate and verifiable.
- Code examples must compile, or be explicitly labeled as pseudocode.
- JSON examples must reflect actual struct field names from Step 2.

**Tone rules**

- Write as a senior developer sharing knowledge with peers.
- No exclamation marks.
- No em-dashes. Use a comma, period, or rewrite the sentence.
- No semicolons. Replace with a period or a comma where the connection is loose.
- No Unicode icons, emojis, or symbols.
- Forbidden words: "dive deep", "unleash the power", "seamlessly", "robust", "game-changer", "it's clear that", "in conclusion", "leverage", "delve", "it's worth noting", "let's explore".
- American English spelling.

**Article structure**

Use this exact section order. H1 for title, H2 for main sections, H3 for subsections. Separate every H2 section with a `---` horizontal rule:

```markdown
# [Title]
*[One-line subtitle: what the reader will learn or observe]*

---

## Introduction

---

## A Brief History of [Topic] in Go

---

## What [Feature/Change] Actually Does

---

## Core Technical Concepts

### [Concept 1]

### [Concept 2]

---

## Practical Examples

### 1. [Example name]

### 2. [Example name]

---

## Benchmarks and Analysis

---

## Practical Recommendations

---

## Conclusion
```

**Code blocks**

- Always declare the language: ` ```go `, ` ```bash `, ` ```json `.
- Never use a plain ` ``` ` without a language tag.

**Diagrams**

Whenever a concept benefits from visual representation (state machines, data flows, GC phases, request lifecycle), render it as a fenced Mermaid code block. Do not describe flows in prose when a diagram would be clearer:

```markdown
    ```mermaid
    graph TD
        A[Allocate object] --> B{Heap goal reached?}
        B -- No --> A
        B -- Yes --> C[Trigger GC cycle]
    ```
```

**Formatting rules for Medium**

- Use bold only for genuinely important terms, not for decoration.
- Use tables when comparing multiple configuration values or options.
- End with a `**Further reading**` header followed by a list of real, verifiable URLs.
- If part of a series, end with an italicized footer linking to the previous article.
- No HTML tags.
- No inline images or external media embeds.

**Length**: 1,200 to 1,800 words. Cover fewer concepts well rather than many concepts superficially.

### Step 4 — Save the article

Save the article to:

```
articles/medium/{slug}/{slug}.md
```

Where `{slug}` is a kebab-case version of the article title. Create the directory if it does not exist.

---

## Output

A Markdown file at `articles/medium/{slug}/{slug}.md` that:

- Follows the exact section order defined above
- Contains only real code snippets verified in Step 2
- Has no em-dashes, semicolons, emojis, or forbidden words
- Renders correctly when pasted into Medium

---

## Constraints

- Do not start writing before completing Step 2
- Do not invent metric names, field names, or endpoint behavior
- Do not use passive voice where active voice is possible
- Do not exceed 1,800 words or fall below 1,200 words
- Do not use HTML tags or external media embeds

---

## Common mistakes

| Mistake | Correct behavior |
|---|---|
| Writing before researching the codebase | Complete Step 2 fully before writing any prose |
| Inventing JSON field names | Read actual `json:"..."` tags from source files |
| Using em-dashes in prose | Rewrite with a comma, colon, or period |
| Using semicolons | Split into two sentences or use a comma |
| Plain ` ``` ` code blocks without language | Always declare the language |
| Describing a flow in prose instead of a diagram | Render flows and state machines as Mermaid blocks |
| Saving to `article.md` at the repo root | Save to `articles/medium/{slug}/{slug}.md` |
| Exceeding 1,800 words | Remove sections; cover fewer concepts in more depth |
| Including emojis or Unicode symbols | Plain text only |
