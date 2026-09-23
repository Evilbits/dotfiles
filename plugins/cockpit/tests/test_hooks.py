"""Opening a snoozed session keeps its snooze; the first prompt typed into it clears it."""
import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
from cockpit import cli, snooze, wake  # noqa: E402

SID = "11111111-2222-3333-4444-555555555555"
STATE = {"id": SID, "ai_title": "Post review comments", "custom_title": "", "tickets": {"PROD-1": 1}, "branch": ""}

class SnoozeSurvivesOpen(unittest.TestCase):
    def setUp(self):
        self.saved = (snooze.SNOOZE, cli.index_sessions, cli.open_session, cli.refresh_marks, wake.log)
        snooze.SNOOZE = os.path.join(tempfile.mkdtemp(), "snooze.json")
        cli.index_sessions = lambda force=False: ([STATE], {})
        cli.open_session = lambda st, origin=None: "jumped"
        cli.refresh_marks = lambda: None
        wake.log = lambda msg: None
        snooze.put(SID, {"until": None, "reason": "waiting", "due": True, "event": "2 new comments (jane)", "mr": {"iid": 12}, "mr_mode": "review"})

    def tearDown(self):
        snooze.SNOOZE, cli.index_sessions, cli.open_session, cli.refresh_marks, wake.log = self.saved

    def test_open_leaves_the_snooze(self):
        self.assertEqual(cli.do_open(SID), "jumped")
        self.assertIn(SID, snooze.load())

    def test_prompt_hook_clears_it_and_says_why(self):
        sys.stdin = io.StringIO(json.dumps({"session_id": SID}))
        out = io.StringIO()
        with redirect_stdout(out):
            cli.main(["--prompt-hook"], "/nowhere/cockpit")
        self.assertNotIn(SID, snooze.load())
        reply = json.loads(out.getvalue())
        self.assertEqual(reply["systemMessage"], "unsnoozed, it fired: !12 2 new comments (jane) · waiting")
        self.assertIn("unsnoozed", reply["hookSpecificOutput"]["additionalContext"])

    def hook(self, payload):
        sys.stdin = io.StringIO(json.dumps(payload))
        out = io.StringIO()
        with redirect_stdout(out):
            cli.main(["--prompt-hook"], "/nowhere/cockpit")
        return out.getvalue()

    def test_housekeeping_commands_keep_the_snooze(self):
        # /exit, /clear, a re-snooze: the user is leaving or parking the session, not working on it.
        for text in ("/exit", "/clear", "/cockpit:snooze https://gitlab.com/g/p/-/merge_requests/1", "/snooze 2h", "/plugin", "/reload-plugins", "  /EXIT  "):
            self.assertEqual(self.hook({"session_id": SID, "prompt": text}), "", text)
            self.assertIn(SID, snooze.load(), text)

    def test_bare_or_odd_slash_prompts_do_not_crash_and_count_as_work(self):
        for text in ("/", "/   ", "  /  ", "//", ""):
            self.assertEqual(cli._housekeeping(text), False, repr(text))
        self.assertIn("unsnoozed", self.hook({"session_id": SID, "prompt": "/"}))
        self.assertNotIn(SID, snooze.load())

    def test_the_prompt_field_may_be_named_user_prompt(self):
        self.assertEqual(self.hook({"session_id": SID, "user_prompt": "/exit"}), "")
        self.assertIn(SID, snooze.load())

    def test_a_skill_that_is_work_clears_the_snooze(self):
        self.assertIn("unsnoozed", self.hook({"session_id": SID, "prompt": "/doxy-review https://gitlab.com/g/p/-/merge_requests/1"}))
        self.assertNotIn(SID, snooze.load())

    def test_prompt_hook_is_quiet_for_an_unsnoozed_session(self):
        sys.stdin = io.StringIO(json.dumps({"session_id": "other"}))
        out = io.StringIO()
        with redirect_stdout(out):
            cli.main(["--prompt-hook"], "/nowhere/cockpit")
        self.assertEqual(out.getvalue(), "")
