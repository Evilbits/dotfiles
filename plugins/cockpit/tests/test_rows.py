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

if __name__ == "__main__":
    unittest.main()
