"""Picker rows carry the ticket where fzf can match it."""
import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
from cockpit import config, index, snooze, ui  # noqa: E402

class TicketColumn(unittest.TestCase):
    def test_ticket_is_a_displayed_column_and_fzf_would_search_it(self):
        st = index.new_state("s1", "-repo")
        st["custom_title"] = "PROD-10977: Report app session to Hotpot journal"
        st["tickets_assistant"] = {"PROD-10977": 3}
        with mock.patch.object(index, "cfg", return_value=dict(config.DEFAULTS)), \
             mock.patch.object(snooze, "load", return_value={}), mock.patch.object(ui, "user_names", return_value={}), \
             mock.patch.object(index, "pinned_tickets", return_value={}):
            row = ui.rows([st], {"s1": 0}, {})[0]
        cols = row.split("\t")
        self.assertIn("PROD-10977", cols[-1])
        # --with-nth 2.. shows every column but the id, so the last one is matched.
        self.assertEqual(ui.pick.__code__.co_consts.count("2.."), 1)

    def test_search_matches_whole_terms(self):
        # Fuzzy matching let a ticket key match any row holding its characters in order, such as
        # PROD-12606 followed by an MR ending in 6, so a key search listed sessions that never
        # saw that ticket. --exact matches each typed term as a substring.
        self.assertIn("--exact", ui.pick.__code__.co_consts)

    def test_rows_stay_scrolled_to_their_subject(self):
        # A match in the ticket column, the last one, scrolled the whole row sideways and hid the
        # subject; the preview already lists every ticket, so the row keeps its start in view.
        self.assertIn("--no-hscroll", ui.pick.__code__.co_consts)

class EverythingASessionTouchedIsSearchable(unittest.TestCase):
    def row(self, st):
        with mock.patch.object(index, "cfg", return_value=dict(config.DEFAULTS)), \
             mock.patch.object(snooze, "load", return_value={}), mock.patch.object(ui, "user_names", return_value={}), \
             mock.patch.object(index, "pinned_tickets", return_value={}):
            return ui.rows([st], {"s1": 0}, {})[0]

    def test_every_ticket_typed_and_every_mr_dealt_with_is_in_the_row(self):
        # A session that worked through three tickets and opened an MR itself is found by any of them.
        st = index.new_state("s1", "-repo")
        st["tickets"] = {"PROD-11963": 1, "PROD-11964": 1, "PROD-12011": 1}
        st["tickets_assistant"] = {"PROD-11963": 9}
        st["mrs"] = ["17713"]
        st["mr_urls"] = ["https://gitlab.com/doxyme/code/doxyme-core/-/merge_requests/17889",
                         "https://gitlab.com/doxyme/cooks/claude-plugins/-/merge_requests/165"]
        row = self.row(st)
        for term in ("PROD-11963", "PROD-11964", "PROD-12011", "17713", "17889", "165"):
            self.assertIn(term, row)
        self.assertIn("PROD-11963", row.split("\t")[-1])

    def test_a_ticket_only_the_assistant_mentioned_stays_out(self):
        # Keys Claude merely mentioned would make every search hit dozens of sessions.
        st = index.new_state("s1", "-repo")
        st["tickets"] = {"PROD-1": 1}
        st["tickets_assistant"] = {"PROD-1": 5, "PROD-9608": 3}
        self.assertNotIn("PROD-9608", self.row(st))

if __name__ == "__main__":
    unittest.main()
