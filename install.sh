#!/usr/bin/env bash
set -euo pipefail

provider=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) provider="${2:-}"; shift 2 ;;
    --provider=*) provider="${1#*=}"; shift ;;
    -h|--help)
      echo "Usage: install.sh [--provider codex|copilot|claude|opencode|all]"
      echo "Sets up ~/.ai-config and, when a provider is chosen, installs its global skills."
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_CONFIG_HOME="${AI_CONFIG_HOME:-$HOME/.ai-config}"

echo "=== ai-config Setup ==="
echo "Repo:     $script_dir"
echo "Target:   $AI_CONFIG_HOME"
echo ""

# Step 1: Symlink repo subdirectories into ~/.ai-config/
echo "--- Symlinking rules, skills, and agents into $AI_CONFIG_HOME ---"
mkdir -p "$AI_CONFIG_HOME"
for subdir in rules skills agents providers; do
  if [[ -e "$AI_CONFIG_HOME/$subdir" && ! -L "$AI_CONFIG_HOME/$subdir" ]]; then
    echo "Skipping $subdir (exists and is not a symlink)"
    continue
  fi
  ln -sfn "$script_dir/$subdir" "$AI_CONFIG_HOME/$subdir"
  echo "  linked $subdir -> $script_dir/$subdir"
done
for script in install.sh install-global-skills.sh; do
  if [[ -e "$AI_CONFIG_HOME/$script" && ! -L "$AI_CONFIG_HOME/$script" ]]; then
    echo "Skipping $script (exists and is not a symlink)"
    continue
  fi
  ln -sfn "$script_dir/$script" "$AI_CONFIG_HOME/$script"
  echo "  linked $script -> $script_dir/$script"
done
echo ""

# Step 2: Install global skills for the chosen provider (no default fan-out)
if [[ -n "$provider" ]]; then
  echo "--- Installing global skills (provider: $provider) ---"
  "$script_dir/install-global-skills.sh" --provider "$provider"
else
  echo "--- Skipping global skills install (no --provider given) ---"
  echo "Choose a provider explicitly, e.g.:"
  echo "  ./install.sh --provider copilot     # Copilot-only machines (e.g. compliance-restricted)"
  echo "  ./install.sh --provider opencode    # OpenCode machines"
  echo "  ./install.sh --provider all         # deliberate opt-in: every provider"
fi
echo ""

# Step 3: Add AI_CONFIG_HOME to shell rc if not present
shell_rc=""
if [[ -n "${BASH_VERSION:-}" && -f "$HOME/.bashrc" ]]; then
  shell_rc="$HOME/.bashrc"
elif [[ -n "${ZSH_VERSION:-}" && -f "$HOME/.zshrc" ]]; then
  shell_rc="$HOME/.zshrc"
fi

if [[ -n "$shell_rc" ]]; then
  if ! grep -qF "export AI_CONFIG_HOME" "$shell_rc" 2>/dev/null; then
    echo "--- Adding AI_CONFIG_HOME to $shell_rc ---"
    printf '\n# ai-config\nexport AI_CONFIG_HOME="%s"\n' "$AI_CONFIG_HOME" >> "$shell_rc"
    echo "Added. Restart your shell or run: export AI_CONFIG_HOME=\"$AI_CONFIG_HOME\""
  else
    echo "--- AI_CONFIG_HOME already set in $shell_rc ---"
  fi
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Rules:  $AI_CONFIG_HOME/rules/"
echo "Skills: $(find "$script_dir/skills" -maxdepth 1 -type d | wc -l) skills available"
echo "Agents: $(find "$script_dir/providers/opencode/agents" -maxdepth 1 -type f | wc -l) opencode agents available"
echo ""
echo "Next steps:"
echo "  1. Restart your shell or run: export AI_CONFIG_HOME=\"$AI_CONFIG_HOME\""
echo "  2. For each project, copy the appropriate entrypoint template:"
echo "     Codex:    cp \$AI_CONFIG_HOME/providers/codex/AGENTS.md /path/to/project/"
echo "     Claude:   cp \$AI_CONFIG_HOME/providers/claude/CLAUDE.md /path/to/project/"
echo "     Opencode: cp \$AI_CONFIG_HOME/providers/codex/AGENTS.md /path/to/project/"
echo "               mkdir -p /path/to/project/.opencode"
echo "               cp \$AI_CONFIG_HOME/providers/opencode/opencode.jsonc /path/to/project/.opencode/"
echo "     Copilot:  See README.md for instructions"
