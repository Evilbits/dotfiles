"""Which ticket a session is filed under."""
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
from cockpit import index  # noqa: E402

def user(text):
    return json.dumps({"type": "user", "message": {"role": "user", "content": text}, "timestamp": "2026-09-23T10:00:00Z"}, separators=(",", ":"))

class PromptTickets(unittest.TestCase):
    def absorb(self, *lines):
        st = index.new_state("s1", "p")
        for l in lines:
            index.absorb_line(st, l)
        return st

    def test_a_key_the_user_typed_counts(self):
        st = self.absorb(user("look at PROD-10977 please"))
        self.assertEqual(st["tickets"], {"PROD-10977": 1})
        self.assertEqual(index.primary_ticket(st), "PROD-10977")

    def test_keys_inside_a_pasted_block_do_not_count(self):
        # A paste is someone else's text: a bug report naming PROD-11125 must not relabel the session.
        st = self.absorb(user('fix this:\n<pasted_content id="1">\nPROD-11125 · Worktree version bump, see PROD-11125\n</pasted_content id="1">\nthanks'))
        self.assertEqual(st["tickets"], {})

    def test_typed_key_still_counts_next_to_a_paste(self):
        st = self.absorb(user('this is about PROD-10977: <pasted_content id="1">PROD-11125</pasted_content id="1">'))
        self.assertEqual(st["tickets"], {"PROD-10977": 1})
