# cockpit

Work across many Claude Code sessions at once, without losing track of any of them.

## Why

Working on doxyme in Claude Code means several sessions open at the same time: one implementing a ticket, one reviewing a colleague's MR, two more finished and waiting, one on a review you asked for and one on an MR that has to merge before the next step can start. Claude names each session from its conversation, so the ticket you would search for is often not in the title. The built-in session list searches those titles and nothing else. And nothing tells you when a waiting session needs you again, so you check the MR by hand and keep the window open in case.

cockpit is the UI for that situation. It gives you three things:

- **A picker.** One list of every Claude session across your repositories, with the ticket, title and MRs each one is about. Enter jumps to a running session or resumes a closed one.
- **Snoozing.** Park a session until a time, or until its merge request gets review activity or merges. When that happens you get a notification that opens the session, and the session is reopened if you had closed it.
- **A status line.** At the bottom of every session: the ticket it is about, its name, whether it is snoozed and how many snoozed sessions are due.

It reads Claude's session files and never writes to them, so it cannot damage a session.

It works best with tmux, where the picker is one key away and Enter switches straight to a session running in another pane. If you use tabs in your terminal instead, it works there too: run `cockpit` in a tab to open the picker, resume closed sessions in place, and let a fired snooze open its session in a new window.

## Install

```
/plugin marketplace add git@gitlab.com:doxyme/cooks/claude-plugins.git
/plugin install cockpit@doxyme
/cockpit:setup
```

Setup asks which of the three parts you want and installs only those. It links the commands into `~/.local/bin`, installs the minute job that fires snoozes, and prints what is left for you to add: a tmux key binding for the picker, the `statusLine` setting for the status line, and a keychain command for a GitLab token if you want snoozes that watch MRs. It needs `fzf`, `jq` and `terminal-notifier` from Homebrew; Python comes with macOS.

Without tmux, setup skips the key binding and tells you to run `cockpit` in a tab; a session already running in another tab is reported rather than switched to, since a plain terminal offers no way to focus another tab.

## The picker

![picker](docs/picker.png)

`prefix r` in tmux opens it, or `cockpit` in any shell. Each row is one session: its state, age, repository, ticket, the skill it was started with, its title and the MRs it mentioned. Running sessions show `●` when busy and `○` when idle. The order is due, running, snoozed, then closed by age, and typing a ticket number filters without reordering.

The ticket is worked out from the session itself: the key you typed most in your prompts, then a key in the title, then one in Claude's replies, then the branch. A review session you opened by pasting an MR link still lists under the ticket that MR was about.

| Key | Action |
| --- | --- |
| `Enter` | Jump to a running session's tmux pane, or resume a closed one in a new window in that repository's tmux session. Clears its snooze. |
| `ctrl-s` | Snooze the highlighted session. |
| `ctrl-u` | Unsnooze it. |
| `ctrl-z` | Show only snoozed sessions; again to go back. |
| `ctrl-y` | Copy the session id. |
| `End`, `Home` | Bottom and top of the list. |

The preview on the right shows the title, whether the session is running and where, its snooze details, tickets, MRs, skills, branch, the first prompt and the latest prompts. A footer keeps every snoozed session in view.

## Snoozing

Inside a session, type `/snooze` followed by when to come back and why:

```
/snooze 3d awaiting review on !17005
/snooze https://gitlab.com/doxyme/code/doxyme-core/-/merge_requests/17005 awaiting review
/snooze https://gitlab.com/doxyme/code/doxyme-core/-/merge_requests/17005 merge next step
/snooze fri https://gitlab.com/doxyme/code/doxyme-core/-/merge_requests/17005 whichever comes first
/snooze off
```

A duration is `30s`, `45m`, `2h`, `3d`, `tomorrow`, a weekday such as `fri`, or a time such as `14:30`; anything in days lands at 09:00. An MR URL on its own wakes the session when someone else comments, approves, the pipeline fails, the MR conflicts, merges or closes; comments from bots are ignored. `merge` after the URL wakes only when it merges or closes, which is the one for a session waiting to start the next step. A duration and an MR together wake on whichever comes first.

While snoozed, the session sits in the snoozed section of the picker showing the remaining time or the MR it waits on, and the status line shows the same. Every minute a background job checks the clock and the watched MRs. When a snooze fires you get a macOS notification naming what happened, `!17005: 2 new comments (jane.doe)` for instance, and clicking it opens the session. The session moves to the top of the picker marked `⏰`, every status line shows a due count, and if you had closed the session it is reopened in tmux. Opening it clears the snooze.

From a shell the same commands are `cockpit --snooze current …` and `cockpit --unsnooze current`, where `current` is the session in this tmux pane; `cockpit --due` lists snoozes and `cockpit --wake` runs the check by hand. At the start of every session a banner lists what is snoozed.

## The status line

![status line](docs/statusline.png)

`model · effort | repo | ticket · session name | snooze | ⏰ N due | branch [primary|worktree]`. The ticket is the same one the picker shows, so it is there even when Claude's title leaves it out. A snoozed session shows its remaining time or the MR it waits on, dimmed; when any snooze is due a yellow count appears in every session. Setup prints the setting to add:

```json
"statusLine": { "type": "command", "command": "~/.local/bin/cockpit-statusline" }
```

## Configuration

`~/.config/cockpit/config.json`, all keys optional:

| Key | Default | Meaning |
| --- | --- | --- |
| `ticket_pattern` | `\b[A-Z][A-Z0-9]{1,9}-\d{1,6}\b` | Which keys count as tickets. |
| `ticket_deny` | `[]` | Keys never counted, such as examples in instruction files. |
| `skill_prefix` | `""` | Slash commands shown in the skill column, with the prefix removed; empty shows any. |
| `bot_pattern` | `bot` | Comment authors ignored by MR watches. |
| `gitlab_host` | `gitlab.com` | Host for the user lookup. |
| `token_env` | `["GITLAB_TOKEN", "GITLAB_NPM_TOKEN"]` | Environment variables tried before the keychain. |
| `reopen_on_wake` | `true` | Reopen a closed session in tmux when its snooze fires. |
| `colour_accent`, `colour_branch` | `183`, `116` | 256-colour indexes for the status line. |

MR watches need a GitLab token with `read_api`. The background job has no shell environment, so store the token in the login keychain: `security add-generic-password -a "$USER" -s cockpit-gitlab -w "<token>"`.

## How it is built

`bin/cockpit` and `bin/cockpit-statusline` are the entry points; Claude adds `bin/` to its Bash PATH while the plugin is enabled, which is how `/snooze` runs. `lib/cockpit/` is one module per concern: `config`, `index` (session files to sessions, cached and incremental), `registry` (running sessions), `snooze`, `gitlab` (the MR watch), `wake` (the minute job, notifications, launchd), `tmux` (jump and resume), `ui` (rows, preview, fzf) and `cli`. `hooks/hooks.json` is the session-start banner; `skills/` holds `setup` and `snooze`. State lives in `~/.cache/cockpit` and `~/.local/state/cockpit`; `cockpit --uninstall` removes the job and the links.
