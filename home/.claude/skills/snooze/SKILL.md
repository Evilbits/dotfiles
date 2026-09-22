---
name: snooze
description: >-
    Park the current Claude Code session until later, with a reason, so it drops
    to the snoozed section of the session picker and comes back with a reminder.
    Use when the user types /snooze with a duration such as 3d, 2h, tomorrow, fri
    or 14:30 and optionally a reason like "awaiting review on !17005", or says
    to snooze, park or shelve this session. "/snooze off" or "unsnooze" clears it.
---

# /snooze — park this session until it needs attention again

Run, in one Bash call, `~/.claude/bin/claude-sessions --snooze current <what the user gave>`, passing the duration, MR URL, mode word and reason exactly as written; the command sorts them out. `current` resolves to this session through the tmux pane, so no id is needed.

What can follow `--snooze current`, in any order: a duration (`30s`, `45m`, `2h`, `3d` lands at 09:00, `tomorrow`, a weekday such as `fri`, a time such as `14:30`); a GitLab MR URL, optionally followed by `merge` to wake only when it merges or closes; without it the watch wakes on a comment by someone else, an approval, a failed pipeline, a conflict, merge or close; and free text as the reason. A duration and an MR together wake on whichever comes first.

Reply with the command's one output line and nothing else.

`/snooze off` or a request to unsnooze runs `~/.claude/bin/claude-sessions --unsnooze current` and replies "unsnoozed".

What the user gets: the session moves to the snoozed section of the prefix-r picker showing the MR and remaining time, the status line shows `⏾ !612 · 2d 3h · <reason>`, and a launchd job (every minute) checks the clock and the MR. When it fires it sends a notification naming what happened (`!612: 2 new comments (dmytro.prykhodko)`, `approved by …`, `merged`), marks the session due, and reopens it in tmux if it was closed. `claude-sessions --wake` runs that check immediately.
