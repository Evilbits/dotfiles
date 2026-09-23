"""Command dispatch. The entry script passes its own absolute path so hooks, launchd and
notifications can call back into the same install."""
import json
import os
import shutil
import subprocess
import sys
import time

from . import gitlab, snooze, ui, wake
from .config import CLAUDE_BIN, HOME, KEYCHAIN_SERVICE, canonical, cfg, load_json, save_json, ticket_re
from .index import find, index_sessions, one_session, primary_ticket, title_of, set_ticket
from .registry import current_session_id, live_sessions
from .tmux import open_session, origin_pane

USAGE = """cockpit: a picker, snoozer and status line for Claude Code sessions.

  cockpit                      fzf picker (prefix-r in tmux once bound)
  cockpit --snooze ID [DURATION] [MR-URL [merge]] [REASON]
                                       park a session until a time, until something happens on a
                                       GitLab MR, or whichever comes first. ID may be "current".
  cockpit --unsnooze ID
  cockpit --ticket ID KEY|none  pin the ticket a session is filed under, or say it has none
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
    if ref is None and any(gitlab.MR_URL_RE.match(w) for w in words):
        sys.exit("only merge requests on %s can be watched" % cfg()["gitlab_host"])
    if until is None and ref is None:
        sys.exit("need a duration (2h, 3d, tomorrow, fri, 14:30) or an MR URL")
    entry = {"until": until, "reason": reason, "due": False}
    baseline_pending = False
    if ref:
        entry.update(mr=ref, mr_mode=mode)
        try:
            snap = gitlab.snapshot(ref, gitlab.me())
            if snap["state"] != "opened":
                print("note: !%d is already %s, so nothing on it will wake this snooze%s" % (ref["iid"], snap["state"], "" if until else "; add a duration or it never fires"))
            entry.update(mr_title=snap["title"], mr_base={k: snap[k] for k in ("state", "conflicts", "pipeline", "approvers", "max_note")})
        except Exception as e:
            # GitLab unreachable right now: keep the snooze, let the minute job take the baseline.
            baseline_pending = True
            wake.log("snooze baseline for !%d deferred: %s" % (ref["iid"], e))
    snooze.put(st["id"], entry)
    parts = []
    if ref:
        parts.append(("until !%d merges" if mode == "merge" else "until review activity on !%d") % ref["iid"])
    if until:
        parts.append("until %s (in %s)" % (snooze.fmt_until(until), snooze.remaining(until)))
    print("snoozed %s %s%s" % (primary_ticket(st) or st["id"][:8], " or ".join(parts), (" · " + reason) if reason else "")
          + ("; GitLab was unreachable, the watch starts from the first check that gets through" if baseline_pending else ""))
    refresh_marks()

def do_unsnooze(session_id):
    if session_id == "current":
        session_id = current_session_id() or sys.exit("no Claude session in this tmux pane")
    snooze.remove(session_id)
    print("unsnoozed")
    refresh_marks()

def do_ticket(session_id, key):
    states, _ = index_sessions()
    st = _resolve(session_id, states)
    if not st:
        sys.exit("unknown session %s (from a Claude session, 'current' needs tmux)" % session_id)
    key = "" if key.lower() in ("none", "off", "-") else key
    if key and not ticket_re().fullmatch(key):
        sys.exit("%s does not look like a ticket key" % key)
    set_ticket(st["id"], key)
    print(("filed under " + key) if key else "no ticket for this session")
    refresh_marks()

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

def do_open(session_id, origin=None):
    states, _ = index_sessions()
    st = _resolve(session_id, states)
    if not st:
        sys.exit("unknown session " + session_id)
    try:
        result = open_session(st, origin)
    except Exception as e:
        wake.log("open %s failed: %r" % (st["id"][:8], e))
        raise
    # Opening leaves the snooze alone; the prompt hook clears it once the user types into the session.
    wake.log("open %s: %s" % (st["id"][:8], result))
    refresh_marks()
    return result

def _is_ours(link):
    """A symlink cockpit made: it points at bin/<name> under a folder named cockpit, either directly
    (a checkout, cockpit/bin/) or through a version folder (the plugin cache, cockpit/0.1.2/bin/)."""
    if not os.path.islink(link):
        return False
    parts = os.readlink(link).split(os.sep)
    return parts[-2:] == ["bin", os.path.basename(link)] and "cockpit" in parts[-4:-2]

def heal_links(me):
    """The ~/.local/bin links point at one installed version; after a plugin update that folder
    may be gone. Runs at every session start from the current plugin root and re-points them.
    Only links cockpit made itself are touched; anything else at those paths is left alone."""
    root = os.path.dirname(os.path.dirname(me))
    for name in ("cockpit", "cockpit-statusline"):
        link = os.path.join(HOME, ".local", "bin", name)
        if not _is_ours(link):
            continue
        target = os.path.realpath(link)
        if not target.startswith(root) or not os.path.exists(target):
            os.remove(link)
            os.symlink(os.path.join(root, "bin", name), link)

def do_banner(me):
    """SessionStart hook output: the snoozed sessions, due first, as a system message."""
    heal_links(me)
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
    if _is_ours(link):
        os.remove(link)
    elif os.path.islink(link) or os.path.exists(link):
        sys.exit("%s exists and is not cockpit's; move it aside and run the install again" % link)
    os.symlink(os.path.join(os.path.dirname(me), name), link)
    return link

TMUX_BIND = 'bind r split-window -v "~/.local/bin/cockpit"'
STATUSLINE_CMD = "~/.local/bin/cockpit-statusline"
# Claude redraws the status line on session events only; the timer keeps snoozes and MRs current while idle.
REFRESH_SECONDS = 60

def _wire_tmux():
    """Append the picker binding to ~/.tmux.conf unless r is already bound, then reload tmux."""
    conf = os.path.join(HOME, ".tmux.conf")
    text = open(conf).read() if os.path.exists(conf) else ""
    if TMUX_BIND in text:
        state = "tmux: prefix r already opens the picker"
    elif any(l.strip().startswith(("bind r ", "bind-key r ", "bind -r r ")) for l in text.splitlines()):
        return "tmux: prefix r is already bound in ~/.tmux.conf; add this yourself with a free key:\n  " + TMUX_BIND
    else:
        with open(conf, "a") as f:
            f.write(("" if text.endswith("\n") or not text else "\n") + "\n# cockpit: fzf picker over Claude Code sessions\n" + TMUX_BIND + "\n")
        state = "tmux: added the prefix r binding to ~/.tmux.conf"
    if subprocess.run(["tmux", "source-file", conf], capture_output=True).returncode == 0:
        state += ", reloaded"
    return state

def _wire_statusline():
    """Point Claude's statusLine at cockpit unless it already points elsewhere."""
    path = os.path.join(HOME, ".claude", "settings.json")
    settings = load_json(path) if os.path.exists(path) else {}
    current = (settings.get("statusLine") or {}).get("command", "")
    entry = {"type": "command", "command": STATUSLINE_CMD, "refreshInterval": REFRESH_SECONDS}
    if current.rstrip("/").endswith("cockpit-statusline"):
        if settings["statusLine"].get("refreshInterval") == REFRESH_SECONDS:
            return "status line: already set"
        settings["statusLine"] = dict(settings["statusLine"], refreshInterval=REFRESH_SECONDS)
        save_json(path, settings, indent=2)
        return "status line: added a %ds refresh so snoozes and MRs update while a session is idle" % REFRESH_SECONDS
    if current:
        return "status line: settings.json already has a statusLine (%s); to switch, set it to:\n  \"statusLine\": %s" % (current, json.dumps(entry))
    settings["statusLine"] = entry
    if os.path.exists(path):
        shutil.copy2(path, path + ".bak")
    save_json(path, settings, indent=2)
    return "status line: added statusLine to ~/.claude/settings.json (previous copy in settings.json.bak); it shows from the next turn"

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
    bad = [p for p in parts if p not in PARTS]
    if bad:
        sys.exit("unknown part(s): %s; choose from %s" % (", ".join(bad), ", ".join(PARTS)))
    if "picker" in parts or "snooze" in parts:
        _link(me, "cockpit")
        print("linked ~/.local/bin/cockpit")
    if "picker" in parts:
        if shutil.which("tmux"):
            print(_wire_tmux())
        else:
            print("no tmux: run `cockpit` in any terminal tab to open the picker; without tmux it resumes closed sessions but cannot switch to one running in another tab")
    if "snooze" in parts:
        print(wake.install(os.path.join(HOME, ".local", "bin", "cockpit")))
        source = gitlab.token_source()
        if source and source != "keychain":
            print("GitLab token for MR watches: found in %s, stored in your login keychain as %s" % (source.split(":", 1)[-1], KEYCHAIN_SERVICE) if gitlab.store_token(gitlab.token()) else "GitLab token for MR watches: found in %s but could not be stored in the keychain" % source)
        elif source:
            print("GitLab token for MR watches: already in your login keychain")
        else:
            print("GitLab token for MR watches: none found. Create a personal access token with read_api scope and run:\n  security add-generic-password -a \"$USER\" -s %s -w \"<token>\"" % KEYCHAIN_SERVICE)
        print("notifications: allow terminal-notifier under System Settings → Notifications when the first reminder fires")
    if "statusline" in parts:
        _link(me, "cockpit-statusline")
        print("linked ~/.local/bin/cockpit-statusline")
        print(_wire_statusline())

