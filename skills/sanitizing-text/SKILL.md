---
name: sanitizing-text
description: Use when text produced by other skills is about to be written to a file or sent to an issue tracker, wiki, or GitHub
model: claude-haiku-4.5
---

# Sanitizing Text

Post-processing pass applied to any text produced by other skills before it is written to a file or sent to an external system (issue tracker, wiki, GitHub). Covers two concerns:

1. **Formatting and structure** — list markers, heading levels, em-dashes, emojis. Applies to all content.
2. **AI writing patterns** — inflated language, sycophantic tone, vague attributions, mechanical structure. Applies to narrative text (descriptions, PR bodies, prose). Based on [Wikipedia: Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing) and patterns from [blader/humanizer](https://github.com/blader/humanizer) (MIT).

Never generates content. Only cleans content that already exists.

If the personal `humanizer` skill is available in the session, prefer it for the AI writing pass on prose — it has a richer voice-calibration process. If it is not available, the narrative rules in this skill cover the same ground.

## Execution Model

**Required model**: `claude-haiku-4.5` · **Agent type**: `general-purpose`

When dispatched by `orchestrating-tasks`, this skill MUST run as an isolated task agent. The caller must use the `task` tool with `model: "claude-haiku-4.5"` and `agent_type: "general-purpose"`. Rationale: rule-based text transformation requires no deep reasoning — Haiku is fast and sufficient.

## When to use

- Another skill has produced text destined for a file, issue tracker ticket, or wiki page
- User asks to sanitize, clean up, or normalize a specific text or file
- User says "remove AI language", "clean this up", "make it sound professional"
- Before any text is sent to issue tracker or wiki APIs

## Steps

1. Read the target text (from conversation context, file, or user selection).
2. Identify whether the text is **narrative** (prose descriptions) or **structured** (checklists, tables, code). Most PR bodies and issue descriptions are a mix of both.
3. Apply **Formatting rules** (Rules 1-6) to the entire text.
4. Apply **Narrative rules** (Rules 7-27) to prose sections only. Skip checklists, table cells with short values, and code comments.
5. For narrative sections: run the **audit pass** — ask "What still sounds AI-generated?" and revise.
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

Apply all rules in order. Each rule is independent — do not skip any.

### Rule 1 — Remove forbidden AI-sounding words and phrases

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

### Rule 2 — Remove em-dashes, en-dashes, and decorative punctuation

- Replace ` — ` (em-dash with spaces) with `, ` or rewrite the sentence to eliminate the dash
- Replace ` -- ` (double hyphen used as dash) with `, ` or rewrite
- Replace `–` (en-dash) in prose with `-` (hyphen) or `, ` as context requires
- Do not remove hyphens in compound words (`auto-withdraw`, `date-range`, `rule-2`) or code identifiers
- Remove repeated punctuation (`...`, `!!!`, `???`) — use a single character

**Exception**: Em-dashes inside code blocks, SQL, or inline code spans are untouched.

### Rule 3 — Remove emojis and icons

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

### Rule 4 — Enforce professional, objective language

- Write in third person or imperative voice. Avoid first person (`I`, `we`, `our`) in ticket descriptions, plans, and reports.
- Use present or future tense for requirements. Avoid past tense unless describing existing behaviour.
- Remove hedging language: `might`, `could potentially`, `sort of`, `kind of`, `basically`, `essentially`, `obviously`, `clearly`.
- Remove filler openings: sentences that start with `So,`, `Well,`, `Basically,`, `In essence,`.
- Remove closing affirmations: `Hope this helps`, `Feel free to`, `Let me know if`, `Happy to`, `I hope this helps`.
- Remove sycophantic openings: `Great question!`, `Of course!`, `Certainly!`, `You're absolutely right!`.
- Keep sentences short. If a sentence exceeds 30 words, split it.
- Use active voice. Passive constructions such as `it was decided that` must be rewritten (`the team decided`).
- Remove subjectless fragments: `No configuration file needed` → `No configuration file is needed` or `You do not need a configuration file`.

### Rule 5 — Replace colons and semicolons with natural connectors

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

### Rule 6 — Normalize formatting

- Use plain `-` for unordered list items. Do not use `*`, `+`, or `•`.
- Do not mix heading levels arbitrarily. `##` for major sections, `###` for subsections, `####` only if strictly necessary.
- Use sentence case for headings, not title case. `## Strategic negotiations` not `## Strategic Negotiations And Partnerships`.
- Code blocks must always declare the language: ` ```go `, ` ```sql `, ` ```bash `. A plain ` ``` ` is not acceptable.
- Table alignment must be consistent. All `|---|` separators must match the number of columns.
- Do not insert blank lines inside a list item block.
- One blank line between sections; two blank lines only before `##` top-level headings.
- Do not use curly/smart quotes (`"..."`, `'...'`). Use straight quotes (`"..."`, `'...'`).
- Do not bold entire phrases for emphasis. Bold is for UI labels, key terms on first use, or table headers — not for decorative emphasis.
- Do not use inline-header list style (bolded word + colon + description on same line). Convert to prose or a proper table.

---

## Narrative rules (apply to prose sections only)

These rules target AI writing patterns. Apply them to paragraph prose, PR descriptions, and issue description fields. Skip checklists, table cells with short values, and code comments.

### Rule 7 — Remove inflated significance and legacy language

AI writing inflates the importance of ordinary facts by adding statements about how they "represent", "mark", or "contribute to" broader themes.

**Words to watch:** stands as, serves as, marks a, represents a, is a testament to, vital/significant/crucial/pivotal role, underscores its importance, reflects broader, symbolizing its enduring, setting the stage for, shaping the, evolving landscape, deeply rooted

| Before | After |
|---|---|
| The fix marks a pivotal moment in how the system handles resolution. | The fix changes how the system resolves the issue. |
| This approach underscores our commitment to correctness. | (remove — it says nothing) |

### Rule 8 — Remove superficial -ing endings

AI appends present participle phrases (`-ing`) to sentences to fake depth. These add no information.

**Words to watch:** highlighting, underscoring, emphasizing, ensuring, reflecting, symbolizing, contributing to, cultivating, fostering, encompassing, showcasing

| Before | After |
|---|---|
| The query was rewritten, ensuring correctness. | The query was rewritten. |
| The handler returns a 404, reflecting the domain convention. | The handler returns a 404 per domain convention. |

### Rule 9 — Remove promotional and advertisement language

**Words to watch:** boasts, vibrant, rich (figurative), profound, enhancing its, showcasing, exemplifies, commitment to, nestled, in the heart of, groundbreaking, renowned, breathtaking

Replace with plain factual statements. If the sentence only carries promotional weight and no information, remove it.

### Rule 10 — Remove vague attributions

AI attributes opinions to unnamed authorities.

**Words to watch:** Industry reports, Observers have cited, Experts argue, Some critics argue, Several sources, It is widely believed

Replace with a specific source or remove entirely. If the point is worth making, make it directly.

### Rule 11 — Replace copula avoidance

AI avoids `is`/`are`/`has` by substituting elaborate constructions.

| Before | After |
|---|---|
| The function serves as the entry point. | The function is the entry point. |
| The repository boasts three query methods. | The repository has three query methods. |
| This commit marks the introduction of the feature. | This commit introduces the feature. |

### Rule 12 — Remove negative parallelisms

AI overuses `It's not just X, it's Y` and tailing negation fragments.

| Before | After |
|---|---|
| It's not just about correctness; it's about predictability. | The fix improves predictability, not just correctness. |
| Options come from the selected item, no guessing. | Options come from the selected item without requiring a guess. |

### Rule 13 — Break up rule-of-three patterns

AI forces ideas into groups of three to appear comprehensive. If two items are the natural scope, use two.

| Before | After |
|---|---|
| The change improves correctness, reliability, and maintainability. | The change improves correctness and makes the code easier to maintain. |

### Rule 14 — Remove chatbot artifacts

Chatbot conversational fragments that end up in published text.

**Phrases to remove entirely:** `Here is an overview of`, `I hope this helps!`, `Let me know if you'd like`, `Would you like me to expand`, `Of course!`, `Certainly!`, `Great question!`, `You're absolutely right!`

Keep the content. Remove the meta-commentary.

### Rule 15 — Remove knowledge-cutoff disclaimers

**Phrases to watch:** `as of [date]`, `up to my last training update`, `while specific details are limited`, `based on available information`

Remove these. State what is known directly, or omit if genuinely unknown.

### Rule 16 — Remove excessive hedging

| Before | After |
|---|---|
| It could potentially possibly be argued that the policy might have some effect. | The policy may affect outcomes. |
| This is essentially a workaround for what is basically a timing issue. | This is a workaround for a timing issue. |

### Rule 17 — Remove generic positive conclusions

Vague upbeat endings that add no information.

| Before | After |
|---|---|
| The future looks bright. Exciting times lie ahead as we continue this journey. | (remove entirely) |
| This represents a major step in the right direction. | (remove entirely — or state what specifically changes next) |

### Rule 18 — Remove signposting and fragmented headers

AI announces what it is about to do instead of doing it.

**Phrases to watch:** `Let's dive in`, `let's explore`, `here's what you need to know`, `without further ado`, `now let's look at`

Remove the announcement. Start with the content.

Also remove warm-up sentences that restate the heading before the real content:

| Before | After |
|---|---|
| `## Performance` + `Speed matters.` + `When users hit a slow page, they leave.` | `## Performance` + `When users hit a slow page, they leave.` |

### Rule 19 — Use contractions in prose

Uncontracted forms ("does not", "it is", "would not", "cannot") read as stiff and machine-generated. Use natural contractions in prose.

| Before | After |
|---|---|
| It does not mention tests. | It doesn't mention tests. |
| This is not a valid approach. | This isn't a valid approach. |
| The function would not compile. | The function wouldn't compile. |

**Exception**: Keep the uncontracted form when used for deliberate emphasis ("The service does not retry. Ever.") or in formal specifications and acceptance criteria.

### Rule 20 — Vary sentence openings

Runs of sentences starting with the same subject ("It names...", "It covers...", "It also...") are a strong AI tell. Break the pattern.

- No two consecutive sentences should start with the same word.
- No three consecutive sentences should start with a pronoun (It, This, That, They).
- Vary by leading with the object, a dependent clause, or a different subject.

| Before | After |
|---|---|
| It covers PSS. It adds a test helper. It organizes changes file by file. | PSS support lands too. A test helper keeps the setup clean. File-by-file changes make the diff easy to follow. |

### Rule 21 — Mix sentence lengths

Uniform sentence length (all 15-25 words) is an AI signature. Vary the rhythm.

- Each paragraph needs at least one sentence under 10 words.
- Short sentences add punch and emphasis. Use them after a longer sentence to land a point.
- Do not let three consecutive sentences sit in the same word-count band.

| Before | After |
|---|---|
| Model A comes last because it describes the same core logic but omits too much detail in its output. | Model A comes last. Same core logic, but too much is left out. |

### Rule 22 — Remove elegant variation and synonym cycling

AI avoids repeating a word by cycling through synonyms, creating unnatural variety. Humans repeat words naturally.

**Pattern**: Using "the feature", "the capability", "the functionality", "the enhancement" for the same concept within a paragraph.

| Before | After |
|---|---|
| The implementation handles edge cases. The solution also covers error paths. The approach validates inputs. | The implementation handles edge cases, covers error paths, and validates inputs. |

If you mean the same thing, use the same word. Forced synonyms sound artificial.

### Rule 23 — Remove false ranges

AI creates "from X to Y" constructions that sound comprehensive but add nothing.

| Before | After |
|---|---|
| From novice developers to seasoned engineers, everyone benefits. | Developers at any level benefit. |
| Everything from configuration to deployment is automated. | Configuration and deployment are automated. |

### Rule 24 — Remove viral and manipulation phrases

Social media and engagement-bait phrases that AI picks up from training data.

**Phrases to remove entirely:** `Let that sink in`, `Read that again`, `The truth is`, `And honestly?`, `Here's the kicker`, `Spoiler alert`, `Plot twist`, `Hot take`, `Unpopular opinion`, `Let me be clear`, `Make no mistake`, `Full stop`, `Period.` (as emphasis), `I said what I said`

### Rule 25 — Remove filler phrase clusters

AI inserts conversational filler to sound human, but overuses specific phrases in clusters.

**Watch for clusters of:** `Here's the thing`, `The thing is`, `Fair enough`, `At the end of the day`, `Look`, `Listen`, `I mean`, `To be fair`, `That said`, `That being said`, `Having said that`, `With that in mind`

One filler phrase per paragraph is natural. Two or more in the same paragraph is a tell. Remove extras.

### Rule 26 — Avoid symmetric treatment in comparisons

When comparing items (models, options, approaches), AI gives each item roughly the same word count and structure. Humans spend more words on what matters and less on the obvious.

| Before | After |
|---|---|
| Model A handles validation with 3 tests. Model B handles validation with 4 tests. Model C handles validation with 2 tests. | B has the most tests at 4. A covers 3. C only manages 2. |

Different items deserve different depth. The winner might get 3 sentences, the loser just one.

### Rule 27 — Reduce hyphenated word pair overuse

AI hyphenates compound modifiers with perfect consistency. Humans are inconsistent with common pairs.

**Words to watch:** cross-functional, client-facing, data-driven, decision-making, high-quality, real-time, long-term, end-to-end, well-known

When three or more hyphenated pairs appear in the same paragraph, drop the hyphens on the most common ones. Keep hyphens on technical or ambiguous compounds where meaning changes without them.

| Before | After |
|---|---|
| The cross-functional team delivered a high-quality, data-driven report. | The cross functional team delivered a high quality, data driven report. |

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

These patterns were flagged by GPTZero Advanced Scan in real evaluations. Apply the fixes during the audit pass or inline while applying Rules 1-21.

### Predictable syntax

- Template openers: "Model B is best because...", "Model C is second.", "A comes last."
  Fix: Lead with what was noticed, not the rank. "What sold me on B is...", "C is pretty close to B, honestly."

- Feature enumeration with connectors: "It covers X, adds Y, and includes Z"
  Fix: Weave features into opinions. "PSS is covered, there's a helper so the test setup stays clean" reads as observation, not a list.

- Balanced comparison sentences: "Same implementation scope as B, and also covers..."
  Fix: Be asymmetric. Spend more words on what matters, less on the obvious.

### Lacks creative grammar

- Perfect grammar throughout. No fragments, no interrupted thoughts.
  Fix: Use fragments for emphasis ("None.", "No PSS either, no test helper."). Start sentences with "And" or "But". Use comma splices.

- Uniform sentence length. All sentences in the 15-25 word band.
  Fix: Alternate 3-word fragments with 20-word sentences in the same paragraph.

### Mechanical precision

- Most-probable word choices: "implementation scope", "test specificity", "file-by-file breakdown"
  Fix: Use casual equivalents. "what it covers", "how specific the tests are", "changes broken down file by file"

- Generic evaluative principles: "A security feature with no visible test coverage doesn't give me confidence..."
  Fix: Make it personal and shorter. "For something that's supposed to block algorithm confusion, that's a dealbreaker."

### Robotic formality

- Three symmetric paragraphs with identical structure.
  Fix: Different length per paragraph. One can be 4 sentences, another 6, another 3.

- No colloquial language anywhere.
  Fix: Allow casual qualifiers in moderation: "pretty close", "honestly", "kind of", "the kind of thing", "comes in handy". Use parenthetical asides: "(well, three if you count the key set path)".

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
