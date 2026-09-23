"""Getting the user to a session: a jump to a running tmux pane, a resume in a new tmux window, or,
without tmux, a resume in this terminal or in a new Terminal/iTerm window."""
import os
import shlex
import subprocess
import time

from .config import CLAUDE_BIN, HOME, OPENED, STATE_DIR, cfg, load_json, save_json
import sys
from .index import primary_ticket
from .registry import live_sessions

def tmux(*args):
    """Run a tmux command; on a machine without tmux behave like a failed command."""
    try:
        return subprocess.run(["tmux", *args], capture_output=True, text=True)
    except FileNotFoundError:
        return subprocess.CompletedProcess(["tmux", *args], 1, "", "tmux not installed")

def available():
    return tmux("list-sessions").returncode == 0

def session_for(cwd):
    """The tmux session named after a folder in the path, else the current one, else the first."""
    names = [n for n in tmux("list-sessions", "-F", "#S").stdout.split("\n") if n]
    for part in reversed([p for p in (cwd or "").split("/") if p]):
        if part in names:
            return part
    if os.environ.get("TMUX_PANE"):
        return tmux("display-message", "-p", "#S").stdout.strip()
    return names[0] if names else None

def jump(target):
    """target is tmux's session:@window.%pane form, as the registry records it. The client is
    named explicitly: from a notification click there is no current client, and tmux would
    otherwise change the session's window without any attached terminal following it."""
    sess = target.split(":")[0]
    clients = sorted(l.split(" ", 1) for l in tmux("list-clients", "-F", "#{client_activity} #{client_tty}").stdout.split("\n") if l)
    for _, tty in clients:
        tmux("switch-client", "-c", tty, "-t", sess)
    tmux("select-window", "-t", target.split(".")[0])
    tmux("select-pane", "-t", target.split(".")[-1])
    for _, tty in clients:
        tmux("refresh-client", "-t", tty)

def open_in_terminal_app(cmd, cwd):
    """Without tmux and without a terminal of our own (a notification click), open a new window in
    the user's terminal app. iTerm2 when it is running, else Terminal."""
    script = "cd %s && %s" % (shlex.quote(cwd), cmd)
    running = subprocess.run(["osascript", "-e", 'tell application "System Events" to (name of processes) contains "iTerm2"'], capture_output=True, text=True).stdout.strip()
    if running == "true":
        osa = 'tell application "iTerm" to create window with default profile command "/bin/zsh -lc \\"%s\\""' % script.replace('"', '\\"')
    else:
        osa = 'tell application "Terminal" to do script "%s"' % script.replace('"', '\\"')
    subprocess.run(["osascript", "-e", osa], capture_output=True)

def pane_exists(target):
    """target ends in a %pane id. tmux answers display-message for a dead target with the current
    pane and exit code 0, so existence is checked against the full pane list instead."""
    pane = target.split(".")[-1]
    return pane in tmux("list-panes", "-a", "-F", "#{pane_id}").stdout.split()

def origin_pane():
    """The pane prefix r was pressed in. The picker runs in a split, so that is the window's previously
    active pane; run from a plain shell there is none and the picker's own pane is the origin."""
    own = os.environ.get("TMUX_PANE")
    if not own:
        return None
    for line in tmux("list-panes", "-t", own, "-F", "#{pane_id} #{pane_last}").stdout.split("\n"):
        pane, last = (line.split(" ") + [""])[:2]
        if last == "1" and pane != own:
            return pane
    return own

def launch_argv(st, live):
    """The claude command that opens the session in a terminal: `attach <jobId>` for a session
    running in the background, `--resume <id>` for a closed one. None when the session already has an
    interactive process somewhere (resuming it would start a copy)."""
    if live and live.get("kind") == "bg" and live.get("jobId"):
        return [CLAUDE_BIN, "attach", live["jobId"]]
    if live:
        return None
    return [CLAUDE_BIN, "--resume", st["id"]]

HOLD = ' || { echo; echo "press Enter to close"; read -r _; }'

def shell_command(argv):
    """argv as one shell command that keeps the pane when claude exits non-zero, so the error stays
    readable instead of the pane closing with it."""
    return "sh -c %s" % shlex.quote(" ".join(shlex.quote(a) for a in argv) + HOLD)

def remembered_target(sid, prev, live, exists=None):
    """The pane opened.json remembers for a session, if it can still be trusted: the pane must exist
    and no other session may be registered in it. A pane is reused when another session is resumed
    in place there, and jumping to it would land on that session instead."""
    if not prev:
        return None
    target = prev["target"]
    if not (exists or pane_exists)(target):
        return None
    pane = target.split(".")[-1]
    for other, entry in live.items():
        if other != sid and (entry.get("tmux") or "").endswith("." + pane):
            return None
    return target

