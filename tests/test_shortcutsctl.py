import copy
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).parents[1]/'shell/helpers'))
import shortcutsctl as s

class ShortcutIntegration(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.env=patch.dict(os.environ,{'XDG_STATE_HOME':self.temp.name});self.env.start()
    def tearDown(self):self.env.stop();self.temp.cleanup()
    def test_normalize_rejects_injection_reserved_and_unmodified(self):
        for mods,key in [([], 'A'),(['shift'],'A'),(['super'],'A);evil()'),(['super'],'Escape'),(['ctrl','alt'],'F2'),(['unknown'],'A')]:
            with self.assertRaises(ValueError):s.normalize(mods,key)
        self.assertEqual(s.normalize(['super','ctrl','super'],'space'),{'modifiers':['ctrl','super'],'key':'Space'})
    def test_named_and_physical_conflicts_preserve_existing_shortcuts(self):
        chord=s.normalize(['super'],'1')
        with patch.object(s,'physical_codes',return_value={10}):
            self.assertEqual(s.collision(chord,[dict(modmask=64,keycode=10,key='',description='Workspace one')]),'Workspace one')
        self.assertEqual(s.collision(s.normalize(['super'],'Q'),[dict(modmask=64,key='q',description='Close window')]),'Close window')
    def test_collision_refuses_before_register_or_backup(self):
        with patch.object(s,'live',return_value=[dict(modmask=64,key='Q',description='Close window')]),patch.object(s,'register') as register:
            with self.assertRaises(ValueError):s.apply('settings',['super'],'Q')
            register.assert_not_called()
        self.assertFalse(s.state_path().exists())
    def test_register_only_removes_owned_handles_never_unbinds_chord(self):
        with patch.object(s,'evaluate') as evaluate:
            s.register('settings',s.normalize(['super','ctrl'],'F35'))
            code=evaluate.call_args.args[0]
            self.assertIn('hl.bind(',code);self.assertIn('__swiftshell_shortcuts["settings"]',code)
            self.assertNotIn('hl.unbind',code)
            self.assertNotIn('io.popen',code)
            s.register('settings',None)
            self.assertIn('old:remove()',evaluate.call_args.args[0])
    def test_apply_readback_failure_restores_previous_binding(self):
        old=s.normalize(['super','ctrl'],'F34')
        s.atomic(s.state_path(),{'version':1,'bindings':{'settings':old}})
        with patch.object(s,'live',return_value=[]),patch.object(s,'register') as register:
            with self.assertRaises(ValueError):s.apply('settings',['super','ctrl'],'F35')
            self.assertEqual(register.call_args.args,('settings',old))
        self.assertEqual(s.settings()['bindings']['settings'],old)
    def test_apply_persists_verified_binding_and_remove_undo(self):
        chord=s.normalize(['super','ctrl'],'F35')
        observed=[dict(modmask=s.mask(chord),key='F35',description=s.owner_description('settings'))]
        with patch.object(s,'live',side_effect=[[],observed]),patch.object(s,'register'):
            s.apply('settings',chord['modifiers'],chord['key'])
        self.assertEqual(s.settings()['bindings']['settings'],chord)
        self.assertEqual(s.state_path().stat().st_mode&0o777,0o600)
        with patch.object(s,'register'):s.remove('settings')
        self.assertEqual(s.settings()['bindings'],{})
        with patch.object(s,'live',return_value=[]),patch.object(s,'register'):
            s.restore_previous()
        self.assertEqual(s.settings()['bindings']['settings'],chord)
    def test_sync_skips_conflicts_without_overriding_user(self):
        s.atomic(s.state_path(),{'version':1,'bindings':{'settings':s.normalize(['super'],'Q')}})
        with patch.object(s,'live',return_value=[dict(modmask=64,key='Q',description='Close window')]),patch.object(s,'register') as register:
            warnings=s.sync();register.assert_not_called()
            self.assertIn('Close window',warnings[0])
    def test_invalid_state_is_protected(self):
        s.atomic(s.state_path(),{'version':9,'bindings':{}})
        with self.assertRaises(ValueError):s.settings()
    def test_malformed_saved_state_is_not_overwritten(self):
        s.state_path().parent.mkdir(parents=True)
        s.state_path().write_text('{broken')
        with self.assertRaises(ValueError):s.settings()
        self.assertEqual(s.state_path().read_text(),'{broken')
    def test_lua_literals_keep_unicode_without_invalid_json_escapes(self):
        value=s.lua_string(s.owner_description('settings'))
        self.assertIn('·',value)
        self.assertNotIn('\\u00b7',value)
        self.assertEqual(s.normalize(['super'],'Page_Up')['key'],'Page_Up')
    def test_snapshot_never_exposes_private_command_arguments(self):
        with patch.object(s,'live',return_value=[dict(key='Q',modmask=64,dispatcher='HL.Dispatcher(exec_cmd)',arg='SECRET_PRIVATE_COMMAND',description='Launch app')]):
            result=s.snapshot()
            self.assertNotIn('SECRET',json.dumps(result));self.assertEqual(result['effective'][0]['owner'],'Hyprland')
    def test_catalog_dispatchers_are_fixed_and_shell_launches_are_quoted(self):
        self.assertEqual(s.action_code('focus-left'),'hl.dsp.focus({direction="left"})')
        self.assertEqual(s.action_code('workspace-10'),'hl.dsp.focus({workspace=10})')
        with self.assertRaises(ValueError):s.action_code('hl.dsp.exec_cmd("bad")')
        self.assertIn('shortcutsctl.py',s.action_code('settings'))

if __name__=='__main__':unittest.main()
