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

@unittest.skipUnless(os.path.exists("/bin/zsh"), "needs zsh")
class LoginShell(unittest.TestCase):
    """A launchd job starts with a bare PATH, so the resumed claude must get the user's shell setup."""

    def run_in(self, rc):
        import tempfile
        from unittest import mock
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, ".zshrc"), "w") as f:
                f.write(rc)
            env = {"PATH": "/usr/bin:/bin", "HOME": d, "ZDOTDIR": d}
            with mock.patch.object(tmux, "login_shell", return_value="/bin/zsh"):
                cmd = tmux.shell_command(["/bin/sh", "-c", "echo $COCKPIT_RC"])
            return subprocess.run(cmd, shell=True, env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True)

    def test_shell_command_loads_the_users_shell_setup(self):
        self.assertEqual(self.run_in("export COCKPIT_RC=loaded\n").stdout.strip(), "loaded")

    def test_terminal_launch_file_loads_the_users_shell_setup_and_removes_itself(self):
        import tempfile
        from unittest import mock
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, ".zshrc"), "w") as f:
                f.write("export COCKPIT_RC=loaded\n")
            env = {"PATH": "/usr/bin:/bin", "HOME": d, "ZDOTDIR": d}
            with mock.patch.object(tmux, "login_shell", return_value="/bin/zsh"), mock.patch.object(tmux, "STATE_DIR", d):
                path = tmux.terminal_launch_file(tmux.shell_command(["/bin/sh", "-c", "echo $COCKPIT_RC"]), "/tmp")
            r = subprocess.run(["/bin/sh", path], env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True)
            self.assertEqual((r.stdout.strip(), os.path.exists(path)), ("loaded", False))

FAKE_FISH = """#!/usr/bin/env python3
import os, shlex, sys
words = shlex.split(sys.argv[-1])
if "||" in words or "{" in words:
    sys.exit("fake-fish: cannot parse POSIX syntax")
if words[0] == "exec":
    os.execv(words[1], words[1:])
"""

class NonPosixLoginShell(unittest.TestCase):
    """A fish or csh login shell must still resume: it loads the environment, /bin/sh runs the command."""

    def run_with(self, argv):
        import tempfile
        from unittest import mock
        with tempfile.TemporaryDirectory() as d:
            shell = os.path.join(d, "fish")
            with open(shell, "w") as f:
                f.write(FAKE_FISH)
            os.chmod(shell, 0o755)
            with mock.patch.object(tmux, "login_shell", return_value=shell):
                cmd = tmux.shell_command(argv)
            return subprocess.run(cmd, shell=True, stdin=subprocess.DEVNULL, capture_output=True, text=True)

    def test_resume_runs_under_a_non_posix_login_shell(self):
        r = self.run_with(["/bin/echo", "resumed"])
        self.assertEqual((r.returncode, r.stdout.strip()), (0, "resumed"))

    def test_pane_still_holds_on_failure_under_a_non_posix_login_shell(self):
        self.assertIn("press Enter to close", self.run_with(["/usr/bin/false"]).stdout)

class TerminalAppReopen(unittest.TestCase):
    """Without tmux or a terminal of its own, cockpit opens a Terminal or iTerm window."""

    def test_terminal_app_gets_the_login_shell_command(self):
        from unittest import mock
        with mock.patch.object(tmux, "live_sessions", return_value={}), mock.patch.object(tmux, "available", return_value=False), \
                mock.patch.object(tmux.sys.stdin, "isatty", return_value=False), mock.patch.object(tmux, "open_in_terminal_app") as opened:
            tmux.open_session(ST)
        argv = tmux.launch_argv(ST, None)
        opened.assert_called_once_with(tmux.shell_command(argv), "/tmp")

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
