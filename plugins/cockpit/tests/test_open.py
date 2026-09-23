"""The command that opens a session in a terminal: resume a closed one, attach a background one,
and never lose the pane when claude exits with an error."""
import os
import subprocess
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
from cockpit import tmux  # noqa: E402

ST = {"id": "ff2bad3c-07ae-46c3-a85d-aa8caf894905", "cwd": "/tmp"}

class LaunchCommand(unittest.TestCase):
    def test_closed_session_is_resumed(self):
        self.assertEqual(tmux.launch_argv(ST, None)[1:], ["--resume", ST["id"]])

    def test_background_session_is_attached_by_job_id(self):
        live = {"kind": "bg", "jobId": "ff2bad3c", "status": "idle"}
        self.assertEqual(tmux.launch_argv(ST, live)[1:], ["attach", "ff2bad3c"])

    def test_interactive_session_without_pane_is_not_launched(self):
        self.assertIsNone(tmux.launch_argv(ST, {"kind": "interactive", "status": "idle"}))

    def test_shell_command_holds_the_pane_on_failure(self):
        cmd = tmux.shell_command(["/usr/bin/false"])
        r = subprocess.run(cmd, shell=True, stdin=subprocess.DEVNULL, capture_output=True, text=True)
        self.assertIn("press Enter to close", r.stdout)

    def test_shell_command_exits_quietly_on_success(self):
        r = subprocess.run(tmux.shell_command(["/usr/bin/true"]), shell=True, stdin=subprocess.DEVNULL, capture_output=True, text=True)
        self.assertEqual((r.returncode, r.stdout), (0, ""))

class RememberedPane(unittest.TestCase):
    """opened.json remembers the pane a session was launched in; a pane can since have been reused."""

    def test_remembered_pane_hosting_another_session_is_forgotten(self):
        live = {"other": {"tmux": "doxyme-core:@60.%271", "kind": "interactive"}}
        self.assertIsNone(tmux.remembered_target("ff2bad3c", {"target": "doxyme-core:@60.%271"}, live, lambda t: True))

    def test_remembered_pane_of_the_session_itself_is_kept(self):
        live = {"ff2bad3c": {"tmux": "doxyme-core:@60.%271", "kind": "interactive"}}
        self.assertEqual(tmux.remembered_target("ff2bad3c", {"target": "doxyme-core:@60.%271"}, live, lambda t: True), "doxyme-core:@60.%271")

    def test_remembered_pane_still_starting_is_kept(self):
        # A window this tool just opened is not registered yet; nobody else claims the pane.
        self.assertEqual(tmux.remembered_target("ff2bad3c", {"target": "s:@1.%2"}, {}, lambda t: True), "s:@1.%2")

    def test_dead_pane_is_forgotten(self):
        self.assertIsNone(tmux.remembered_target("ff2bad3c", {"target": "s:@1.%2"}, {}, lambda t: False))

    def test_recording_a_pane_evicts_other_sessions_remembered_there(self):
        opened = {"a": {"target": "s:@1.%2", "at": 1}, "b": {"target": "s:@3.%4", "at": 1}}
        tmux.remember(opened, "c", "s:@1.%2")
        self.assertEqual(set(opened), {"b", "c"})
        self.assertEqual(opened["c"]["target"], "s:@1.%2")
