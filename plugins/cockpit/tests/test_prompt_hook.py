"""The prompt hook refreshes tmux window names on every prompt, snoozed or not."""
import io
import json
import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
from cockpit import cli, snooze  # noqa: E402

class PromptHook(unittest.TestCase):
    def run_hook(self, snoozed):
        payload = json.dumps({"session_id": "s1", "prompt": "carry on"})
        with mock.patch.object(sys, "stdin", io.StringIO(payload)), \
             mock.patch.object(snooze, "load", return_value=snoozed), mock.patch.object(snooze, "remove"), \
             mock.patch.object(cli, "canonical", side_effect=lambda s: s), \
             mock.patch.object(cli, "refresh_marks") as refresh, mock.patch.object(cli.wake, "log"), \
             mock.patch.object(sys, "stdout", io.StringIO()):
            cli.main(["--prompt-hook"], "/x/bin/cockpit")
        return refresh.call_count

    def test_an_ordinary_prompt_refreshes_the_window_names(self):
        self.assertEqual(self.run_hook({}), 1)

    def test_clearing_a_snooze_refreshes_them_once(self):
        self.assertEqual(self.run_hook({"s1": {"until": None}}), 1)

if __name__ == "__main__":
    unittest.main()
