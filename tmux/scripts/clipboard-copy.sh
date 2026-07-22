#!/usr/bin/env bash
# Copies stdin to the system clipboard. Bound to copy-mode-vi's `y` in tmux.conf.
#   macOS         -> pbcopy
#   WSL2          -> clip.exe (reached via PATH through /mnt/c)
#   other Linux   -> xclip, falling back to xsel

if [ "$(uname)" = "Darwin" ]; then
  exec pbcopy
elif grep -qi microsoft /proc/version 2>/dev/null; then
  exec clip.exe
elif command -v xclip >/dev/null 2>&1; then
  exec xclip -in -selection clipboard
elif command -v xsel >/dev/null 2>&1; then
  exec xsel --clipboard --input
fi
