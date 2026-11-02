import importlib.util
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('networkctl',Path(__file__).parents[1]/'shell/helpers/networkctl.py')
n=importlib.util.module_from_spec(spec);spec.loader.exec_module(n)
DEVICE=dict(id='wlan0',kind='wifi',state='disconnected',connected=False,available=True)
AP=dict(id='AA:BB:CC:DD:EE:FF',name='Private: Network',device='wlan0',security='WPA2',supported=True)
BASE=dict(ok=True,available=True,devices=[DEVICE],profiles=[dict(id='00000000-0000-0000-0000-000000000001')],networks=[AP])
class NetworkTests(unittest.TestCase):
    def test_escaped_names_and_mac_are_parsed_without_shell_interpretation(self):
        self.assertEqual(n.fields(r'AA\:BB\:CC:Office\: West\\Lobby:70'),['AA:BB:CC','Office: West\\Lobby','70'])
    def test_unknown_device_cannot_be_used_as_an_option(self):
        with patch.object(n,'snapshot',return_value=BASE),patch.object(n,'nm') as nm:
            with self.assertRaisesRegex(ValueError,'no longer available'):n.request(dict(action='device-disconnect',device='--help'))
            nm.assert_not_called()
    def test_wifi_password_is_only_sent_over_stdin(self):
        with patch.object(n,'snapshot',return_value=BASE),patch.object(n,'nm') as nm:
            n.request(dict(action='wifi-connect',device='wlan0',id=AP['id'],secret='synthetic-password'))
            args=nm.call_args.args[0]
            self.assertNotIn('synthetic-password',args)
            self.assertIn('--ask',args)
            self.assertEqual(nm.call_args.kwargs['secret'],'synthetic-password\n')
            self.assertEqual(args[-3:],[AP['id'],'ifname','wlan0'])
    def test_invalid_or_missing_password_never_starts_connection(self):
        with patch.object(n,'snapshot',return_value=BASE),patch.object(n,'nm') as nm:
            for secret in ['short','bad\npassword',None,'a'*65]:
                with self.assertRaises(ValueError):n.request(dict(action='wifi-connect',device='wlan0',id=AP['id'],secret=secret))
            nm.assert_not_called()
    def test_only_discovered_access_points_can_be_connected(self):
        with patch.object(n,'snapshot',return_value=BASE),patch.object(n,'nm') as nm:
            with self.assertRaises(ValueError):n.request(dict(action='wifi-connect',device='wlan0',id='evil;command',secret='synthetic-password'))
            nm.assert_not_called()
    def test_enterprise_creation_is_honestly_refused(self):
        data=dict(BASE,networks=[dict(AP,supported=False)])
        with patch.object(n,'snapshot',return_value=data),patch.object(n,'nm') as nm:
            with self.assertRaisesRegex(ValueError,'existing connection profile'):n.request(dict(action='wifi-connect',device='wlan0',id=AP['id'],secret='synthetic-password'))
            nm.assert_not_called()
    def test_saved_profile_uuid_and_radio_are_typed(self):
        with patch.object(n,'snapshot',return_value=BASE),patch.object(n,'nm') as nm:
            n.request(dict(action='profile-connect',id=BASE['profiles'][0]['id']))
            self.assertEqual(nm.call_args.args[0],['--wait','25','connection','up','uuid',BASE['profiles'][0]['id']])
            with self.assertRaises(ValueError):n.request(dict(action='wifi-radio',enabled='false'))
            n.request(dict(action='wifi-radio',enabled=False))
            self.assertEqual(nm.call_args.args[0],['radio','wifi','off'])
    def test_backend_errors_do_not_return_private_diagnostics(self):
        failed=subprocess.CompletedProcess([],4,'PRIVATE SSID PASSWORD','PRIVATE USER PATH')
        with patch.object(n.subprocess,'run',return_value=failed):
            with self.assertRaises(ValueError) as error:n.nm(['device','status'])
            self.assertNotIn('PRIVATE',str(error.exception))
    def test_timeout_is_generic_and_process_never_uses_shell(self):
        with patch.object(n.subprocess,'run',side_effect=subprocess.TimeoutExpired(['nmcli'],1)) as run:
            with self.assertRaisesRegex(ValueError,'did not respond'):n.nm(['device','status'])
            self.assertNotIn('shell',run.call_args.kwargs)
    def test_live_get_values_shape_has_colon_separated_general_fields(self):
        def nm(args,**kwargs):
            if args[:2]==['--get-values','STATE,CONNECTIVITY']:return 'connected:full\n'
            if args[:2]==['--get-values','WIFI-HW,WIFI']:return 'enabled:disabled\n'
            return ''
        with patch.object(n.shutil,'which',return_value='/usr/bin/nmcli'),patch.object(n,'nm',side_effect=nm):
            status=n.snapshot()
            self.assertEqual(status['state'],'connected')
            self.assertEqual(status['connectivity'],'full')
            self.assertTrue(status['wifiHardware'])
            self.assertFalse(status['wifiEnabled'])
    def test_invalid_top_level_requests_are_rejected(self):
        for data in [[],dict(action='snapshot',extra='ignored')]:
            with self.assertRaises(ValueError):n.request(data)
if __name__=='__main__':unittest.main()
