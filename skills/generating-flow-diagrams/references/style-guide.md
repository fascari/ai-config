# Style guide

Reference look: light cards with coloured borders, thin curved arrows with moving dots, a numbered step timeline at the bottom and one caption per step. Aesthetic rules follow Anthropic's `frontend-design` skill, applied to a diagram.

- One job per screen: the diagram on the left, the explanation of the current step on the right, the timeline at the bottom.
- Motion carries information. Dots travel only on the edges of the current step. Past steps stay visible, future steps fade. No entrance animation on load.
- Colour encodes the node kind only. No decoration.
- System font stack, with a monospace face for code, paths and states.
- Respect `prefers-reduced-motion`: dots are not drawn.
- Keyboard: left and right arrows move between steps, space plays.
- Write captions for a reader with no context. Define each internal term the first time it appears.
- Pick the UI language with `--lang pt|en`. Captions are whatever language the flow files use.
- Run the prose through `sanitizing-text` before sharing: no em dashes, no filler words, no emojis.
