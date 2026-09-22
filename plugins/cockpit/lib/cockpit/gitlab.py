"""Just enough GitLab to watch a merge request: state, notes by others, approvals, pipeline."""
import json
import os
import re
import subprocess
import urllib.parse
import urllib.request

from .config import CACHE, HOME, KEYCHAIN_SERVICE, cfg, load_json, save_json

MR_URL_RE = re.compile(r"https?://([^/]+)/(.+?)/-/merge_requests/(\d+)")
_token = None

def token():
    """Env var first, then the login keychain (what the launchd job relies on), then a literal in ~/.npmrc."""
    global _token
    if _token is not None:
        return _token
    for var in cfg()["token_env"]:
        if os.environ.get(var):
            _token = os.environ[var]
            return _token
    for service in (KEYCHAIN_SERVICE, "claude-fzf-sessions-gitlab", "claude-sessions-gitlab"):
        r = subprocess.run(["security", "find-generic-password", "-s", service, "-w"], capture_output=True, text=True)
        if r.returncode == 0 and r.stdout.strip():
            _token = r.stdout.strip()
            return _token
    try:
        for line in open(os.path.join(HOME, ".npmrc")):
            if "_authToken=" in line and cfg()["gitlab_host"] in line:
                val = line.split("_authToken=", 1)[1].strip()
                if val and not val.startswith("${"):
                    _token = val
                    return _token
    except Exception:
        pass
    _token = ""
    return _token

def get(host, path):
    req = urllib.request.Request("https://%s/api/v4/%s" % (host, path), headers={"PRIVATE-TOKEN": token()})
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.load(r)

def mr_ref(url):
    m = MR_URL_RE.match(url.strip())
    if not m:
        return None
    host, project, iid = m.groups()
    return {"host": host, "project": urllib.parse.quote(project, safe=""), "path": project, "iid": int(iid), "url": url.strip()}

def me():
    """The token owner's username, cached in the index file so it is fetched once."""
    cache = load_json(CACHE)
    who = cache.get("_me")
    if not who:
        try:
            who = get(cfg()["gitlab_host"], "user")["username"]
            cache["_me"] = who
            save_json(CACHE, cache)
        except Exception:
            who = ""
    return who

def snapshot(ref, user):
    base = "projects/%s/merge_requests/%d" % (ref["project"], ref["iid"])
    mr = get(ref["host"], base)
    notes = get(ref["host"], base + "/notes?sort=desc&order_by=updated_at&per_page=50")
    approvals = get(ref["host"], base + "/approvals")
    bot = re.compile(cfg()["bot_pattern"], re.I) if cfg()["bot_pattern"] else None
    others = [n for n in notes if not n.get("system") and n["author"]["username"] != user and not (bot and bot.search(n["author"]["username"]))]
    return {
        "state": mr.get("state"),
        "conflicts": bool(mr.get("has_conflicts")),
        "pipeline": (mr.get("head_pipeline") or {}).get("status"),
        "approvers": sorted(a["user"]["username"] for a in approvals.get("approved_by", [])),
        "max_note": max([n["id"] for n in notes] or [0]),
        "others": [(n["id"], n["author"]["username"]) for n in others],
        "title": mr.get("title", ""),
    }

def events(entry, snap):
    """What changed since the baseline stored on the snooze entry, as short phrases."""
    base = entry.get("mr_base") or {}
    ev = []
    closed = snap["state"] in ("merged", "closed") and base.get("state") == "opened"
    if entry.get("mr_mode") == "merge":
        return [snap["state"]] if closed else []
    new = [u for (nid, u) in snap["others"] if nid > base.get("max_note", 0)]
    if new:
        ev.append("%d new comment%s (%s)" % (len(new), "" if len(new) == 1 else "s", ", ".join(sorted(set(new)))))
    for a in snap["approvers"]:
        if a not in base.get("approvers", []):
            ev.append("approved by " + a)
    if snap["pipeline"] == "failed" and base.get("pipeline") != "failed":
        ev.append("pipeline failed")
    if snap["conflicts"] and not base.get("conflicts"):
        ev.append("has conflicts")
    if closed:
        ev.append(snap["state"])
    return ev
