"""Cache files written by several processes at once: every session's status line and the minute job."""
import json
import multiprocessing
import os
import sys
import tempfile
import time
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
from cockpit import mrs, snooze  # noqa: E402

RENDERED = "https://gitlab.com/g/p/-/merge_requests/1"
FETCHED = "https://gitlab.com/g/p/-/merge_requests/2"
FETCHED_MR = {"iid": 2, "title": "fetched", "url": FETCHED, "state": "opened", "author": "me"}

def render_status_lines(path, rounds):
    # A status line records interest in the MR it shows on every render.
    mrs.MRS = path
    for _ in range(rounds):
        mrs.lookup_url(RENDERED)

def run_wake_once(path, delay):
    # The minute job fetches the MRs asked about; the fetch itself takes a while.
    mrs.MRS = path
    def slow_fetch(project, iid):
        time.sleep(0.05)
        return dict(FETCHED_MR, iid=iid, url="https://gitlab.com/%s/-/merge_requests/%d" % (project, iid))
    mrs.fetch_iid = slow_fetch
    time.sleep(delay)
    mrs.refresh_wanted(lambda *_: None)

def snooze_many(path, prefix, count):
    snooze.SNOOZE = path
    for i in range(count):
        snooze.put("%s-%d" % (prefix, i), {"until": time.time() + 60})

class SharedSnoozeStore(unittest.TestCase):
    def test_snoozes_written_at_once_all_survive(self):
        # Sessions snooze, the wake marks entries due and a typed prompt unsnoozes, all at once.
        ctx = multiprocessing.get_context("fork")
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "snoozed.json")
            procs = [ctx.Process(target=snooze_many, args=(path, "s%d" % n, 60)) for n in range(4)]
            for p in procs:
                p.start()
            for p in procs:
                p.join()
            with open(path) as f:
                self.assertEqual(len(json.load(f)), 240)

class SharedMrCache(unittest.TestCase):
    def test_a_fetched_mr_survives_status_lines_rendering_meanwhile(self):
        # The wake fetched !2 while sessions kept rendering; a render that loaded the file before the
        # wake saved must not write back a copy without !2, or the status line skips it.
        ctx = multiprocessing.get_context("fork")
        for attempt in range(5):
            with tempfile.TemporaryDirectory() as d:
                path = os.path.join(d, "mrs.json")
                with open(path, "w") as f:
                    json.dump({"g/p!2": {"project": "g/p", "iid": 2, "checked": 0, "wanted": time.time()}}, f)
                renders = [ctx.Process(target=render_status_lines, args=(path, 400)) for _ in range(3)]
                wake = ctx.Process(target=run_wake_once, args=(path, 0.02))
                for p in renders + [wake]:
                    p.start()
                for p in renders + [wake]:
                    p.join()
                with open(path) as f:
                    data = json.load(f)
                self.assertEqual((data.get("g/p!2") or {}).get("mr", {}).get("iid"), 2, "attempt %d lost the fetched MR" % attempt)
                self.assertIn("g/p!1", data, "attempt %d lost a render's interest" % attempt)

if __name__ == "__main__":
    unittest.main()
