#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install-provider-rules.sh --provider codex|copilot|claude|opencode|all [--target PATH] [--force]

Installs provider-native project entrypoints into a target repository.
Auto-detects project language, commands, and architecture from go.mod, mise.toml, etc.
Entrypoints are generated with actual project data (not templates).

Options:
  --provider  Provider name. Supported: codex, copilot, claude, opencode, all
  --target    Target repository path. Defaults to current directory.
  --force     Replace existing managed files
EOF
}

provider=""
target="$(pwd)"
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

repo_root="$(cd "$(dirname "$0")" && pwd)"
target="$(cd "$target" && pwd)"

if [[ ! -d "$target/.git" && ! -f "$target/.git" ]]; then
  echo "Target does not look like a git repository: $target" >&2
  exit 1
fi

# ============================================================
# Auto-detect project info
# ============================================================
detect_lang() {
  if [[ -f "$target/go.mod" ]]; then
    local mod
    mod=$(head -1 "$target/go.mod" 2>/dev/null | awk '{print $2}')
    local ver
    ver=$(grep '^go ' "$target/go.mod" 2>/dev/null | awk '{print $2}')
    echo "Go $ver ($mod)"
  elif [[ -f "$target/package.json" ]]; then
    local ver
    ver=$(grep '"version"' "$target/package.json" 2>/dev/null | head -1 | sed 's/.*: *"\(.*\)".*/\1/')
    local pkg
    pkg=$(grep '"name"' "$target/package.json" 2>/dev/null | head -1 | sed 's/.*: *"\(.*\)".*/\1/')
    echo "Node.js${ver:+ $ver}${pkg:+ ($pkg)}"
  elif [[ -f "$target/Cargo.toml" ]]; then
    echo "Rust"
  elif [[ -f "$target/pyproject.toml" ]]; then
    echo "Python"
  else
    echo "Unknown"
  fi
}

