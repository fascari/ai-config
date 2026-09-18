---
name: sanitizing-text
description: Removes AI tells and normalizes formatting in text before it's saved or published. Use when text produced by other skills is about to be written to a file or sent to an issue tracker, wiki, or GitHub
---

# Sanitizing Text

Post-processing pass applied to any text produced by other skills before it is written to a file or sent to an external system (issue tracker, wiki, GitHub). Covers two concerns:

1. **Formatting and structure**, list markers, heading levels, em-dashes, emojis. Applies to all content.
2. **AI tells**, inflated language, sycophantic tone, vague attributions, mechanical structure. Applies to narrative text (descriptions, PR bodies, prose). Based on [Wikipedia: Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing) and patterns from [blader/humanizer](https://github.com/blader/humanizer) (MIT).

Never generates content. Only cleans content that already exists.

If the personal `humanizer` skill is available in the session, prefer it for the AI writing pass on prose, it has a richer voice-calibration process. If it is not available, the narrative rules in this skill cover the same ground.

## Execution Model

**Preferred tier**: Fast · **Logical role**: `general-purpose`

Rule-based text transformation needs no deep reasoning: dispatch as `general-purpose` on the provider's Fast tier. See `orchestrating-tasks/dispatching.md`'s Capability Tiers table for the Fast-tier model per provider. This skill never needs the Complex or Expert Review tiers, so the full `provider-dispatch.md` chain (`dispatching.md`, `claude-runtime.md`, `task-types.md`, `gates.md`, `codex-runtime.md`) is unnecessary here.

## When to use

- Another skill has produced text destined for a file, issue tracker ticket, or wiki page
- User asks to sanitize, clean up, or normalize a specific text or file
- User says "remove AI language", "clean this up", "make it sound professional"
- Before any text is sent to issue tracker or wiki APIs

## Steps

1. Read the target text (from conversation context, file, or user selection).
2. Identify whether the text is **narrative** (prose descriptions) or **structured** (checklists, tables, code). Most PR bodies and issue descriptions are a mix of both.
3. Apply **Formatting rules** (Rules 1, 2, 3, 5, 6) to the entire text.
4. Apply **Rule 4** and the **Narrative rules** (Rules 7-27, see [NARRATIVE-RULES.md](NARRATIVE-RULES.md)) to prose sections only. Skip checklists, table cells with short values, and code comments.
5. For narrative sections: run the **audit pass**, ask "What still sounds AI-generated?" and revise.
6. Return the sanitized text only. No commentary about what was changed unless the user asked for it.

## Output

The sanitized text, unchanged in structure, cleaned in language and formatting. If nothing required sanitization, return the original text unchanged.

---

## Mandatory invocation points

Every skill that produces user-facing text must run its output through this skill before finalizing. Mandatory invocation points:

| Producing skill | Invocation point |
|---|---|
| planning-implementation | Before writing `implementation-plan.md` |
| researching-codebase | Before writing `research.md` |
| implementing-feature | Before writing inline code comments or docstrings |
| reviewing-code | Before writing `reviews/*.md` |
| creating-pull-request | Before presenting the PR body for approval |
| any skill or direct edit | Before writing or modifying any `.md` or `.txt` file under `docs/` or `.github/` |

### Direct edits (no skill involved)

When a `.md` or `.txt` file under `docs/` or `.github/` is written directly (not via a skill), sanitization is still mandatory. Apply all rules from this skill to the full content of the file before saving.

### HTML files (CV and site content)

Every `.html` file written or modified must be sanitized before the file is saved. This applies to the full visible text content of the file (not CSS, HTML tags, or attribute values).

Steps for HTML sanitization:
1. Extract all visible text (content between tags, excluding `<style>`, `<script>`, and HTML comments).
2. Apply all rules from this skill to that text.
3. Write the corrected content back to the file.
4. Only then generate the PDF (if applicable).

---

## Formatting rules (apply to all content)

Apply all rules in order. Each rule is independent, do not skip any.

### Rule 1: Remove forbidden AI-sounding words and phrases

Replace or remove any of the following. The list is not exhaustive; apply the same judgment to synonyms.

| Forbidden | Replacement |
|---|---|
| leverage / leveraging | use / using |
| utilize / utilizing | use / using |
| streamline / streamlining | simplify / improve |
| robust | reliable / stable / solid |
| cutting-edge | (remove or replace with specific technology name) |
| state-of-the-art | (remove or replace with specific technology name) |
| seamless / seamlessly | (remove or describe concretely) |
| holistic | complete / full / overall |
| synergy / synergies | (remove or describe concretely) |
| paradigm | model / approach / pattern |
| revolutionize | change / improve / redesign |
| game-changer | (remove or describe the impact concretely) |
| empower / empowering | allow / enable |
| foster / fostering | support / encourage / build |
| delve into | examine / review / look at |
| it is worth noting that | (remove the phrase, keep the content) |
| it is important to note that | (remove the phrase, keep the content) |
| in order to | to |
| due to the fact that | because |
| at this point in time | now |
| in the event that | if |
| prior to | before |
| subsequent to | after |
| on a regular basis | regularly |
| in close proximity to | near |
| a wide range of | many / various |
| a number of | several / many |
| please note that | (remove the phrase, keep the content) |
| ensure that | ensure / verify |
| make sure that | ensure / verify |
| as mentioned above | (remove or reference the specific section) |
| as previously stated | (remove or reference the specific section) |
| this is because | because |
| first and foremost | first |
| last but not least | finally |
| needless to say | (remove the phrase entirely) |
| goes without saying | (remove the phrase entirely) |
| in a nutshell | in summary |
| at the end of the day | ultimately |
| moving forward | (remove or be specific about what changes) |
| additionally | also / (remove if implied) |
| align with | match / follow / fit |
| crucial | important / critical (or remove if obvious) |
| enduring | lasting / long-standing |
| enhance | improve |
| garner | get / earn / attract |
| highlight (verb) | show / point out |
| interplay | interaction / relationship |
| intricate / intricacies | complex / complexity (or describe concretely) |
| key (adjective before noun) | main / primary / critical (or remove) |
| landscape (abstract noun) | industry / market / field |
| pivotal | important / decisive |
| showcase | show / present / demonstrate |
| tapestry (abstract noun) | (remove or describe concretely) |
| testament | proof / sign / evidence |
| underscore (verb) | show / confirm |
| valuable | useful / important (or remove if obvious) |
| vibrant | active / busy (or describe concretely) |
| actually | (remove unless used for genuine contrast) |
| the real question is | (remove, state the question directly) |
| at its core | (remove) |
| in reality | (remove) |
| what really matters | (state the point directly) |
| fundamentally | (remove) |
| the deeper issue | (state the issue directly) |
| the heart of the matter | (remove) |

### Rule 2: Remove em-dashes, en-dashes, and decorative punctuation

- Replace ` — ` (em-dash with spaces) with `, ` or rewrite the sentence to eliminate the dash
- Replace ` -- ` (double hyphen used as dash) with `, ` or rewrite
- Replace `–` (en-dash) in prose with `-` (hyphen) or `, ` as context requires
- Do not remove hyphens in compound words (`auto-withdraw`, `date-range`, `rule-2`) or code identifiers
- Remove repeated punctuation (`...`, `!!!`, `???`): use a single character

**Exception**: Em-dashes inside code blocks, SQL, or inline code spans are untouched.

### Rule 3: Remove emojis and icons

- Remove all emoji characters (Unicode ranges U+1F300 to U+1FFFF and U+2600 to U+26FF)
- Remove all icon shortcodes (e.g. `:white_check_mark:`, `:x:`, `:warning:`)
- Replace visual status indicators with plain text equivalents:

| Icon | Plain text replacement |
|---|---|
| `✅` at start of list item | (remove, keep the text) |
| `❌` at start of list item | (remove, keep the text) |
| `⚠️` / `⚠` | `Warning:` |
| `🔴` | `High` or `Critical` (context-dependent) |
| `🟡` | `Medium` |
| `🟢` | `Low` or `OK` (context-dependent) |
| `→` / `►` / `▶` / `➡` used as bullets | `-` |
| `←` used as inline annotation | `(see above)` or remove |
| `✓` | (remove or replace with `[x]` in checklists) |

**Exception**: Icons inside code blocks or inline code spans are untouched.

### Rule 4: Enforce professional, objective language

**Scope: narrative sections only** (not table cells, checklists, or code comments). Hedging and sycophantic-opener removal only makes sense for prose, so unlike Rules 1-3 and 5-6 this rule does not apply to all content the way its position in this list might suggest.

- Write in third person or imperative voice. Avoid first person (`I`, `we`, `our`) in ticket descriptions, plans, and reports.
- Use present or future tense for requirements. Avoid past tense unless describing existing behaviour.
- Remove filler openings: sentences that start with `So,`, `Well,`, `Basically,`, `In essence,`.
- Remove closing affirmations: `Hope this helps`, `Feel free to`, `Let me know if`, `Happy to`, `I hope this helps`.
- See [NARRATIVE-RULES.md](NARRATIVE-RULES.md) Rules 14 and 16 for the full hedging-language and sycophantic-opener word lists.
- Vary sentence length. Humans naturally write some short sentences and some longer ones with comma-separated clauses. A 50-word sentence is fine when the clauses connect logically; a paragraph of 15-word sentences all built the same way is the real AI tell.
- Use active voice. Passive constructions such as `it was decided that` must be rewritten (`the team decided`).
- Remove subjectless fragments: `No configuration file needed` → `No configuration file is needed` or `You do not need a configuration file`.

### Rule 5: Replace colons and semicolons with natural connectors

Colons (`:`) and semicolons (`;`) used as sentence connectors make prose feel mechanical. Replace them with natural language connectors when they join two related clauses or introduce a consequence.

**Semicolons (`;`) in prose:**

| Pattern | Replacement |
|---|---|
| `X; Y` (two related independent clauses) | Rewrite as two sentences, or join with `and`, `but`, `while`, `whereas` |
| `X; therefore Y` | `X, so Y` or split into two sentences |
| `X; however Y` | `X. However, Y` or `X, but Y` |
| `X; otherwise Y` | `X. Otherwise, Y` or `if not, Y` |

**Colons (`:`) as clause connectors:**

| Pattern | Replacement |
|---|---|
| `X: Y` where Y completes a thought (not a list) | Rewrite with `because`, `so`, `and`, `which means`, or split sentences |
| `This means: Y` | `This means Y` (remove colon) |
| `The result: Y` | `The result is Y` or `Y is the result` |

**Keep colons when:**
- Introducing a bullet list or numbered list
- Inside code spans or code blocks
- After section labels in tables (e.g., `Note:`, `Warning:`)
- In time expressions (`09:00`)
- In URLs or file paths

**Exception**: Colons and semicolons inside code blocks, inline code spans, or quoted strings are untouched.

### Rule 6: Normalize formatting

- Use plain `-` for unordered list items. Do not use `*`, `+`, or `•`.
- Do not mix heading levels arbitrarily. `##` for major sections, `###` for subsections, `####` only if strictly necessary.
- Use sentence case for headings, not title case. `## Strategic negotiations` not `## Strategic Negotiations And Partnerships`.
- Code blocks must always declare the language: ` ```go `, ` ```sql `, ` ```bash `. A plain ` ``` ` is not acceptable.
- Table alignment must be consistent. All `|---|` separators must match the number of columns.
- Do not insert blank lines inside a list item block.
- One blank line between sections; two blank lines only before `##` top-level headings.
- Do not use curly/smart quotes (`"..."`, `'...'`). Use straight quotes (`"..."`, `'...'`).
- Do not bold entire phrases for emphasis. Bold is for UI labels, key terms on first use, or table headers: not for decorative emphasis.
- Do not use inline-header list style (bolded word + colon + description on same line). Convert to prose or a proper table.

---

## Narrative rules (apply to prose sections only)

Rules 7-27 target AI tells in prose: inflated significance, superficial `-ing` padding, promotional language, vague attributions, copula avoidance, negative parallelisms, rule-of-three, chatbot artifacts, knowledge-cutoff disclaimers, hedging, generic conclusions, signposting, missing contractions, uniform sentence openings and length, synonym cycling, false ranges, viral phrases, filler clusters, symmetric comparisons, and hyphen overuse.

Apply to paragraph prose, PR descriptions, and issue description fields. Skip checklists, table cells with short values, and code comments.

**Full rule text, words to watch, and before/after tables**: see [NARRATIVE-RULES.md](NARRATIVE-RULES.md).

---

## Audit pass (for narrative text)

After applying all rules, run a final audit on narrative sections:

1. Read the full text aloud in your head. Flag anything that sounds like a report rather than a person writing.
2. Check specifically for:
   - Uniform sentence length (all sentences in a similar word-count band)
   - Consecutive sentences starting with the same word or pronoun
   - Zero contractions (a strong AI tell in informal or semi-formal prose)
   - Parallel paragraph structure (every paragraph follows the same template)
   - Balanced, even-handed tone where a human would be opinionated
   - Symmetric word count across compared items (Rule 26)
   - Synonym cycling for the same concept (Rule 22)
   - Filler phrase clusters, more than one per paragraph (Rule 25)
3. Revise flagged sections. Prefer short, punchy rewrites over elaborate restructuring.
4. Return the final version.

---

## AI detector patterns (reference)

Additional patterns to check for during the audit pass, drawn from real detector-tool evaluations (GPTZero Advanced Scan): predictable syntax, lack of creative grammar, mechanical word choice, and robotic formality.

**Full pattern list with fixes**: see [AI-DETECTOR-PATTERNS.md](AI-DETECTOR-PATTERNS.md).

---

## What NOT to change

- Content inside ` ``` ` code blocks (code, SQL, shell commands)
- Content inside ` ` ` inline code spans
- Issue tracker keys (e.g. issue numbers, references)
- File paths (`internal/app/user/domain/user.go`)
- Package or function names used in prose (`MyFunc`, `r.DB(ctx)`)
- Quoted error messages or log output
- Acceptance criteria checklist markers (`- [ ]`, `- [x]`)

---

## Permissions

- Read any file to obtain the text to sanitize
- Write sanitized output to the same file
- No external API calls
- No code generation
