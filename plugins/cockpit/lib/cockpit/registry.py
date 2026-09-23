"""Running Claude sessions, from the registry Claude Code keeps under ~/.claude/sessions."""
import json
import os
import subprocess

from .config import REGISTRY, canonical

def attached_panes():
    """tmux panes running `claude attach <jobId>`, keyed by job id, as session:@window.%pane. A
    background session has no pane of its own; the pane showing it is where Enter should land and
    where a snooze mark belongs, so it is found from the processes instead."""
    try:
        pids = subprocess.run(["pgrep", "-f", "claude attach "], capture_output=True, text=True).stdout.split()
        panes = subprocess.run(["tmux", "list-panes", "-a", "-F", "#{pane_pid}\t#{session_name}:#{window_id}.#{pane_id}"],
                               capture_output=True, text=True).stdout
        ps = subprocess.run(["ps", "-axo", "pid=,ppid=,command="], capture_output=True, text=True).stdout
    except FileNotFoundError:
        return {}
    by_pane_pid = dict(l.split("\t", 1) for l in panes.splitlines() if "\t" in l)
    parent, command = {}, {}
    for l in ps.splitlines():
        parts = l.split(None, 2)
        if len(parts) == 3:
            parent[parts[0]], command[parts[0]] = parts[1], parts[2]
    out = {}
    for pid in pids:
        words = command.get(pid, "").split()
        if "attach" not in words or words.index("attach") + 1 >= len(words):
            continue
        job = words[words.index("attach") + 1]
        p = pid
        for _ in range(8):
            if p in by_pane_pid:
                out[job] = by_pane_pid[p]
                break
            p = parent.get(p, "")
            if not p:
                break
    return out

def live_sessions():
    """Running Claude processes, keyed by canonical session id. Claude registers two kinds: an
    interactive process, with a tmux pane when it runs in one, and a background session
    ("kind": "bg", from claude --bg or a conversation continued into a background job), which has
    no pane and is opened with `claude attach <jobId>`. When both exist for one conversation the
    interactive entry is kept, since that is where Enter should land, busy if either is."""
    live, background = {}, []
    if not os.path.isdir(REGISTRY):
        return live
    for name in os.listdir(REGISTRY):
        if not name.endswith(".json"):
            continue
        try:
            with open(os.path.join(REGISTRY, name)) as f:
                d = json.load(f)
            os.kill(int(d["pid"]), 0)
        except Exception:
            continue
        if d.get("kind") == "bg":
            background.append(d)
            continue
        sid = canonical(d.get("sessionId", ""))
        prev = live.get(sid)
        if prev and prev.get("tmux") and not d.get("tmux"):
            d = dict(prev, status="busy" if "busy" in (prev.get("status"), d.get("status")) else prev.get("status"))
        elif prev and "busy" in (prev.get("status"), d.get("status")):
            d = dict(d, status="busy")
        live[sid] = d
    attached = attached_panes() if background else {}
    for d in background:
        sid = canonical(d.get("sessionId", ""))
        if d.get("jobId") in attached and not d.get("tmux"):
            d = dict(d, tmux=attached[d["jobId"]])
        if sid not in live:
            live[sid] = d
        elif d.get("status") == "busy":
            live[sid] = dict(live[sid], status="busy")
    return live

def user_names():
    """Names given with /rename to running sessions, keyed by canonical session id. Claude writes the
    name into the process's registry entry at once, while the transcript's title record can lag
    behind the hook that re-asserts an older title."""
    names = {}
    if not os.path.isdir(REGISTRY):
        return names
    for name in os.listdir(REGISTRY):
        if not name.endswith(".json"):
            continue
        try:
            with open(os.path.join(REGISTRY, name)) as f:
                d = json.load(f)
            os.kill(int(d["pid"]), 0)
        except Exception:
            continue
        if d.get("nameSource") != "user" or not d.get("name"):
            continue
        sid = canonical(d.get("sessionId", ""))
        if d.get("nameSince", 0) >= names.get(sid, (0, ""))[0]:
            names[sid] = (d.get("nameSince", 0), d["name"])
    return {sid: v[1] for sid, v in names.items()}

def current_session_id():
    """The session this command runs inside: Claude exports CLAUDE_CODE_SESSION_ID to its Bash;
    from a plain shell inside tmux, the session whose pane matches $TMUX_PANE."""
    sid = os.environ.get("CLAUDE_CODE_SESSION_ID")
    if sid:
        return sid
    pane = os.environ.get("TMUX_PANE", "")
    if not pane:
        return None
    for sid, entry in live_sessions().items():
        if (entry.get("tmux") or "").endswith("." + pane):
            return sid
    return None
