"""Live sessions from Claude's process registry."""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
from cockpit import registry  # noqa: E402

def entry(sid, kind, tmux=None, status="idle"):
    d = {"pid": os.getpid(), "sessionId": sid, "kind": kind, "status": status}
    if tmux:
        d["tmux"] = tmux
    return d

class LiveSessions(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.saved = registry.REGISTRY
        registry.REGISTRY = self.dir

    def tearDown(self):
        registry.REGISTRY = self.saved

    def write(self, name, d):
        with open(os.path.join(self.dir, name), "w") as f:
            json.dump(d, f)

    def test_a_background_session_alone_is_live_and_marked(self):
        # claude --bg (or a conversation continued into a background job) has no pane to jump to;
        # it is still running, so opening it must attach, never resume.
        self.write("1.json", dict(entry("s1", "bg"), jobId="s1"))
        live = registry.live_sessions()
        self.assertEqual(live["s1"]["kind"], "bg")
        self.assertEqual(live["s1"]["jobId"], "s1")

    def test_interactive_process_wins_over_the_background_one_and_stays_busy(self):
        self.write("1.json", entry("s1", "bg", status="busy"))
        self.write("2.json", entry("s1", "interactive", tmux="repo:@1.%2", status="idle"))
        live = registry.live_sessions()
        self.assertEqual(list(live), ["s1"])
        self.assertEqual(live["s1"]["tmux"], "repo:@1.%2")
        self.assertEqual(live["s1"]["status"], "busy")

    def test_interactive_without_tmux_is_live(self):
        self.write("1.json", entry("s1", "interactive"))
        self.assertIn("s1", registry.live_sessions())
