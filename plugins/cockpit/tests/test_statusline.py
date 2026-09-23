"""The status line's choice of MR: the session's own links first, the checkout branch only as a fallback."""
import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
from cockpit import mrs, snooze, ui  # noqa: E402
from cockpit.index import new_state  # noqa: E402

BRANCH_MR = {"iid": 17005, "title": "docs: restructure", "url": "https://gitlab.com/g/p/-/merge_requests/17005", "state": "merged"}
OWN_MR = {"iid": 16595, "title": "retry stash writes", "url": "https://gitlab.com/g/p/-/merge_requests/16595", "state": "opened"}

class StatuslineMr(unittest.TestCase):
    def fields(self, state, own):
        with mock.patch.object(snooze, "load", return_value={}), \
             mock.patch.object(ui, "user_names", return_value={}), \
             mock.patch.object(mrs, "session_mr", return_value=own), \
             mock.patch.object(mrs, "lookup", return_value=BRANCH_MR) as lookup:
            out = ui.statusline_fields(state, "sid", "/repo", "feature-branch").split("\t")
        return out[5], out[6], lookup.called

    def test_subject_and_ticket_link_are_the_last_fields(self):
        state = new_state("sid", "-repo")
        state["custom_title"] = "PROD-11125: read-protected stash fields"
        state["tickets"] = {"PROD-11125": 1}
        state["jira_host"] = "doxyme.atlassian.net"
        with mock.patch.object(snooze, "load", return_value={}), \
             mock.patch.object(ui, "user_names", return_value={}), \
             mock.patch.object(mrs, "lookup", return_value=None):
            out = ui.statusline_fields(state, "sid", "/repo", "b").split("\t")
        self.assertEqual(out[7:], ["Read-protected stash fields", "https://doxyme.atlassian.net/browse/PROD-11125"])

    def test_session_with_links_never_shows_the_branch_mr(self):
        state = new_state("sid", "-repo")
        state["mr_urls"] = [OWN_MR["url"]]
        label, url, used_branch = self.fields(state, own=None)
        self.assertEqual((label, url), ("", ""))
        self.assertFalse(used_branch)

    def test_session_with_links_shows_its_own_once_fetched(self):
        state = new_state("sid", "-repo")
        state["mr_urls"] = [OWN_MR["url"]]
        label, url, used_branch = self.fields(state, own=OWN_MR)
        self.assertEqual((label, url), ("!16595 retry stash writes", OWN_MR["url"]))
        self.assertFalse(used_branch)

    def test_session_without_links_falls_back_to_the_branch(self):
        label, url, used_branch = self.fields(new_state("sid", "-repo"), own=None)
        self.assertEqual(url, BRANCH_MR["url"])
        self.assertTrue(label.startswith("!17005"))
        self.assertTrue(used_branch)

if __name__ == "__main__":
    unittest.main()
