#!/usr/bin/env bash
set -euo pipefail

AI_CONFIG_HOME="${AI_CONFIG_HOME:-$HOME/.ai-config}"

echo "=== ai-config Setup ==="
echo "Target: $AI_CONFIG_HOME"
echo ""

# Step 1: Symlink skills globally for all providers
echo "--- Installing global skills ---"
"$AI_CONFIG_HOME/install-global-skills.sh" --provider all
echo ""

# Step 2: Add AI_CONFIG_HOME to shell rc if not present
shell_rc=""
if [[ -n "$BASH_VERSION" && -f "$HOME/.bashrc" ]]; then
  shell_rc="$HOME/.bashrc"
elif [[ -n "$ZSH_VERSION" && -f "$HOME/.zshrc" ]]; then
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
echo "Skills: $(find "$AI_CONFIG_HOME/skills" -maxdepth 1 -type d | wc -l) skills available"
echo ""
echo "Next steps:"
echo "  1. Restart your shell or run: export AI_CONFIG_HOME=\"$AI_CONFIG_HOME\""
echo "  2. For each project: mise run project:install:all --target /path/to/project"
echo "     Or: $AI_CONFIG_HOME/install-provider-rules.sh --provider all --target /path/to/project"
