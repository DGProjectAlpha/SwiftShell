import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).parents[1]/'shell/helpers'))
import appearancectl as appearance

class DesktopAppearanceTests(unittest.TestCase):
    def test_only_finite_bounded_controls_are_accepted(self):
        self.assertEqual(appearance.validated({'radius':12,'strength':.5}),{'rounding':12,'size':7,'passes':2})
        for bad in ({'radius':True},{'radius':25},{'strength':float('nan')},{'strength':0},{'command':'unsafe'},[]):
            with self.assertRaises(ValueError):appearance.validated(bad)
    def test_codegen_has_only_owned_numeric_options(self):
        self.assertEqual(appearance.code({'rounding':12,'size':7,'passes':2}),'hl.config({decoration={rounding=12,blur={size=7,passes=2}}})')
    def test_recovery_record_precedes_apply_and_restore_retains_unmanaged_options(self):
        with tempfile.TemporaryDirectory() as temp, patch.dict(os.environ,{'XDG_STATE_HOME':temp,'HYPRLAND_INSTANCE_SIGNATURE':'owned-session'}):
            state={'rounding':10,'size':5,'passes':4,'border':2,'activeOpacity':.95,'inactiveOpacity':.85}
            path=Path(temp)/'swiftshell/desktop-appearance.json'
            def configure(values):
                self.assertTrue(path.is_file())
                recovery=json.loads(path.read_text())
                self.assertEqual(recovery['original'],{'rounding':10,'size':5,'passes':4,'border':2,'activeOpacity':.95,'inactiveOpacity':.85})
                state.update(values)
                return dict(state)
            with patch.object(appearance,'observed',side_effect=lambda:dict(state)),patch.object(appearance,'configure',side_effect=configure):
                appearance.run('apply',{'radius':18})
                self.assertEqual(state['rounding'],18)
                state['size']=9  # User changed an option we do not own.
                appearance.run('restore')
                self.assertEqual(state,{'rounding':10,'size':9,'passes':4,'border':2,'activeOpacity':.95,'inactiveOpacity':.85})
                self.assertEqual(json.loads(path.read_text())['managed'],{})
    def test_failed_apply_attempts_exact_previous_values(self):
        with tempfile.TemporaryDirectory() as temp,patch.dict(os.environ,{'XDG_STATE_HOME':temp,'HYPRLAND_INSTANCE_SIGNATURE':'test'}):
            initial={'rounding':10,'size':5,'passes':4,'border':2,'activeOpacity':.95,'inactiveOpacity':.85}
            with patch.object(appearance,'observed',return_value=initial),patch.object(appearance,'configure',side_effect=[ValueError('rejected'),initial]) as configure:
                with self.assertRaises(ValueError):appearance.run('apply',{'strength':.5})
                self.assertEqual(configure.call_args.args[0],{'size':5,'passes':4})
                recovery=json.loads((Path(temp)/'swiftshell/desktop-appearance.json').read_text())
                self.assertEqual(recovery['managed'],{})

    def test_interrupted_apply_retains_new_keys_in_recovery_journal(self):
        with tempfile.TemporaryDirectory() as temp,patch.dict(os.environ,{'XDG_STATE_HOME':temp,'HYPRLAND_INSTANCE_SIGNATURE':'test'}):
            initial={'rounding':10,'size':5,'passes':4,'border':2,'activeOpacity':.95,'inactiveOpacity':.85}
            with patch.object(appearance,'observed',return_value=initial),patch.object(appearance,'configure',side_effect=SystemExit):
                with self.assertRaises(SystemExit):appearance.run('apply',{'radius':18})
            journal=json.loads((Path(temp)/'swiftshell/desktop-appearance.json').read_text())
            self.assertEqual(journal['pending'],{'rounding':18})
            with patch.object(appearance,'observed',return_value=dict(initial,rounding=18)),patch.object(appearance,'configure',return_value=initial) as configure:
                appearance.run('restore')
                self.assertEqual(configure.call_args.args[0],{'rounding':10})
    def test_config_reload_rebases_recovery_to_new_user_values(self):
        with tempfile.TemporaryDirectory() as temp,patch.dict(os.environ,{'XDG_STATE_HOME':temp,'HYPRLAND_INSTANCE_SIGNATURE':'test'}):
            state={'rounding':10,'size':5,'passes':4,'border':2,'activeOpacity':.95,'inactiveOpacity':.85}
            def configure(values):state.update(values);return dict(state)
            with patch.object(appearance,'observed',side_effect=lambda:dict(state)),patch.object(appearance,'configure',side_effect=configure):
                appearance.run('apply',{'radius':18})
                state['rounding']=14
                appearance.run('reload')
                self.assertEqual(state['rounding'],18)
                appearance.run('restore')
                self.assertEqual(state['rounding'],14)
    def test_malformed_or_unsafe_recovery_is_left_unchanged(self):
        with tempfile.TemporaryDirectory() as temp,patch.dict(os.environ,{'XDG_STATE_HOME':temp,'HYPRLAND_INSTANCE_SIGNATURE':'test'}):
            path=Path(temp)/'swiftshell/desktop-appearance.json';path.parent.mkdir()
            for raw in ['{broken',json.dumps({'version':99}),json.dumps({'session':'test','original':{'rounding':10,'size':5,'passes':4,'border':2,'activeOpacity':.95,'inactiveOpacity':.85},'managed':{'size':99999}})]:
                path.write_text(raw)
                with patch.object(appearance,'observed',return_value={'rounding':10,'size':5,'passes':4,'border':2,'activeOpacity':.95,'inactiveOpacity':.85}),patch.object(appearance,'configure') as configure:
                    with self.assertRaisesRegex(ValueError,'left unchanged'):appearance.run('resume')
                    configure.assert_not_called()
                    self.assertEqual(path.read_text(),raw)

    def test_window_borders_can_be_disabled_without_changing_decorations(self):
        self.assertEqual(appearance.validated({'border':0}),{'border':0})
        self.assertEqual(appearance.code({'border':0}),'hl.config({general={border_size=0}})')
        for value in [True,-1,9,2.5]:
            with self.assertRaises(ValueError):appearance.validated({'border':value})

    def test_opaque_windows_restore_only_their_owned_float_options(self):
        with tempfile.TemporaryDirectory() as temp,patch.dict(os.environ,{'XDG_STATE_HOME':temp,'HYPRLAND_INSTANCE_SIGNATURE':'test'}):
            initial={'rounding':10,'size':5,'passes':4,'border':2,'activeOpacity':.95,'inactiveOpacity':.85}
            state=dict(initial)
            path=Path(temp)/'swiftshell/desktop-appearance.json'
            def configure(values):
                journal=json.loads(path.read_text())
                self.assertTrue(set(values)<=set(journal['pending']))
                self.assertEqual(journal['original'],initial)
                state.update(values)
                return dict(state)
            with patch.object(appearance,'observed',side_effect=lambda:dict(state)),patch.object(appearance,'configure',side_effect=configure):
                appearance.run('apply',{'radius':18})
                appearance.run('apply',{'opaqueWindows':True})
                self.assertEqual(state['activeOpacity'],1)
                self.assertEqual(state['inactiveOpacity'],1)
                state['size']=9
                result=appearance.run('apply',{'opaqueWindows':False})
                self.assertEqual(state,dict(initial,rounding=18,size=9))
                self.assertEqual(result['managed'],{'rounding':18})

    def test_disabling_unmanaged_opacity_does_not_change_user_values(self):
        with tempfile.TemporaryDirectory() as temp,patch.dict(os.environ,{'XDG_STATE_HOME':temp,'HYPRLAND_INSTANCE_SIGNATURE':'test'}):
            initial={'rounding':10,'size':5,'passes':4,'border':2,'activeOpacity':.7,'inactiveOpacity':.6}
            with patch.object(appearance,'observed',return_value=initial),patch.object(appearance,'configure',return_value=initial) as configure:
                result=appearance.run('apply',{'opaqueWindows':False})
                self.assertEqual(configure.call_args.args[0],{})
                self.assertEqual(result['managed'],{})

    def test_version_two_journal_adds_opacity_baseline_without_overwriting_owned_values(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'appearance.json'
            previous={'version':2,'session':'test','original':{'rounding':10,'size':5,'passes':4,'border':2},'managed':{'rounding':18},'pending':{}}
            raw=json.dumps(previous);path.write_text(raw)
            actual={'rounding':18,'size':5,'passes':4,'border':2,'activeOpacity':.95,'inactiveOpacity':.85}
            result=appearance.recovery(path,actual,'test')
            self.assertEqual(result['version'],3)
            self.assertEqual(result['original']['rounding'],10)
            self.assertEqual(result['original']['activeOpacity'],.95)
            self.assertEqual(result['original']['inactiveOpacity'],.85)
            self.assertEqual(result['managed'],{'rounding':18})
            self.assertEqual(path.read_text(),raw)

    def test_opaque_payload_is_boolean_and_codegen_is_numeric_only(self):
        self.assertEqual(appearance.validated({'opaqueWindows':True}),{'activeOpacity':1.0,'inactiveOpacity':1.0})
        self.assertEqual(appearance.validated({'opaqueWindows':False}),{})
        self.assertEqual(appearance.code({'activeOpacity':.95,'inactiveOpacity':1.0}),'hl.config({decoration={active_opacity=0.95,inactive_opacity=1}})')
        for value in ['true',1,None,{},float('nan')]:
            with self.assertRaises(ValueError):appearance.validated({'opaqueWindows':value})
        for value in [True,-.1,1.1,float('nan'),float('inf')]:
            with self.assertRaises(ValueError):appearance.checked_values({'activeOpacity':value})

    def test_unchanged_values_never_reconfigure_the_compositor(self):
        initial={'rounding':10,'size':5,'passes':4,'border':2,'activeOpacity':1.,'inactiveOpacity':1.}
        with patch.object(appearance,'observed',return_value=initial),patch.object(appearance,'ipc') as ipc:
            self.assertEqual(appearance.configure(initial),initial)
            ipc.assert_not_called()
        changed=dict(initial,inactiveOpacity=.85)
        with patch.object(appearance,'observed',side_effect=[initial,changed]),patch.object(appearance,'ipc',return_value='ok') as ipc:
            self.assertEqual(appearance.configure(dict(initial,inactiveOpacity=.85)),changed)
            ipc.assert_called_once_with('eval hl.config({decoration={inactive_opacity=0.85}})')

if __name__=='__main__':unittest.main()
