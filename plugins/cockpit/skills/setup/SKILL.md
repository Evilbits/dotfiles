---
name: setup
description: >-
    Set up cockpit on this machine: the tmux picker binding, the status line, the minute
    wake job, and the GitLab token for MR watches. Use when the user runs /cockpit:setup,
    asks to install or configure the session picker, snoozing or the status line, or when
    `cockpit --install` has not been run yet.
allowed-tools: AskUserQuestion, Bash(cockpit *), Bash(brew *), Bash(tmux *)
---

# /cockpit:setup

1. Ask which parts to install with the **AskUserQuestion tool**, `multiSelect: true`, one question, three options, so the user ticks boxes instead of typing letters. Header `Parts`, question "Which parts of cockpit do you want?", options: **picker** ("`prefix r` in tmux lists every Claude session; Enter jumps to or resumes it"), **snooze** ("`/snooze` parks a session until a time or MR activity; a minute job wakes it with a notification"), **status line** ("ticket, session name and snooze state at the bottom of Claude Code"). Treat no selection as all three. Never present the choice as prose.
2. Check the tools the chosen parts need: `fzf` for the picker, `terminal-notifier` for snooze, `jq` for the status line (`brew install fzf jq terminal-notifier`). Python 3.9 from macOS is enough. tmux is optional; without it the picker runs as `cockpit` in a tab.
3. Run `cockpit --install <parts>` with the chosen words, for example `cockpit --install picker statusline`. It does everything itself: links the commands into `~/.local/bin`, adds the `prefix r` binding to `~/.tmux.conf` and reloads tmux, adds the `statusLine` entry to `~/.claude/settings.json`, installs the launchd job, and stores the GitLab token from the shell in the keychain. It never overwrites a binding or a statusLine that already points elsewhere; in that case it prints the line for the user to place.
4. Relay the command's output as it is. It is the whole report. The only follow-up is when it printed a `security add-generic-password` line, meaning no GitLab token was found; then the user creates a personal access token with `read_api` scope and runs that line themselves.

Configuration lives in `~/.config/cockpit/config.json`; the keys are in the plugin README. The two most teams set are `ticket_pattern` (which Jira keys to recognise) and `skill_prefix` (a prefix stripped from skill names used as fallback titles). `cockpit --uninstall` removes the job, the links, the binding and the setting.
