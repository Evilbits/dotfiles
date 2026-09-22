---
name: setup
description: >-
    Set up cockpit on this machine: the tmux picker binding, the status line, the minute
    wake job, and the GitLab token for MR watches. Use when the user runs /cockpit:setup,
    asks to install or configure the session picker, snoozing or the status line, or when
    `cockpit --install` has not been run yet.
allowed-tools: Bash(cockpit *), Bash(brew *), Bash(tmux *), Read, Edit
---

# /cockpit:setup

1. Ask one question with lettered options, multiple allowed: which parts to install. **A** picker: `prefix r` in tmux lists every Claude session, Enter jumps to or resumes it. **B** snooze: `/snooze` parks a session until a time or MR activity, a minute job wakes it with a notification. **C** status line: ticket, session name and snooze state at the bottom of Claude Code. Default is all three.
2. Check the tools the chosen parts need: `fzf` for the picker, `terminal-notifier` for snooze, `jq` for the status line (`brew install fzf jq terminal-notifier`). Python 3.9 from macOS is enough. tmux is optional: with it the picker gets a key binding and can switch to running sessions; without it the picker runs as `cockpit` in a tab and the install output says so.
3. Run `cockpit --install <parts>` with the chosen words, for example `cockpit --install picker statusline`. It links the commands into `~/.local/bin`, installs the launchd job when snooze is chosen, and prints what remains to add.
4. Offer to add each printed line for the user, showing the change first: the `bind r` line in `~/.tmux.conf` followed by `tmux source-file ~/.tmux.conf`; the `statusLine` entry in `~/.claude/settings.json`; the keychain command for a GitLab token with `read_api` scope, which the user runs themselves since it contains the token.
5. Say that the first reminder asks macOS to allow notifications from `terminal-notifier`.

Configuration lives in `~/.config/cockpit/config.json`; the keys are in the plugin README. The two most teams set are `ticket_pattern` (which Jira keys to recognise) and `skill_prefix` (which slash commands fill the skill column). `cockpit --uninstall` removes the job and the links.
