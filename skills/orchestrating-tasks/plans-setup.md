# Plans Directory Setup

Create a repo-local symlink for inspection, but keep the real plan artifacts
in the external vault.

Resolve the external `{plan_root}`:

1. Prefer `$AI_MEMORY_HOME/{project}/plans/`.
2. If unset, use `$COPILOT_VAULT/{project}/plans/`.
3. If neither is set, stop and ask the user to configure an external plan root.

Then ensure `{plan_root}` exists and create or refresh `.plans` in the current
repo root:

```bash
REPO_ROOT="$(rtk git rev-parse --show-toplevel)"
PROJECT="${REPO_ROOT##*/}"

if [ -n "${AI_MEMORY_HOME:-}" ]; then
  PLAN_ROOT="$AI_MEMORY_HOME/$PROJECT/plans"
elif [ -n "${COPILOT_VAULT:-}" ]; then
  PLAN_ROOT="$COPILOT_VAULT/$PROJECT/plans"
else
  echo "No external plan root configured; set AI_MEMORY_HOME or COPILOT_VAULT"
  exit 1
fi

rtk mkdir -p "$PLAN_ROOT"
cd "$REPO_ROOT"

if [ -e .plans ] && [ ! -L .plans ]; then
  echo ".plans exists and is not a symlink; stop and ask before changing it"
  exit 1
fi

rtk ln -sfn "$PLAN_ROOT" .plans

EXCLUDE_HAS_PLANS=false
while IFS= read -r line; do
  [ "$line" = ".plans" ] && EXCLUDE_HAS_PLANS=true && break
done < .git/info/exclude
[ "$EXCLUDE_HAS_PLANS" = true ] || printf "\n.plans\n" >> .git/info/exclude
```

Rules:

- `{plan_root}/{slug}/` is the authoritative location for plan artifacts.
- `.plans` is only a convenience symlink inside the repo where the orchestrator runs.
- Never create real plan directories inside the repo.
- Never create or use `.github/plans` for implementation plans.
