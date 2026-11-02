#!/usr/bin/env python3
"""Scoped window behavior; never reads clipboard data."""
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'shell/helpers'))
import clipboardwindow as window

class ClipboardWindowTests(unittest.TestCase):
    def test_window_selection_requires_pid_class_and_title(self):
        rows=[{'pid':44,'class':'org.quickshell','title':window.TITLE,'address':'0x1'}, {'pid':55,'class':'org.quickshell','title':window.TITLE,'address':'0x2'}]
        with patch.object(window,'ipc',return_value=json.dumps(rows)):
            self.assertEqual(window.own_window(55)['address'],'0x2')
            self.assertIsNone(window.own_window(66))
    def test_prepare_scopes_rule_without_writing_config(self):
        with patch.object(window,'read',return_value={}),patch.object(window,'ipc',return_value='ok') as ipc,patch.object(window,'atomic') as write:
            self.assertTrue(window.run('prepare',55)['ok'])
            self.assertIn('title="^SwiftShell Clipboard$"',ipc.call_args.args[0])
            self.assertIn('__swiftshell_clipboard_owner=55',ipc.call_args.args[0])
            write.assert_not_called()
    def test_mapped_focus_float_and_blur_target_exact_owned_address(self):
        owned={'address':'0x2','floating':False}
        with patch.object(window,'read',return_value={}),patch.object(window,'own_window',return_value=owned),patch.object(window,'dispatch') as dispatch:
            window.run('mapped',55,False)
            calls=[call.args[0] for call in dispatch.call_args_list]
            self.assertTrue(all('address:0x2' in command for command in calls))
            self.assertTrue(any('action="enable"' in command for command in calls))
            self.assertIn('prop="no_blur",value="1"',calls[-1])
    def test_geometry_is_clamped_to_connected_logical_output(self):
        m={'name':'DP-1','x':112,'y':-88,'width':2560,'height':1440,'scale':1,'enabled':True,'transform':0}
        saved={'x':9000,'y':9000,'width':9000,'height':9000,'monitor':'DP-1'}
        owned={'address':'0x2','floating':True}
        with patch.object(window,'read',return_value=saved),patch.object(window,'own_window',return_value=owned),patch.object(window,'snapshot',return_value=[m]),patch.object(window,'dispatch') as dispatch:
            window.run('mapped',55)
            calls=[call.args[0] for call in dispatch.call_args_list]
            self.assertTrue(any('x=2560,y=1440' in command for command in calls))
            self.assertTrue(any('x=112,y=-88' in command for command in calls))
    def test_missing_window_never_targets_another_client(self):
        with patch.object(window,'read',return_value={}),patch.object(window,'own_window',return_value=None),patch.object(window,'dispatch') as dispatch:
            with self.assertRaises(ValueError):window.run('activate',55)
            dispatch.assert_not_called()

if __name__=='__main__':unittest.main()
