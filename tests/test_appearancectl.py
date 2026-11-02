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
            state={'rounding':10,'size':5,'passes':4,'border':2}
            path=Path(temp)/'swiftshell/desktop-appearance.json'
            def configure(values):
                self.assertTrue(path.is_file())
                recovery=json.loads(path.read_text())
                self.assertEqual(recovery['original'],{'rounding':10,'size':5,'passes':4,'border':2})
                state.update(values)
                return dict(state)
            with patch.object(appearance,'observed',side_effect=lambda:dict(state)),patch.object(appearance,'configure',side_effect=configure):
                appearance.run('apply',{'radius':18})
                self.assertEqual(state['rounding'],18)
                state['size']=9  # User changed an option we do not own.
                appearance.run('restore')
                self.assertEqual(state,{'rounding':10,'size':9,'passes':4,'border':2})
                self.assertEqual(json.loads(path.read_text())['managed'],{})
    def test_failed_apply_attempts_exact_previous_values(self):
        with tempfile.TemporaryDirectory() as temp,patch.dict(os.environ,{'XDG_STATE_HOME':temp,'HYPRLAND_INSTANCE_SIGNATURE':'test'}):
            initial={'rounding':10,'size':5,'passes':4,'border':2}
            with patch.object(appearance,'observed',return_value=initial),patch.object(appearance,'configure',side_effect=[ValueError('rejected'),initial]) as configure:
                with self.assertRaises(ValueError):appearance.run('apply',{'strength':.5})
                self.assertEqual(configure.call_args.args[0],{'size':5,'passes':4})
                recovery=json.loads((Path(temp)/'swiftshell/desktop-appearance.json').read_text())
                self.assertEqual(recovery['managed'],{})

    def test_interrupted_apply_retains_new_keys_in_recovery_journal(self):
        with tempfile.TemporaryDirectory() as temp,patch.dict(os.environ,{'XDG_STATE_HOME':temp,'HYPRLAND_INSTANCE_SIGNATURE':'test'}):
            initial={'rounding':10,'size':5,'passes':4,'border':2}
            with patch.object(appearance,'observed',return_value=initial),patch.object(appearance,'configure',side_effect=SystemExit):
                with self.assertRaises(SystemExit):appearance.run('apply',{'radius':18})
            journal=json.loads((Path(temp)/'swiftshell/desktop-appearance.json').read_text())
            self.assertEqual(journal['pending'],{'rounding':18})
            with patch.object(appearance,'observed',return_value=dict(initial,rounding=18)),patch.object(appearance,'configure',return_value=initial) as configure:
                appearance.run('restore')
                self.assertEqual(configure.call_args.args[0],{'rounding':10})
    def test_config_reload_rebases_recovery_to_new_user_values(self):
        with tempfile.TemporaryDirectory() as temp,patch.dict(os.environ,{'XDG_STATE_HOME':temp,'HYPRLAND_INSTANCE_SIGNATURE':'test'}):
            state={'rounding':10,'size':5,'passes':4,'border':2}
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
            for raw in ['{broken',json.dumps({'version':99}),json.dumps({'session':'test','original':{'rounding':10,'size':5,'passes':4,'border':2},'managed':{'size':99999}})]:
                path.write_text(raw)
                with patch.object(appearance,'observed',return_value={'rounding':10,'size':5,'passes':4,'border':2}),patch.object(appearance,'configure') as configure:
                    with self.assertRaisesRegex(ValueError,'left unchanged'):appearance.run('resume')
                    configure.assert_not_called()
                    self.assertEqual(path.read_text(),raw)

    def test_window_borders_can_be_disabled_without_changing_decorations(self):
        self.assertEqual(appearance.validated({'border':0}),{'border':0})
        self.assertEqual(appearance.code({'border':0}),'hl.config({general={border_size=0}})')
        for value in [True,-1,9,2.5]:
            with self.assertRaises(ValueError):appearance.validated({'border':value})

if __name__=='__main__':unittest.main()
