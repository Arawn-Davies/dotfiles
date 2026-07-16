# Port Paul's Claude Tooling + Neovim + CLI Configs — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Claude tmux session-status feature (Tier 1), the Neovim config, and the CLI tool configs from `~/src/dotfiles` (Paul's checkout) into `~/dotfiles`, installed via dotbot.

**Architecture:** Restructure `~/dotfiles` to dotbot's declarative-symlink model using Paul's top-level-directory convention. Copy files from the local source checkout (no network). Two configs are *merged/grafted* in place rather than symlinked, to preserve the user's own settings: `~/.claude/settings.json` (hook merge) and `tmux.conf` (feature graft).

**Tech Stack:** dotbot (git submodule), zsh/bash, tmux 3.x user-options, Neovim (Lazy.nvim), `jq`.

## Global Constraints

- Source of truth is the local checkout `~/src/dotfiles`. No network. Leave it untouched.
- Target repo `~/dotfiles`, worked and committed on `main` (no feature branch).
- Zero `/Users/paul` or `paulrichardalden` strings may remain in `~/dotfiles` at the end.
- `brew` is NEVER run by the agent. The `brew bundle` step is surfaced for the user to run.
- Do NOT symlink or overwrite `~/.claude/settings.json` — merge into it.
- Do NOT port Paul's `statusline-command.sh`. The user's OWN statusline (their usage bar) is instead copied into the repo (`claude/statusline-command.sh`) and dotbot-linked back to `~/.claude/statusline-command.sh` for version control. Content unchanged.
- Do NOT port `gitconfig` — the user's is already correct.
- Keep the user's existing `kitty.conf` — skip Paul's `kitty/`.

---

### Task 1: dotbot scaffolding (replace hand-rolled install.sh)

**Files:**
- Create: `~/dotfiles/dotbot` (git submodule)
- Create: `~/dotfiles/install` (wrapper)
- Create: `~/dotfiles/install.conf.yaml`
- Delete: `~/dotfiles/install.sh`

**Interfaces:**
- Produces: a working `./install` that symlinks every existing config plus the new ones added in later tasks. Later tasks append `link:` entries to `install.conf.yaml`.

- [ ] **Step 1: Add dotbot as a submodule**

```bash
cd ~/dotfiles
git submodule add -q https://github.com/anishathalye/dotbot
git config -f .gitmodules submodule.dotbot.ignore dirty
```

- [ ] **Step 2: Create the `./install` wrapper**

```bash
cat > ~/dotfiles/install <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
DOTFILES="$(cd "$(dirname "$0")" && pwd)"
cd "$DOTFILES"
git submodule update --init --recursive
"$DOTFILES/dotbot/bin/dotbot" -d "$DOTFILES" -c install.conf.yaml "$@"
EOF
chmod +x ~/dotfiles/install
```

- [ ] **Step 3: Create `install.conf.yaml` covering the CURRENT configs**

This reproduces exactly what `install.sh` linked today. Later tasks append to the `link:` block.

```yaml
- defaults:
    link:
      relink: true
      create: true

- clean: ["~", "~/.config"]

- link:
    ~/.zshrc: zshrc
    ~/worktrees.sh: worktrees.sh
    ~/.tmux.conf: tmux.conf
    ~/.gitconfig: gitconfig
    ~/.config/git/ignore: .config/git/ignore
    ~/.config/kitty/kitty.conf: .config/kitty/kitty.conf
    ~/.config/sketchybar/sketchybarrc: .config/sketchybar/sketchybarrc
    ~/.claude/statusline-command.sh: claude/statusline-command.sh
```

> `claude/statusline-command.sh` is the user's OWN statusline, already copied into the repo. dotbot links it back over the live file (identical content), so the usage bar keeps working and is now tracked. Note: `~/.claude/settings.json` is deliberately absent from this map — it is merged in place (Task 5), never linked.

- [ ] **Step 4: Remove the old installer**

```bash
git -C ~/dotfiles rm -q install.sh
```

- [ ] **Step 5: Run dotbot and verify existing symlinks resolve**

Run: `~/dotfiles/install`
Then: `ls -l ~/.zshrc ~/.tmux.conf ~/.gitconfig ~/.config/git/ignore`
Expected: all four are symlinks into `~/dotfiles`, none dangling. Command exits 0.

- [ ] **Step 6: Commit**

```bash
cd ~/dotfiles
git add .gitmodules dotbot install install.conf.yaml claude/statusline-command.sh
git commit -m "Switch installer to dotbot; track own Claude statusline; retire install.sh"
```

---

### Task 2: CLI tool configs

**Files:**
- Create: `~/dotfiles/bat/`, `lazygit/`, `ranger/`, `htop/`, `fzfrc`, `asdfrc`, `homebrew/Brewfile` (copied from source)
- Modify: `~/dotfiles/install.conf.yaml` (append links)