def do_uninstall():
    print(wake.uninstall())
    conf = os.path.join(HOME, ".tmux.conf")
    if os.path.exists(conf):
        lines = open(conf).read().split("\n")
        kept = [l for l in lines if l.strip() not in (TMUX_BIND, "# cockpit: fzf picker over Claude Code sessions")]
        if kept != lines:
            open(conf, "w").write("\n".join(kept))
            print("removed the prefix r binding from ~/.tmux.conf")
    path = os.path.join(HOME, ".claude", "settings.json")
    settings = load_json(path) if os.path.exists(path) else {}
    if (settings.get("statusLine") or {}).get("command", "").endswith("cockpit-statusline"):
        del settings["statusLine"]
        save_json(path, settings, indent=2)
        print("removed the statusLine entry from ~/.claude/settings.json")
    for name in ("cockpit", "cockpit-statusline"):
        link = os.path.join(HOME, ".local", "bin", name)
        if _is_ours(link):
            os.remove(link)
            print("removed", link)
        elif os.path.lexists(link):
            print("left %s alone, it is not cockpit's" % link)

def _housekeeping(prompt):
    """A slash command from snooze_keep_commands: leaving, clearing, re-snoozing or plugin upkeep,
    which is not working on the session. A bare or malformed slash is not one."""
    words = prompt.strip().split()
    if not words or not words[0].startswith("/"):
        return False
    return words[0][1:].lower() in cfg()["snooze_keep_commands"]

