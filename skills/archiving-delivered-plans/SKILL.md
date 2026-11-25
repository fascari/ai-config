---
name: archiving-delivered-plans
description: Use when cleaning up the AI memory vault, when plans/ folders pile up, or when asked which plans are finished, delivered, shipped or completed in the issue tracker and should move to plans/archive.
---

# Archiving delivered plans

## Overview

A plan slug (`$AI_MEMORY_HOME/{project}/plans/{slug}/`) is archived when the tracker work it covers is completed and nothing local is still pending. The tracker (Asana, Jira, Linear, GitHub issues) decides "delivered". The slug's own status lines don't, because they go stale.

The vault is usually not a git repository, so a move or a link rewrite can't be undone. Back up first and show the plan before touching anything.

## Prerequisites

`AI_MEMORY_HOME` must be set. You need read access to the tracker, through an MCP server or a CLI such as `gh`.

## Steps

1. **List the slugs** in every project's `plans/`, skipping `plans/archive/`.
2. **Match each slug to its tracker items** by the ids or URLs in `brief.md`, `progress.md` and `next-session-prompt.md`. If none are written down, look for the slug in other notes, such as a structure file or a sibling slug, and mark the match "inferred".
3. **Read each item** (read only, never write): whether it's completed, when, and its parent.
4. **Decide per slug:**

| Situation | Decision |
|---|---|
| Every matched item completed, and no pending item left in the slug | archive |
| Item completed, but the slug lists open follow-ups (a follow-up file, unchecked items, "pending" in progress) | keep, and list the follow-ups for the user |
| The slug tracks an umbrella or project item that's still open, even when its children are done | keep |
| No tracker item at all (PR review notes, experiments) | ask the user, and check the related PRs to inform the question |
| Item open, or the plan on hold | keep |

5. **Show the dry run and wait for the user's go.** It has the table (project, slug, items and how they matched, completed date, decision, reason), the move commands and the questions.
6. **On approval:**
   1. Back up: `tar czf /tmp/plans-backup-$(date +%F).tgz -C "$AI_MEMORY_HOME" {project}/plans` for each project touched.
   2. Check that no slug of the same name already sits in `plans/archive/`, then move: `mv {project}/plans/{slug} {project}/plans/archive/`. Quote the slug list as an array, because some shells don't split a plain variable.
   3. Rewrite links: `python3 rewrite_links.py {project} {slug}...`, from this skill's folder. It rewrites absolute and vault-relative paths and relative links in both directions: from inside each archived slug to slugs still active, and from active slugs to the archived ones. Add `--root DIR` for other folders that hold notes, such as a provider's memory folder, and run it first with `--dry-run`.
   4. Append the archived slugs, with date and tracker item, to `{project}/plans/archive/README.md`, creating it if needed.
   5. Leave the archived files' own status lines as they are, since they're history.
7. **Search for leftovers.** `grep` for `plans/{slug}` and `../{slug}` outside `plans/archive/` should find nothing. Fix whatever remains.
8. **Report** what moved, the links rewritten and where the backup is.

## Common mistakes

- **Trusting `progress.md` "Status".** It's often stale (PROPOSED on shipped work). The tracker is the source.
- **Archiving a slug whose umbrella item is still open** because its first children shipped.
- **Moving before the dry run is approved**, or without a backup.
- **Rewriting only the `plans/{slug}` paths.** Relative `../{slug}` links break in both directions.
- **Writing to the tracker**, such as closing or moving items. This skill only reads.
