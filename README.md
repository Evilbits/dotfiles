# dotfiles

Everything under `home/` mirrors `~`. `linker.sh` symlinks each entry into place: files directly, directories one level deep, so a folder such as `~/.config/nvim` becomes a symlink to `home/.config/nvim` while unmanaged neighbours in `~/.config` are left alone. Run it after cloning and again whenever a new top-level entry is added; it asks before overriding anything that differs.

```sh
git clone git@github.com:Evilbits/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./linker.sh
```

## Setup

Install the tools the configs expect, then link.

```sh
brew install zsh tmux neovim fzf fnm fd ripgrep glab terminal-notifier koekeishiya/formulae/skhd
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fnm install 24 && fnm default 24
./linker.sh
```

Then, inside tmux, `prefix + I` installs the tmux plugins, and the first `nvim` start installs the Neovim plugins through lazy.nvim. `skhd --start-service` enables the app hotkeys. The Claude Code section below has two more one-off steps.

## What is in here

| Area | Where | What it does |
| --- | --- | --- |
| zsh | `home/.zshrc` | oh-my-zsh with autosuggestions and syntax highlighting, git and kubectl aliases, fnm for Node with `--use-on-cd`, pnpm on PATH, `nx` as `pnpm nx`, `vim` as `nvim`, custom fzf widgets from `home/.config/fzf/key-bindings.zsh`. |
| tmux | `home/.tmux.conf` | Prefix is `C-a`. Vim-style pane movement with `hjkl`, `x`/`v` split, `c` new window in the current path, `Shift+arrows` switch windows. fzf pickers on `prefix t` (tmux sessions), `prefix r` (Claude sessions, see below) and `prefix b` (git branches). Plugins: tpm, tmux-fzf, tmux-mode-indicator. `home/.config/tmux/mem-percentage.sh` feeds the status bar. |
| Neovim | `home/.config/nvim` | lazy.nvim with one file per plugin under `lua/plugins/`: LSP, blink completion, treesitter, telescope, nvim-tree, git, Copilot, claudecode.nvim, lualine, zen mode, Catppuccin theme. General keymaps live in `lua/config.lua`, plugin keymaps in each plugin file. |
| Terminal theme | `home/catppuccin-macchiato.toml` | Catppuccin Macchiato palette for Alacritty; the tmux status line and Claude status line use the same colours. |
| skhd | `home/.config/skhd` | `cmd-1/2/3` focus or cycle Zen, Slack and Alacritty through `bin/focus_or_cycle`. |
| git | `home/.config/git/ignore` | Global ignore file. |
| Claude Code | `home/.claude` | Instructions, settings, hooks, skills and the session picker. Details below. |
| Specs | `home/.config/claude/specs` | Design briefs and plans written with Claude. They live here so they never land in a work repo. |

## Claude Code

`home/.claude` is linked to `~/.claude`. Its `.gitignore` allows only the files listed here; everything else Claude writes at runtime stays untracked.

### Files

- `CLAUDE.md`: global instructions, including the safety rules, the commit format and how `.cursor/` skills and rules in a repo take precedence.
- `settings.json`: model, permissions and the hooks below. Every hook runs `node` from fnm's default alias, `~/.local/share/fnm/aliases/default/bin`, so it works even when Claude was launched from a shell without fnm on PATH.
- `hooks/bash-guard.mjs`: PreToolUse on Bash. Denies bypassing git hooks, `npx nx` and `git add .`/`-A`; asks before force-pushes, resets, rebases, amends, branch deletes and `rm -rf`.
- `hooks/format-on-edit.mjs`: PostToolUse on Edit and Write. Runs the nearest `oxfmt` on the edited file.
- `hooks/doxy-skills-banner.mjs`: SessionStart. Lists the `/doxy-*` skills in the doxyme repos and, everywhere, the snoozed sessions, due first.
- `hooks/statusline.sh`: the status line: `model · effort | repo | <ticket> · <session name> | <own snooze> | ⏰ N due | branch [primary|worktree]`. The ticket is derived from the session's own prompts, so it appears even when Claude's auto-generated title omits it.
- `hooks/claude-rename*.mjs`, `hooks/title-prompt.mjs`: a third-party session namer, kept but not wired into settings while Claude's built-in titles are on trial.
- `skills/doxy-design`, `doxy-ticket`, `doxy-implement`, `doxy-review`: one skill per step of the development flow, from an idea to a brief, to Jira, to code and a draft MR, to an architecture-first review. `skills/snooze` parks the current session (see below).
- `bin/claude-sessions`: the session picker and snooze tool.

### Session picker: `prefix r`

Lists every Claude session across repos, read from the transcripts under `~/.claude/projects` and the live registry under `~/.claude/sessions`. Columns: state, age, repo, ticket, skill, title, MRs. Order: due, live, snoozed, then closed by age; fzf keeps that order while you type. The ticket comes from the keys you typed in the session, then the title, then Claude's replies, then the branch, so searching a ticket number finds review sessions whose branch was something else.

| Key | Action |
| --- | --- |
| `Enter` | Jump to a running session's tmux pane, or resume a closed one in a new window in that repo's tmux session. Clears its snooze. |
| `ctrl-s` | Snooze the highlighted session (asks for a duration or MR URL, and a reason). |
| `ctrl-u` | Unsnooze. |
| `ctrl-z` | Toggle a snoozed-only view. |
| `ctrl-y` | Copy the session id. |
| `End` / `Home` | Bottom and top of the list. |

The preview shows the title, live state, snooze details, tickets, MRs, skills, branch, the first prompt and the most recent prompts. A footer keeps every snoozed session in view with its remaining time.

### Snoozing

A snooze parks a session until a time, until something happens on a GitLab MR, or whichever comes first. From inside a session type `/snooze …`; from a shell use the tool directly with `current` for the session in this tmux pane or a session id prefix.

```sh
claude-sessions --snooze current 3d awaiting review on !17005
claude-sessions --snooze current https://gitlab.com/doxyme/cooks/hotpot/-/merge_requests/612 awaiting review
claude-sessions --snooze current https://gitlab.com/doxyme/cooks/hotpot/-/merge_requests/612 merge next step
claude-sessions --snooze current fri https://gitlab.com/.../merge_requests/612 whichever comes first
claude-sessions --unsnooze current
```

Durations: `30s`, `45m`, `2h`, `3d` (day-based lands at 09:00), `tomorrow`, a weekday such as `fri`, a time such as `14:30`. An MR without a mode word wakes on a comment by someone else, an approval, a failed pipeline, a conflict, merge or close; `merge` after the URL wakes only on merge or close.

A launchd job runs `claude-sessions --wake` every minute. When a snooze fires it sends a macOS notification (clicking it opens the session), marks the session due in the picker and status line, and reopens the session in tmux if it was closed. `claude-sessions --due` prints the list the banner shows; `--wake` runs the check by hand; the log is `~/.local/state/claude-sessions/wake.log`.

Two one-off steps on a new machine:

```sh
claude-sessions --install-wake                                   # launchd job, every minute
security add-generic-password -a "$USER" -s claude-sessions-gitlab -w "$GITLAB_NPM_TOKEN"   # token for MR polling, read from the login keychain
```

Then allow `terminal-notifier` under System Settings → Notifications the first time a reminder fires. `claude-sessions --uninstall-wake` removes the job.