def refresh_marks():
    from .tmux import mark_windows
    states, _ = index_sessions()
    mark_windows(states, snooze.load(), live_sessions())

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
        origin = origin_pane()
        choice = ui.pick(lines, "\n".join(ui.snoozed_lines(states)), me)
        if choice:
            do_open(choice, origin)
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
        repo_dir = rest[rest.index("--dir") + 1] if "--dir" in rest else ""
        branch = rest[rest.index("--branch") + 1] if "--branch" in rest else ""
        print(ui.statusline_fields(one_session(rest[0]), rest[0], repo_dir, branch))
    elif cmd == "--snooze" and len(rest) >= 2:
        do_snooze(rest[0], rest[1:])
    elif cmd == "--snooze-prompt" and rest:
        do_snooze_prompt(rest[0])
    elif cmd == "--unsnooze" and rest:
        do_unsnooze(rest[0])
    elif cmd == "--ticket" and len(rest) >= 2:
        do_ticket(rest[0], rest[1])
    elif cmd == "--due":
        states, _ = index_sessions()
        print("\n".join(ui.snoozed_lines(states, banner=True)))
    elif cmd == "--banner":
        do_banner(me)
    elif cmd == "--prompt-hook":
        # UserPromptSubmit: typing into a snoozed session means it is being worked on again, unless
        # the prompt is a housekeeping command such as /exit or a re-snooze. The systemMessage lands
        # in the chat, so the reader sees what fired or that nothing has yet.
        try:
            payload = json.load(sys.stdin)
        except Exception:
            payload = {}
        sid = payload.get("session_id", "")
        prompt = payload.get("prompt") or payload.get("user_prompt") or ""
        entry = snooze.load().get(canonical(sid)) if sid and not _housekeeping(prompt) else None
        if entry:
            msg = snooze.woke_text(entry)
            snooze.remove(sid)
            wake.log("unsnoozed %s on prompt: %s" % (sid[:8], msg))
            print(json.dumps({"systemMessage": msg, "hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "This session was snoozed and the user's prompt just cleared it: " + msg}}))
        # Every prompt refreshes the window names, so a window opened by hand is named after its
        # session on the first prompt rather than on the next minute job, and a cleared snooze loses
        # its mark at once.
        refresh_marks()
    elif cmd == "--wake":
        wake.wake(me)
    elif cmd == "--install":
        do_install(me, rest)
    elif cmd == "--uninstall":
        do_uninstall()
    else:
        print(USAGE)
