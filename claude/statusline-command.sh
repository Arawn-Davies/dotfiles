#!/usr/bin/env bash
# Claude Code status line — information-dense display of all available metrics

input=$(cat)

# --- Model ---
model=$(echo "$input" | jq -r '.model.display_name // "unknown"')

# --- CWD (basename only to save space) ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
cwd_display=$(basename "$cwd")

# --- Git branch (fast, skip locks) ---
git_branch=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# --- Context window ---
used_pct=$(echo "$input"    | jq -r '.context_window.used_percentage      // empty')
remain_pct=$(echo "$input"  | jq -r '.context_window.remaining_percentage // empty')
ctx_size=$(echo "$input"    | jq -r '.context_window.context_window_size  // empty')
in_tok=$(echo "$input"      | jq -r '.context_window.total_input_tokens   // empty')
out_tok=$(echo "$input"     | jq -r '.context_window.total_output_tokens  // empty')

# --- Rate limits ---
five_pct=$(echo "$input"    | jq -r '.rate_limits.five_hour.used_percentage  // empty')
five_reset=$(echo "$input"  | jq -r '.rate_limits.five_hour.resets_at        // empty')
week_pct=$(echo "$input"    | jq -r '.rate_limits.seven_day.used_percentage  // empty')
week_reset=$(echo "$input"  | jq -r '.rate_limits.seven_day.resets_at        // empty')

# --- Effort / thinking ---
effort=$(echo "$input"      | jq -r '.effort.level          // empty')
thinking=$(echo "$input"    | jq -r '.thinking.enabled      // empty')

# --- Vim mode ---
vim_mode=$(echo "$input"    | jq -r '.vim.mode              // empty')

# --- Output style ---
style=$(echo "$input"       | jq -r '.output_style.name     // empty')

# --- Session name ---
session_name=$(echo "$input" | jq -r '.session_name         // empty')

# --- Worktree ---
worktree_name=$(echo "$input" | jq -r '.worktree.name       // empty')
worktree_branch=$(echo "$input" | jq -r '.worktree.branch   // empty')

# --- Agent ---
agent_name=$(echo "$input"  | jq -r '.agent.name            // empty')

# --- Version ---
version=$(echo "$input"     | jq -r '.version               // empty')

# ===== Build output segments =====

# ANSI helpers (dim terminal will tone these further)
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
MAGENTA='\033[35m'
BLUE='\033[34m'
WHITE='\033[37m'

# Two output rows so wide displays don't truncate:
#   row1 = identity (location, model, session, agent, context, tokens)
#   row2 = limits & meta (rate limits, effort/think, style, vim)
row1=()
row2=()

# -- Location block: dir + git --
loc_str=""
if [ -n "$git_branch" ]; then
  loc_str="${cwd_display}(${git_branch})"
else
  loc_str="${cwd_display}"
fi
[ -n "$worktree_name" ] && loc_str="${loc_str}[wt:${worktree_name}]"
row1+=("$(printf "${CYAN}%s${RESET}" "$loc_str")")

# -- Model + version --
model_str="${model}"
[ -n "$version" ] && model_str="${model_str} v${version}"
row1+=("$(printf "${BLUE}%s${RESET}" "$model_str")")

# -- Session name --
[ -n "$session_name" ] && row1+=("$(printf "${DIM}[%s]${RESET}" "$session_name")")

# -- Agent --
[ -n "$agent_name" ] && row1+=("$(printf "${MAGENTA}agent:%s${RESET}" "$agent_name")")

# -- Context window --
if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")
  remain_int=$(printf "%.0f" "$remain_pct")
  if   [ "$used_int" -ge 85 ]; then ctx_color="$RED"
  elif [ "$used_int" -ge 60 ]; then ctx_color="$YELLOW"
  else                               ctx_color="$GREEN"
  fi
  ctx_str="ctx:${used_int}%used/${remain_int}%left"
  [ -n "$ctx_size" ] && ctx_str="${ctx_str}($(( ctx_size / 1000 ))k)"
  row1+=("$(printf "${ctx_color}%s${RESET}" "$ctx_str")")
fi

# -- Session token totals --
if [ -n "$in_tok" ] && [ -n "$out_tok" ]; then
  in_k=$(echo "$in_tok"  | awk '{printf "%.1fk", $1/1000}')
  out_k=$(echo "$out_tok" | awk '{printf "%.1fk", $1/1000}')
  row1+=("$(printf "${WHITE}sess:in=%s,out=%s${RESET}" "$in_k" "$out_k")")
fi

# -- 5-hour rate limit --
if [ -n "$five_pct" ]; then
  five_int=$(printf "%.0f" "$five_pct")
  if   [ "$five_int" -ge 85 ]; then rl_color="$RED"
  elif [ "$five_int" -ge 60 ]; then rl_color="$YELLOW"
  else                               rl_color="$GREEN"
  fi
  rl_str="5h:${five_int}%"
  if [ -n "$five_reset" ]; then
    mins=$(( (five_reset - $(date +%s)) / 60 ))
    [ "$mins" -gt 0 ] && rl_str="${rl_str}(${mins}m)"
  fi
  row2+=("$(printf "${rl_color}%s${RESET}" "$rl_str")")
fi

# -- 7-day rate limit --
if [ -n "$week_pct" ]; then
  week_int=$(printf "%.0f" "$week_pct")
  if   [ "$week_int" -ge 85 ]; then wk_color="$RED"
  elif [ "$week_int" -ge 60 ]; then wk_color="$YELLOW"
  else                               wk_color="$GREEN"
  fi
  wk_str="7d:${week_int}%"
  if [ -n "$week_reset" ]; then
    hrs=$(( (week_reset - $(date +%s)) / 3600 ))
    [ "$hrs" -gt 0 ] && wk_str="${wk_str}(${hrs}h)"
  fi
  row2+=("$(printf "${wk_color}%s${RESET}" "$wk_str")")
fi

# -- Effort + thinking --
meta_str=""
[ -n "$effort" ] && meta_str="effort:${effort}"
if [ "$thinking" = "true" ]; then
  [ -n "$meta_str" ] && meta_str="${meta_str}+think" || meta_str="think:on"
fi
[ -n "$meta_str" ] && row2+=("$(printf "${MAGENTA}%s${RESET}" "$meta_str")")

# -- Output style (skip "default") --
if [ -n "$style" ] && [ "$style" != "default" ] && [ "$style" != "Default" ]; then
  row2+=("$(printf "${DIM}style:%s${RESET}" "$style")")
fi

# -- Vim mode --
[ -n "$vim_mode" ] && row2+=("$(printf "${YELLOW}vim:%s${RESET}" "$vim_mode")")

# ===== Join each row with separator =====
sep="$(printf "${DIM} | ${RESET}")"

join_row() {
  local out=""
  local p
  for p in "$@"; do
    [ -z "$out" ] && out="$p" || out="${out}${sep}${p}"
  done
  printf "%s" "$out"
}

line1=$(join_row "${row1[@]}")
line2=$(join_row "${row2[@]}")

# Only emit row2 if it has content - keeps minimal sessions compact.
if [ -n "$line2" ]; then
  printf "%b\n%b\n" "$line1" "$line2"
else
  printf "%b\n" "$line1"
fi
