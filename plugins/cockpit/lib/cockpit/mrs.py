"""The merge request behind a branch, for the status line. Lookups are answered from a cache; the
minute job refreshes every branch the status line has asked about, so a render never waits on
GitLab."""
import os
import re
import subprocess
import time
import urllib.error
import urllib.parse

from . import gitlab
from .config import CACHE_DIR, load_json, updating_json

MRS = os.path.join(CACHE_DIR, "mrs.json")
FRESH = 120          # seconds a cached answer is served without a refresh
FORGET = 3 * 86400   # branches not asked about for this long are dropped

def project_of_repo(repo_dir):
    """'group/sub/repo' from the origin remote, or ''."""
    r = subprocess.run(["git", "-C", repo_dir, "remote", "get-url", "origin"], capture_output=True, text=True)
    m = re.search(r"gitlab\.com[:/](.+?)(?:\.git)?$", r.stdout.strip())
    return m.group(1) if m else ""

def _key(project, branch):
    return project + "#" + branch

def _want(key, seed):
    with updating_json(MRS) as data:
        entry = data.setdefault(key, dict(seed, checked=0))
        entry["wanted"] = time.time()
    return entry.get("mr")

def lookup_url(url):
    """The cached MR behind a link, any state; records the interest for the next wake."""
    m = re.match(r"https://([^/]+)/(.+?)/-/merge_requests/(\d+)", url)
    if not m:
        return None
    return _want(m.group(2) + "!" + m.group(3), {"project": m.group(2), "iid": int(m.group(3))})

def session_mrs(state):
    """The MRs that came out of a session, newest first: the ones it created, then every link it
    dealt with that the token owner authored, else the latest one the user pasted, as a review
    session does. An MR Claude only mentioned is never the session's. Empty until the wake has
    fetched them."""
    from .gitlab import me
    created = [lookup_url(u) for u in reversed(state.get("created_mrs", []))]
    created = [m for m in created if m]
    mrs_ = [lookup_url(u) for u in reversed(state.get("mr_urls", []))]
    mrs_ = [m for m in mrs_ if m]
    who = me()
    seen = {m["url"] for m in created}
    own = created + [m for m in mrs_ if m.get("author") == who and m["url"] not in seen]
    pasted_urls = set(state.get("mr_urls_pasted", []))
    pasted = [m for m in mrs_ if m["url"] in pasted_urls]
    return own or pasted[:1]

def session_mr(state):
    """The MR a session is working on: the newest of session_mrs, None until fetched."""
    found = session_mrs(state)
    return found[0] if found else None

def lookup(repo_dir, branch):
    """The cached latest MR for this branch, any state, as {iid, title, url, state} or None. Records
    the interest so the next wake refreshes it."""
    if not branch or branch.startswith("@") or branch in ("master", "main"):
        return None
    project = project_of_repo(repo_dir)
    if not project:
        return None
    return _want(_key(project, branch), {"project": project, "branch": branch})

def _shape(mr):
    return {"iid": mr["iid"], "title": mr["title"], "url": mr["web_url"], "state": mr["state"], "author": (mr.get("author") or {}).get("username", "")}

def fetch(project, branch):
    path = "projects/%s/merge_requests?source_branch=%s&state=all&order_by=updated_at&per_page=1" % (urllib.parse.quote(project, safe=""), urllib.parse.quote(branch, safe=""))
    found = gitlab.get(gitlab.cfg()["gitlab_host"], path)
    return _shape(found[0]) if found else None

def fetch_iid(project, iid):
    return _shape(gitlab.get(gitlab.cfg()["gitlab_host"], "projects/%s/merge_requests/%d" % (urllib.parse.quote(project, safe=""), iid)))

def refresh_wanted(log):
    """Called by the wake: refresh stale entries the status line asked about, forget old ones.
    GitLab is asked outside the lock, and the answers are merged into the file as it is then, so
    the status lines that render meanwhile are neither blocked nor overwritten."""
    now = time.time()
    found = {}
    for key, e in load_json(MRS).items():
        if now - e.get("wanted", 0) > FORGET or now - e.get("checked", 0) < FRESH:
            continue
        try:
            found[key] = fetch_iid(e["project"], e["iid"]) if "iid" in e else fetch(e["project"], e["branch"])
        except urllib.error.HTTPError as ex:
            if ex.code == 404:
                # An example link or a deleted MR: remember there is nothing, stop asking every minute.
                found[key] = None
            else:
                log("mr lookup failed for %s: %s" % (key, ex))
        except Exception as ex:
            log("mr lookup failed for %s: %s" % (key, ex))
    with updating_json(MRS) as data:
        for key in [k for k, e in data.items() if now - e.get("wanted", 0) > FORGET]:
            del data[key]
        for key, mr in found.items():
            if key in data:
                data[key]["mr"], data[key]["checked"] = mr, now
