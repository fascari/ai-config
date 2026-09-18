# Perplexity & Burstiness

Removing style patterns is half the job. AI detectors like GPTZero also measure two statistical signals:

- **Perplexity**: how predictable each word is to a language model. AI text is "too smooth" because LLMs favor high-probability tokens. Human writing surprises more.
- **Burstiness**: how varied sentence length and structure are across the text. AI output is uniform. Humans are bursty.

Clean text that reads like a Wikipedia article still gets flagged. The text must also be statistically unpredictable.

### Rule P1: Token unpredictability

After rewriting, scan for "safe" words any LLM would pick. Swap 3-5 per paragraph for less obvious alternatives.

| Too predictable | Less obvious |
|---|---|
| significantly | way more than expected |
| comprehensive | covers everything |
| demonstrate | show, prove, make clear |
| facilitate | make easier, help with |
| effectively | (cut it entirely) |
| utilize | use |
| implement | build, wire up, add |
| robust | solid, holds up |
| specifically | (rephrase the clause) |
| addressing | fixing, dealing with, tackling |

The replacement does not need to be a single-word synonym. Rephrase the whole clause if needed. The goal is to pick words a language model would not rank as the top-1 prediction in that context.

### Rule P2: Burstiness targets

Each paragraph must have at least:
- One sentence with **5 words or fewer**
- One sentence with **18 words or more**

If all sentences land in the 8-14 word range, the text reads as "uniform" to detectors.

**Before (low burstiness):**
> The tool handles configuration files well. It generates test scaffolding quickly. It also manages repetitive refactors effectively.

**After (high burstiness):**
> Config files? Done. It also handles test scaffolding and those repetitive refactors nobody wants to touch by hand, which honestly saves more time than the flashier features.

### Rule P3: Syntactic inversions

Use at least one inverted construction per 2 paragraphs. LLMs almost never generate these. Humans use them all the time.

Types:
- **Adjective-first:** "Lineless and functionless, the summary falls flat."
- **Prepositional-first:** "Without a single test name, the writeup leaves you guessing."
- **Object-first:** "That part I actually liked."

### Rule P4: Break repetitive openers

No two consecutive sentences should start with the same word or pattern. Three sentences starting with "The..." or "It..." is a detector magnet.

**Before:**
> The model handles edge cases. The implementation is clean. The tests all pass.

**After:**
> Edge cases are handled. Clean implementation too. All tests pass.

### Rule P5: Controlled imperfection

Allow 1-2 constructions per text that are grammatically correct but stylistically unusual. Humans write slightly off phrases naturally. LLMs never do because they optimize for the most probable output.

**Examples of controlled imperfection:**
- "nails what code does most accurately" (slightly awkward word order, but clear)
- "managed to keep the scope tamed" (unusual verb choice for "scope")
- "Same closed scope and implementation." (fragment with unexpected adjective)

Do NOT introduce actual grammar errors. The imperfection is in word choice and phrasing, not in correctness.
