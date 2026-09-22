"""The snooze store: one entry per session id, with a wake time, an MR watch, or both.
Writes merge into the file on disk, so a wake running for seconds over the network cannot
overwrite a snooze the user changed meanwhile."""
import datetime as dt
import re
import time

from .config import SNOOZE, load_json, save_json

WEEKDAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

def load():
    """Entries only: older versions kept a `_me` string in this file."""
    return {k: v for k, v in load_json(SNOOZE).items() if isinstance(v, dict)}

def put(session_id, entry):
    data = load()
    data[session_id] = entry
    save_json(SNOOZE, data, indent=1)

def remove(session_id):
    data = load()
    for k in list(data):
        if k == session_id or k.startswith(session_id):
            del data[k]
    save_json(SNOOZE, data, indent=1)

def mark_due(session_id, event):
    """Set due on the entry as it is on disk now; a no-op if the user removed it meanwhile."""
    data = load()
    if session_id in data:
        data[session_id]["due"] = True
        data[session_id]["event"] = event
        save_json(SNOOZE, data, indent=1)

def parse_until(spec, now=None):
    """2h, 45m, 3d, tomorrow, fri, 14:30 -> epoch seconds. Day-based specs land at 09:00."""
    now = now or dt.datetime.now()
    s = spec.strip().lower()
    morning = now.replace(hour=9, minute=0, second=0, microsecond=0)
    m = re.fullmatch(r"(\d+)\s*([smhd])", s)
    if m:
        n, unit = int(m.group(1)), m.group(2)
        if unit == "d":
            return (morning + dt.timedelta(days=n)).timestamp()
        secs = {"s": 1, "m": 60, "h": 3600}[unit] * n
        return (now + dt.timedelta(seconds=secs)).timestamp()
    if s in ("tomorrow", "tmr"):
        return (morning + dt.timedelta(days=1)).timestamp()
    if s[:3] in WEEKDAYS:
        days = (WEEKDAYS.index(s[:3]) - now.weekday()) % 7 or 7
        return (morning + dt.timedelta(days=days)).timestamp()
    m = re.fullmatch(r"(\d{1,2}):(\d{2})", s)
    if m:
        at = now.replace(hour=int(m.group(1)), minute=int(m.group(2)), second=0, microsecond=0)
        if at <= now:
            at += dt.timedelta(days=1)
        return at.timestamp()
    raise ValueError("cannot parse duration %r" % spec)

def fmt_until(ts):
    at = dt.datetime.fromtimestamp(ts)
    today = dt.datetime.now().date()
    if at.date() == today:
        return at.strftime("%H:%M")
    if (at.date() - today).days < 7:
        return at.strftime("%a %H:%M")
    return at.strftime("%d %b %H:%M")

def remaining(ts):
    s = int(ts - time.time())
    if s <= 0:
        return "due"
    d, rem = divmod(s, 86400)
    h, rem = divmod(rem, 3600)
    m = rem // 60
    if d:
        return "%dd %dh" % (d, h)
    if h:
        return "%dh %dm" % (h, m)
    return "%dm" % m if m else "<1m"

def is_due(e):
    return bool(e.get("due")) or (e.get("until") is not None and e["until"] <= time.time())

def text(e):
    """'⏰ !612: 2 new comments (x)' when due, else '⏾ !612 · in 2d 3h'."""
    mr = e.get("mr")
    tag = ("!%d%s" % (mr["iid"], " merge" if e.get("mr_mode") == "merge" else "")) if mr else ""
    if is_due(e):
        what = e.get("event") or ("" if mr else "time")
        return ("⏰ " + (tag + (": " if tag and what else "") + what)).rstrip(": ")
    bits = [tag] if tag else []
    if e.get("until") is not None:
        bits.append("in " + remaining(e["until"]))
    return "⏾ " + " · ".join(bits)

def triggers(e):
    if not e.get("mr"):
        return ""
    return "merge or close" if e.get("mr_mode") == "merge" else "a comment by someone else, an approval, a failed pipeline, a conflict, merge or close"

def parse_request(words):
    """Split a snooze request into (until, mr_ref, mode, reason). Tokens may come in any order."""
    from .gitlab import mr_ref
    until, ref, mode, reason = None, None, "review", []
    for tok in words:
        if ref is None and mr_ref(tok):
            ref = mr_ref(tok)
            continue
        if ref and not reason and tok.lower() in ("merge", "merged"):
            mode = "merge"
            continue
        if until is None:
            try:
                until = parse_until(tok)
                continue
            except ValueError:
                pass
        reason.append(tok)
    return until, ref, mode, " ".join(reason)
