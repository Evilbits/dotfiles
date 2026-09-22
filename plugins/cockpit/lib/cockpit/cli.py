"""Command dispatch. The entry script passes its own absolute path so hooks, launchd and
notifications can call back into the same install."""
import json
import os
import shutil
import sys
import time

from . import gitlab, snooze, ui, wake
from .config import CLAUDE_BIN, HOME, KEYCHAIN_SERVICE, cfg
from .index import find, index_sessions, one_session, primary_ticket, title_of
from .registry import current_session_id, live_sessions
from .tmux import open_session

USAGE = """cockpit: a picker, snoozer and status line for Claude Code sessions.

  cockpit                      fzf picker (prefix-r in tmux once bound)
  cockpit --snooze ID [DURATION] [MR-URL [merge]] [REASON]
                                       park a session until a time, until something happens on a
                                       GitLab MR, or whichever comes first. ID may be "current".
  cockpit --unsnooze ID
  cockpit --due                snoozed sessions, due first
  cockpit --wake               run the minute check now
  cockpit --install [picker] [snooze] [statusline]
                                       install some or all parts; asks when none is given
  cockpit --uninstall
  cockpit --list [--snoozed] | --preview ID | --open ID | --statusline ID | --banner | --reindex

Durations: 30s, 45m, 2h, 3d (09:00), tomorrow, fri, 14:30. An MR URL wakes on a comment by
someone else, an approval, a failed pipeline, a conflict, merge or close; add "merge" after the
URL to wake only on merge or close. Config: ~/.config/cockpit/config.json.
"""

def _resolve(session_id, states):
    if session_id == "current":
        sid = current_session_id()
        return find(states, sid) if sid else None
    return find(states, session_id)

def do_snooze(session_id, words):
    states, _ = index_sessions()
    st = _resolve(session_id, states)
    if not st:
        sys.exit("unknown session %s (from a Claude session, 'current' needs tmux)" % session_id)
    until, ref, mode, reason = snooze.parse_request(words)
    if until is None and ref is None:
        sys.exit("need a duration (2h, 3d, tomorrow, fri, 14:30) or an MR URL")
    entry = {"until": until, "reason": reason, "due": False}
    if ref:
        try:
            snap = gitlab.snapshot(ref, gitlab.me())
        except Exception as e:
            sys.exit("cannot read %s: %s" % (ref["url"], e))
        entry.update(mr=ref, mr_mode=mode, mr_title=snap["title"],
                     mr_base={k: snap[k] for k in ("state", "conflicts", "pipeline", "approvers", "max_note")})
    snooze.put(st["id"], entry)
    parts = []
    if ref:
        parts.append(("until !%d merges" if mode == "merge" else "until review activity on !%d") % ref["iid"])
    if until:
        parts.append("until %s (in %s)" % (snooze.fmt_until(until), snooze.remaining(until)))
    print("snoozed %s %s%s" % (primary_ticket(st) or st["id"][:8], " or ".join(parts), (" · " + reason) if reason else ""))

def do_unsnooze(session_id):
    if session_id == "current":
        session_id = current_session_id() or sys.exit("no Claude session in this tmux pane")
    snooze.remove(session_id)
    print("unsnoozed")

def do_snooze_prompt(session_id):
    states, _ = index_sessions()
    st = find(states, session_id)
    if not st:
        return
    print("snooze  %s  %s" % (primary_ticket(st), title_of(st)))
    try:
        spec = input("until (30s, 2h, 3d, tomorrow, fri, 14:30) and/or an MR URL [1d]: ").strip() or "1d"
        reason = input("reason: ").strip()
        do_snooze(st["id"], (spec + " " + reason).split())
    except (EOFError, KeyboardInterrupt, SystemExit) as e:
        print(e)
        time.sleep(1)

def do_open(session_id):
    states, _ = index_sessions()
    st = _resolve(session_id, states)
    if not st:
        sys.exit("unknown session " + session_id)
    result = open_session(st)
    snooze.remove(st["id"])
    return result

def do_banner():
    """SessionStart hook output: the snoozed sessions, due first, as a system message."""
    states, _ = index_sessions()
    lines = ui.snoozed_lines(states, banner=True)
    if not lines:
        return
    msg = "Snoozed sessions (prefix-r to open):\n" + "\n".join("  " + l for l in lines)
    print(json.dumps({"systemMessage": msg}))

PARTS = ("picker", "snooze", "statusline")

