#!/usr/bin/env python3
"""Rewrite vault links after moving plan slugs into plans/archive.

Usage: rewrite_links.py PROJECT SLUG [SLUG ...] [--root DIR ...] [--dry-run]

Scans $AI_MEMORY_HOME and every --root DIR (.md and .txt files):
- "plans/{slug}" becomes "plans/archive/{slug}".
- Inside each archived slug, "../{active}" becomes "../../{active}" for
  slugs still active in {project}/plans.
- Inside each active slug, "../{slug}" becomes "../archive/{slug}".
"""
import os
import re
import sys

argv = sys.argv[1:]
dry = "--dry-run" in argv
roots, positional = [], []
i = 0
while i < len(argv):
    if argv[i] == "--dry-run":
        i += 1
    elif argv[i] == "--root" and i + 1 < len(argv):
        roots.append(os.path.expanduser(argv[i + 1]))
        i += 2
    else:
        positional.append(argv[i])
        i += 1
if len(positional) < 2:
    sys.exit(__doc__)

vault = os.environ.get("AI_MEMORY_HOME")
if not vault:
    sys.exit("AI_MEMORY_HOME is not set")
project, slugs = positional[0], positional[1:]
plans = os.path.join(vault, project, "plans")
roots = [vault] + roots
tail = r"(?=[/\s`)\]\"'.,:]|$)"

slug_alt = "|".join(re.escape(s) for s in slugs)
absolute = re.compile(r"(?<![\w-])plans/(" + slug_alt + r")" + tail)
back = re.compile(r"(?<![\w./-])\.\./(" + slug_alt + r")" + tail)
active = {d for d in os.listdir(plans) if d != "archive" and os.path.isdir(os.path.join(plans, d))}
forward = re.compile(r"(?<![\w./-])\.\./(" + "|".join(re.escape(a) for a in active) + r")" + tail) if active else None

archived_dirs = [os.path.join(plans, "archive", s) + os.sep for s in slugs]
active_dirs = [os.path.join(plans, a) + os.sep for a in active]

changed = []
for root in roots:
    for dirpath, _, files in os.walk(root):
        for name in files:
            if not name.endswith((".md", ".txt")):
                continue
            path = os.path.join(dirpath, name)
            text = open(path, encoding="utf-8", errors="ignore").read()
            new = absolute.sub(lambda m: "plans/archive/" + m.group(1), text)
            new = new.replace("plans/archive/archive/", "plans/archive/")
            if forward and any(path.startswith(d) for d in archived_dirs):
                new = forward.sub(lambda m: "../../" + m.group(1), new)
            if any(path.startswith(d) for d in active_dirs):
                new = back.sub(lambda m: "../archive/" + m.group(1), new)
            if new != text:
                changed.append(path)
                if not dry:
                    open(path, "w", encoding="utf-8").write(new)

print(("would change" if dry else "changed"), len(changed), "files")
print("\n".join(changed))
