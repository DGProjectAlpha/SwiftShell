#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'shell/helpers'))
import terminallaunch as launcher


class TerminalLaunchTests(unittest.TestCase):
    def test_cachy_update_is_wrapped_in_available_terminal(self):
        with patch.object(launcher, 'preferences', return_value={'roles': {}}), \
                patch.object(launcher.shutil, 'which', side_effect=lambda name: '/usr/bin/konsole' if name == 'konsole' else None), \
                patch.object(launcher.subprocess, 'Popen') as spawn:
            self.assertTrue(launcher.launch({'command': ['arch-update']})['ok'])
            self.assertEqual(spawn.call_args.args[0], ['konsole', '--separate', '-e', 'arch-update'])
            self.assertNotIn('shell', spawn.call_args.kwargs)

    def test_selected_terminal_and_literal_arguments_and_cwd(self):
        with tempfile.TemporaryDirectory() as folder:
            desktop = Path(folder) / 'kitty.desktop'
            desktop.write_text('[Desktop Entry]\nExec=kitty --single-instance\n')
            with patch.object(launcher, 'preferences', return_value={'roles': {'terminal': {'id': 'kitty.desktop'}}}), \
                    patch.object(launcher, 'desktop_entries', return_value={'kitty.desktop': {'path': str(desktop)}}), \
                    patch.object(launcher.shutil, 'which', return_value='/usr/bin/kitty'), \
                    patch.object(launcher.subprocess, 'Popen') as spawn:
                launcher.launch({'command': ['fixture', 'space argument', '$(touch forbidden)', ';'], 'workingDirectory': folder})
                self.assertEqual(spawn.call_args.args[0], ['kitty', '--single-instance', '--', 'fixture', 'space argument', '$(touch forbidden)', ';'])
                self.assertEqual(spawn.call_args.kwargs['cwd'], folder)

    def test_missing_selected_terminal_does_not_silently_fallback(self):
        with patch.object(launcher, 'preferences', return_value={'roles': {'terminal': {'id': 'missing.desktop'}}}), \
                patch.object(launcher, 'desktop_entries', return_value={}):
            with self.assertRaisesRegex(ValueError, 'selected terminal is unavailable'):
                launcher.terminal_prefix()

    def test_missing_terminal_explains_failure(self):
        with patch.object(launcher, 'preferences', return_value={'roles': {}}), \
                patch.object(launcher.shutil, 'which', return_value=None):
            with self.assertRaisesRegex(ValueError, 'No supported terminal'):
                launcher.terminal_prefix()

    def test_invalid_commands_never_spawn(self):
        with patch.object(launcher.subprocess, 'Popen') as spawn:
            for command in ([], '', [''], ['bad\0command'], [42]):
                with self.assertRaises(ValueError):
                    launcher.launch({'command': command})
            spawn.assert_not_called()


if __name__ == '__main__':
    unittest.main()
