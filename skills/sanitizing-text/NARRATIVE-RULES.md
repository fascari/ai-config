# Narrative rules (sanitizing-text)

Reference file for the `sanitizing-text` skill. These rules target AI tells: inflated significance, superficial padding, promotional language, vague attributions, mechanical structure, and uniform rhythm. Apply them to paragraph prose, PR descriptions, and issue description fields. Skip checklists, table cells with short values, and code comments.

## Contents

- Rule 7: Remove inflated significance and legacy language
- Rule 8: Remove superficial -ing endings
- Rule 9: Remove promotional and advertisement language
- Rule 10: Remove vague attributions
- Rule 11: Replace copula avoidance
- Rule 12: Remove negative parallelisms
- Rule 13: Break up rule-of-three patterns
- Rule 14: Remove chatbot artifacts
- Rule 15: Remove knowledge-cutoff disclaimers
- Rule 16: Remove excessive hedging
- Rule 17: Remove generic positive conclusions
- Rule 18: Remove signposting and fragmented headers
- Rule 19: Use contractions in prose
- Rule 20: Vary sentence openings
- Rule 21: Mix sentence lengths
- Rule 22: Remove elegant variation and synonym cycling
- Rule 23: Remove false ranges
- Rule 24: Remove viral and manipulation phrases
- Rule 25: Remove filler phrase clusters
- Rule 26: Avoid symmetric treatment in comparisons
- Rule 27: Reduce hyphenated word pair overuse

---

### Rule 7: Remove inflated significance and legacy language

AI writing inflates the importance of ordinary facts by adding statements about how they "represent", "mark", or "contribute to" broader themes.

**Words to watch:** stands as, serves as, marks a, represents a, is a testament to, vital/significant/crucial/pivotal role, underscores its importance, reflects broader, symbolizing its enduring, setting the stage for, shaping the, evolving landscape, deeply rooted

| Before | After |
|---|---|
| The fix marks a pivotal moment in how the system handles resolution. | The fix changes how the system resolves the issue. |
| This approach underscores our commitment to correctness. | (remove: it says nothing) |

### Rule 8: Remove superficial -ing endings

AI appends present participle phrases (`-ing`) to sentences to fake depth. These add no information.

**Words to watch:** highlighting, underscoring, emphasizing, ensuring, reflecting, symbolizing, contributing to, cultivating, fostering, encompassing, showcasing

| Before | After |
|---|---|
| The query was rewritten, ensuring correctness. | The query was rewritten. |
| The handler returns a 404, reflecting the domain convention. | The handler returns a 404 per domain convention. |

### Rule 9: Remove promotional and advertisement language

**Words to watch:** boasts, vibrant, rich (figurative), profound, enhancing its, showcasing, exemplifies, commitment to, nestled, in the heart of, groundbreaking, renowned, breathtaking

Replace with plain factual statements. If the sentence only carries promotional weight and no information, remove it.

### Rule 10: Remove vague attributions

AI attributes opinions to unnamed authorities.

**Words to watch:** Industry reports, Observers have cited, Experts argue, Some critics argue, Several sources, It is widely believed

Replace with a specific source or remove entirely. If the point is worth making, make it directly.

### Rule 11: Replace copula avoidance

AI avoids `is`/`are`/`has` by substituting elaborate constructions.

| Before | After |
|---|---|
| The function serves as the entry point. | The function is the entry point. |
| The repository boasts three query methods. | The repository has three query methods. |
| This commit marks the introduction of the feature. | This commit introduces the feature. |

### Rule 12: Remove negative parallelisms

AI overuses `It's not just X, it's Y` and tailing negation fragments.

| Before | After |
|---|---|
| It's not just about correctness; it's about predictability. | The fix improves predictability, not just correctness. |
| Options come from the selected item, no guessing. | Options come from the selected item without requiring a guess. |

### Rule 13: Break up rule-of-three patterns

AI forces ideas into groups of three to appear comprehensive. If two items are the natural scope, use two.

| Before | After |
|---|---|
| The change improves correctness, reliability, and maintainability. | The change improves correctness and makes the code easier to maintain. |

### Rule 14: Remove chatbot artifacts

Chatbot conversational fragments that end up in published text.

**Phrases to remove entirely:** `Here is an overview of`, `I hope this helps!`, `Let me know if you'd like`, `Would you like me to expand`, `Of course!`, `Certainly!`, `Great question!`, `You're absolutely right!`

Keep the content. Remove the meta-commentary.

### Rule 15: Remove knowledge-cutoff disclaimers

**Phrases to watch:** `as of [date]`, `up to my last training update`, `while specific details are limited`, `based on available information`

Remove these. State what is known directly, or omit if genuinely unknown.

### Rule 16: Remove excessive hedging

| Before | After |
|---|---|
| It could potentially possibly be argued that the policy might have some effect. | The policy may affect outcomes. |
| This is essentially a workaround for what is basically a timing issue. | This is a workaround for a timing issue. |

### Rule 17: Remove generic positive conclusions

Vague upbeat endings that add no information.

