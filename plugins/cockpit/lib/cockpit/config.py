"""Paths and user configuration. Everything a person might want to change lives here or in
~/.config/cockpit/config.json, so the code itself carries no personal constants."""
import json
import os
import re
import shutil

HOME = os.path.expanduser("~")
PROJECTS = os.path.join(HOME, ".claude", "projects")
REGISTRY = os.path.join(HOME, ".claude", "sessions")
CACHE_DIR = os.path.join(HOME, ".cache", "cockpit")
STATE_DIR = os.path.join(HOME, ".local", "state", "cockpit")
CACHE = os.path.join(CACHE_DIR, "index.json")
SNOOZE = os.path.join(STATE_DIR, "snooze.json")
OPENED = os.path.join(STATE_DIR, "opened.json")
WAKE_LOG = os.path.join(STATE_DIR, "wake.log")
CONFIG = os.path.join(HOME, ".config", "cockpit", "config.json")
LAUNCHD_LABEL = "com.doxyme.cockpit.wake"
PLIST = os.path.join(HOME, "Library", "LaunchAgents", LAUNCHD_LABEL + ".plist")
KEYCHAIN_SERVICE = "cockpit-gitlab"
CLAUDE_BIN = shutil.which("claude") or os.path.join(HOME, ".local", "bin", "claude")

DEFAULTS = {
    # Jira-style keys counted in prompts; the most frequent one becomes the session's ticket.
    "ticket_pattern": r"\b[A-Z][A-Z0-9]{1,9}-\d{1,6}\b",
    # Keys never counted, e.g. examples that live in instruction files.
    "ticket_deny": [],
    # Slash-command skills worth a column; empty means any command the session invoked.
    "skill_prefix": "",
    # The kind of work a session is, from the skill it started with: shown before its subject in the
    # picker and the menu bar. Skills not listed here give no verb.
    "skill_verbs": {"doxy-review": "Review", "doxy-implement": "Implement", "doxy-design": "Design",
                    "doxy-ticket": "Ticket", "doxy-epic": "Epic"},
    # Host for ticket links in the status line; empty means the host of the first Jira link a
    # session was given, and no link when it never saw one.
    "jira_host": "",
    # Comment authors ignored by MR review watches (regex on the username).
    "bot_pattern": r"bot",
    # Where MR review activity is polled; only gitlab.com-style APIs are supported.
    "gitlab_host": "gitlab.com",
    # Environment variables tried, in order, before the keychain, for the GitLab token.
    "token_env": ["GITLAB_TOKEN", "GITLAB_NPM_TOKEN"],
    # Slash commands that do not count as working on a snoozed session, so typing them keeps the
    # snooze: leaving, clearing, re-snoozing and plugin housekeeping. Compared without the slash.
    "snooze_keep_commands": ["exit", "quit", "clear", "compact", "snooze", "unsnooze", "cockpit:snooze",
                             "cockpit:unsnooze", "plugin", "reload-plugins", "reload", "recap", "status",
                             "config", "help", "cost", "model", "color", "resume", "context"],
    # Wake reopens closed sessions in tmux when their snooze fires.
    "reopen_on_wake": True,
    # Prefix the tmux window of a snoozed session with ⏾ and of a due one with ⏰; restored afterwards.
    "tmux_window_marks": True,
    # Colours (256-colour indexes) used by the picker preview and status line.
    "colour_accent": 183,
    "colour_branch": 116,
}

_cfg = None

def cfg():
    global _cfg
    if _cfg is None:
        data = dict(DEFAULTS)
        try:
            with open(CONFIG) as f:
                data.update(json.load(f))
        except Exception:
            pass
        _cfg = data
    return _cfg

def ticket_re():
    return re.compile(cfg()["ticket_pattern"])

def canonical(session_id):
    """A conversation can continue under a new id (a background job, a fork on resume, a compaction);
    the old transcript then carries a continued-in record. Every id in such a chain resolves to
    the newest one, so snoozes, live processes and picker rows all meet on one session."""
    alias = load_json(CACHE).get("_alias", {})
    seen = set()
    while session_id in alias and session_id not in seen:
        seen.add(session_id)
        session_id = alias[session_id]
    return session_id

def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return {}

def save_json(path, data, indent=None):
    """Atomic write that follows a symlink, so a settings file linked from a dotfiles repo is
    updated in place instead of being replaced by a plain file."""
    path = os.path.realpath(path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=indent)
    os.replace(tmp, path)
