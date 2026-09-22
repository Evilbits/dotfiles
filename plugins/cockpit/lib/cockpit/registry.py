"""Running Claude sessions, from the registry Claude Code keeps under ~/.claude/sessions."""
import json
import os

from .config import REGISTRY

def live_sessions():
    live = {}
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
        live[d.get("sessionId", "")] = d
    return live

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
