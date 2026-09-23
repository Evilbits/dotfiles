---
name: snooze
description: >-
    Park the current Claude Code session until later so it drops to the snoozed section of the
    session picker and comes back with a reminder. Use when the user types /snooze with a duration
    such as 3d, 2h, tomorrow, fri or 14:30, a GitLab merge request URL, or both, optionally followed
    by a reason, or says to snooze, park or shelve this session. "/snooze off" or "unsnooze" clears it.
allowed-tools: Bash(cockpit *)
---

# /snooze — park this session until it needs attention again

Run, in one Bash call, `cockpit --snooze current <the user's words>`, passing the duration, MR URL, the word `merge` and the reason exactly as given; the command sorts them out. `current` resolves to this session through its tmux pane.

What may follow, in any order: a duration (`30s`, `45m`, `2h`, `3d` lands at 09:00, `tomorrow`, a weekday such as `fri`, a time such as `14:30`); a GitLab MR URL, which wakes on a comment by someone else, an approval, a failed pipeline, a conflict, merge or close, or followed by `merge` to wake only on merge or close; and free text as the reason. A duration and an MR together wake on whichever comes first.

Reply with the command's one output line and nothing else.

`/snooze off`, or any request to unsnooze, runs `cockpit --unsnooze current`.

What happens next: the session moves to the snoozed section of the picker showing the MR and remaining time, the status line shows the same, and a launchd job checks every minute. When the snooze fires it sends a notification that opens the session when clicked, marks the session due in the picker and status line, and reopens it in tmux if it was closed. Opening the session does not clear the snooze; the first prompt typed into it does (`/exit`, `/clear` and another `/snooze` do not count), and a system message in the chat then says what fired or that nothing has happened yet.