**Interfaces:**
- Consumes: the `link:` block from Task 1.

- [ ] **Step 1: Copy the CLI configs from the source checkout**

```bash
cd ~/dotfiles
cp -R ~/src/dotfiles/bat ~/src/dotfiles/lazygit ~/src/dotfiles/ranger ~/src/dotfiles/htop .
cp ~/src/dotfiles/fzfrc ~/src/dotfiles/asdfrc .
mkdir -p homebrew && cp ~/src/dotfiles/homebrew/Brewfile homebrew/Brewfile
```

- [ ] **Step 2: Confirm no paul-coupling was copied in**

Run: `grep -rIn "/Users/paul\|paulrichardalden" bat lazygit ranger htop fzfrc asdfrc homebrew`
Expected: no output.
(`.tool-versions` is intentionally NOT copied — asdf is not installed and there is nothing to seed.)

- [ ] **Step 3: Append the CLI links to `install.conf.yaml`**

Add these lines under the existing `link:` block:

```yaml
    ~/.config/bat: bat
    ~/.config/lazygit: lazygit
    ~/.config/ranger: ranger
    ~/.config/htop: htop
    ~/.fzfrc: fzfrc
    ~/.asdfrc: asdfrc
    ~/.Brewfile: homebrew/Brewfile
```

- [ ] **Step 4: Run dotbot and verify the new symlinks resolve**

Run: `~/dotfiles/install`
Then: `ls -l ~/.config/bat ~/.config/lazygit ~/.fzfrc ~/.asdfrc ~/.Brewfile`
Expected: all are symlinks into `~/dotfiles`, none dangling.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles
git add bat lazygit ranger htop fzfrc asdfrc homebrew install.conf.yaml
git commit -m "Add CLI tool configs (bat, lazygit, ranger, htop, fzf, asdf, Brewfile)"
```

> **User action (not run by agent):** after this task, packages install via `! brew bundle --file ~/.Brewfile`.

---

### Task 3: Neovim config

**Files:**
- Create: `~/dotfiles/neovim/` (copied from source)
- Modify: `~/dotfiles/install.conf.yaml`

- [ ] **Step 1: Copy the Neovim config**

```bash
cp -R ~/src/dotfiles/neovim ~/dotfiles/neovim
```

- [ ] **Step 2: Append the nvim link to `install.conf.yaml`**

```yaml
    ~/.config/nvim: neovim
```

- [ ] **Step 3: Run dotbot**

Run: `~/dotfiles/install`
Then: `ls -l ~/.config/nvim`
Expected: symlink into `~/dotfiles/neovim`.

- [ ] **Step 4: Verify Neovim loads the config without errors**

Run: `nvim --headless -c "lua vim.cmd('checkhealth')" -c "qa" 2>&1 | tail -20`
Expected: Neovim starts, Lazy.nvim bootstraps plugins, no Lua config errors (plugin install messages are fine).

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles
git add neovim install.conf.yaml
git commit -m "Add Neovim config (Lazy.nvim)"
```

---

### Task 4: Claude tmux scripts

**Files:**
- Create: `~/dotfiles/tmux/scripts/claude-lib.sh`, `claude-notify.sh`, `claude-tick.sh`, `claude-jump.sh`, `claude-clear-done.sh`
- Modify: `~/dotfiles/install.conf.yaml`

**Interfaces:**
- Produces: `~/.config/tmux/scripts/claude-notify.sh <working|urgent|done|clear>` (called by settings.json hooks in Task 5); `claude-tick.sh` (called from tmux `status-right` in Task 6); `claude-clear-done.sh <pane_id>` and `claude-jump.sh` (called from tmux hooks/bindings in Task 6). All read/write tmux user-options `@claude_pane_state`, `@claude_alert`, `@claude_since`, `@claude_notified`.

- [ ] **Step 1: Copy just the five Tier-1 scripts (not fzf-claude / not fzf-* infra)**

```bash
mkdir -p ~/dotfiles/tmux/scripts
cp ~/src/dotfiles/tmux/scripts/claude-lib.sh \
   ~/src/dotfiles/tmux/scripts/claude-notify.sh \
   ~/src/dotfiles/tmux/scripts/claude-tick.sh \
   ~/src/dotfiles/tmux/scripts/claude-jump.sh \
   ~/src/dotfiles/tmux/scripts/claude-clear-done.sh \
   ~/dotfiles/tmux/scripts/
chmod +x ~/dotfiles/tmux/scripts/*.sh
```

- [ ] **Step 2: Verify no script sources the excluded fzf/popup infra**

Run: `grep -nE "fzf-|\\\$POPUP|tmux-popup" ~/dotfiles/tmux/scripts/*.sh`
Expected: no output. (If any appears, that script pulled a Tier-2 dependency and must be reviewed — Tier-1 scripts should only source `claude-lib.sh`.)

