# AI detector patterns (reference)

Reference file for the `sanitizing-text` skill. These patterns were flagged by GPTZero Advanced Scan in real evaluations, as observed in 2025. Detector heuristics drift over time, so treat this list as illustrative rather than a permanent standard, and update it if a future audit turns up patterns that no longer match. Apply the fixes during the audit pass or inline while applying the formatting and narrative rules.

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
