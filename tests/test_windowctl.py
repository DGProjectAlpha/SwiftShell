import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).parents[1]/'shell/helpers'))
import windowctl as w

OWN=dict(pid=11,**{'class':'org.quickshell'},title='SwiftShell Settings',address='0x1234',at=[100,100],size=[1000,700],fullscreen=0,floating=True,workspace={'name':'1'})
OTHER=dict(OWN,pid=22,address='0x5678')

class WindowIntegration(unittest.TestCase):
    def setUp(self):
        self.folder=tempfile.TemporaryDirectory()
        self.env=patch.dict(os.environ,{'XDG_STATE_HOME':self.folder.name});self.env.start()
    def tearDown(self):self.env.stop();self.folder.cleanup()
    def test_never_selects_another_pid_or_application(self):
        with patch.object(w,'ipc',return_value=json.dumps([OTHER,dict(OWN,**{'class':'other.app'}),OWN])):
            self.assertEqual(w.own_window(11)['address'],'0x1234')
            self.assertIsNone(w.own_window(99))
    def test_unknown_owner_does_not_dispatch(self):
        with patch.object(w,'own_window',return_value=None),patch.object(w,'dispatch') as dispatch:
            with self.assertRaises(ValueError):w.run('minimize',99)
            dispatch.assert_not_called()
    def test_blur_off_disables_compositor_auto_blur_only_on_own_window(self):
        with patch.object(w,'own_window',return_value=OWN),patch.object(w,'dispatch') as dispatch:
            self.assertTrue(w.run('blur-off',11)['ok'])
            self.assertIn('window="address:0x1234"',dispatch.call_args.args[0])
            self.assertIn('prop="no_blur",value="1"',dispatch.call_args.args[0])
            w.run('blur-on',11)
            self.assertIn('prop="no_blur",value="0"',dispatch.call_args.args[0])
    def test_cleanup_is_scoped_to_owner(self):
        with patch.object(w,'own_window',return_value=None),patch.object(w,'ipc',return_value='ok') as ipc:
            w.run('cleanup',11)
            self.assertIn('__swiftshell_settings_owner==11',ipc.call_args.args[0])
    def test_minimize_preserves_geometry_and_uses_private_workspace(self):
        with patch.object(w,'own_window',return_value=OWN),patch.object(w,'snapshot',return_value=[{'name':'DP-1','x':0,'width':2560,'scale':1}]),patch.object(w,'dispatch') as dispatch:
            w.run('minimize',11)
            self.assertIn('special:swiftshell-settings-hidden',dispatch.call_args.args[0])
            self.assertIn('follow=false',dispatch.call_args.args[0])
            saved=json.loads((Path(self.folder.name)/'swiftshell/settings-window.json').read_text())
            self.assertEqual((saved['width'],saved['height']),(1000,700))

if __name__=='__main__':unittest.main()
