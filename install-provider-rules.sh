#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install-provider-rules.sh --provider codex|copilot|claude|opencode|all [--target PATH] [--mode copy|symlink] [--force]

Installs provider-native project entrypoints into a target repository.

Options:
  --provider  Provider name. Supported: codex, copilot, claude, opencode, all
  --target    Target repository path. Defaults to current directory.
  --mode      Install mode: symlink (default) or copy
  --force     Replace existing managed files
EOF
}

provider=""
target="$(pwd)"
mode="symlink"
force=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider)
      provider="${2:-}"
      shift 2
      ;;
    --target)
      target="${2:-}"
      shift 2
      ;;
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --force)
      force=1
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

if [[ -z "$provider" ]]; then
  echo "Missing required --provider" >&2
  usage >&2
  exit 1
fi

valid="codex|copilot|claude|opencode|all"
if ! echo "$provider" | grep -qE "^(codex|copilot|claude|opencode|all)$"; then
  echo "Unsupported provider: $provider" >&2
  echo "Supported: codex, copilot, claude, opencode, all" >&2
  exit 1
fi

if [[ "$mode" != "symlink" && "$mode" != "copy" ]]; then
  echo "Unsupported mode: $mode" >&2
  echo "Supported modes: symlink, copy" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "$0")" && pwd)"
target="$(cd "$target" && pwd)"

if [[ ! -d "$target/.git" && ! -f "$target/.git" ]]; then
  echo "Target does not look like a git repository: $target" >&2
  exit 1
fi

install_path() {
  local src="$1"
  local dst="$2"
  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ "$force" -ne 1 ]]; then
      echo "Refusing to replace existing path without --force: $dst" >&2
      exit 1
    fi
    rm -rf "$dst"
  fi
  if [[ "$mode" == "symlink" ]]; then
    ln -s "$src" "$dst"
  else
    cp -R "$src" "$dst"
  fi
}

install_optional_path() {
  local src="$1"
  local dst="$2"
  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ "$force" -ne 1 ]]; then
      echo "Leaving existing path unchanged: $dst" >&2
      return 0
    fi
  fi
  install_path "$src" "$dst"
}

install_copilot_rules() {
  local rules_src="$1"
  local instructions_dir="$2"
  mkdir -p "$instructions_dir"
  shopt -s nullglob
  for rule_src in "$rules_src"/*.md; do
    local rule_name
    rule_name="$(basename "$rule_src" .md)"
    install_path "$rule_src" "$instructions_dir/$rule_name.instructions.md"
  done
}

install_codex() {
  install_path "$repo_root/providers/codex/AGENTS.md" "$target/AGENTS.md"
  echo "Installed Codex entrypoint: $target/AGENTS.md (mode: $mode)"
}

install_copilot() {
  mkdir -p "$target/.github"
  install_optional_path "$repo_root/providers/codex/AGENTS.md" "$target/AGENTS.md"
  install_path "$repo_root/providers/copilot/copilot-instructions.md" "$target/.github/copilot-instructions.md"
  install_copilot_rules "$repo_root/rules" "$target/.github/instructions"
  echo "Installed Copilot entrypoints:"
  echo "  - $target/AGENTS.md (mode: $mode)"
  echo "  - $target/.github/copilot-instructions.md (mode: $mode)"
  echo "  - $target/.github/instructions/*.instructions.md (mode: $mode)"
}

install_claude() {
  install_path "$repo_root/providers/claude/CLAUDE.md" "$target/CLAUDE.md"
  echo "Installed Claude entrypoint: $target/CLAUDE.md (mode: $mode)"
}

install_opencode() {
  mkdir -p "$target/.opencode"
  install_optional_path "$repo_root/providers/codex/AGENTS.md" "$target/AGENTS.md"
  install_path "$repo_root/providers/opencode/opencode.jsonc" "$target/.opencode/opencode.jsonc"
  echo "Installed Opencode entrypoints:"
  echo "  - $target/AGENTS.md (mode: $mode)"
  echo "  - $target/.opencode/opencode.jsonc (mode: $mode)"
}

case "$provider" in
  codex)    install_codex ;;
  copilot)  install_copilot ;;
  claude)   install_claude ;;
  opencode) install_opencode ;;
  all)
    install_codex
    install_copilot
    install_claude
    install_opencode
    ;;
esac