| Before | After |
|---|---|
| The future looks bright. Exciting times lie ahead as we continue this journey. | (remove entirely) |
| This represents a major step in the right direction. | (remove entirely: or state what specifically changes next) |

### Rule 18: Remove signposting and fragmented headers

AI announces what it is about to do instead of doing it.

**Phrases to watch:** `Let's dive in`, `let's explore`, `here's what you need to know`, `without further ado`, `now let's look at`

Remove the announcement. Start with the content.

Also remove warm-up sentences that restate the heading before the real content:

| Before | After |
|---|---|
| `## Performance` + `Speed matters.` + `When users hit a slow page, they leave.` | `## Performance` + `When users hit a slow page, they leave.` |

### Rule 19: Use contractions in prose

Uncontracted forms ("does not", "it is", "would not", "cannot") read as stiff and machine-generated. Use natural contractions in prose.

| Before | After |
|---|---|
| It does not mention tests. | It doesn't mention tests. |
| This is not a valid approach. | This isn't a valid approach. |
| The function would not compile. | The function wouldn't compile. |

**Exception**: Keep the uncontracted form when used for deliberate emphasis ("The service does not retry. Ever.") or in formal specifications and acceptance criteria.

### Rule 20: Vary sentence openings

Runs of sentences starting with the same subject ("It names...", "It covers...", "It also...") are a strong AI tell. Break the pattern.

- No two consecutive sentences should start with the same word.
- No three consecutive sentences should start with a pronoun (It, This, That, They).
- Vary by leading with the object, a dependent clause, or a different subject.

| Before | After |
|---|---|
| It covers PSS. It adds a test helper. It organizes changes file by file. | PSS support lands too. A test helper keeps the setup clean. File-by-file changes make the diff easy to follow. |

### Rule 21: Mix sentence lengths

Uniform sentence length (all 15-25 words, all built with the same structure) is an AI tell. Vary the rhythm.

- Prefer a natural mix: one long sentence weaving clauses with commas, then a shorter one landing the point.
- Do not mechanically insert a short sentence in every paragraph. Some paragraphs work as one long, flowing sentence.
- Three consecutive sentences starting with the same subject is a stronger tell than uniform length.

| Before | After |
|---|---|
| Model A comes last because it describes the same core logic but omits too much detail in its output. | Model A comes last. Same core logic, but too much is left out. |

### Rule 22: Remove elegant variation and synonym cycling

AI avoids repeating a word by cycling through synonyms, creating unnatural variety. Humans repeat words naturally.

**Pattern**: Using "the feature", "the capability", "the functionality", "the enhancement" for the same concept within a paragraph.

| Before | After |
|---|---|
| The implementation handles edge cases. The solution also covers error paths. The approach validates inputs. | The implementation handles edge cases, covers error paths, and validates inputs. |

If you mean the same thing, use the same word. Forced synonyms sound artificial.

### Rule 23: Remove false ranges

AI creates "from X to Y" constructions that sound comprehensive but add nothing.

| Before | After |
|---|---|
| From novice developers to seasoned engineers, everyone benefits. | Developers at any level benefit. |
| Everything from configuration to deployment is automated. | Configuration and deployment are automated. |

### Rule 24: Remove viral and manipulation phrases

Social media and engagement-bait phrases that AI picks up from training data.

**Phrases to remove entirely:** `Let that sink in`, `Read that again`, `The truth is`, `And honestly?`, `Here's the kicker`, `Spoiler alert`, `Plot twist`, `Hot take`, `Unpopular opinion`, `Let me be clear`, `Make no mistake`, `Full stop`, `Period.` (as emphasis), `I said what I said`

### Rule 25: Remove filler phrase clusters

AI inserts conversational filler to sound human, but overuses specific phrases in clusters.

**Watch for clusters of:** `Here's the thing`, `The thing is`, `Fair enough`, `At the end of the day`, `Look`, `Listen`, `I mean`, `To be fair`, `That said`, `That being said`, `Having said that`, `With that in mind`

One filler phrase per paragraph is natural. Two or more in the same paragraph is a tell. Remove extras.

### Rule 26: Avoid symmetric treatment in comparisons

When comparing items (models, options, approaches), AI gives each item roughly the same word count and structure. Humans spend more words on what matters and less on the obvious.

| Before | After |
|---|---|
| Model A handles validation with 3 tests. Model B handles validation with 4 tests. Model C handles validation with 2 tests. | B has the most tests at 4. A covers 3. C only manages 2. |

Different items deserve different depth. The winner might get 3 sentences, the loser just one.

### Rule 27: Reduce hyphenated word pair overuse

AI hyphenates compound modifiers with perfect consistency. Humans are inconsistent with common pairs.

**Words to watch:** cross-functional, client-facing, data-driven, decision-making, high-quality, real-time, long-term, end-to-end, well-known

When three or more hyphenated pairs appear in the same paragraph, drop the hyphens on the most common ones. Keep hyphens on technical or ambiguous compounds where meaning changes without them.

| Before | After |
|---|---|
| The cross-functional team delivered a high-quality, data-driven report. | The cross functional team delivered a high quality, data driven report. |
