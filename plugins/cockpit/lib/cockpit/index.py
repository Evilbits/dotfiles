"""Read-only index of Claude Code transcripts. Each session file is parsed once and then
incrementally from its last size; the result is cached under ~/.cache."""
import glob
import json
import os
import re
from collections import Counter

from .config import CACHE, PROJECTS, cfg, load_json, save_json, ticket_re

MR_RE = re.compile(r"merge_requests/(\d{3,6})")
COMMAND_RE = re.compile(r"<command-name>/?([a-z][a-z0-9-]*(?::[a-z][a-z0-9-]*)?)</command-name>")
ARGS_RE = re.compile(r"<command-args>([\s\S]*?)</command-args>")
REMINDER_RE = re.compile(r"<system-reminder>[\s\S]*?</system-reminder>")
JUNK_TITLE_RE = re.compile(r"^(please |i need|alternatively|base directory|review this pasted|want you to|then i)", re.I)
BUILTIN_COMMANDS = {"clear", "compact", "model", "rename", "resume", "help", "config", "status", "cost", "init", "login", "logout", "exit", "quit"}
SKIP_DIRS = ("claude-rename-worker",)
PROMPT_KEEP = 8
PROMPT_CHARS = 400

def new_state(session_id, project_dir):
    return {
        "id": session_id, "project_dir": project_dir, "cwd": "", "branch": "",
        "custom_title": "", "ai_title": "", "first_prompt": "", "prompts": [],
        "tickets": {}, "tickets_assistant": {}, "mrs": [], "skills": [],
        "first_ts": "", "last_ts": "", "turns": 0,
    }

def _prompt_text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return " ".join(c.get("text", "") for c in content if isinstance(c, dict) and c.get("type") == "text")
    return ""

def absorb_line(state, line):
    tre = ticket_re()
    deny = set(cfg()["ticket_deny"])
    if '"type":"user"' in line and '"isMeta":true' not in line and '"isSidechain":true' not in line:
        try:
            rec = json.loads(line)
        except Exception:
            return
        if rec.get("type") != "user":
            return
        state["cwd"] = rec.get("cwd") or state["cwd"]
        state["branch"] = rec.get("gitBranch") or state["branch"]
        ts = rec.get("timestamp") or ""
        if ts:
            state["first_ts"] = state["first_ts"] or ts
            state["last_ts"] = ts
        text = _prompt_text((rec.get("message") or {}).get("content"))
        if not text:
            return
        text = REMINDER_RE.sub("", text).strip()
        cmd = COMMAND_RE.search(text)
        if cmd and cmd.group(1) not in BUILTIN_COMMANDS and cmd.group(1) not in state["skills"]:
            state["skills"].append(cmd.group(1))
        args = ARGS_RE.search(text)
        if args:
            text = (("/" + cmd.group(1) + " ") if cmd else "") + args.group(1).strip()
        if not text or text.startswith("<"):
            return
        state["turns"] += 1
        for t in tre.findall(text):
            if t not in deny:
                state["tickets"][t] = state["tickets"].get(t, 0) + 1
        for m in MR_RE.findall(text):
            if m not in state["mrs"]:
                state["mrs"].append(m)
        short = re.sub(r"\s+", " ", text)[:PROMPT_CHARS]
        state["first_prompt"] = state["first_prompt"] or short
        state["prompts"].append(short)
        del state["prompts"][:-PROMPT_KEEP]
        return
    if '"type":"assistant"' in line:
        for t in tre.findall(line):
            if t not in deny:
                state["tickets_assistant"][t] = state["tickets_assistant"].get(t, 0) + 1
        return
    if '"type":"custom-title"' in line:
        try:
            state["custom_title"] = json.loads(line).get("customTitle") or state["custom_title"]
        except Exception:
            pass
        return
    if '"type":"ai-title"' in line:
        try:
            state["ai_title"] = json.loads(line).get("aiTitle") or state["ai_title"]
        except Exception:
            pass

def refresh_entry(cache, path):
    """Bring one transcript's cache entry up to date. Returns True when it changed."""
    st = os.stat(path)
    entry = cache.get(path)
    if entry and entry["size"] == st.st_size and entry["mtime"] == st.st_mtime:
        return False
    if entry and entry["size"] < st.st_size:
        state, offset = entry["state"], entry["size"]
    else:
        state, offset = new_state(os.path.basename(path)[:-6], os.path.basename(os.path.dirname(path))), 0
    with open(path, "rb") as f:
        f.seek(offset)
        for raw in f:
            try:
                absorb_line(state, raw.decode("utf-8", "replace"))
            except Exception:
                pass
    cache[path] = {"size": st.st_size, "mtime": st.st_mtime, "state": state}
    return True

def index_sessions(force=False):
    """All sessions: list of states plus id -> transcript mtime."""
    cache = {} if force else load_json(CACHE)
    seen = set()
    changed = force
    for project_dir in sorted(os.listdir(PROJECTS)) if os.path.isdir(PROJECTS) else []:
        if any(s in project_dir for s in SKIP_DIRS):
            continue
        full = os.path.join(PROJECTS, project_dir)
        if not os.path.isdir(full):
            continue
        for name in os.listdir(full):
            if name.endswith(".jsonl"):
                path = os.path.join(full, name)
                seen.add(path)
                changed |= refresh_entry(cache, path)
    for path in [p for p in cache if p not in seen and not p.startswith("_")]:
        del cache[path]
        changed = True
    if changed:
        save_json(CACHE, cache)
    entries = [e for k, e in cache.items() if not k.startswith("_")]
    return [e["state"] for e in entries], {e["state"]["id"]: e["mtime"] for e in entries}

def one_session(session_id):
    """Cheap path for the status line: refresh only this session's entry."""
    cache = load_json(CACHE)
    paths = glob.glob(os.path.join(PROJECTS, "*", session_id + ".jsonl"))
    if not paths:
        return None
    if refresh_entry(cache, paths[0]):
        save_json(CACHE, cache)
    return cache[paths[0]]["state"]

def find(states, session_id):
    for st in states:
        if st["id"] == session_id or st["id"].startswith(session_id):
            return st
    return None

def primary_ticket(state):
    tre = ticket_re()
    titles = {k: 1 for k in tre.findall(state["ai_title"] + " " + state["custom_title"])}
    for source in (state["tickets"], titles, state.get("tickets_assistant", {})):
        if source:
            return Counter(source).most_common(1)[0][0]
    m = tre.search(state["branch"] or "")
    return m.group(0) if m else ""

def title_of(state):
    custom = state["custom_title"]
    if custom and JUNK_TITLE_RE.search(custom):
        custom = ""
    return custom or state["ai_title"] or state["first_prompt"][:70] or "(untitled)"

def project_of(state):
    """The repository a session belongs to: the checkout folder, also for a worktree inside it."""
    cwd = state["cwd"]
    if not cwd:
        return state["project_dir"].split("--")[0].rsplit("-", 1)[-1]
    if "/.claude/worktrees/" in cwd:
        cwd = cwd.split("/.claude/worktrees/")[0]
    if "/.worktrees/" in cwd:
        cwd = cwd.split("/.worktrees/")[0]
    parts = [p for p in cwd.split("/") if p]
    return parts[-1] if parts else "?"

def skill_of(state):
    prefix = cfg()["skill_prefix"]
    for s in state["skills"]:
        if prefix and s.startswith(prefix):
            return s[len(prefix):]
    return "" if prefix else (state["skills"][0] if state["skills"] else "")
