import copy
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).parents[1]/'shell/helpers'))
import hyprsource as h

class FakeRuntime:
    watchdog=False
    def __init__(self):
        self.values=[dict(key='Return',modmask=64,keycode=0,description='Terminal',arg='119',submap=''),dict(key='Q',modmask=64,keycode=0,description='Close',arg='120',submap='')]
        self.original=copy.deepcopy(self.values);self.disabled=False;self.flags=[];self.probes=0
    def binds(self):return copy.deepcopy(self.values)
    def probe(self,entry):self.probes+=1
    def autoreload_disabled(self):return self.disabled
    def autoreload(self,disabled):self.flags.append(disabled);self.disabled=disabled
    def replace(self,transaction,entry,binding,new_chord,command=None,global_terminal=None):
        self.command=command;self.terminal=global_terminal
        self.values.remove(entry);value=copy.deepcopy(entry);target=h.chord(new_chord);value.update(key=target['key'],modmask=target['mask'],arg='999');self.values.append(value)
    def rollback(self,transaction,binding,old_missing=True):self.values=copy.deepcopy(self.original)

class SourceShortcuts(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)/'hypr';(self.root/'config').mkdir(parents=True)
        self.state=Path(self.temp.name)/'state'
        self.env=patch.dict(os.environ,{'XDG_STATE_HOME':str(self.state),'HYPRLAND_INSTANCE_SIGNATURE':'source-test'});self.env.start()
        (self.root/'hyprland.lua').write_text('require("config.variables")\nrequire("config.binds")\n')
        (self.root/'config/variables.lua').write_text('-- apps\nTERMINAL = "kitty"\n')
        self.path=self.root/'config/binds.lua'
        self.path.write_text('-- preserved comments\nlocal mainMod = "SUPER"\nlocal prefix = "uwsm app -- "\nhl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(prefix .. TERMINAL), { description = "Terminal" }) -- keep\nhl.bind("SUPER + Q", function() local x,y=1,2; if x then return y end end, {description="Close"})\n')
        self.path.chmod(0o640);self.runtime=FakeRuntime()
    def tearDown(self):self.env.stop();self.temp.cleanup()
    def test_loaded_source_graph_and_constant_expression_preserve_offsets(self):
        bindings,assignments=h.discover(self.root)
        self.assertEqual(len(bindings),2)
        self.assertEqual(bindings[0]['text'],'SUPER + Return')
        self.assertEqual(bindings[0]['source'][bindings[0]['start']:bindings[0]['end']],'mainMod .. " + Return"')
        self.assertEqual(bindings[1]['description'],'Close')
        self.assertEqual(next(item['value'] for item in assignments if item['name']=='TERMINAL'),'kitty')
    def test_comments_strings_and_unloaded_files_never_become_bindings(self):
        (self.root/'config/unloaded.lua').write_text('hl.bind("SUPER + A", function() end)')
        self.path.write_text('-- hl.bind("SUPER + X",foo)\nlocal data="hl.bind(unsafe)"\n--[=[ hl.bind("X",bad) ]=]\nhl.bind("SUPER + Q",function() end,{description="Close"})')
        bindings,_=h.discover(self.root)
        self.assertEqual(len(bindings),1);self.assertEqual(bindings[0]['key'],'Q')
    def test_generated_and_device_specific_forms_are_not_rewritten(self):
        self.path.write_text('for i=1,6 do hl.bind("SUPER + " .. digit(i),function()end) end\nhl.bind("SUPER + A",function()end,{device={"keyboard"}})\nhl.bind("SUPER + mouse:272",function()end,{mouse=true})')
        self.assertEqual(h.discover(self.root)[0],[])
    def test_unique_effective_binding_matches_source_and_duplicate_is_protected(self):
        self.assertEqual(len(h.linked(self.runtime.binds(),self.root)),2)
        observed=self.runtime.binds();observed.append(copy.deepcopy(observed[0]))
        self.assertNotIn(0,h.linked(observed,self.root))
    def test_partial_edit_is_validated_backed_up_and_keeps_other_source_and_live_binds(self):
        original=self.path.read_text();identifier=h.linked(self.runtime.binds(),self.root)[0]['id']
        transaction=h.apply(identifier,['ctrl','super'],'F30',self.root,self.runtime)
        updated=self.path.read_text()
        self.assertEqual(updated,original.replace('mainMod .. " + Return"','"CTRL + SUPER + F30"',1))
        self.assertEqual(stat.S_IMODE(self.path.stat().st_mode),0o640)
        self.assertEqual(next(value for value in self.runtime.values if value['key']=='Q'),self.runtime.original[1])
        self.assertFalse(self.runtime.disabled);self.assertIn(True,self.runtime.flags)
        saved=json.loads((h.state_root()/(transaction+'.json')).read_text())
        self.assertEqual(saved['status'],'committed');self.assertEqual(saved['files'][0]['beforeHash'],h.digest(original.encode()))
        self.assertEqual((h.state_root()/(transaction+'.json')).stat().st_mode&0o777,0o600)
        h.undo(self.runtime);self.assertEqual(self.path.read_text(),original);self.assertEqual(self.runtime.values,self.runtime.original)
    def test_conflict_and_stale_source_ids_never_mutate(self):
        identifier=h.linked(self.runtime.binds(),self.root)[0]['id'];original=self.path.read_text()
        with self.assertRaisesRegex(ValueError,'Already used'):h.apply(identifier,['super'],'Q',self.root,self.runtime)
        self.assertEqual(self.runtime.probes,0);self.assertEqual(self.path.read_text(),original)
        self.path.write_text(original+'-- external edit\n')
        with self.assertRaisesRegex(ValueError,'changed'):h.apply(identifier,['super'],'F30',self.root,self.runtime)
    def test_invalid_lua_is_rejected_without_runtime_mutation(self):
        with self.assertRaisesRegex(ValueError,'Lua validation'):h.validate_lua('hl.bind("bad", function( end)')
        self.assertEqual(self.runtime.probes,0)
    def test_failed_runtime_readback_restores_callback_and_autoreload_policy(self):
        identifier=h.linked(self.runtime.binds(),self.root)[0]['id'];original=self.path.read_text()
        def broken(*args):self.runtime.values.append(dict(self.runtime.values[0],key='F30'))
        with patch.object(self.runtime,'replace',side_effect=broken):
            with self.assertRaises(ValueError):h.apply(identifier,['super'],'F30',self.root,self.runtime)
        self.assertEqual(self.path.read_text(),original);self.assertEqual(self.runtime.values,self.runtime.original);self.assertFalse(self.runtime.disabled)
    def test_undo_does_not_overwrite_external_changes(self):
        identifier=h.linked(self.runtime.binds(),self.root)[0]['id'];h.apply(identifier,['super'],'F30',self.root,self.runtime)
        self.path.write_text(self.path.read_text()+'-- user changed this\n')
        with self.assertRaisesRegex(ValueError,'left unchanged'):h.undo(self.runtime)
        self.assertIn('-- user changed this',self.path.read_text());self.assertFalse(self.runtime.disabled)

    def test_terminal_selection_updates_only_the_original_variable_and_live_action(self):
        variable=self.root/'config/variables.lua';before=variable.read_text();binds=self.path.read_text()
        result=h.sync_terminal('konsole',self.root,self.runtime)
        self.assertTrue(result['supported'])
        self.assertEqual(variable.read_text(),before.replace('"kitty"','"konsole"'))
        self.assertEqual(self.path.read_text(),binds)
        self.assertEqual(self.runtime.command,'uwsm app -- konsole')
        self.assertEqual(self.runtime.terminal,'konsole')
        self.assertEqual(len(self.runtime.values),2)
        h.undo(self.runtime);self.assertEqual(variable.read_text(),before)
    def test_terminal_task_suffix_does_not_hide_the_default_launch_action(self):
        with self.path.open('a') as stream:
            stream.write('hl.bind("SUPER + B", hl.dsp.exec_cmd(prefix .. TERMINAL .. " -e btop"), {description="Monitor"})\n')
        matched=h.terminal_binding(self.root)
        self.assertIsNotNone(matched)
        self.assertEqual(matched['binding']['key'],'Return')
        self.assertEqual(matched['command'],'uwsm app -- kitty')
        self.assertTrue(h.sync_terminal('konsole',self.root,self.runtime)['supported'])
    def test_reselecting_current_terminal_does_not_mutate_runtime_or_source(self):
        before=self.path.read_bytes()
        result=h.sync_terminal('kitty',self.root,self.runtime)
        self.assertTrue(result['supported']);self.assertFalse(result['changed'])
        self.assertEqual(self.runtime.probes,0)
        self.assertEqual(self.path.read_bytes(),before)
    def test_missing_or_computed_terminal_variable_is_not_fabricated(self):
        (self.root/'config/variables.lua').write_text('TERMINAL = os.getenv("TERMINAL")\n')
        self.assertIsNone(h.terminal_binding(self.root))
        self.assertFalse(h.sync_terminal('konsole',self.root,self.runtime)['supported'])
        self.assertEqual(self.runtime.probes,0)
    def test_changed_variable_source_is_not_overwritten_by_stale_terminal_plan(self):
        matched=h.terminal_binding(self.root);variable=self.root/'config/variables.lua'
        variable.write_text('TERMINAL = "another"\n')
        with patch.object(h,'terminal_binding',return_value=matched):
            with self.assertRaisesRegex(ValueError,'changed'):h.sync_terminal('konsole',self.root,self.runtime)
        self.assertEqual(variable.read_text(),'TERMINAL = "another"\n')
    def test_prepared_crash_restores_autoreload_without_replacing_untouched_callback(self):
        binding=h.discover(self.root)[0][0]
        path=h.state_root()/'prepared.json'
        h.atomic(path,dict(version=1,id='a'*32,root=str(self.root),session='source-test',files=[],old=h.source_key(binding),new='SUPER + F30',status='pending',phase='prepared',entryArg='119',autoreloadDisabled=False))
        self.runtime.disabled=True
        with patch.object(self.runtime,'rollback') as rollback:h.recover(path,self.runtime);rollback.assert_not_called()
        self.assertFalse(self.runtime.disabled)
    def test_failure_after_source_write_restores_source_permissions_and_callback(self):
        identifier=h.linked(self.runtime.binds(),self.root)[0]['id'];before=self.path.read_bytes()
        original=h.write_source
        def failed(path,raw,expected):
            original(path,raw,expected)
            if b'F30' in raw:raise OSError('Synthetic failure after replacement')
        with patch.object(h,'write_source',side_effect=failed):
            with self.assertRaises(OSError):h.apply(identifier,['super'],'F30',self.root,self.runtime)
        self.assertEqual(self.path.read_bytes(),before);self.assertEqual(self.path.stat().st_mode&0o777,0o640)
        self.assertEqual(self.runtime.values,self.runtime.original);self.assertFalse(self.runtime.disabled)

if __name__=='__main__':unittest.main()
