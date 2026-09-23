"""A pinned ticket, or a pinned absence of one, wins over what the prompts say."""
import json
import os
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
from cockpit import index  # noqa: E402

def user(text):
    return json.dumps({"type": "user", "message": {"role": "user", "content": text}, "timestamp": "2026-09-23T10:00:00Z"}, separators=(",", ":"))

class PinnedTicket(unittest.TestCase):
    def setUp(self):
        self.path = os.path.join(tempfile.mkdtemp(), "tickets.json")
        for mod in (index,):
            patcher = mock.patch.object(mod, "TICKETS", self.path)
            patcher.start()
            self.addCleanup(patcher.stop)

    def state(self):
        st = index.new_state("s1", "p")
        index.absorb_line(st, user("look at PROD-10779 please"))
        return st

    def test_prompts_decide_without_a_pin(self):
        self.assertEqual(index.primary_ticket(self.state()), "PROD-10779")

    def test_a_pinned_key_wins(self):
        index.set_ticket("s1", "PROD-11125")
        self.assertEqual(index.primary_ticket(self.state()), "PROD-11125")

    def test_pinning_none_hides_the_typed_key(self):
        index.set_ticket("s1", "")
        self.assertEqual(index.primary_ticket(self.state()), "")

    def test_a_pin_on_an_old_id_still_wins_after_the_session_continues(self):
        # The pin was written while the conversation had id "old"; a compaction then continued it
        # into "s1", and the index resolves old -> s1.
        with open(self.path, "w") as f:
            json.dump({"old": "PROD-11125"}, f)
        with mock.patch.object(index, "canonical", side_effect=lambda s: "s1" if s == "old" else s):
            self.assertEqual(index.primary_ticket(self.state()), "PROD-11125")

    def test_repinning_after_continuation_replaces_the_old_pin(self):
        with open(self.path, "w") as f:
            json.dump({"old": "PROD-11125"}, f)
        with mock.patch.object(index, "canonical", side_effect=lambda s: "s1" if s == "old" else s):
            index.set_ticket("s1", "PROD-10977")
            self.assertEqual(index.primary_ticket(self.state()), "PROD-10977")
        self.assertEqual(json.load(open(self.path)), {"s1": "PROD-10977"})

if __name__ == "__main__":
    unittest.main()