def remember(opened, sid, target):
    """Record where a session was launched, forgetting any other session remembered in that pane."""
    for other in [k for k, v in opened.items() if k != sid and v.get("target") == target]:
        del opened[other]
    opened[sid] = {"target": target, "at": time.time()}

def open_session(st, origin=None):
    """Jump to the session if it runs in a tmux pane, otherwise open it (attach to a background
    session, resume a closed one): in `origin` (a tmux pane, whatever it runs is replaced) when given,
    else in a new window. Returns a phrase for the log."""
    all_live = live_sessions()
    live = all_live.get(st["id"])
    in_tmux = available()
    if live and in_tmux and live.get("tmux"):
        jump(live["tmux"])
        return "jumped to " + live["tmux"]
    argv = launch_argv(st, live)
    if argv is None:
        msg = "already running in another terminal window; switch to it there"
        print(msg, file=sys.stderr)
        return msg
    verb = "attached" if argv[1] == "attach" else "resumed"
    cwd = st["cwd"] if os.path.isdir(st["cwd"]) else HOME
    cmd = shell_command(argv)
    if not in_tmux:
        if sys.stdin.isatty():
            os.chdir(cwd)
            os.execvp("sh", ["sh", "-c", " ".join(shlex.quote(a) for a in argv) + HOLD])
        open_in_terminal_app(" ".join(shlex.quote(a) for a in argv), cwd)
        return verb + " in a new terminal window"
    # A window this tool opened may still be starting and not yet registered; a second
    # resume or attach there would start a copy or a second view, so jump to that window.
    opened = load_json(OPENED)
    prev = remembered_target(st["id"], opened.get(st["id"]), all_live)
    if prev:
        jump(prev)
        return "jumped to " + prev
    if origin:
        tmux("rename-window", "-t", origin, primary_ticket(st) or st["id"][:8])
        if origin == os.environ.get("TMUX_PANE"):
            os.chdir(cwd)
            os.execvp("sh", ["sh", "-c", " ".join(shlex.quote(a) for a in argv) + HOLD])
        if tmux("respawn-pane", "-k", "-t", origin, "-c", cwd, cmd).returncode == 0:
            target = tmux("display-message", "-p", "-t", origin, "#{session_name}:#{window_id}.#{pane_id}").stdout.strip()
            remember(opened, st["id"], target)
            save_json(OPENED, opened)
            return verb + " in place at " + target
    sess = session_for(cwd)
    r = tmux("new-window", "-t", sess + ":", "-n", primary_ticket(st) or st["id"][:8], "-c", cwd, "-P", "-F", "#{session_name}:#{window_id}.#{pane_id}", cmd)
    target = r.stdout.strip()
    if target:
        remember(opened, st["id"], target)
        save_json(OPENED, opened)
    tmux("switch-client", "-t", sess)
    return verb + " in " + (target or sess)

WINDOWS = os.path.join(STATE_DIR, "windows.json")
MARKS = ("⏰ ", "⏾ ")

def mark_windows(states, snoozed, live):
    """Show snooze state in tmux window names: '⏾ PROD-11125' while snoozed, '⏰ PROD-11125' when
    due, and the window's own name back once neither applies. Only windows hosting a session that
    is or was marked are touched; the original name and its automatic-rename setting are kept in
    the state folder so the restore is exact."""
    from . import snooze as snooze_mod
    from .index import find, primary_ticket
    if not cfg()["tmux_window_marks"] or not available():
        return
    remembered = load_json(WINDOWS)
    changed = False
    wanted = {}
    for sid, entry in live.items():
        target = entry.get("tmux") or ""
        if ":" not in target:
            continue
        window = target.split(".")[0]
        e = snoozed.get(sid)
        if not e:
            continue
        st = find(states, sid)
        label = (primary_ticket(st) if st else "") or sid[:8]
        wanted[window] = (MARKS[0] if snooze_mod.is_due(e) else MARKS[1]) + label
    for window, name in wanted.items():
        r = tmux("display-message", "-p", "-t", window, "#{window_name}\t#{automatic-rename}")
        if r.returncode != 0:
            continue
        current, auto = (r.stdout.rstrip("\n").split("\t") + [""])[:2]
        if window not in remembered and not current.startswith(MARKS):
            remembered[window] = {"name": current, "automatic": auto == "1"}
            changed = True
        if current != name:
            tmux("rename-window", "-t", window, name)
    for window in list(remembered):
        if window in wanted:
            continue
        r = tmux("display-message", "-p", "-t", window, "#{window_name}")
        if r.returncode == 0 and r.stdout.strip().startswith(MARKS):
            if remembered[window].get("automatic"):
                tmux("set-option", "-w", "-t", window, "automatic-rename", "on")
            else:
                tmux("rename-window", "-t", window, remembered[window]["name"])
        del remembered[window]
        changed = True
    if changed:
        save_json(WINDOWS, remembered)
