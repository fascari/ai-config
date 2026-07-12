#!/usr/bin/env bash
set -euo pipefail

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
echo ""

# Step 2: Symlink skills globally for all providers
echo "--- Installing global skills ---"
"$script_dir/install-global-skills.sh" --provider all
echo ""

# Step 3: Symlink opencode agents globally
echo "--- Installing global opencode agents ---"
mkdir -p ~/.config/opencode/agents
ln -sf "$script_dir/providers/opencode/agents/"*.md ~/.config/opencode/agents/
echo "Symlinked opencode agents to ~/.config/opencode/agents/"
echo ""

# Step 4: Add AI_CONFIG_HOME to shell rc if not present
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
