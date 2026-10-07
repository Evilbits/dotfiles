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

def skill_call(name, sidechain=False):
    rec = {"type": "assistant", "message": {"role": "assistant", "content": [{"type": "tool_use", "id": "t1", "name": "Skill", "input": {"skill": name}}]}}
    if sidechain:
        rec["isSidechain"] = True
    return json.dumps(rec, separators=(",", ":"))

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

    def test_verb_follows_the_latest_skill(self):
        st = self.absorb(*skill("doxy-implement", "PROD-1"), *skill("doxy-review", MR_URL))
        self.assertEqual(index.verb_of(st), "Review")
        st = self.absorb(*skill("doxy-implement", "PROD-1"), *skill("doxy-review", MR_URL), *skill("doxy-implement", "PROD-1"))
        self.assertEqual(index.verb_of(st), "Implement")

    def test_a_skill_without_a_verb_keeps_the_last_one(self):
        st = self.absorb(*skill("doxy-implement", "PROD-1"), *skill("grilling", "x"))
        self.assertEqual(index.verb_of(st), "Implement")

    def test_a_plugin_skill_counts_as_its_standalone_name(self):
        st = self.absorb(*skill("doxy:implement", "PROD-1"), *skill("doxy:blitz-test", "PROD-1"))
        self.assertEqual(index.verb_of(st), "Test")

    def test_the_company_doxy_apps_plugin_names_its_verb(self):
        st = self.absorb(*skill("doxy-apps:implement", "PROD-1"), *skill("doxy-apps:review", MR_URL))
        self.assertEqual(index.verb_of(st), "Review")
        self.assertEqual(index.verb_of(self.absorb(*skill("doxy-apps:vibe-app", "PROD-1"))), "App")

    def test_a_skill_claude_starts_itself_counts(self):
        st = self.absorb(*skill("doxy:implement", "PROD-1"), skill_call("doxy:review"))
        self.assertEqual(index.verb_of(st), "Review")

    def test_a_subagent_skill_does_not_count(self):
        st = self.absorb(*skill("doxy:implement", "PROD-1"), skill_call("doxy:review", sidechain=True))
        self.assertEqual(index.verb_of(st), "Implement")

    def test_configured_verbs_add_to_the_defaults(self):
        import tempfile
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
            json.dump({"skill_verbs": {"doxy-review": "Look"}}, f)
        self.addCleanup(os.unlink, f.name)
        with mock.patch.object(config, "CONFIG", f.name), mock.patch.object(config, "_cfg", None):
            verbs = config.cfg()["skill_verbs"]
        self.assertEqual(verbs["doxy-review"], "Look")
        self.assertEqual(verbs["doxy-blitz-test"], "Test")

    def test_review_is_named_after_its_mr_without_commit_prefix_or_key(self):
        st = self.absorb(*skill("doxy-review", MR_URL))
        with mock.patch.object(mrs, "lookup_url", return_value={"iid": 16595, "title": "feat(extensions-hotpot): PROD-10905 - retry stash writes", "url": MR_URL, "state": "opened"}):
            self.assertEqual(index.subject_of(st), "Retry stash writes")

    def test_a_session_that_reviews_along_the_way_keeps_its_own_title(self):
        st = self.absorb(*skill("doxy-design", "an idea"), custom("Optimize Claude workflow"), *skill("doxy:review", MR_URL))
        with mock.patch.object(mrs, "lookup_url", return_value={"iid": 16595, "title": "feat(extensions-hotpot): PROD-10905 - retry stash writes", "url": MR_URL, "state": "opened"}):
            self.assertEqual(index.verb_of(st), "Review")
            self.assertEqual(index.subject_of(st), "Optimize Claude workflow")

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
