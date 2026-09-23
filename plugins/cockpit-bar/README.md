# cockpit-bar

A macOS menu bar app over [cockpit](../cockpit): the spinning splat and what each Claude Code session is doing right now, plus cockpit's view of your sessions in the dropdown. A fork of [claude-status-bar](https://github.com/m1ckc3s/claude-status-bar) (MIT) that keeps its menu bar side and replaces the session list.

## What it shows

**In the menu bar.** The splat spins while any session works, with the activity text of the lead session ("Running command", "Editing", "Reading", or one of Claude's thinking words) and an optional elapsed clock. An amber dot means a session waits for a permission answer. A `⏰ N` follows when snoozes have fired.

**In the dropdown.** Four sections: **Due** (snoozes that fired), **Running** (open sessions, the ones working first, each with its activity and timer on the right), **Snoozed** (what they wait for on the right) and **Recent** (the last eight closed sessions). Every row reads `ticket · title`, the same ticket and title cockpit's picker shows. Clicking a row runs cockpit's open: it jumps to the session's tmux pane, or resumes a closed one in a new tmux window, and brings the terminal to the front.

**The flyout** on each row: where the session runs, repository and branch, when it started and when it was last prompted, its snooze and what wakes it, its merge requests grouped by repository with title and state (click opens the MR), then Open and the snooze actions (2h, tomorrow, until its MR moves, until its MR merges, or Unsnooze).

## Install

Needs the cockpit plugin, Node, and the Xcode Command Line Tools for the Swift compiler (`xcode-select --install`).

```
/plugin marketplace add https://github.com/Evilbits/dotfiles
/plugin install cockpit-bar@rasmus
/cockpit-bar:setup
```

Setup runs `build.sh`, which compiles the app into `~/Applications/Cockpit Bar.app`, adds a LaunchAgent so it starts at login, and launches it. The plugin's hooks also relaunch it whenever a session is active, unless it was quit from its menu. Run `/cockpit-bar:setup` again after a plugin update.

## How it works

`hooks/` are the upstream hook scripts, writing one file per session to `~/.local/state/cockpit/bar/state.d/` on every prompt, tool call, permission prompt and stop. The app (`Sources/`) watches that folder at 2.5 Hz for the menu bar icon and the row spinners, which is why it reacts within a tool call. `bin/cockpit-bar --json` is the rest of the data: it reads through cockpit's library and lists due, running, snoozed and recent sessions with their tickets, titles, MRs and snoozes, and says which hook files belong to which row. The app runs it every five seconds, on menu open, and after any hook file changes. `bin/cockpit-bar --open|--snooze|--unsnooze|--picker` are the actions, all delegated to `cockpit`.

Options in the menu: Show timer, Show text, four animation styles, orange or system colour, and a completion chime for turns longer than a chosen length. `~/.local/state/cockpit/bar/uiconfig.json` takes `boxWidth` for the dropdown width.
