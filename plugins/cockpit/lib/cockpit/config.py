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
    # Comment authors ignored by MR review watches (regex on the username).
    "bot_pattern": r"bot",
    # Where MR review activity is polled; only gitlab.com-style APIs are supported.
    "gitlab_host": "gitlab.com",
    # Environment variables tried, in order, before the keychain, for the GitLab token.
    "token_env": ["GITLAB_TOKEN", "GITLAB_NPM_TOKEN"],
    # Wake reopens closed sessions in tmux when their snooze fires.
    "reopen_on_wake": True,
    # Colours (256-colour indexes) used by the picker preview and status line.
    "colour_accent": 183,
    "colour_branch": 116,
}

_cfg = None

OLD_NAMES = ("claude-fzf-sessions", "claude-sessions")

def migrate_from_old_name():
    """One-time move of cache, state and config written by the pre-plugin tool. Called from
    --install only, so a machine still running the old tool is not disturbed until it switches."""
    moved = []
    for new in (CACHE_DIR, STATE_DIR, os.path.dirname(CONFIG)):
        for old_name in OLD_NAMES:
            old = new.replace("cockpit", old_name)
            if not os.path.isdir(old):
                continue
            if not os.path.exists(new):
                os.makedirs(os.path.dirname(new), exist_ok=True)
                os.rename(old, new)
                moved.append(new)
                continue
            # Both exist (the new tool ran before the switch): fold the old snoozes in, keep the rest.
            old_snooze = os.path.join(old, "snooze.json")
            if new == STATE_DIR and os.path.isfile(old_snooze):
                merged = load_json(SNOOZE)
                for k, v in load_json(old_snooze).items():
                    if isinstance(v, dict) and k not in merged:
                        merged[k] = v
                save_json(SNOOZE, merged, indent=1)
                os.rename(old_snooze, old_snooze + ".migrated")
                moved.append(SNOOZE)
    return moved

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

def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return {}

def save_json(path, data, indent=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=indent)
    os.replace(tmp, path)
