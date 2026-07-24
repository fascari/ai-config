#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install-global-skills.sh [--provider codex|copilot|claude|opencode|all]

Install this repo's skills as global symlinks for the selected provider target.
For Codex, this also installs the repo's custom subagents as global TOML files.

You MUST choose a provider explicitly. There is no default, so the installer
never fans out to providers a machine must not use (e.g. compliance-restricted
machines). Use 'all' only as a deliberate opt-in.
EOF
}

provider=""
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

case "$provider" in
  codex|opencode|copilot|claude|all)
    ;;
  "")
    echo "No provider selected." >&2
    echo "Choose one explicitly: --provider codex|copilot|claude|opencode|all" >&2
    usage >&2
    exit 1
    ;;
  *)
    echo "Unknown provider: $provider" >&2
    echo "Supported: codex, copilot, claude, opencode, all" >&2
    exit 1
    ;;
esac

shopt -s nullglob
skill_paths=("$skills_dir"/*/)
if (( ${#skill_paths[@]} == 0 )); then
  echo "No skills found in $skills_dir" >&2
  exit 1
fi

install_skill_links() {
  local target_dir="$1"
  local skill_path
  local skill_name
  local link_path
  mkdir -p "$target_dir"

  for skill_path in "${skill_paths[@]}"; do
    skill_name="$(basename "$skill_path")"
    link_path="$target_dir/$skill_name"
    if [[ -e "$link_path" && ! -L "$link_path" ]]; then
      echo "Skipping $link_path because it exists and is not a symlink." >&2
      continue
    fi
    ln -sfn "$skill_path" "$link_path"
    ((link_count += 1))
  done
}

link_count=0
case "$provider" in
  all|codex)
    install_skill_links "$HOME/.agents/skills"
    ;;
esac
case "$provider" in
  all|copilot)
    install_skill_links "$HOME/.copilot/skills"
    ;;
esac
case "$provider" in
  all|claude)
    install_skill_links "$HOME/.claude/skills"
    ;;
esac
case "$provider" in
  all|opencode)
    install_skill_links "$HOME/.config/opencode/skills"
    ;;
esac

echo "Installed $link_count skill link(s) from $repo_name for $provider."

# Install Codex custom agents as TOML files (when codex is included)
if [[ "$provider" == "all" || "$provider" == "codex" ]]; then
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
    link_path="$codex_target_dir/$agent_name"
    if [[ -e "$link_path" && ! -L "$link_path" ]]; then
      echo "Skipping $link_path because it exists and is not a symlink." >&2
      continue
    fi
    ln -sfn "$agent_path" "$link_path"
    ((agent_link_count += 1))
  done

  echo "Installed $agent_link_count Codex custom agent link(s) into $codex_target_dir."
fi

# Install Opencode custom agents as markdown files (when opencode is included)
if [[ "$provider" == "all" || "$provider" == "opencode" ]]; then
  opencode_agents_dir="$repo_root/providers/opencode/agents"
  opencode_target_dir="$HOME/.config/opencode/agents"

  if [[ -d "$opencode_agents_dir" ]]; then
    shopt -s nullglob
    opencode_agent_paths=("$opencode_agents_dir"/*.md)
    if (( ${#opencode_agent_paths[@]} > 0 )); then
      mkdir -p "$opencode_target_dir"

      opencode_link_count=0
      for agent_path in "${opencode_agent_paths[@]}"; do
        agent_name="$(basename "$agent_path")"
        link_path="$opencode_target_dir/$agent_name"
        if [[ -e "$link_path" && ! -L "$link_path" ]]; then
          echo "Skipping $link_path because it exists and is not a symlink." >&2
          continue
        fi
        ln -sfn "$agent_path" "$link_path"
        ((opencode_link_count += 1))
      done
      
      echo "Installed $opencode_link_count Opencode custom agent link(s) into $opencode_target_dir."
    fi
  fi

  # Install opencode.jsonc template
  opencode_config_src="$repo_root/providers/opencode/opencode.jsonc"
  opencode_config_dst="$HOME/.config/opencode/opencode.jsonc"
  if [[ -f "$opencode_config_src" ]]; then
    mkdir -p "$(dirname "$opencode_config_dst")"
    cp "$opencode_config_src" "$opencode_config_dst"
    echo "Installed opencode.jsonc to $opencode_config_dst."
  fi
fi
