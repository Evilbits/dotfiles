"""Everything a person looks at: picker rows, the footer, the preview pane, the status line."""
import os
import subprocess
import sys
import textwrap
import time
from collections import Counter

from . import snooze
from .config import cfg
from .index import find, primary_ticket, project_of, skill_of, title_of

def _age(mtime):
    s = int(time.time() - mtime)
    for unit, size in (("w", 604800), ("d", 86400), ("h", 3600), ("m", 60)):
        if s >= size:
            return "%d%s" % (s // size, unit)
    return "now"

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
    out = []
    for st in sorted(states, key=key):
        l = live.get(st["id"])
        e = snoozed.get(st["id"])
        marker = "⏰" if e and snooze.is_due(e) else "z" if e else ("●" if l and l.get("status") == "busy" else "○") if l else " "
        title = title_of(st)
        if e:
            title += "  %s%s" % (snooze.text(e), (" · " + e["reason"]) if e.get("reason") else "")
        out.append("\t".join([
            st["id"], marker, fit(_age(mtimes.get(st["id"], 0)), 4), fit(project_of(st), 12),
            fit(primary_ticket(st), 10), fit(skill_of(st), 14), fit(title, 60),
            fit(" ".join("!" + m for m in st["mrs"][:2]), 14),
        ]))
    return out

def snoozed_lines(states, banner=False):
    """One line per snoozed session, soonest first. The footer form is column-aligned for fzf;
    the banner form leads with the snooze text and leaves the title unclipped."""
    snoozed = snooze.load()
    out = []
    for sid, e in sorted(snoozed.items(), key=lambda kv: kv[1].get("until") or float("inf")):
        st = find(states, sid)
        if not st:
            continue
        reason = ("  · " + e["reason"]) if e.get("reason") else ""
        if banner:
            out.append("%s  %s  %s%s" % (fit(snooze.text(e), 30), fit(primary_ticket(st), 10), title_of(st), reason))
        else:
            out.append("%s  %s  %s%s" % (fit(primary_ticket(st), 10), fit(snooze.text(e), 26), fit(title_of(st), 40), reason))
    return out

def statusline_fields(state, session_id):
    ticket = primary_ticket(state) if state else ""
    snoozed = snooze.load()
    own = snoozed.get(session_id)
    own_text = (snooze.text(own) + ((" · " + own["reason"]) if own.get("reason") else "")) if own else ""
    due = sum(1 for e in snoozed.values() if snooze.is_due(e))
    return "%s\t%s\t%d" % (ticket, own_text, due)

def preview(st, live):
    accent = "\033[1;38;5;%dm" % cfg()["colour_accent"]
    dim, rst, bold = "\033[2m", "\033[0m", "\033[1m"
    width = int(os.environ.get("FZF_PREVIEW_COLUMNS") or 80)
    wrap = lambda s: "\n".join(textwrap.wrap(s, width - 2)) if s else ""
    label = lambda k, v: print(dim + k.ljust(11) + rst + v)
    header = lambda s: print(accent + s + rst)
    print(bold + wrap(title_of(st)) + rst)
    if st["ai_title"] and st["ai_title"] != title_of(st):
        label("ai title", st["ai_title"])
    print()
    label("state", ("%s in tmux %s" % (live.get("status"), live.get("tmux"))) if live else "closed, resumable")
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

HEADER = "   age  project      ticket     skill          title                                                        MRs             ⏰due ●busy ○idle z snoozed   order: due, live, snoozed, closed   ctrl-z snoozed only  ctrl-s snooze  ctrl-u unsnooze  ctrl-y copy id"

def pick(lines, footer, me):
    args = [
        "fzf", "--reverse", "--no-sort", "--delimiter", "\t", "--with-nth", "2..", "--tabstop", "1",
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
