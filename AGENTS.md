# Copilot Agent Instructions

## Automatic Session Bootstrap

On the first user message of every new session, execute these steps before responding.

Skip bootstrap when any of the following is true:
- User message contains "recall" or "/recall" (user is invoking manually — avoid running twice)
- A re-attach prompt is present in context (the `resuming-context` skill handles that case)
- User message is a one-word command or slash command with no codebase context needed (e.g., `/help`, `/clear`)

### Bootstrap Steps

**1. Resolve vault and project:**
```bash
REPO_NAME=$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null || echo "unknown")
echo "VAULT=${COPILOT_VAULT:-NO_VAULT}"
echo "REPO=$REPO_NAME"
```
Map the repo name to the vault project folder using the table in your personal copilot instructions.
If `COPILOT_VAULT` is not set: skip steps 2, 3, and vault parts of 4 and 5 — proceed gracefully with what is available locally.

**2. Read recent session logs** (3 most recent):
`$COPILOT_VAULT/{project}/logs/`

**3. Read architecture decisions:**
`$COPILOT_VAULT/{project}/architecture/decisions.md`

**4. Read active plans:**
- All devs: `.github/plans/` (symlink, always available)
- Vault devs: `$COPILOT_VAULT/{project}/plans/`

**5. Read Graphify context:**
- Always: `graphify-out/GRAPH_REPORT.md`
- Vault devs: `$COPILOT_VAULT/graphify/{project}/_COMMUNITY_{relevant name}.md` (max 3–5 communities)

**6. Check git state:**
```bash
git --no-pager log --oneline -10
git --no-pager status
```

**7. Present summary** (max 20 lines): last session summary, active plan phase, current branch and recent commits.

---

## Vault Setup (optional, per developer)

Add to `~/.zshrc` or `~/.bashrc`:
```bash
export COPILOT_VAULT="$HOME/path/to/your/obsidian-vault"
```

Developers without Obsidian do not need this variable — all vault steps are skipped automatically when `COPILOT_VAULT` is unset.

---

## Codebase Search Rules

Never use `grep` or `find` to explore the codebase. Use Graphify instead:

| Need | Command |
|---|---|
| Broad context about a concept | `graphify query "concept"` |
| Trace connection between two nodes | `graphify path "A" "B"` |
| Details about a specific node | `graphify explain "NodeName"` |

Read source files only when editing or when graphify does not have the answer.
