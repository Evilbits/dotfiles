"""The minute job: fire snoozes whose time has come or whose MR changed, notify, reopen."""
import os
import shutil
import subprocess
import sys
import time

from . import gitlab, snooze
from .config import LAUNCHD_LABEL, PLIST, WAKE_LOG, cfg
from .index import find, index_sessions, primary_ticket, title_of
from .registry import live_sessions
from .tmux import available, open_session, tmux

def log(msg):
    try:
        os.makedirs(os.path.dirname(WAKE_LOG), exist_ok=True)
        with open(WAKE_LOG, "a") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + msg + "\n")
    except Exception:
        pass

def notify(title, body, session_id, entry_script):
    tn = shutil.which("terminal-notifier") or "/opt/homebrew/bin/terminal-notifier"
    if os.path.exists(tn):
        args = [tn, "-title", title, "-message", body, "-sound", "default", "-group", "cockpit",
                "-execute", "'%s' --open %s" % (entry_script, session_id)]
        r = subprocess.run(args, capture_output=True, text=True)
        log("terminal-notifier exit %s %s" % (r.returncode, r.stderr.strip()))
    else:
        r = subprocess.run(["osascript", "-e", 'display notification "%s" with title "%s"' % (body.replace('"', "'"), title.replace('"', "'"))], capture_output=True, text=True)
        log("osascript exit %s %s" % (r.returncode, r.stderr.strip()))
    tmux("display-message", "-d", "8000", "%s: %s" % (title, body))

def wake(entry_script):
    data = snooze.load()
    if not data:
        return
    states, _ = index_sessions()
    live = live_sessions()
    user = gitlab.me() if any(e.get("mr") for e in data.values()) else ""
    now = time.time()
    for sid, entry in data.items():
        if entry.get("due"):
            continue
        events = []
        if entry.get("mr"):
            try:
                events = gitlab.events(entry, gitlab.snapshot(entry["mr"], user))
            except Exception as e:
                log("mr check failed for !%s: %s" % (entry["mr"]["iid"], e))
        timed_out = entry.get("until") is not None and entry["until"] <= now
        if not events and not timed_out:
            continue
        event = "; ".join(events) if events else "time"
        st = find(states, sid)
        label = ((primary_ticket(st) + " · ") if st and primary_ticket(st) else "") + (title_of(st) if st else sid[:8])
        detail = ("!%d %s" % (entry["mr"]["iid"], event)) if entry.get("mr") and events else ""
        log("due: %s %s" % (label, detail))
        snooze.mark_due(sid, event)
        notify("Claude session due", label + ((" — " + detail) if detail else "") + ((" — " + entry["reason"]) if entry.get("reason") else ""), sid, entry_script)
        if st and cfg()["reopen_on_wake"] and sid not in live and available():
            log(open_session(st))   # without tmux the notification click reopens it instead

PLIST_XML = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>%(label)s</string>
  <key>ProgramArguments</key><array><string>/usr/bin/python3</string><string>%(script)s</string><string>--wake</string></array>
  <key>StartInterval</key><integer>60</integer>
  <key>RunAtLoad</key><true/>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string></dict>
</dict></plist>
"""

def install(entry_script):
    os.makedirs(os.path.dirname(PLIST), exist_ok=True)
    subprocess.run(["launchctl", "bootout", "gui/%d" % os.getuid(), PLIST], capture_output=True)
    with open(PLIST, "w") as f:
        f.write(PLIST_XML % {"label": LAUNCHD_LABEL, "script": entry_script})
    r = subprocess.run(["launchctl", "bootstrap", "gui/%d" % os.getuid(), PLIST], capture_output=True, text=True)
    return "wake job installed, every minute" if r.returncode == 0 else r.stderr.strip()

def uninstall():
    subprocess.run(["launchctl", "bootout", "gui/%d" % os.getuid(), PLIST], capture_output=True)
    if os.path.exists(PLIST):
        os.remove(PLIST)
    return "wake job removed"