- [ ] **Step 3: Append the scripts-dir link to `install.conf.yaml`**

```yaml
    ~/.config/tmux/scripts: tmux/scripts
```

- [ ] **Step 4: Run dotbot and verify**

Run: `~/dotfiles/install`
Then: `ls -l ~/.config/tmux/scripts/claude-lib.sh && bash -n ~/.config/tmux/scripts/claude-notify.sh && echo "syntax ok"`
Expected: symlink resolves; `syntax ok` prints (no bash syntax errors).

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles
git add tmux/scripts install.conf.yaml
git commit -m "Add Claude tmux status scripts (Tier 1)"
```

---

### Task 5: Merge Claude hooks into the live ~/.claude/settings.json

**Files:**
- Modify (live, OUT of repo, NOT symlinked): `~/.claude/settings.json`

**Interfaces:**
- Consumes: `~/.config/tmux/scripts/claude-notify.sh` from Task 4.

This is a `jq` merge that ADDS the tmux-notify hooks while preserving every existing key and hook. It drops Paul's `context-mode-cache-heal.mjs` (the user already has their own SessionStart cache-heal) and does NOT touch `statusLine` (already identical).

- [ ] **Step 1: Back up the live settings**

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak
```

- [ ] **Step 2: Merge the notify hooks with jq**

Appends `claude-notify.sh working` to the existing `SessionStart` and `UserPromptSubmit` arrays, and adds `Notification`, `Stop`, `PreToolUse`, `PostToolUse`, `SessionEnd`.

```bash
NOTIFY='~/.config/tmux/scripts/claude-notify.sh'
jq --arg n "$NOTIFY" '
  def grp(state): {hooks:[{type:"command", command:($n + " " + state)}]};
  .hooks.SessionStart    = ((.hooks.SessionStart    // []) + [grp("working")])
  | .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + [grp("working")])
  | .hooks.Notification  = ((.hooks.Notification  // []) + [{matcher:"permission_prompt|elicitation_dialog|agent_needs_input"} + grp("urgent")])
  | .hooks.Stop          = ((.hooks.Stop          // []) + [grp("done")])
  | .hooks.PreToolUse    = ((.hooks.PreToolUse    // []) + [grp("working")])
  | .hooks.PostToolUse   = ((.hooks.PostToolUse   // []) + [grp("working")])
  | .hooks.SessionEnd    = ((.hooks.SessionEnd    // []) + [grp("clear")])
' ~/.claude/settings.json.bak > ~/.claude/settings.json
```

- [ ] **Step 3: Verify JSON is valid and originals survived**

```bash
jq -e '
  .permissions.allow and .statusLine.command and .enabledPlugins and
  (.hooks.UserPromptSubmit | length) >= 3 and
  ([.hooks.Stop,.hooks.Notification,.hooks.PreToolUse,.hooks.PostToolUse,.hooks.SessionEnd] | all(. != null)) and
  ([.. | strings | select(test("claude-notify.sh"))] | length) == 7
' ~/.claude/settings.json && echo "MERGE OK"
```
Expected: `MERGE OK`. (Original `permissions`, `statusLine`, `enabledPlugins` intact; UserPromptSubmit now has the two originals + 1 new; all five new events present; exactly 7 `claude-notify.sh` references.)

- [ ] **Step 4: Verify no paul path leaked in**

Run: `grep -c "/Users/paul" ~/.claude/settings.json`
Expected: `0`.

> No git commit — this file lives outside the repo. The `.bak` is the rollback.

---

### Task 6: Graft the status feature into tmux.conf

**Files:**
- Modify: `~/dotfiles/tmux.conf`

**Interfaces:**
- Consumes: `claude-tick.sh`, `claude-clear-done.sh`, `claude-jump.sh` from Task 4; the `@claude_alert` user-option they maintain.