detect_entrypoints() {
  local eps=()
  for dir in "$target"/cmd/*/; do
    [[ -d "$dir" ]] && eps+=("$(basename "$dir")")
  done
  if [[ ${#eps[@]} -gt 0 ]]; then
    printf '%s\n' "cmd/{$(IFS=,; echo "${eps[*]}")}/"
    return
  fi
  [[ -f "$target/main.go" ]] && echo "main.go" && return
  [[ -f "$target/src/index.ts" ]] && echo "src/index.ts" && return
  [[ -f "$target/src/main.rs" ]] && echo "src/main.rs" && return
  echo "Unknown"
}

detect_architecture() {
  if [[ -d "$target/cmd" && -d "$target/internal" ]]; then
    echo "Go standard layout (cmd/, internal/)"
    return
  fi
  if [[ -d "$target/src" && -d "$target/tests" ]]; then
    echo "src/ + tests/"
    return
  fi
  if [[ -d "$target/src" ]]; then
    echo "src/"
    return
  fi
  echo "Standard layout"
}

detect_commands() {
  local tasks=()
  if [[ -f "$target/.mise.toml" ]]; then
    while IFS= read -r line; do
      # Match [tasks.name] or [tasks."name.with.dots"]
      if [[ $line =~ ^\[tasks\.\"([^\"]+)\"\]$ ]]; then
        tasks+=("${BASH_REMATCH[1]}")
      elif [[ $line =~ ^\[tasks\.([a-zA-Z0-9_-]+)\]$ ]]; then
        tasks+=("${BASH_REMATCH[1]}")
      fi
    done < "$target/.mise.toml"
  fi
  printf '%s\n' "${tasks[@]}"
}

detect_stack_info() {
  local info=""
  [[ -f "$target/Dockerfile" ]] && info="${info:+ + }Docker"
  [[ -d "$target/.github/workflows" ]] && info="${info:+ + }GitHub Actions"
  [[ -f "$target/.golangci.yml" || -f "$target/.golangci.yaml" ]] && info="${info:+ + }golangci-lint"
  [[ -f "$target/docker-compose.yml" || -f "$target/docker-compose.yaml" ]] && info="${info:+ + }Docker Compose"
  [[ -f "$target/Dockerfile.postgres" ]] && info="${info:+ + }PostgreSQL"
  echo "${info:-}"
}

write_file_if_changed() {
  local dst="$1"
  local content="$2"
  if [[ -f "$dst" && "$force" -ne 1 ]]; then
    return 1
  fi
  mkdir -p "$(dirname "$dst")"
  echo "$content" > "$dst"
  echo "  created: $dst"
}

install_symlink() {
  local src="$1"
  local dst="$2"
  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ "$force" -ne 1 ]]; then
      return 1
    fi
    rm -rf "$dst"
  fi
  ln -s "$src" "$dst"
  echo "  symlink: $dst -> $src"
}

# ============================================================
# Gather project data
# ============================================================
LANG=$(detect_lang)
ENTRYPOINT=$(detect_entrypoints)
STACK=$(detect_stack_info)

# Gather commands from mise.toml
declare -a CMDS
while IFS= read -r line; do
  [[ -n "$line" ]] && CMDS+=("$line")
done < <(detect_commands)

# Detect architecture folders
ARCH_LINES=()
for d in "$target"/cmd/*/; do
  [[ -d "$d" ]] && ARCH_LINES+=("$(basename "$d")/")
done
for d in cmd internal pkg src lib app tests docs scripts; do
  [[ -d "$target/$d" ]] && ARCH_LINES+=("$d/")
done
if [[ ${#ARCH_LINES[@]} -eq 0 ]]; then
  ARCH_LINES=("cmd/" "internal/" "pkg/")
fi

# Build AGENTS.md content
build_agents_md() {
  local project_name
  project_name=$(basename "$target")

  printf '# AGENTS.md - %s\n\n' "$project_name"
  printf '%s\n' "$LANG${STACK:+ ($STACK)}."
  printf '\n'
  printf '## Shared rules\n\n'
  printf 'Read relevant files from `~/.ai-config/rules/` before making changes:\n'
  printf -- '- Go projects: `go-style.md`, `testing.md`, `error-handling.md`, `package-design.md`, `clean-architecture.md`\n'
  printf -- '- Writing: `sanitizing-text.md`\n'
  printf '\n## Architecture\n\n```\n'
  for line in "${ARCH_LINES[@]}"; do
    printf '%s\n' "$line"
  done
  printf '```\n\n## Commands\n\n'
  if [[ ${#CMDS[@]} -gt 0 ]]; then
    for cmd in "${CMDS[@]}"; do
      local label="${cmd^}"
      label="${label//-/ }"
      label="${label//:/ }"
      printf -- '- `mise run %s` — %s\n' "$cmd" "$label"
    done
  else
    printf -- '- `mise run test` — Run tests\n- `mise run lint` — Lint\n- `mise run build` — Build\n'
  fi
  printf '\n## Hard rules\n\n'
  printf -- '- Never log and return the same error — choose one\n'
  printf -- '- No cross-domain imports inside `internal/`\n'
  printf -- '- No `else` — early returns only\n'
  printf -- '- `require` not `assert` in tests\n'
  printf -- '- **Never commit directly.** Always invoke `committing-changes` skill (`~/.ai-config/skills/committing-changes/SKILL.md`). The skill requires explicit user approval before any `git commit` or `git push`.\n'
}

# Build CLAUDE.md content
build_claude_md() {
  local project_name
  project_name=$(basename "$target")

  printf '# %s\n\n' "$project_name"
  printf '%s\n\n' "$LANG${STACK:+ ($STACK)}."
  printf '## Commands\n\n'
  if [[ ${#CMDS[@]} -gt 0 ]]; then
    for cmd in "${CMDS[@]}"; do
      local label="${cmd^}"
      label="${label//-/ }"
      label="${label//:/ }"
      printf -- '- `mise run %s` — %s\n' "$cmd" "$label"
    done
  else
    printf -- '- `mise run test` — Run tests\n- `mise run lint` — Lint\n'
  fi
  printf '\n## Shared Rules\n\n'
  printf 'Read relevant files from `~/.ai-config/rules/` before making changes:\n'
  printf -- '- `go-style.md` — naming, formatting, control flow\n'
  printf -- '- `testing.md` — table-driven tests, mocks, assertions\n'
  printf -- '- `error-handling.md` — domain errors, wrapping, HTTP mapping\n'
  printf -- '- `package-design.md` — package naming, dependency direction\n'
  printf -- '- `clean-architecture.md` — layer rules, DI, domain isolation\n'
  printf '\n## Architecture\n\n```\n'
  for line in "${ARCH_LINES[@]}"; do
    printf '%s\n' "$line"
  done
  printf '```\n\n## Hard Rules\n\n'
  printf -- '- Never log and return the same error — choose one\n'
  printf -- '- No cross-domain imports inside `internal/`\n'
  printf -- '- No `else` — early returns only\n'
  printf -- '- `require` not `assert` in tests\n'
  printf -- '- **Never commit directly.** Always invoke `committing-changes` skill (`~/.ai-config/skills/committing-changes/SKILL.md`). The skill requires explicit user approval before any `git commit` or `git push`.\n'
}

# Build opencode.jsonc content
build_opencode_jsonc() {
  cat <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.md",
    "~/.ai-config/rules/go-style.md",
    "~/.ai-config/rules/testing.md",
    "~/.ai-config/rules/error-handling.md",
    "~/.ai-config/rules/package-design.md",
    "~/.ai-config/rules/clean-architecture.md"
  ]
}
EOF
}

# Build opencode.jsonc content
build_opencode_jsonc() {
  cat <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.md",
    "~/.ai-config/rules/go-style.md",
    "~/.ai-config/rules/testing.md",
    "~/.ai-config/rules/error-handling.md",
    "~/.ai-config/rules/package-design.md",
    "~/.ai-config/rules/clean-architecture.md"
  ]
}
EOF
}

# ============================================================
# Install functions
# ============================================================
install_codex() {
  local content
  content=$(build_agents_md)
  write_file_if_changed "$target/AGENTS.md" "$content" || {
    echo "  skipped: $target/AGENTS.md (use --force to overwrite)"
  }
}

install_copilot() {
  mkdir -p "$target/.github"
  local content
  content=$(build_agents_md)
  write_file_if_changed "$target/AGENTS.md" "$content" || true

  # Install copilot instructions template (this is a static reference, ok as symlink)
  install_symlink "$repo_root/providers/copilot/copilot-instructions.md" "$target/.github/copilot-instructions.md" || {
    echo "  skipped: .github/copilot-instructions.md (use --force)"
  }

  # Symlink rules
  mkdir -p "$target/.github/instructions"
  shopt -s nullglob
  for rule_src in "$repo_root/rules"/*.md; do
    local rule_name
    rule_name="$(basename "$rule_src" .md)"
    install_symlink "$rule_src" "$target/.github/instructions/$rule_name.instructions.md" || true
  done
}

install_claude() {
  local content
  content=$(build_claude_md)
  write_file_if_changed "$target/CLAUDE.md" "$content" || {
    echo "  skipped: $target/CLAUDE.md (use --force to overwrite)"
  }
}

install_opencode() {
  mkdir -p "$target/.opencode"
  local content
  content=$(build_agents_md)
  write_file_if_changed "$target/AGENTS.md" "$content" || true

  local jsonc
  jsonc=$(build_opencode_jsonc)
  write_file_if_changed "$target/.opencode/opencode.jsonc" "$jsonc" || {
    echo "  skipped: .opencode/opencode.jsonc (use --force)"
  }
}

# ============================================================
# Summary
# ============================================================
print_summary() {
  echo ""
  echo "Detected project: $(basename "$target")"
  echo "  Language/Stack: $LANG"
  echo "  Entrypoint: $ENTRYPOINT"
  echo "  Stack: $STACK"
  echo "  Commands: ${#CMDS[@]} tasks found"
  echo "  Architecture: ${ARCH_LINES[*]}"
  echo ""
}

# ============================================================
# Execute
# ============================================================
print_summary

case "$provider" in
  codex)
    install_codex
    echo "Installed Codex entrypoint"
    ;;
  copilot)
    install_copilot
    echo "Installed Copilot entrypoints"
    ;;
  claude)
    install_claude
    echo "Installed Claude entrypoint"
    ;;
  opencode)
    install_opencode
    echo "Installed Opencode entrypoints"
    ;;
  all)
    install_codex
    install_copilot
    install_claude
    install_opencode
    echo "Installed entrypoints for all providers"
    ;;
esac
