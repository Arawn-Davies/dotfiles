#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname)"

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    echo "  backup: $dst -> ${dst}.bak"
    mv "$dst" "${dst}.bak"
  fi
  ln -s "$src" "$dst"
  echo "  linked: $dst -> $src"
}

echo "Installing dotfiles from $DOTFILES"
echo "Detected OS: $OS"
echo

# ── Cross-platform ────────────────────────────────────────────────

# Shell
link "$DOTFILES/zshrc"        "$HOME/.zshrc"
link "$DOTFILES/worktrees.sh" "$HOME/worktrees.sh"

# Tmux
link "$DOTFILES/tmux.conf"    "$HOME/.tmux.conf"

# Git
link "$DOTFILES/gitconfig"    "$HOME/.gitconfig"
link "$DOTFILES/.config/git/ignore" "$HOME/.config/git/ignore"

# ── macOS only ────────────────────────────────────────────────────

if [[ "$OS" == "Darwin" ]]; then
  echo
  echo "macOS extras:"

  # Sketchybar
  link "$DOTFILES/.config/sketchybar/sketchybarrc" "$HOME/.config/sketchybar/sketchybarrc"
  for plugin in "$DOTFILES/.config/sketchybar/plugins/"*.sh; do
    link "$plugin" "$HOME/.config/sketchybar/plugins/$(basename "$plugin")"
  done
else
  echo
  echo "Skipping macOS-only configs (sketchybar)"
fi

echo
echo "Done. You may need to restart your shell or run: source ~/.zshrc"
