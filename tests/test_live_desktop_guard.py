import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parent / 'live'))
from fullscreen_guard import require_idle_desktop


class LiveDesktopGuardTests(unittest.TestCase):
    def test_observed_named_gaming_workspace_blocks_other_monitor_tests(self):
        game = {'class': 'steam_app_1343400', 'workspace': {'name': 'gaming'},
                'monitor': 1, 'fullscreen': 2, 'fullscreenClient': 2, 'mapped': True}
        with self.assertRaisesRegex(SystemExit, 'before creating windows'):
            require_idle_desktop([game, {'monitor': 0, 'fullscreen': 0}])

    def test_client_fullscreen_is_protected_after_compositor_demotion(self):
        with self.assertRaises(SystemExit):
            require_idle_desktop([{'fullscreen': 0, 'fullscreenClient': 2}])

    def test_non_game_fullscreen_and_combined_fullscreen_are_protected(self):
        for state in (2, 3):
            with self.subTest(state=state), self.assertRaises(SystemExit):
                require_idle_desktop([{'class': 'browser', 'monitor': 0, 'fullscreen': state}])

    def test_normal_and_maximized_clients_do_not_block(self):
        require_idle_desktop([{'fullscreen': 0}, {'fullscreen': 1}, {'fullscreen': 2, 'mapped': False}])
        require_idle_desktop([])

    def test_unreadable_compositor_fails_closed(self):
        with patch('fullscreen_guard.subprocess.check_output', side_effect=OSError):
            with self.assertRaisesRegex(SystemExit, 'Cannot verify'):
                require_idle_desktop()
        for malformed in ('{}', 'null', '[null]'):
            with patch('fullscreen_guard.subprocess.check_output', return_value=malformed):
                with self.assertRaises(SystemExit):
                    require_idle_desktop()

    def test_probe_only_reads_clients(self):
        with patch('fullscreen_guard.subprocess.check_output', return_value=json.dumps([])) as read:
            require_idle_desktop()
            self.assertEqual(read.call_args.args[0], ['hyprctl', '-j', 'clients'])


if __name__ == '__main__':
    unittest.main()
