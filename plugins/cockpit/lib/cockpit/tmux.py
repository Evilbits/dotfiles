"""Getting the user to a session: a jump to a running tmux pane, a resume in a new tmux window, or,
without tmux, a resume in this terminal or in a new Terminal/iTerm window."""
import os
import subprocess
import time

from .config import CLAUDE_BIN, HOME, OPENED, cfg, load_json, save_json
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
    """target is tmux's session:@window.%pane form, as the registry records it."""
    tmux("switch-client", "-t", target.split(":")[0])
    tmux("select-window", "-t", target.split(".")[0])
    tmux("select-pane", "-t", target.split(".")[-1])

def open_in_terminal_app(cmd, cwd):
    """Without tmux and without a terminal of our own (a notification click), open a new window in
    the user's terminal app. iTerm2 when it is running, else Terminal."""
    script = 'cd %s && %s' % (cwd.replace('"', '\\"'), cmd)
    running = subprocess.run(["osascript", "-e", 'tell application "System Events" to (name of processes) contains "iTerm2"'], capture_output=True, text=True).stdout.strip()
    if running == "true":
        osa = 'tell application "iTerm" to create window with default profile command "/bin/zsh -lc \\"%s\\""' % script.replace('"', '\\"')
    else:
        osa = 'tell application "Terminal" to do script "%s"' % script.replace('"', '\\"')
    subprocess.run(["osascript", "-e", osa], capture_output=True)

def open_session(st):
    """Jump to the session if it runs anywhere, otherwise resume it. Returns a phrase for the log."""
    live = live_sessions().get(st["id"])
    in_tmux = available()
    if live:
        if in_tmux and live.get("tmux"):
            jump(live["tmux"])
            return "jumped to " + live["tmux"]
        msg = "already running in another terminal window; switch to it there"
        print(msg, file=sys.stderr)
        return msg
    cwd = st["cwd"] if os.path.isdir(st["cwd"]) else HOME
    cmd = "%s --resume %s" % (CLAUDE_BIN, st["id"])
    if not in_tmux:
        if sys.stdin.isatty():
            os.chdir(cwd)
            os.execvp(CLAUDE_BIN, [CLAUDE_BIN, "--resume", st["id"]])
        open_in_terminal_app(cmd, cwd)
        return "resumed in a new terminal window"
    # A window this tool opened may still be starting and not yet registered; a second
    # resume of a running session would make Claude start a copy, so jump to that window.
    opened = load_json(OPENED)
    prev = opened.get(st["id"])
    if prev and tmux("display-message", "-p", "-t", prev["target"], "#{pane_id}").returncode == 0:
        jump(prev["target"])
        return "jumped to " + prev["target"]
    sess = session_for(cwd)
    r = tmux("new-window", "-t", sess + ":", "-n", primary_ticket(st) or st["id"][:8], "-c", cwd, "-P", "-F", "#{session_name}:#{window_id}.#{pane_id}", cmd)
    target = r.stdout.strip()
    if target:
        opened[st["id"]] = {"target": target, "at": time.time()}
        save_json(OPENED, opened)
    tmux("switch-client", "-t", sess)
    return "resumed in " + (target or sess)
