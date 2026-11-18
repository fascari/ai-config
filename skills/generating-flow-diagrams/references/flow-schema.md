# Flow file schema

One JSON file per diagram in the flows directory. Files are merged in name order into tabs.

```json
{
  "id": "slug-used-in-url-hash",
  "tab": "Tab label",
  "title": "Diagram title shown in the side panel",
  "canvas": [1320, 760],
  "legend": ["service", "data"],
  "groups": [{ "label": "Row name", "x": 10, "y": 50, "w": 1300, "h": 120 }],
  "nodes": [{ "id": "api", "label": "api", "sub": "short role", "kind": "service", "x": 470, "y": 90, "w": 150 }],
  "edges": [{ "id": "e-a-b", "from": "a", "to": "b", "label": "short", "sides": ["bottom", "top"], "bidir": false, "dashed": false }],
  "steps": [{
    "label": "Timeline label",
    "title": "Step heading",
    "text": ["Paragraph with `code` spans."],
    "nodes": ["ids highlighted in this step"],
    "edges": ["ids animated in this step"],
    "state": ["chips such as order states"],
    "note": "Amber callout for caveats and guesses",
    "tag": "Planned",
    "src": ["repo-relative file paths, checked by build.mjs"]
  }]
}
```

## Fields

- `canvas`: SVG viewBox size. Keep it the same across flows of one set so the scale matches.
- `legend`: node kinds to show in the panel. Defaults to all.
- `sides`: `[from side, to side]`, each one of `left`, `right`, `top`, `bottom`. Default is picked from the relative position.
- `bidir`: arrowheads on both ends, for request and response or approve and return.
- `dashed`: dashed line. Use it for anything planned or optional.
- `tag`: small badge next to the step counter.
- `src`: files that back the step. `build.mjs` warns when one does not exist, which catches stale references.

## Node kinds

`service` (blue), `queue` (red, events and failure states), `data` (green, stores and end states), `actor` (amber, customers), `human` (purple, internal team), `external` (grey dashed, third-party systems).

## Grid

Columns at `x = 30 + 220 * i` with `w = 150`, rows at `y = 90, 270, 450, 630` with `h = 58`, groups at `y = 50, 230, 410, 590` with `h = 120`. This leaves a 70px gap between neighbours, enough for an edge label of about 10 characters.

## Rules learned

- Anchors are the centre of a side, so two edges that share a node side overlap at the anchor. Spread them with `sides`.
- `sides: ["bottom","bottom"]` draws a U that leaves the row. Reorder nodes so edges stay lateral.
- Edge labels longer than the gap hide behind the cards. `capture.mjs` fails on this.
- A node label wraps at about `(w - 18) / 6.9` characters. A single long word such as `a_very_long_identifier_name` needs `w` of 180.
- Every node must be highlighted by at least one step, or `build.mjs` warns.
- An edge between two non-adjacent nodes of the same row crosses the nodes between them. Reorder or move one node to the next row.
- `src` paths are resolved against `--root`. A path starting with `~` is resolved against the home directory.