def _link(me, name):
    bindir = os.path.join(HOME, ".local", "bin")
    os.makedirs(bindir, exist_ok=True)
    link = os.path.join(bindir, name)
    if os.path.islink(link) or os.path.exists(link):
        os.remove(link)
    os.symlink(os.path.join(os.path.dirname(me), name), link)
    return link

def do_install(me, parts):
    """Install any subset of picker, snooze and statusline; with no parts given, ask."""
    if not parts:
        print("Which parts? (space-separated, or Enter for all)")
        print("  picker      prefix-r fzf list of every session, jump or resume")
        print("  snooze      /snooze, the minute wake job, notifications, MR watches")
        print("  statusline  ticket, session name and snooze state in Claude's status line")
        try:
            parts = input("> ").split() or list(PARTS)
        except EOFError:
            parts = list(PARTS)
    from .config import migrate_from_old_name
    for path in migrate_from_old_name():
        print("moved state from the pre-plugin tool to " + path)
    bad = [p for p in parts if p not in PARTS]
    if bad:
        sys.exit("unknown part(s): %s; choose from %s" % (", ".join(bad), ", ".join(PARTS)))
    todo = []
    if "picker" in parts or "snooze" in parts:
        _link(me, "cockpit")
        print("linked ~/.local/bin/cockpit")
    if "picker" in parts:
        if shutil.which("tmux"):
            todo.append(("Add to ~/.tmux.conf, then run `tmux source-file ~/.tmux.conf`:",
                         '  bind r split-window -v "~/.local/bin/cockpit"'))
        else:
            todo.append(("No tmux: run `cockpit` in any terminal tab to open the picker. Without tmux it can resume closed sessions but cannot switch to a session running in another tab.", ""))
    if "snooze" in parts:
        print(wake.install(os.path.join(HOME, ".local", "bin", "cockpit")))
        todo.append(("For MR watches, store a GitLab token with read_api scope in the login keychain (the job has no shell environment):",
                     '  security add-generic-password -a "$USER" -s %s -w "<token>"' % KEYCHAIN_SERVICE))
        todo.append(("Allow terminal-notifier under System Settings → Notifications when the first reminder fires.", ""))
    if "statusline" in parts:
        _link(me, "cockpit-statusline")
        print("linked ~/.local/bin/cockpit-statusline")
        todo.append(("Add to ~/.claude/settings.json:",
                     '  "statusLine": { "type": "command", "command": "~/.local/bin/cockpit-statusline" }'))
    for head, line in todo:
        print()
        print(head)
        if line:
            print(line)

def do_uninstall():
    print(wake.uninstall())
    for name in ("cockpit", "cockpit-statusline"):
        link = os.path.join(HOME, ".local", "bin", name)
        if os.path.islink(link):
            os.remove(link)
    print("removed the ~/.local/bin links; the tmux bind and statusLine setting are yours to delete")

def main(argv, me):
    os.environ["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + os.environ.get("PATH", "")
    if "--reindex" in argv:
        index_sessions(force=True)
        argv = [a for a in argv if a != "--reindex"]
    if not argv:
        states, mtimes = index_sessions()
        lines = ui.rows(states, mtimes, live_sessions())
        if not lines:
            sys.exit("no sessions found")
        choice = ui.pick(lines, "\n".join(ui.snoozed_lines(states)), me)
        if choice:
            do_open(choice)
        return
    cmd, rest = argv[0], argv[1:]
    if cmd == "--list":
        states, mtimes = index_sessions()
        print("\n".join(ui.rows(states, mtimes, live_sessions(), only_snoozed="--snoozed" in rest)))
    elif cmd == "--preview" and rest:
        states, _ = index_sessions()
        st = find(states, rest[0])
        if st:
            ui.preview(st, live_sessions().get(st["id"]))
        else:
            print("unknown session", rest[0])
    elif cmd == "--open" and rest:
        do_open(rest[0])
    elif cmd == "--statusline" and rest:
        print(ui.statusline_fields(one_session(rest[0]), rest[0]))
    elif cmd == "--snooze" and len(rest) >= 2:
        do_snooze(rest[0], rest[1:])
    elif cmd == "--snooze-prompt" and rest:
        do_snooze_prompt(rest[0])
    elif cmd == "--unsnooze" and rest:
        do_unsnooze(rest[0])
    elif cmd == "--due":
        states, _ = index_sessions()
        print("\n".join(ui.snoozed_lines(states, banner=True)))
    elif cmd == "--banner":
        do_banner()
    elif cmd == "--wake":
        wake.wake(me)
    elif cmd == "--install":
        do_install(me, rest)
    elif cmd == "--uninstall":
        do_uninstall()
    else:
        print(USAGE)
