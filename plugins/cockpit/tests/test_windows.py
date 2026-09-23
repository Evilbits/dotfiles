"""tmux window names for sessions, and the pane a background session is attached in."""
import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
from cockpit import config, index, registry, tmux  # noqa: E402
from tests.test_registry import LiveSessions, entry  # noqa: E402

class WindowName(unittest.TestCase):
    def setUp(self):
        patcher = mock.patch.object(index, "cfg", return_value=dict(config.DEFAULTS))
        patcher.start()
        self.addCleanup(patcher.stop)

    def state(self, title):
        st = index.new_state("ff2bad3c-07ae-46c3-a85d-aa8caf894905", "p")
        st["custom_title"] = title
        return st

    def test_window_is_named_after_the_subject(self):
        self.assertEqual(tmux.window_name(self.state("PROD-11125: read-protected stash fields")), "Read-protected stash fields")

    def test_a_rename_of_the_running_session_wins(self):
        self.assertEqual(tmux.window_name(self.state("PROD-11125"), "Review token refresh"), "Review token refresh")

    def test_long_names_are_clipped_for_the_status_bar(self):
        name = tmux.window_name(self.state("A very long session title that would crowd out every other window"))
        self.assertEqual(len(name), tmux.WINDOW_NAME_MAX)
        self.assertTrue(name.endswith("…"))

class AttachedBackground(LiveSessions):
    def test_background_session_shown_in_a_pane_is_live_there(self):
        self.write("1.json", dict(entry("s1", "bg"), jobId="s1"))
        with mock.patch.object(registry, "attached_panes", return_value={"s1": "repo:@4.%9"}):
            live = registry.live_sessions()
        self.assertEqual(live["s1"]["tmux"], "repo:@4.%9")
        self.assertEqual(live["s1"]["kind"], "bg")

    def test_background_session_without_a_pane_stays_paneless(self):
        self.write("1.json", dict(entry("s1", "bg"), jobId="s1"))
        with mock.patch.object(registry, "attached_panes", return_value={}):
            self.assertIsNone(registry.live_sessions()["s1"].get("tmux"))

if __name__ == "__main__":
    unittest.main()
