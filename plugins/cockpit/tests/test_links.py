"""Which ~/.local/bin links cockpit treats as its own, so install and the session-start heal touch only those."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
from cockpit import cli  # noqa: E402

class OwnLinks(unittest.TestCase):
    def link_to(self, target):
        link = os.path.join(tempfile.mkdtemp(), "cockpit")
        os.symlink(target, link)
        return link

    def test_plugin_cache_install_is_ours(self):
        self.assertTrue(cli._is_ours(self.link_to("/u/.claude/plugins/cache/doxyme/cockpit/0.1.2/bin/cockpit")))

    def test_checkout_install_is_ours(self):
        self.assertTrue(cli._is_ours(self.link_to("/u/dev/claude-plugins/plugins/cockpit/bin/cockpit")))

    def test_other_programs_are_not(self):
        self.assertFalse(cli._is_ours(self.link_to("/opt/homebrew/bin/cockpit")))
        self.assertFalse(cli._is_ours(self.link_to("/u/cockpit/lib/cockpit")))
        self.assertFalse(cli._is_ours(self.link_to("/u/cockpit/0.1.2/bin/cockpit-statusline")))
        self.assertFalse(cli._is_ours("/nonexistent/cockpit"))
