#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install-global-skills.sh [--provider codex|copilot|claude|all]

Install this repo's skills as global symlinks for the selected provider target(s).
For Codex, this also installs the repo's custom subagents as global TOML files.
The default installs for Codex, Copilot, and Claude.
EOF
}

provider="all"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider)
      provider="${2:-}"
      shift 2
      ;;
    --provider=*)
      provider="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$script_dir"
repo_name="$(basename "$repo_root")"
skills_dir="$repo_root/skills"
codex_agents_dir="$repo_root/providers/codex/agents"

if [[ ! -d "$skills_dir" ]]; then
  echo "Skills directory not found: $skills_dir" >&2
  exit 1
fi

targets=()
case "$provider" in
  codex)
    targets+=("codex:$HOME/.agents/skills")
    ;;
  copilot)
    targets+=("copilot:$HOME/.copilot/skills")
    ;;
  claude)
    targets+=("claude:$HOME/.claude/skills")
    ;;
  all)
    targets+=("codex:$HOME/.agents/skills" "copilot:$HOME/.copilot/skills" "claude:$HOME/.claude/skills")
    ;;
  *)
    echo "Unknown provider: $provider" >&2
    usage >&2
    exit 1
    ;;
esac

shopt -s nullglob
skill_paths=("$skills_dir"/*/)
if (( ${#skill_paths[@]} == 0 )); then
  echo "No skills found in $skills_dir" >&2
  exit 1
fi

link_count=0
for target in "${targets[@]}"; do
  target_provider="${target%%:*}"
  target_dir="${target#*:}"
  mkdir -p "$target_dir"
  for skill_path in "${skill_paths[@]}"; do
    skill_name="$(basename "$skill_path")"
    link_name="$skill_name"
    if [[ "$target_provider" == "codex" ]]; then
      link_name="atlas-${repo_name}-${skill_name}"
    fi

    link_path="$target_dir/$link_name"
    if [[ -e "$link_path" && ! -L "$link_path" ]]; then
      echo "Skipping $link_path because it exists and is not a symlink." >&2
      continue
    fi

    ln -sfn "$skill_path" "$link_path"
    ((link_count += 1))
  done
done

echo "Installed $link_count skill link(s) from $repo_name for $provider."

if [[ "$provider" == "codex" || "$provider" == "all" ]]; then
  shopt -s nullglob
  agent_paths=("$codex_agents_dir"/*.toml)
  if (( ${#agent_paths[@]} == 0 )); then
    echo "No Codex custom agents found in $codex_agents_dir" >&2
    exit 1
  fi

  codex_target_dir="$HOME/.codex/agents"
  mkdir -p "$codex_target_dir"

  agent_link_count=0
  for agent_path in "${agent_paths[@]}"; do
    agent_name="$(basename "$agent_path")"
    link_path="$codex_target_dir/atlas-${repo_name}-${agent_name}"
    if [[ -e "$link_path" && ! -L "$link_path" ]]; then
      echo "Skipping $link_path because it exists and is not a symlink." >&2
      continue
    fi

    ln -sfn "$agent_path" "$link_path"
    ((agent_link_count += 1))
  done

  echo "Installed $agent_link_count Codex custom agent link(s) into $codex_target_dir."
fi
