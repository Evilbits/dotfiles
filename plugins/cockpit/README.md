# cockpit

Work across many Claude Code sessions at once, without losing track of any of them.

[Loom: installing cockpit and what it gives you](https://www.loom.com/share/ac57ddf4d91244cdb14cfab00d798734)

## Why

Working on doxyme in Claude Code means several sessions open at the same time: one implementing a ticket, one reviewing a colleague's MR, two more finished and waiting, one on a review you asked for and one on an MR that has to merge before the next step can start. Claude names each session from its conversation, so the ticket you would search for is often not in the title. The built-in session list searches those titles and nothing else. And nothing tells you when a waiting session needs you again, so you check the MR by hand and keep the window open in case.

cockpit is the UI for that situation. It gives you three things:

- **A picker.** One list of every Claude session across your repositories, each named by the kind of work and what it is about, with its MRs. Enter jumps to a running session or resumes a closed one.
- **Snoozing.** Park a session until a time, or until its merge request gets review activity or merges. When that happens you get a notification that opens the session, and the session is reopened if you had closed it.
- **A status line.** At the bottom of every session: the ticket it is about as a link, what it is about, whether it is snoozed and how many snoozed sessions are due.

It reads Claude's session files and never writes to them, so it cannot damage a session.

It works best with tmux, where the picker is one key away and Enter switches straight to a session running in another pane. If you use tabs in your terminal instead, it works there too: run `cockpit` in a tab to open the picker, resume closed sessions in place, and let a fired snooze open its session in a new window.

## Install

```
/plugin marketplace add https://github.com/Evilbits/dotfiles
/plugin install cockpit@rasmus
/cockpit:setup
```

Setup asks which of the three parts you want and installs only those. It links the commands into `~/.local/bin`, adds the `prefix r` binding to `~/.tmux.conf`, adds the `statusLine` entry to `~/.claude/settings.json`, installs the minute job that fires snoozes, and stores your GitLab token for MR watches. It never overwrites a binding or a status line you already have; then it prints the line for you to place. It needs `fzf`, `jq` and `terminal-notifier` from Homebrew; Python comes with macOS.

Without tmux, setup skips the key binding and tells you to run `cockpit` in a tab; a session already running in another tab is reported rather than switched to, since a plain terminal offers no way to focus another tab. `cockpit --uninstall` takes everything out again.

## The picker

![picker](docs/picker.png)

`prefix r` in tmux opens it, or `cockpit` in any shell. Each row is one session: its state, age, repository, the kind of work, what it is about and the MRs it mentioned; a `z` marks a snoozed one, and the footer lists every snooze with its remaining time and reason. Running sessions show `●` when busy and `○` when idle. The order is due, running, snoozed, then closed by age, and typing a ticket number filters without reordering, since the ticket is a hidden column of every row.

The kind of work is the skill the session started with, `Review`, `Implement`, `Design`, `Ticket` or `Epic` by default (`skill_verbs` in the config). The subject is what the session is about without identifiers: a name you gave it with `/rename`, else for a review the title of the MR it was given, else Claude's title, with a leading ticket key or commit type removed. A session started without a skill shows its title as before.

The ticket is worked out from the session itself: the key you typed most in your prompts, then a key in the title, then one in Claude's replies, then the branch. A review session you opened by pasting an MR link still lists under the ticket that MR was about.

| Key | Action |
| --- | --- |
| `Enter` | Jump to a running session's tmux pane, attach to one running in the background (`claude --bg`), or resume a closed one, in the pane you pressed `prefix r` in, replacing whatever ran there. If claude exits with an error the pane stays until you press Enter. A snooze that fires reopens its session in a new window instead. The session's snooze stays until you type into it. |
| `ctrl-s` | Snooze the highlighted session. |
| `ctrl-u` | Unsnooze it. |
| `ctrl-z` | Show only snoozed sessions; again to go back. |
| `ctrl-y` | Copy the session id. |
| `End`, `Home` | Bottom and top of the list. |

The preview on the right shows the title, whether the session is running and where, when it started and when you last prompted it, its snooze details, tickets, MRs, skills, branch, the first prompt and the latest prompts. A footer keeps every snoozed session in view.

## Snoozing

Inside a session, type `/snooze` followed by when to come back and why:

```
/snooze 3d awaiting review on !17005
/snooze https://gitlab.com/acme/app/-/merge_requests/17005 awaiting review
/snooze https://gitlab.com/acme/app/-/merge_requests/17005 merge next step
/snooze fri https://gitlab.com/acme/app/-/merge_requests/17005 whichever comes first
/snooze off
```

A duration is `30s`, `45m`, `2h`, `3d`, `tomorrow`, a weekday such as `fri`, or a time such as `14:30`; anything in days lands at 09:00. An MR URL on its own wakes the session when someone else comments, approves, the pipeline fails, the MR conflicts, merges or closes; comments from bots are ignored. `merge` after the URL wakes only when it merges or closes, which is the one for a session waiting to start the next step. A duration and an MR together wake on whichever comes first.

While snoozed, the session sits in the snoozed section of the picker showing the remaining time or the MR it waits on, the status line shows the same, and in tmux the session's window is renamed `⏾ PROD-11125` (`⏰` once due) until the snooze clears, when its own name comes back. Every minute a background job checks the clock and the watched MRs. When a snooze fires you get a macOS notification naming what happened, `!17005: 2 new comments (jane.doe)` for instance, and clicking it opens the session. The session moves to the top of the picker marked `⏰`, every status line shows a due count, and if you had closed the session it is reopened in tmux. Opening it, from the picker or the notification, leaves the snooze in place, so you can look at a parked session without losing its watch. Typing into the session clears it (housekeeping commands such as `/exit`, `/clear` or a new `/snooze` do not count; the list is `snooze_keep_commands` in the config): a prompt hook removes the snooze and puts a line in the chat saying what fired, `unsnoozed, it fired: !17005 2 new comments (jane.doe) · waiting for review`, or that nothing has happened yet.

From a shell the same commands are `cockpit --snooze current …` and `cockpit --unsnooze current`, where `current` is the session in this tmux pane; `cockpit --due` lists snoozes and `cockpit --wake` runs the check by hand. At the start of every session a banner lists what is snoozed.

## The status line

![status line](docs/statusline.png)

`model · effort | repo | ticket · subject | snooze | ⏰ N due | branch [primary|worktree] | !MR title`. The ticket is the one the picker filters on, so it is there even when the name leaves it out, and it is a link to the ticket in Jira in terminals that support hyperlinks; the host is `jira_host` in the config, or the host of the first Jira link the session was given. The subject is the picker's, so a `/rename` shows up here too. A snoozed session shows its wake time or the MR it waits on, dimmed; when any snooze is due a yellow count appears in every session. The merge request the session is working on, the latest one it dealt with that you authored, or failing that the one for the current branch, appears as its number and title, a link you can click in terminals that support hyperlinks, with `· merged` or `· closed` after it once it is no longer open; the lookup is served from a cache the minute job refreshes, so the status line never waits on GitLab. Setup adds the setting to `~/.claude/settings.json`:

```json
"statusLine": { "type": "command", "command": "~/.local/bin/cockpit-statusline", "refreshInterval": 60 }
```

Claude redraws a session's status line when that session does something; the refresh interval also redraws it once a minute while it sits idle, so a snooze that fires or an MR that appears reaches every session's bar within a minute.

## Configuration

`~/.config/cockpit/config.json`, all keys optional:

| Key | Default | Meaning |
| --- | --- | --- |
| `ticket_pattern` | `\b[A-Z][A-Z0-9]{1,9}-\d{1,6}\b` | Which keys count as tickets. |
| `ticket_deny` | `[]` | Keys never counted, such as examples in instruction files. |
| `skill_prefix` | `""` | Prefix stripped from a skill name when it stands in as the title of an untitled session. |
| `bot_pattern` | `bot` | Comment authors ignored by MR watches. |
| `gitlab_host` | `gitlab.com` | Host for the user lookup. |
| `token_env` | `["GITLAB_TOKEN", "GITLAB_NPM_TOKEN"]` | Environment variables tried before the keychain. |
| `reopen_on_wake` | `true` | Reopen a closed session in tmux when its snooze fires. |
| `tmux_window_marks` | `true` | Prefix a snoozed session's tmux window name with ⏾, a due one with ⏰. |
| `skill_verbs` | `{"doxy-review": "Review", …}` | The kind of work a session is, from the skill it started with. |
| `jira_host` | `""` | Host for ticket links in the status line; empty uses the host of the first Jira link a session was given. |
| `colour_accent`, `colour_branch` | `183`, `116` | 256-colour indexes for the status line. |

MR watches need a GitLab token with `read_api`. The background job has no shell environment, so the token lives in the login keychain as `cockpit-gitlab`. Setup fills it from `GITLAB_NPM_TOKEN` or `GITLAB_TOKEN` when one of them is set in your shell, which is the case on a doxyme machine with npm access to GitLab; otherwise it prints the `security add-generic-password` line to run with a token of your own.

## How it is built

`bin/cockpit` and `bin/cockpit-statusline` are the entry points; Claude adds `bin/` to its Bash PATH while the plugin is enabled, which is how `/snooze` runs. `lib/cockpit/` is one module per concern: `config`, `index` (session files to sessions, cached and incremental), `registry` (running sessions), `snooze`, `gitlab` (the MR watch), `wake` (the minute job, notifications, launchd), `tmux` (jump and resume), `ui` (rows, preview, fzf) and `cli` (command dispatch, and the install that writes the tmux binding and the `statusLine` setting). `hooks/hooks.json` is the session-start banner; `skills/` holds `setup` and `snooze`. State lives in `~/.cache/cockpit` and `~/.local/state/cockpit`; `cockpit --uninstall` removes the job and the links.
