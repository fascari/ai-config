#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install-provider-rules.sh --provider codex [--target PATH] [--mode symlink|copy] [--force]

Installs provider-native project rules into a target repository.

Options:
  --provider  Provider name. Currently supported: codex
  --target    Target repository path. Defaults to the current working directory.
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

if [[ "$provider" != "codex" ]]; then
  echo "Unsupported provider: $provider" >&2
  echo "Supported providers: codex" >&2
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

template_src="$repo_root/providers/codex/AGENTS.md"
rules_src="$repo_root/rules"
agents_dst="$target/AGENTS.md"
rules_dst="$target/.codex/rules"

mkdir -p "$target/.codex"

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

install_path "$rules_src" "$rules_dst"
install_path "$template_src" "$agents_dst"

echo "Installed provider-native project rules:"
echo "- provider: $provider"
echo "- mode: $mode"
echo "- target: $target"
echo "- entrypoint: $agents_dst"
echo "- shared rules: $rules_dst"
