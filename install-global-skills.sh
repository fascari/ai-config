#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install-global-skills.sh [--provider codex|copilot|all]

Install this repo's skills as global symlinks for the selected provider target(s).
The default installs for both Codex and Copilot.
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

if [[ ! -d "$skills_dir" ]]; then
  echo "Skills directory not found: $skills_dir" >&2
  exit 1
fi

targets=()
case "$provider" in
  codex)
    targets+=("codex:$HOME/.codex/skills")
    ;;
  copilot)
    targets+=("copilot:$HOME/.copilot/skills")
    ;;
  all)
    targets+=("codex:$HOME/.codex/skills" "copilot:$HOME/.copilot/skills")
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