Colours are mapped from Paul's hex theme to the user's existing 256-colour palette: urgent→`colour196` (red), done→`colour33` (the user's accent blue), working→`colour220` (yellow). The `A` jump binding uses the user's default prefix table (prefix `C-a`, then `A`) — not Paul's `tmux-popup` table, which is not ported.

- [ ] **Step 1: Set the 2-second status refresh**

Add after `tmux.conf:13` (`set -g history-limit 50000`):

```tmux
set -g status-interval 2       # claude-tick.sh sweeps pane state every 2s
```

- [ ] **Step 2: Prepend claude-tick to status-right**

Replace `tmux.conf:31`:

```tmux
set -g status-right "#(~/.config/tmux/scripts/claude-tick.sh)#[fg=colour238] %H:%M "
```

- [ ] **Step 3: Weave the @claude_alert dot into both window formats**

Replace `tmux.conf:32-33`:

```tmux
set -g window-status-format         "#[fg=colour245] #I:#W#{?#{==:#{@claude_alert},urgent}, #[fg=colour196]●#[fg=colour245],#{?#{==:#{@claude_alert},done}, #[fg=colour33]●#[fg=colour245],#{?#{==:#{@claude_alert},working}, #[fg=colour220]●#[fg=colour245],}}} "
set -g window-status-current-format "#[fg=colour255,bold,bg=colour238] #I:#W#{?#{==:#{@claude_alert},urgent}, #[fg=colour196]●#[fg=colour255],#{?#{==:#{@claude_alert},done}, #[fg=colour33]●#[fg=colour255],#{?#{==:#{@claude_alert},working}, #[fg=colour220]●#[fg=colour255],}}} "
```

- [ ] **Step 4: Add the pane-focus-in clear hook and the jump binding**

Add after `tmux.conf:74` (`bind R source-file ...`):

```tmux
# ── Claude session status ─────────────────────────────────────────────────────
set-hook -g pane-focus-in "run-shell \"~/.config/tmux/scripts/claude-clear-done.sh #{pane_id}\""
bind A run-shell "~/.config/tmux/scripts/claude-jump.sh"   # prefix C-a A → jump to oldest blocked Claude
```

- [ ] **Step 5: Verify tmux parses the config with no error**

Run (inside or outside a tmux session):
```bash
tmux -f ~/dotfiles/tmux.conf new-session -d -s _lint 2>&1; echo "exit=$?"; tmux kill-session -t _lint 2>/dev/null
```
Expected: `exit=0`, no parse error printed.

- [ ] **Step 6: Functional check — a manual notify lights the dot**

```bash
tmux new-session -d -s _claudetest
tmux send-keys -t _claudetest "~/.config/tmux/scripts/claude-notify.sh working; tmux show -p @claude_pane_state" C-m
sleep 1
tmux show-options -p -t _claudetest @claude_pane_state 2>/dev/null
tmux kill-session -t _claudetest
```
Expected: `@claude_pane_state working` is reported (proves notify → tmux user-option path works end to end).

- [ ] **Step 7: Reload and commit**

```bash
tmux source-file ~/.tmux.conf 2>/dev/null || true
cd ~/dotfiles
git add tmux.conf
git commit -m "Graft Claude session-status feature into tmux.conf"
```

---

### Task 7: Final integration sweep

**Files:** none created; verification + install of the whole.

- [ ] **Step 1: Full install from clean**

Run: `~/dotfiles/install`
Expected: exits 0; dotbot reports all links (no failures).

- [ ] **Step 2: Assert zero paul-coupling in the repo**

Run: `grep -rIn "/Users/paul\|paulrichardalden" ~/dotfiles --exclude-dir=.git --exclude-dir=dotbot`
Expected: no output.

- [ ] **Step 3: Assert every new symlink resolves (no dangling)**

```bash
for l in ~/.config/nvim ~/.config/tmux/scripts ~/.config/bat ~/.config/lazygit \
         ~/.config/ranger ~/.config/htop ~/.fzfrc ~/.asdfrc ~/.Brewfile ~/.tmux.conf; do
  [ -e "$l" ] && echo "OK   $l" || echo "DANGLING $l"
done
```
Expected: every line `OK`.

- [ ] **Step 4: Confirm the Claude usage bar is tracked and still works**

Run: `ls -l ~/.claude/statusline-command.sh && diff -q ~/.claude/statusline-command.sh ~/dotfiles/claude/statusline-command.sh`
Expected: now a symlink into `~/dotfiles/claude/statusline-command.sh`; `diff` reports identical (it is the same file). Usage bar content unchanged.

- [ ] **Step 5: Report remaining user-run step**

Print a reminder that package installation is the user's to run: `! brew bundle --file ~/.Brewfile`.

## Self-Review

- **Spec coverage:** dotbot (Task 1) ✓; Claude tmux tooling scripts (Task 4) + hook merge (Task 5) + tmux graft (Task 6) ✓; Neovim (Task 3) ✓; CLI configs (Task 2) ✓; paul-decoupling (Tasks 2/4/5/7 greps) ✓; kitty-kept / statusline-not-ported / gitconfig-not-touched encoded in Global Constraints ✓; Tier-2 fzf popup excluded (Task 4 Step 2 guard) ✓.
- **Deviations from spec (deliberate, verified during planning):** statusline-command.sh NOT ported (user has own; identical config) — spec's "copy statusline" line superseded. gitconfig NOT ported (user's already correct). `.tool-versions` NOT created (asdf absent, nothing to seed). These tighten scope and avoid clobbering; noted in Global Constraints.
- **Placeholder scan:** none — every step has exact commands/code.
- **Consistency:** script names, `@claude_*` option names, and the four notify states (`working|urgent|done|clear`) match across Tasks 4/5/6.
