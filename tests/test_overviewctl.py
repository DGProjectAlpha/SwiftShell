import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).parents[1]/'shell/helpers'))
import overviewctl as o

class OverviewShortcut(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.env=patch.dict(os.environ,{'XDG_STATE_HOME':self.tmp.name});self.env.start()
        self.original=[{'modmask':8,'key':'Tab','dispatcher':o.ORIGINAL_DISPATCHER,'description':o.ORIGINAL_DESCRIPTION,'arg':'37','submap':''}]
        self.owned=[{'modmask':8,'key':'Tab','description':o.DESCRIPTION,'submap':'','dispatcher':'HL.Dispatcher(exec_cmd)'}]
    def tearDown(self):self.env.stop();self.tmp.cleanup()
    def test_lua_strings_are_not_json_unicode_escapes(self):
        self.assertNotIn("\\u",o.handler_code());self.assertIn(o.DESCRIPTION,o.handler_code())
    def test_custom_or_duplicate_chords_are_never_removed(self):
        for values in [[],self.original*2,[dict(self.original[0],dispatcher='custom')],[dict(self.original[0],submap='other')],[dict(self.original[0],release=True)]]:
            with patch.object(o,'bindings',return_value=values),patch.object(o,'evaluate') as mutate,patch.object(o,'source_verified',return_value=True):
                with self.assertRaises(ValueError):o.enable()
                mutate.assert_not_called()
        self.assertFalse(o.state_path().exists())
    def test_matching_description_does_not_authorize_other_dispatchers(self):
        self.assertFalse(o.owned([dict(self.owned[0],dispatcher="custom")]))
        self.assertFalse(o.owned([dict(self.owned[0],release=True)]))
    def test_source_must_also_match(self):
        with patch.object(o,'bindings',return_value=self.original),patch.object(o,'evaluate') as mutate,patch.object(o,'source_verified',return_value=False):
            with self.assertRaises(ValueError):o.enable()
            mutate.assert_not_called()
    def test_journal_durable_before_mutation_and_restore(self):
        def evaluate(code):
            self.assertTrue(o.load()['enabled']);self.assertEqual(o.load()['original'],'cycle-next')
            self.assertIn('hl.unbind("ALT + Tab")',code)
        with patch.object(o,'bindings',side_effect=[self.original,self.owned,self.owned]),patch.object(o,'evaluate',side_effect=evaluate),patch.object(o,'source_verified',return_value=True):
            self.assertTrue(o.enable()['active'])
        with patch.object(o,'bindings',side_effect=[self.owned,self.original,self.original]),patch.object(o,'evaluate') as mutate,patch.object(o,'source_verified',return_value=True):
            self.assertFalse(o.restore()['enabled'])
            self.assertIn('hl.dsp.window.cycle_next()',mutate.call_args.args[0])
    def test_registration_failure_restores_original(self):
        with patch.object(o,'bindings',side_effect=[self.original,[],[],self.original]),patch.object(o,'evaluate') as mutate,patch.object(o,'source_verified',return_value=True):
            with self.assertRaises(ValueError):o.enable()
            self.assertIn('hl.dsp.window.cycle_next()',mutate.call_args.args[0])
        self.assertFalse(o.load()['enabled'])
    def test_external_change_is_not_overwritten_by_restore(self):
        o.atomic(o.state_path(),{'version':1,'enabled':True,'original':'cycle-next'})
        with patch.object(o,'bindings',return_value=[dict(self.original[0],dispatcher='custom')]),patch.object(o,'evaluate') as mutate:
            with self.assertRaises(ValueError):o.restore()
            mutate.assert_not_called()
    def test_future_state_preserved(self):
        o.atomic(o.state_path(),{'version':7,'enabled':True});before=o.state_path().read_bytes()
        with self.assertRaises(ValueError):o.load()
        self.assertEqual(o.state_path().read_bytes(),before)
    def test_shell_absent_invocation_falls_back_to_original(self):
        import subprocess
        with patch.object(o.subprocess,'run',return_value=subprocess.CompletedProcess([],1)),patch.object(o,'evaluate') as evaluate:
            o.invoke();evaluate.assert_called_once_with('hl.dispatch(hl.dsp.window.cycle_next())')
    def test_no_fallback_after_successful_ipc(self):
        import subprocess
        with patch.object(o.subprocess,'run',return_value=subprocess.CompletedProcess([],0)),patch.object(o,'evaluate') as evaluate:
            o.invoke();evaluate.assert_not_called()

if __name__=='__main__':unittest.main()
