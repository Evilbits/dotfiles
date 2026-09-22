#!/bin/sh
# statusLine command: renders "<model> | <repo> <branch> [primary|worktree]" at
# the bottom of the Claude Code session. Both cases carry an explicit label so a
# session that has dropped out of a worktree (e.g. after a restart, which resets
# the working directory to wherever Claude was launched) is obvious at a glance.
#
# Claude Code pipes session JSON on stdin every turn, so keep this cheap:
# one jq call plus one git call in the common case.
#
# Debug: `touch ~/.claude/statusline-debug` to dump the raw payload to
# ~/.claude/statusline-last.json on every render.
input=$(cat)

[ -f "$HOME/.claude/statusline-debug" ] && printf '%s' "$input" > "$HOME/.claude/statusline-last.json"

# .cwd is the fallback in case workspace.current_dir is absent; effort is absent
# on older versions, in which case it is simply omitted from the output.
fields=$(printf '%s' "$input" | jq -r '[.model.display_name, (.workspace.current_dir // .cwd), (.effort.level // ""), (.session_name // ""), (.session_id // "")] | @tsv')
model=$(printf '%s' "$fields" | cut -f1)
dir=$(printf '%s' "$fields" | cut -f2)
effort=$(printf '%s' "$fields" | cut -f3)
session=$(printf '%s' "$fields" | cut -f4)
session_id=$(printf '%s' "$fields" | cut -f5)

# One call into the session picker's index (read-only, cached): the Jira ticket
# this session is about, this session's own snooze, and how many snoozed
# sessions are due. Claude's own titles never carry the ticket, so it is
# prefixed unless the name already contains it.
ticket=""; own_snooze=""; due_count=0
if [ -n "$session_id" ]; then
  sl=$("$HOME/.claude/bin/claude-sessions" --statusline "$session_id" 2>/dev/null)
  ticket=$(printf '%s' "$sl" | cut -f1)
  own_snooze=$(printf '%s' "$sl" | cut -f2)
  due_count=$(printf '%s' "$sl" | cut -f3)
fi
if [ -n "$ticket" ]; then
  case "$session" in
    *"$ticket"*) ;;
    "") session="$ticket" ;;
    *) session="$ticket · $session" ;;
  esac
fi

# Keep a long session name from crowding out the branch.
[ "${#session}" -gt 52 ] && session="$(printf '%.51s' "$session")…"

# "Opus 5 (1M context) · medium"
left="$model${effort:+ · $effort}"

# 256-colour 183 ≈ Catppuccin Macchiato mauve (#c6a0f6). Unnamed sessions omit
# the segment entirely rather than showing an empty one.
name_seg=""
[ -n "$session" ] && name_seg="$(printf '\033[38;5;183m%s\033[0m | ' "$session")"
# This session's own snooze in dim, and a yellow count when other sessions are due.
[ -n "$own_snooze" ] && name_seg="$name_seg$(printf '\033[2m%s\033[0m | ' "$own_snooze")"
[ "${due_count:-0}" -gt 0 ] && name_seg="$name_seg$(printf '\033[33m⏰ %s due\033[0m | ' "$due_count")"

if ! git_info=$(git -C "$dir" rev-parse --path-format=absolute --git-dir --git-common-dir --show-toplevel --abbrev-ref HEAD 2>/dev/null); then
  if [ -n "$session" ]; then
    printf '%s | %s | \033[38;5;183m%s\033[0m' "$left" "$(basename "$dir")" "$session"
  else
    printf '%s | %s' "$left" "$(basename "$dir")"
  fi
  exit 0
fi

git_dir=$(printf '%s\n' "$git_info" | sed -n 1p)
common_dir=$(printf '%s\n' "$git_info" | sed -n 2p)
toplevel=$(printf '%s\n' "$git_info" | sed -n 3p)
branch=$(printf '%s\n' "$git_info" | sed -n 4p)

# Detached HEAD reports "HEAD"; show the short SHA instead.
[ "$branch" = "HEAD" ] && branch="@$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)"

# The repo name comes from the COMMON dir so a worktree still shows the repo it
# belongs to rather than the worktree folder.
repo=$(basename "$(dirname "$common_dir")")

if [ "$git_dir" != "$common_dir" ]; then
  # Linked worktree: its git dir lives under <common>/worktrees/<name>.
  folder=$(basename "$toplevel")
  if [ "$folder" = "$branch" ]; then
    label="worktree"
  else
    label="worktree: $folder"
  fi
  printf '%s | %s | %s\033[33m⧉ %s [%s]\033[0m' "$left" "$repo" "$name_seg" "$branch" "$label"
else
  # 256-colour 116 ≈ Catppuccin Macchiato teal (#8bd5ca), to match the editor.
  printf '%s | %s | %s\033[38;5;116m⎇ %s [primary]\033[0m' "$left" "$repo" "$name_seg" "$branch"
fi

# Second row, only while the session has neither a name nor a ticket yet: the
# personal skill set, so a fresh session opens with the menu visible instead of
# relying on memory to type /doxy-.
if [ -z "$session" ]; then
  printf '\n\033[2m/doxy-design · /doxy-ticket · /doxy-implement · /doxy-review\033[0m'
fi
