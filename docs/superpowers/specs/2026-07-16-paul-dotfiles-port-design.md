# Port Paul's Claude tooling + Neovim + CLI configs into ~/dotfiles

**Date:** 2026-07-16
**Repo:** `~/dotfiles` (github.com/Arawn-Davies/dotfiles), worked on `main`
**Source (local, no network):** `~/src/dotfiles` — a checkout of Paul's repo (github.com/paulalden/dotfiles), left untouched.

## Goal

Make the user's dotfiles more similar to a colleague's (Paul's) by adopting three components — the Claude tmux session-status tooling (Tier 1), the Neovim config, and the smaller CLI tool configs — and switching the installer to dotbot. The tiling WM stack (yabai/skhd/sketchybar), Alfred workflows, and an upstream-remote sync model are explicitly out of scope.

## Hard constraints (discovered during exploration)

### C1 — "Claude tmux tooling" is a feature woven across three subsystems, not a folder

It comprises:

- **`claude/settings.json`** — 6 hook entries calling `~/.config/tmux/scripts/claude-notify.sh <state>` (states: `working`, `urgent`, `done`, `clear`), plus a `statusLine` command running `bash ~/.claude/statusline-command.sh`.
- **`tmux/scripts/`** — `claude-lib.sh` (shared state library; source-of-truth for `@claude_pane_state`, sourced by every other script), `claude-notify.sh`, `claude-tick.sh` (runs every ~2s from `status-right`: cleans dead panes, rolls up window dots, escalates to macOS notification after a threshold), `claude-jump.sh`, `claude-clear-done.sh`.
- **`tmux/config/`** — `theme.conf` (`status-right` invokes `claude-tick.sh`; `window-status-format`/`window-status-current-format` render the `@claude_alert` ● in red/blue/yellow), `options.conf` (`pane-focus-in` hook → `claude-clear-done.sh #{pane_id}`), `keybindings.conf` (the `A` jump binding).

All script references use `~/.config/tmux/scripts/...` and dirname-relative sourcing → **portable as-is once the scripts are symlinked to `~/.config/tmux/scripts`.**

`fzf-claude.sh` (the `t a` session-switcher popup) is **Tier 2 — EXCLUDED.** It depends on Paul's `$POPUP` wrapper and `tmux-popup` key-table infrastructure. Not ported in this spec.

### C2 — Two configs must be MERGED, never wholesale-symlinked

- **`~/.claude/settings.json`** is a real 141-line file (not a symlink) containing the user's own `SessionStart` (superpowers), `UserPromptSubmit` (standing-rules injection), `PermissionRequest` hooks, plus `permissions`, `statusLine`, `model`, `theme`, `enabledPlugins`, `env`. Paul's dotbot symlinks this path to his repo; doing so here **destroys all of the above.** → Merge only the Claude-tmux hook entries + statusLine into the existing file via a script edit. Do **not** symlink this path.
- **`tmux.conf`** — the user's is monolithic and personalised (C-a prefix, custom styling, top status bar). Paul's Claude wiring lives inside his split `theme.conf`/`options.conf`/`keybindings.conf`. → Graft the feature's lines into the user's existing `tmux.conf`; do not replace it.

## Component plan

### A. Installer → dotbot

- Vendor `dotbot` as a git submodule at `dotfiles/dotbot`.
- Add `./install` wrapper (invokes dotbot with `install.conf.yaml`) and `install.conf.yaml` (declarative symlink map).
- Retire the hand-rolled `install.sh` (keep in git history; remove from tree).
- Adopt Paul's top-level-directory convention (`tmux/`, `neovim/`, `bat/`, `lazygit/`, `ranger/`, `htop/`, `fzf`, `kitty/`) so layout mirrors his. Existing `.config/git/ignore` and `.config/sketchybar/` fold into the dotbot map.
- **Excluded from the dotbot map:** `~/.claude/settings.json` (see C2 — merged, not linked).

### B. Claude tmux tooling (Tier 1)

Files copied into `~/dotfiles`:
- `tmux/scripts/claude-lib.sh`, `claude-notify.sh`, `claude-tick.sh`, `claude-jump.sh`, `claude-clear-done.sh`
- `claude/statusline-command.sh`

Wiring:
- dotbot-symlink `~/.config/tmux/scripts` (dir) and `~/.claude/statusline-command.sh`.
- **Merge** into `~/.claude/settings.json`: the 6 hook entries (mapping the correct hook events → `claude-notify.sh <state>`) and the `statusLine` command. Preserve every existing key/hook. The Paul-private `context-mode-cache-heal.mjs` PreToolUse hook is **dropped**.
- **Graft** into `tmux.conf`: the `status-right` `claude-tick.sh` call; the `@claude_alert` ● conditional woven into the user's own `window-status-format`/`window-status-current-format`; the `pane-focus-in` → `claude-clear-done.sh` hook; the `A` jump keybinding (adapted to the user's prefix/key-table scheme, not Paul's `tmux-popup` table).

### C. Neovim

- Clean copy of `neovim/` (user has none). dotbot-link `~/.config/nvim`.
- Ruby-LSP-focused (Paul's stack); config only, works as-is. No changes required.

### D. CLI configs

- Copy `bat/`, `lazygit/`, `ranger/`, `htop/`, `fzf` (`fzfrc`), `asdfrc`, and `homebrew/Brewfile`. dotbot-link each to its target (`~/.config/bat`, `~/.config/lazygit`, `~/.config/ranger`, `~/.config/htop`, `~/.fzfrc`, `~/.asdfrc`, `~/.Brewfile`).
- `.tool-versions`: create as a **real file** (not the dangling `→ /Users/paul/.tool-versions` symlink). Seed from the user's current toolchain versions, or omit if not wanted.
- **kitty conflict:** the user already has `.config/kitty/kitty.conf`. **Keep the user's**; skip Paul's `kitty/`.

## Paul-decoupling (applied during port; never carried in)

| Item | Source value | Action |
|------|--------------|--------|
| `gitconfig` email | `paulrichardalden@gmail.com` | user's identity; user's existing `gitconfig` stays authoritative |
| `gitconfig` excludesfile | `/Users/paul/.gitignore_global` | `~/.gitignore_global` |
| `settings.json:104` | `/Users/paul/.claude/hooks/context-mode-cache-heal.mjs` | **dropped** (Paul-private, not in repo, not part of feature) |
| `settings.json:222` | `additionalDirectories: [/Users/paul/Personal/repos/dotfiles]` | not merged (Paul-specific pref) |
| `.tool-versions` | symlink → `/Users/paul/.tool-versions` | real file |

## Out of scope (dropped)

Tiling WM stack (yabai/skhd/sketchybar), Alfred (217 files), upstream-remote sync (one-time copy instead), Paul's `~/.claude/settings.json` preferences (`effortLevel`, `preferredNotifChannel`, `skipAutoPermissionPrompt`, `editorMode`, etc. — only the tmux hooks + statusLine are merged), the `t a` fzf-claude session-switcher popup (Tier 2).

## Installation & verification

- **`brew bundle` is NOT run by the agent** (standing rule: no `brew`). After the Brewfile is in place, the user runs it themselves: `! brew bundle --file ~/.Brewfile`.
- dotbot `./install` performs symlinking; agent may run it (no package installs).
- Verification per component:
  - dotbot: symlinks resolve (`ls -la` targets exist, none dangling).
  - Claude tmux tooling: `~/.claude/settings.json` still valid JSON with all original keys/hooks intact **plus** the new ones (`jq` check); tmux sourced without error; a manual `claude-notify.sh working` sets `@claude_pane_state` and the window dot renders.
  - Neovim: `nvim --headless -c "checkhealth" -c "q"` runs without config errors.
  - CLI: each symlink target exists.

## Success criteria

1. `~/dotfiles` installs via `./install` (dotbot) and mirrors Paul's top-level layout.
2. The Claude tmux status feature (dots, banner, escalation, `A` jump) works on the user's machine, with the user's existing `~/.claude/settings.json` behaviour fully preserved.
3. Neovim and the CLI configs are present and functional.
4. Zero `/Users/paul` or `paulrichardalden` references remain in `~/dotfiles`.
