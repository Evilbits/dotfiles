"""The dependency-free core: durations, snooze requests and MR event detection."""
import datetime as dt
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
from cockpit import gitlab, snooze  # noqa: E402

NOW = dt.datetime(2026, 9, 22, 12, 30)  # a Tuesday

class ParseUntil(unittest.TestCase):
    def at(self, spec):
        return dt.datetime.fromtimestamp(snooze.parse_until(spec, NOW))

    def test_relative(self):
        self.assertEqual(self.at("30s"), NOW + dt.timedelta(seconds=30))
        self.assertEqual(self.at("45m"), NOW + dt.timedelta(minutes=45))
        self.assertEqual(self.at("2h"), NOW + dt.timedelta(hours=2))

    def test_days_land_at_nine(self):
        self.assertEqual(self.at("3d"), dt.datetime(2026, 9, 25, 9, 0))
        self.assertEqual(self.at("tomorrow"), dt.datetime(2026, 9, 23, 9, 0))

    def test_weekdays_exact(self):
        self.assertEqual(self.at("fri"), dt.datetime(2026, 9, 25, 9, 0))
        self.assertEqual(self.at("friday"), dt.datetime(2026, 9, 25, 9, 0))
        self.assertEqual(self.at("tue"), dt.datetime(2026, 9, 29, 9, 0))
        for word in ("monitor", "friend", "satisfy", "sunset", "thumbs", "wedge"):
            with self.assertRaises(ValueError):
                snooze.parse_until(word, NOW)

    def test_clock_time_rolls_to_tomorrow(self):
        self.assertEqual(self.at("14:30"), dt.datetime(2026, 9, 22, 14, 30))
        self.assertEqual(self.at("09:00"), dt.datetime(2026, 9, 23, 9, 0))

class ParseRequest(unittest.TestCase):
    URL = "https://gitlab.com/doxyme/code/doxyme-core/-/merge_requests/17005"

    def test_duration_and_reason(self):
        until, ref, mode, reason = snooze.parse_request(["3d", "awaiting", "review"])
        self.assertIsNotNone(until); self.assertIsNone(ref); self.assertEqual(reason, "awaiting review")

    def test_mr_review_mode_keeps_the_word_review(self):
        until, ref, mode, reason = snooze.parse_request([self.URL, "review", "round", "3"])
        self.assertIsNone(until); self.assertEqual(ref["iid"], 17005); self.assertEqual(mode, "review"); self.assertEqual(reason, "review round 3")

    def test_mr_merge_mode(self):
        _, ref, mode, reason = snooze.parse_request([self.URL, "merge", "next", "step"])
        self.assertEqual(mode, "merge"); self.assertEqual(reason, "next step")

    def test_reason_words_that_look_like_weekdays(self):
        until, ref, mode, reason = snooze.parse_request([self.URL, "monitor", "the", "deploy"])
        self.assertIsNone(until); self.assertEqual(reason, "monitor the deploy")

    def test_other_hosts_are_not_mrs(self):
        until, ref, mode, reason = snooze.parse_request(["https://example.com/g/p/-/merge_requests/1", "2h"])
        self.assertIsNone(ref)
        self.assertEqual(reason, "https://example.com/g/p/-/merge_requests/1")
        with self.assertRaises(ValueError):
            gitlab.get("example.com", "version")

    def test_both_whichever_first(self):
        until, ref, _, reason = snooze.parse_request(["fri", self.URL, "whichever", "comes", "first"])
        self.assertIsNotNone(until); self.assertEqual(ref["iid"], 17005); self.assertEqual(reason, "whichever comes first")

class Events(unittest.TestCase):
    base = {"state": "opened", "conflicts": False, "pipeline": "success", "approvers": [], "max_note": 100}

    def snap(self, **over):
        s = {"state": "opened", "conflicts": False, "pipeline": "success", "approvers": [], "max_note": 100, "others": [], "title": "t"}
        s.update(over); return s

    def test_quiet(self):
        self.assertEqual(gitlab.events({"mr_base": self.base}, self.snap()), [])

    def test_review_mode_reports_each_kind(self):
        ev = gitlab.events({"mr_base": self.base}, self.snap(others=[(101, "jane"), (102, "jane"), (99, "old")], approvers=["bob"], pipeline="failed", conflicts=True))
        self.assertEqual(ev, ["2 new comments (jane)", "approved by bob", "pipeline failed", "has conflicts"])

    def test_merge_mode_ignores_review_activity(self):
        entry = {"mr_base": self.base, "mr_mode": "merge"}
        self.assertEqual(gitlab.events(entry, self.snap(others=[(101, "jane")], approvers=["bob"])), [])
        self.assertEqual(gitlab.events(entry, self.snap(state="merged")), ["merged"])

if __name__ == "__main__":
    unittest.main()

class WokeText(unittest.TestCase):
    """The line the prompt hook puts in the chat when typing clears a snooze."""

    def test_due_on_mr_activity_names_the_event(self):
        e = {"until": None, "reason": "Waiting for this review", "due": True, "event": "2 new comments (jane.doe)",
             "mr": {"iid": 612}, "mr_mode": "review"}
        self.assertEqual(snooze.woke_text(e), "unsnoozed, it fired: !612 2 new comments (jane.doe) · Waiting for this review")

    def test_due_by_time(self):
        e = {"until": 1.0, "reason": "", "due": True, "event": "time"}
        self.assertEqual(snooze.woke_text(e), "unsnoozed, it fired: the time ran out")

    def test_pending_says_nothing_happened(self):
        e = {"until": None, "reason": "", "due": False, "mr": {"iid": 612}, "mr_mode": "review"}
        self.assertEqual(snooze.woke_text(e), "unsnoozed before it fired: no review activity on !612 yet")

    def test_pending_merge_and_time(self):
        far = dt.datetime.now() + dt.timedelta(days=30)
        e = {"until": far.timestamp(), "reason": "ship it", "due": False, "mr": {"iid": 7}, "mr_mode": "merge"}
        self.assertEqual(snooze.woke_text(e), "unsnoozed before it fired: !7 not merged yet, was set until %s · ship it" % snooze.fmt_until(e["until"]))
