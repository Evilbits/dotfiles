"""tmux window names follow the sessions they host."""
import os
import subprocess
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
from cockpit import config, index, tmux  # noqa: E402

def state(sid, title):
    st = index.new_state(sid, "p")
    st["custom_title"] = title
    return st

class FakeTmux:
    """Answers display-message from a table of window names and records rename-window calls."""
    def __init__(self, windows):
        self.windows, self.renames = windows, []
    def __call__(self, *args):
        if args[0] == "display-message":
            window = args[args.index("-t") + 1]
            if window not in self.windows:
                return subprocess.CompletedProcess(args, 1, "", "")
            return subprocess.CompletedProcess(args, 0, self.windows[window] + "\t0\n", "")
        if args[0] == "rename-window":
            self.renames.append((args[2], args[3]))
        return subprocess.CompletedProcess(args, 0, "", "")

class WindowNames(unittest.TestCase):
    def run_marks(self, cfg_overrides, snoozed, windows):
        cfg = dict(config.DEFAULTS, **cfg_overrides)
        fake = FakeTmux(windows)
        states = [state("s1", "PROD-1: Fix the thing"), state("s2", "PROD-2: Review the other")]
        live = {"s1": {"tmux": "repo:@1.%1"}, "s2": {"tmux": "repo:@2.%2"}}
        with mock.patch.object(tmux, "cfg", return_value=cfg), mock.patch.object(index, "cfg", return_value=cfg), \
             mock.patch.object(tmux, "available", return_value=True), mock.patch.object(tmux, "tmux", fake), \
             mock.patch.object(tmux, "user_names", return_value={}), \
             mock.patch.object(tmux, "load_json", return_value={}), mock.patch.object(tmux, "save_json"):
            tmux.mark_windows(states, snoozed, live)
        return fake.renames

    def test_every_session_window_is_named_after_its_subject(self):
        renames = self.run_marks({}, {}, {"repo:@1": "PROD-1", "repo:@2": "zsh"})
        self.assertEqual(sorted(renames), [("repo:@1", "Fix the thing"), ("repo:@2", "Review the other")])

    def test_snoozed_window_carries_the_mark_in_front_of_the_subject(self):
        renames = self.run_marks({}, {"s2": {"until": None}}, {"repo:@1": "Fix the thing", "repo:@2": "Review the other"})
        self.assertEqual(renames, [("repo:@2", "⏾ Review the other")])

    def test_names_off_touches_only_snoozed_windows(self):
        renames = self.run_marks({"tmux_window_names": False}, {"s2": {"until": None}}, {"repo:@1": "PROD-1", "repo:@2": "PROD-2"})
        self.assertEqual(renames, [("repo:@2", "⏾ Review the other")])

    def test_unchanged_names_are_left_alone(self):
        self.assertEqual(self.run_marks({}, {}, {"repo:@1": "Fix the thing", "repo:@2": "Review the other"}), [])

if __name__ == "__main__":
    unittest.main()
