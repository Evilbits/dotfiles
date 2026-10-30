"""The status line's choice of MR: the checkout branch's open MR, then the session's own links, then the branch's closed MR as a fallback."""
import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
from cockpit import mrs, snooze, ui  # noqa: E402
from cockpit.index import new_state  # noqa: E402

BRANCH_MR = {"iid": 17005, "title": "docs: restructure", "url": "https://gitlab.com/g/p/-/merge_requests/17005", "state": "merged"}
OWN_MR = {"iid": 16595, "title": "retry stash writes", "url": "https://gitlab.com/g/p/-/merge_requests/16595", "state": "opened"}
OLDER_MR = {"iid": 89, "title": "never show the branch MR", "url": "https://gitlab.com/g/p/-/merge_requests/89", "state": "merged"}
OPEN_BRANCH_MR = {"iid": 18222, "title": "mint names a Visit", "url": "https://gitlab.com/g/p/-/merge_requests/18222", "state": "opened"}

class StatuslineMr(unittest.TestCase):
    def fields(self, state, own, branch=BRANCH_MR):
        owns = own if isinstance(own, list) else ([own] if own else [])
        with mock.patch.object(snooze, "load", return_value={}), \
             mock.patch.object(ui, "user_names", return_value={}), \
             mock.patch.object(mrs, "session_mrs", return_value=owns), \
             mock.patch.object(mrs, "lookup", return_value=branch) as lookup:
            out = ui.statusline_fields(state, "sid", "/repo", "feature-branch").split("\t")
        return out[5], out[6], lookup.called

    def test_the_branchs_open_mr_comes_before_the_sessions_links(self):
        # The open MR of the checked-out branch is the one the session pushes to; a link to it
        # may never appear in the transcript, or an older own MR's link may be the newest one.
        state = new_state("sid", "-repo")
        state["mr_urls"] = [OLDER_MR["url"]]
        label, url, _ = self.fields(state, own=OLDER_MR, branch=OPEN_BRANCH_MR)
        self.assertEqual(label.split("\x1f"), ["!18222 mint names a Visit", "!89 · merged"])
        self.assertEqual(url.split("\x1f"), [OPEN_BRANCH_MR["url"], OLDER_MR["url"]])

    def test_the_branchs_open_mr_is_listed_once(self):
        state = new_state("sid", "-repo")
        state["mr_urls"] = [OPEN_BRANCH_MR["url"], OLDER_MR["url"]]
        _, url, _ = self.fields(state, own=[OLDER_MR, OPEN_BRANCH_MR], branch=OPEN_BRANCH_MR)
        self.assertEqual(url.split("\x1f"), [OPEN_BRANCH_MR["url"], OLDER_MR["url"]])

    def test_every_own_mr_is_listed_newest_first_with_the_title_on_the_newest(self):
        state = new_state("sid", "-repo")
        state["mr_urls"] = [OLDER_MR["url"], OWN_MR["url"]]
        with mock.patch.object(snooze, "load", return_value={}), \
             mock.patch.object(ui, "user_names", return_value={}), \
             mock.patch.object(mrs, "session_mrs", return_value=[OWN_MR, OLDER_MR]):
            out = ui.statusline_fields(state, "sid", "/repo", "b").split("\t")
        self.assertEqual(out[5].split("\x1f"), ["!16595 retry stash writes", "!89 · merged"])
        self.assertEqual(out[6].split("\x1f"), [OWN_MR["url"], OLDER_MR["url"]])

    def test_session_mrs_prefers_the_authors_own_newest_first(self):
        state = new_state("sid", "-repo")
        state["mr_urls"] = [OLDER_MR["url"], BRANCH_MR["url"], OWN_MR["url"]]
        by_url = {m["url"]: dict(m, author="me" if m is not BRANCH_MR else "other") for m in (OLDER_MR, BRANCH_MR, OWN_MR)}
        with mock.patch.object(mrs, "lookup_url", side_effect=lambda u: by_url[u]), \
             mock.patch("cockpit.gitlab.me", return_value="me"):
            found = mrs.session_mrs(state)
        self.assertEqual([m["iid"] for m in found], [16595, 89])

    def test_mrs_the_session_created_come_first(self):
        # Created MRs are known from pr-link records even when no link to them is left in mr_urls.
        state = new_state("sid", "-repo")
        state["mr_urls"] = [OWN_MR["url"]]
        state["created_mrs"] = [OLDER_MR["url"]]
        by_url = {m["url"]: dict(m, author="me") for m in (OLDER_MR, OWN_MR)}
        with mock.patch.object(mrs, "lookup_url", side_effect=lambda u: by_url[u]), \
             mock.patch("cockpit.gitlab.me", return_value="me"):
            self.assertEqual([m["iid"] for m in mrs.session_mrs(state)], [89, 16595])

    def found(self, state, authors):
        by_url = {m["url"]: dict(m, author=authors[m["iid"]]) for m in (OLDER_MR, BRANCH_MR, OWN_MR)}
        with mock.patch.object(mrs, "lookup_url", side_effect=lambda u: by_url[u]), \
             mock.patch("cockpit.gitlab.me", return_value="me"):
            return [m["iid"] for m in mrs.session_mrs(state)]

    def test_an_mr_only_claude_mentioned_is_never_shown(self):
        # Claude cites someone else's MR while working; the status line must not call it the session's MR.
        state = new_state("sid", "-repo")
        state["mr_urls"] = [BRANCH_MR["url"]]
        self.assertEqual(self.found(state, {17005: "other", 16595: "me", 89: "me"}), [])

    def test_someone_elses_mr_the_user_pasted_is_shown(self):
        # A review session: the user pasted the MR under review.
        state = new_state("sid", "-repo")
        state["mr_urls"] = [OLDER_MR["url"], BRANCH_MR["url"]]
        state["mr_urls_pasted"] = [BRANCH_MR["url"]]
        self.assertEqual(self.found(state, {17005: "other", 16595: "me", 89: "other"}), [17005])

    def test_the_same_number_in_another_project_is_not_the_pasted_mr(self):
        # IIDs are per project: the user pasted project a's !17005, Claude mentioned project b's.
        state = new_state("sid", "-repo")
        other = dict(BRANCH_MR, url="https://gitlab.com/g/other/-/merge_requests/17005")
        state["mr_urls"] = [other["url"]]
        state["mr_urls_pasted"] = [BRANCH_MR["url"]]
        with mock.patch.object(mrs, "lookup_url", return_value=dict(other, author="other")), \
             mock.patch("cockpit.gitlab.me", return_value="me"):
            self.assertEqual(mrs.session_mrs(state), [])

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
        label, url, _ = self.fields(state, own=None)
        # The branch's MR here is merged, so it may be an earlier piece of work on a reused branch.
        self.assertEqual((label, url), ("", ""))

    def test_session_with_links_shows_its_own_once_fetched(self):
        state = new_state("sid", "-repo")
        state["mr_urls"] = [OWN_MR["url"]]
        label, url, _ = self.fields(state, own=OWN_MR)
        self.assertEqual((label, url), ("!16595 retry stash writes", OWN_MR["url"]))

    def test_session_without_links_falls_back_to_the_branch(self):
        label, url, used_branch = self.fields(new_state("sid", "-repo"), own=None)
        self.assertEqual(url, BRANCH_MR["url"])
        self.assertTrue(label.startswith("!17005"))
        self.assertTrue(used_branch)

if __name__ == "__main__":
    unittest.main()
