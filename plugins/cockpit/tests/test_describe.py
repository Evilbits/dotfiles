"""What a session is about: the verb from its skill, the subject without identifiers, the Jira link."""
import json
import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
from cockpit import config, index, mrs  # noqa: E402

def user(text):
    return json.dumps({"type": "user", "message": {"role": "user", "content": text}, "timestamp": "2026-09-23T10:00:00Z"}, separators=(",", ":"))

def skill(name, args):
    body = "<command-message>%s</command-message>\n<command-name>/%s</command-name>\n<command-args>%s</command-args>" % (name, name, args)
    return [user(body), json.dumps({"type": "user", "isMeta": True, "message": {"role": "user", "content": "Base directory for this skill: /x"}}, separators=(",", ":"))]

def custom(title):
    return json.dumps({"type": "custom-title", "customTitle": title}, separators=(",", ":"))

MR_URL = "https://gitlab.com/g/p/-/merge_requests/16595"

class Describe(unittest.TestCase):
    def setUp(self):
        # The machine's own ~/.config/cockpit/config.json must not leak into these assertions.
        patcher = mock.patch.object(index, "cfg", return_value=dict(config.DEFAULTS))
        patcher.start()
        self.addCleanup(patcher.stop)

    def absorb(self, *lines):
        st = index.new_state("s1", "p")
        for l in lines:
            index.absorb_line(st, l)
        return st

    def test_verb_comes_from_the_skill(self):
        st = self.absorb(*skill("doxy-review", MR_URL))
        self.assertEqual(index.verb_of(st), "Review")
        self.assertEqual(index.verb_of(self.absorb(user("hello"))), "")

    def test_review_is_named_after_its_mr_without_commit_prefix_or_key(self):
        st = self.absorb(*skill("doxy-review", MR_URL))
        with mock.patch.object(mrs, "lookup_url", return_value={"iid": 16595, "title": "feat(extensions-hotpot): PROD-10905 - retry stash writes", "url": MR_URL, "state": "opened"}):
            self.assertEqual(index.subject_of(st), "Retry stash writes")

    def test_review_falls_back_to_the_title_until_the_mr_is_fetched(self):
        st = self.absorb(*skill("doxy-review", MR_URL))
        with mock.patch.object(mrs, "lookup_url", return_value=None):
            self.assertEqual(index.subject_of(st), "!16595")

    def test_implement_drops_the_ticket_key_from_the_title(self):
        st = self.absorb(*skill("doxy-implement", "https://doxyme.atlassian.net/browse/PROD-11125"), custom("PROD-11125: read-protected stash fields"))
        self.assertEqual(index.subject_of(st), "Read-protected stash fields")

    def test_a_name_given_to_the_running_session_wins(self):
        st = self.absorb(*skill("doxy-implement", "https://doxyme.atlassian.net/browse/PROD-11125"), custom("PROD-11125"))
        self.assertEqual(index.subject_of(st, live_name="PROD-11125 read-protected stash fields"), "Read-protected stash fields")

    def test_a_repeated_verb_is_dropped(self):
        st = self.absorb(*skill("doxy-review", "https://gitlab.com/g/p/-/merge_requests/86"), custom("doxy-review !86"))
        with mock.patch.object(mrs, "lookup_url", return_value=None):
            self.assertEqual(index.subject_of(st), "!86")

    def test_ticket_url_uses_the_host_the_session_was_given(self):
        st = self.absorb(*skill("doxy-implement", "https://doxyme.atlassian.net/browse/PROD-11125"))
        self.assertEqual(index.ticket_url(st), "https://doxyme.atlassian.net/browse/PROD-11125")

    def test_no_ticket_url_without_a_host(self):
        st = self.absorb(user("look at PROD-10977 please"))
        self.assertEqual(index.ticket_url(st), "")

if __name__ == "__main__":
    unittest.main()
