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

Run, in one Bash call, `~/.claude/bin/claude-sessions --snooze current <duration> <reason>` with the duration and reason exactly as the user gave them. `current` resolves to this session through the tmux pane, so no id is needed. Durations: `30s`, `45m`, `2h`, `3d` (day-based lands at 09:00), `tomorrow`, a weekday such as `fri`, or a time such as `14:30`.

Reply with the command's one output line and nothing else. It states the ticket, the wake time and the remaining duration.

`/snooze off` or a request to unsnooze runs `~/.claude/bin/claude-sessions --unsnooze current` and replies "unsnoozed".

What the user gets: the session moves to the snoozed section at the bottom of the prefix-r picker with its remaining time and reason, the status line shows `⏾ <remaining> · <reason>`, and when the time is up a launchd job (every minute) sends a notification, marks the session due, and reopens it in tmux if it was closed. `claude-sessions --wake` runs that check immediately.
