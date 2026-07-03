#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install-provider-rules.sh --provider codex|copilot|claude|all [--target PATH] [--mode copy|symlink] [--force]

Installs provider-native project rules into a target repository.

Options:
  --provider  Provider name. Currently supported: codex, copilot, claude, all
  --target    Target repository path. Defaults to the current working directory.
  --mode      Install mode: copy (default) or symlink
  --force     Replace existing managed files
EOF
}

provider=""
target="$(pwd)"
mode="copy"
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

if [[ "$provider" != "codex" && "$provider" != "copilot" && "$provider" != "claude" && "$provider" != "all" ]]; then
  echo "Unsupported provider: $provider" >&2
  echo "Supported providers: codex, copilot, claude, all" >&2
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

shared_agents_src="$repo_root/providers/codex/AGENTS.md"
copilot_src="$repo_root/providers/copilot/copilot-instructions.md"
claude_src="$repo_root/providers/claude/CLAUDE.md"
rules_src="$repo_root/rules"

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

install_generated_path() {
  local src="$1"
  local dst="$2"
  local tmp
  local rules_path

  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ "$force" -ne 1 ]]; then
      echo "Refusing to replace existing path without --force: $dst" >&2
      exit 1
    fi
    rm -rf "$dst"
  fi

  # Try to resolve rules path intelligently:
  # 1. If AI_CONFIG_HOME is set, use that (for machine portability)
  # 2. Otherwise use relative path from target to ai-config repo
  if [[ -n "${AI_CONFIG_HOME:-}" ]]; then
    rules_path="$AI_CONFIG_HOME/rules"
  else
    rules_path="$(realpath --relative-to="$(dirname "$dst")" "$rules_src")"
  fi

  tmp="$(mktemp)"
  sed "s#__AI_CONFIG_RULES_DIR__#$rules_path#g" "$src" > "$tmp"
  cp "$tmp" "$dst"
  rm -f "$tmp"
}

install_optional_generated_path() {
  local src="$1"
  local dst="$2"

  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ "$force" -ne 1 ]]; then
      echo "Leaving existing path unchanged: $dst" >&2
      return 0
    fi
  fi

  install_generated_path "$src" "$dst"
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
  local src_dir="$1"
  local dst_dir="$2"
  local rule_src

  mkdir -p "$dst_dir"

  shopt -s nullglob
  for rule_src in "$src_dir"/*.md; do
    local rule_name
    rule_name="$(basename "$rule_src" .md)"
    install_path "$rule_src" "$dst_dir/$rule_name.instructions.md"
  done
}

install_codex() {
  install_generated_path "$shared_agents_src" "$target/AGENTS.md"

  echo "Installed Codex-native project rules:"
  echo "- mode: $mode"
  echo "- target: $target"
  echo "- entrypoint: $target/AGENTS.md"
  echo "- shared rules: $rules_src"
}

install_copilot() {
  mkdir -p "$target/.github/instructions"
  install_optional_generated_path "$shared_agents_src" "$target/AGENTS.md"
  install_path "$copilot_src" "$target/.github/copilot-instructions.md"
  install_copilot_rules "$rules_src" "$target/.github/instructions"

  echo "Installed Copilot-native project rules:"
  echo "- mode: $mode"
  echo "- target: $target"
  echo "- shared AGENTS: $target/AGENTS.md"
  echo "- copilot instructions: $target/.github/copilot-instructions.md"
  echo "- path-specific rules: $target/.github/instructions"
}

install_claude() {
  install_generated_path "$claude_src" "$target/CLAUDE.md"

  echo "Installed Claude-native project rules:"
  echo "- mode: $mode"
  echo "- target: $target"
  echo "- entrypoint: $target/CLAUDE.md"
  echo "- shared rules: $rules_src"
}

case "$provider" in
  codex)
    install_codex
    ;;
  copilot)
    install_copilot
    ;;
  claude)
    install_claude
    ;;
  all)
    install_codex
    install_copilot
    install_claude
    ;;
esac
