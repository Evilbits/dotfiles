"""Everything a person looks at: picker rows, the footer, the preview pane, the status line."""
import os
import subprocess
import sys
import textwrap
import time
from collections import Counter

from . import snooze
from .config import cfg
from .index import find, primary_ticket, project_of, subject_of, ticket_url, title_of, verb_of
from .registry import user_names

def _age(mtime):
    s = int(time.time() - mtime)
    for unit, size in (("w", 604800), ("d", 86400), ("h", 3600), ("m", 60)):
        if s >= size:
            return "%d%s" % (s // size, unit)
    return "now"

def _when(ts):
    """An ISO timestamp from a transcript as 'in 3d 2h' style age plus the local date and time."""
    from datetime import datetime, timezone
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone()
    except ValueError:
        return ts
    age = _age(dt.timestamp())
    return "%s (%s)" % ("just now" if age == "now" else age + " ago", dt.strftime("%a %d %b %H:%M"))

def fit(s, n):
    s = s or ""
    return (s[: n - 1] + "…") if len(s) > n else s.ljust(n)

def rows(states, mtimes, live, only_snoozed=False):
    snoozed = snooze.load()
    if only_snoozed:
        states = [s for s in states if s["id"] in snoozed]
    def group(s):
        e = snoozed.get(s["id"])
        if e and snooze.is_due(e):
            return 0
        if e:
            return 2
        return 1 if s["id"] in live else 3
    def key(s):
        g = group(s)
        return (g, (snoozed[s["id"]].get("until") or float("inf")) if g == 2 else -mtimes.get(s["id"], 0))
    names = user_names()
    out = []
    for st in sorted(states, key=key):
        l = live.get(st["id"])
        e = snoozed.get(st["id"])
        marker = "⏰" if e and snooze.is_due(e) else "z" if e else ("●" if l and l.get("status") == "busy" else "○") if l else " "
        # The ticket is the last column: hidden by --with-nth, still matched when typed into the filter.
        out.append("\t".join([
            st["id"], marker, fit(_age(mtimes.get(st["id"], 0)), 4), fit(project_of(st), 12),
            fit(verb_of(st), 9), fit(subject_of(st, names.get(st["id"], "")), 60),
            " ".join("!" + m for m in st["mrs"][:2]), primary_ticket(st),
        ]))
    return out

def snoozed_lines(states, banner=False):
    """One line per snoozed session, soonest first. The footer form is column-aligned for fzf;
    the banner form leads with the snooze text and leaves the title unclipped."""
    snoozed = snooze.load()
    rows_ = []
    for sid, e in sorted(snoozed.items(), key=lambda kv: kv[1].get("until") or float("inf")):
        st = find(states, sid)
        if st:
            rows_.append((snooze.text(e), primary_ticket(st), title_of(st), ("  · " + e["reason"]) if e.get("reason") else ""))
    if not rows_:
        return []
    # Columns sized to what is present, so a short list is not padded for the longest possible text.
    w_snooze = max(len(r[0]) for r in rows_)
    w_ticket = max([len(r[1]) for r in rows_] + [1])
    out = []
    for text, ticket, title, reason in rows_:
        if banner:
            out.append("%s  %s  %s%s" % (fit(text, w_snooze), fit(ticket, w_ticket), title, reason))
        else:
            out.append("%s  %s  %s%s" % (fit(ticket, w_ticket), fit(text, min(w_snooze, 26)), fit(title, 40), reason))
    return out

def statusline_fields(state, session_id, repo_dir="", branch=""):
    """ticket, own snooze, due count, accent colour, branch colour, MR labels, MR urls, subject, ticket url.
    The MR fields hold up to three MRs newest first, joined with \x1f, so the newest stays on screen
    when the bar runs out of room; only the newest carries its title."""
    from . import mrs
    ticket = primary_ticket(state) if state else ""
    subject = subject_of(state, user_names().get(state["id"], "")) if state else ""
    link = ticket_url(state) if state else ""
    snoozed = snooze.load()
    own = snoozed.get(session_id)
    own_text = (snooze.text(own, absolute=True) + ((" · " + own["reason"]) if own.get("reason") else "")) if own else ""
    due = sum(1 for e in snoozed.values() if snooze.is_due(e))
    # A session that has dealt with MR links shows one of those, or nothing until they are fetched;
    # the checkout's branch MR is only a guess for sessions that never named one.
    if state and state.get("mr_urls"):
        found = mrs.session_mrs(state)[:3]
    else:
        mr = mrs.lookup(repo_dir, branch) if repo_dir and branch else None
        found = [mr] if mr else []
    labels = []
    for i, mr in enumerate(found):
        label = ("!%d %s" % (mr["iid"], mr["title"])) if i == 0 else "!%d" % mr["iid"]
        if len(label) > 30:
            label = label[:29] + "…"
        if mr.get("state") != "opened":
            label += " · " + mr["state"]
        labels.append(label)
    return "%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s" % (ticket, own_text, due, cfg()["colour_accent"], cfg()["colour_branch"],
                                                    "\x1f".join(labels), "\x1f".join(m["url"] for m in found), subject, link)

def preview(st, live):
    accent = "\033[1;38;5;%dm" % cfg()["colour_accent"]
    dim, rst, bold = "\033[2m", "\033[0m", "\033[1m"
    width = int(os.environ.get("FZF_PREVIEW_COLUMNS") or 80)
    wrap = lambda s: "\n".join(textwrap.wrap(s, width - 2)) if s else ""
    label = lambda k, v: print(dim + k.ljust(12) + rst + v)
    header = lambda s: print(accent + s + rst)
    verb, subject = verb_of(st), subject_of(st, user_names().get(st["id"], ""))
    print(bold + wrap(((verb + " · ") if verb else "") + subject) + rst)
    if title_of(st) not in (subject, ((verb + " ") if verb else "") + subject):
        label("title", title_of(st))
    if st["ai_title"] and st["ai_title"] != title_of(st):
        label("ai title", st["ai_title"])
    print()
    if live:
        where = (" in tmux " + live["tmux"]) if live.get("tmux") else (", running in the background (Enter attaches)" if live.get("kind") == "bg" else ", not in tmux")
        label("state", "%s%s" % (live.get("status"), where))
    else:
        label("state", "closed, resumable")
    if st["first_ts"]:
        label("started", _when(st["first_ts"]))
    if st["last_ts"]:
        label("last prompt", _when(st["last_ts"]))
    e = snooze.load().get(st["id"])
    if e:
        print()
        header("⏰ due" if snooze.is_due(e) else "⏾ snoozed")
        if snooze.is_due(e) and e.get("event"):
            label("fired", e["event"])
        if e.get("until") is not None:
            label("until", "%s (in %s)" % (snooze.fmt_until(e["until"]), snooze.remaining(e["until"])))
        if e.get("mr"):
            label("waiting on", "!%d %s" % (e["mr"]["iid"], e.get("mr_title", "")))
            label("", e["mr"]["url"])
            label("wakes on", snooze.triggers(e))
        if e.get("reason"):
            label("reason", e["reason"])
    if st["tickets"]:
        label("tickets", ", ".join(k for k, _ in Counter(st["tickets"]).most_common(6)))
    if st["mrs"]:
        label("MRs", ", ".join("!" + m for m in st["mrs"][:12]))
    if st["skills"]:
        label("skills", ", ".join(st["skills"]))
    if st["branch"]:
        label("branch", st["branch"])
    print()
    header("first prompt")
    print(wrap(st["first_prompt"]))
    print()
    header("recent prompts (newest on top)")
    for p in reversed(st["prompts"][-6:]):
        print(wrap("- " + p))
        print()

HEADER = "   age  project      kind      subject                                                      MRs          ⏰due ●busy ○idle z snoozed   ctrl-z snoozed only  ctrl-s snooze  ctrl-u unsnooze  ctrl-y copy id"

def pick(lines, footer, me):
    args = [
        "fzf", "--reverse", "--no-sort", "--delimiter", "\t", "--with-nth", "2..7", "--tabstop", "1",
        "--header", HEADER, "--header-first",
        "--preview", "'%s' --preview {1}" % me, "--preview-window", "right,50%,wrap",
        "--bind", "ctrl-y:execute-silent(printf %s {1} | pbcopy)",
        "--bind", "ctrl-r:reload('%s' --list)" % me,
        "--bind", "end:last,home:first",
        "--bind", "ctrl-z:transform:[ \"$FZF_PROMPT\" = 'snoozed> ' ] && echo 'change-prompt(> )+reload(\"%s\" --list)' || echo 'change-prompt(snoozed> )+reload(\"%s\" --list --snoozed)'" % (me, me),
        "--bind", "ctrl-s:execute('%s' --snooze-prompt {1})+reload('%s' --list)" % (me, me),
        "--bind", "ctrl-u:execute-silent('%s' --unsnooze {1})+reload('%s' --list)" % (me, me),
    ]
    if footer:
        args += ["--footer", footer, "--footer-border", "top", "--footer-label", " snoozed "]
    r = subprocess.run(args, input="\n".join(lines), capture_output=True, text=True)
    choice = r.stdout.strip()
    return choice.split("\t")[0] if r.returncode == 0 and choice else None
