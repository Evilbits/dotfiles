---
name: ticket
description: >-
    Pin which Jira ticket the current Claude Code session is filed under in the picker, the menu bar
    and the status line, or say it has none. Use when the user types /ticket with a key such as
    PROD-1234 or with "none", or says this session is about a different ticket than shown, or that
    it has no ticket.
allowed-tools: Bash(cockpit *)
---

# /ticket — file this session under the right ticket

Run, in one Bash call, `cockpit --ticket current <key>` with the key the user gave, or `cockpit --ticket current none` when the session has no ticket. `current` resolves to this session through its tmux pane.

Reply with the command's one output line and nothing else.

The pin overrides what cockpit infers from the prompts, the title, Claude's replies and the branch, and it sticks for the life of the session, including across compaction. Without a pin cockpit goes back to inferring.
