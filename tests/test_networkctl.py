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
            self.assertIn(['radio','wifi','off'],[call.args[0] for call in nm.call_args_list])
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
    def test_cancel_only_deactivates_an_observed_activating_connection(self):
        identifier=BASE['profiles'][0]['id']
        active=dict(id=identifier,device='wlan0',state='activating')
        with patch.object(n,'snapshot',return_value=BASE),patch.object(n,'active_connections',side_effect=[[active],[]]),patch.object(n,'nm') as nm:
            result=n.request(dict(action='cancel-connect',device='wlan0',id=AP['id']))
            self.assertTrue(result['cancelled'])
            self.assertEqual(nm.call_args.args[0],['--wait','10','connection','down','uuid',identifier])
    def test_cancel_refuses_to_disconnect_an_already_working_connection(self):
        active=dict(id=BASE['profiles'][0]['id'],device='wlan0',state='activated')
        with patch.object(n,'snapshot',return_value=BASE),patch.object(n,'active_connections',return_value=[active]),patch.object(n,'nm') as nm:
            result=n.request(dict(action='cancel-connect',device='wlan0',id=AP['id']))
            self.assertFalse(result['cancelled']);nm.assert_not_called()
    def test_cancel_profile_is_scoped_to_its_uuid(self):
        identifier=BASE['profiles'][0]['id']
        other=dict(id='00000000-0000-0000-0000-000000000002',device='wlan0',state='activating')
        with patch.object(n,'snapshot',return_value=BASE),patch.object(n,'active_connections',return_value=[other]),patch.object(n,'nm') as nm:
            self.assertFalse(n.request(dict(action='cancel-connect',id=identifier))['cancelled'])
            nm.assert_not_called()
    def test_cancellation_readback_must_confirm_the_activation_ended(self):
        active=dict(id=BASE['profiles'][0]['id'],device='wlan0',state='activating')
        with patch.object(n,'snapshot',return_value=BASE),patch.object(n,'active_connections',return_value=[active]),patch.object(n,'nm'):
            with self.assertRaisesRegex(n.NetworkError,'could not be confirmed'):
                n.request(dict(action='cancel-connect',device='wlan0'))
    def test_cancel_rejects_unknown_targets_without_mutation(self):
        with patch.object(n,'snapshot',return_value=BASE),patch.object(n,'active_connections') as active,patch.object(n,'nm') as nm:
            for payload in [dict(action='cancel-connect',device='missing'),dict(action='cancel-connect',id='bad;command',device='wlan0'),dict(action='cancel-connect',id='00000000-0000-0000-0000-000000000002')]:
                with self.assertRaises(ValueError):n.request(payload)
            active.assert_not_called();nm.assert_not_called()
    def test_authentication_error_is_typed_but_never_echoes_private_diagnostics(self):
        failed=subprocess.CompletedProcess([],7,'PRIVATE SSID PASSWORD','PRIVATE AUTH MESSAGE')
        with patch.object(n.subprocess,'run',return_value=failed):
            with self.assertRaises(n.NetworkError) as error:n.nm(['connection','up'])
            self.assertEqual(error.exception.code,'authentication-required')
            self.assertNotIn('PRIVATE',str(error.exception))

    def snapshot_nm(self,enabled,fail_access_points=False,fail_details=False):
        def call(args,**kwargs):
            if args[:2]==['--get-values','STATE,CONNECTIVITY']:return 'connected:full\n'
            if args[:2]==['--get-values','WIFI-HW,WIFI']:return 'enabled:'+('enabled' if enabled else 'disabled')+'\n'
            if 'DEVICE,TYPE,STATE,CONNECTION' in args:return 'wlan0:wifi:disconnected:--\n'
            if 'GENERAL.STATE,GENERAL.REASON,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS' in args:
                if fail_details:raise n.NetworkError('Transient device change','not-found')
                return ''
            if 'BSSID,SSID,SIGNAL,SECURITY,IN-USE,DEVICE' in args:
                if fail_access_points:raise n.NetworkError('Transient unavailable radio','not-found')
                return ''
            return ''
        return call
    def test_disabled_radio_does_not_query_cached_available_access_points(self):
        with patch.object(n.shutil,'which',return_value='/usr/bin/nmcli'),patch.object(n,'nm',side_effect=self.snapshot_nm(False,True)) as nm:
            result=n.snapshot()
            self.assertTrue(result['available']);self.assertFalse(result['wifiEnabled'])
            self.assertFalse(any('BSSID,SSID,SIGNAL,SECURITY,IN-USE,DEVICE' in call.args[0] for call in nm.call_args_list))
    def test_radio_startup_ap_failure_preserves_observed_enabled_state(self):
        with patch.object(n.shutil,'which',return_value='/usr/bin/nmcli'),patch.object(n,'nm',side_effect=self.snapshot_nm(True,True)):
            result=n.snapshot()
            self.assertTrue(result['available']);self.assertTrue(result['wifiEnabled'])
            self.assertEqual(result['networks'],[])
            self.assertIn('getting ready',result['wifiScanMessage'])
    def test_transient_device_detail_failure_does_not_hide_radio_or_devices(self):
        with patch.object(n.shutil,'which',return_value='/usr/bin/nmcli'),patch.object(n,'nm',side_effect=self.snapshot_nm(False,False,True)):
            result=n.snapshot()
            self.assertTrue(result['available']);self.assertEqual(len(result['devices']),1)
            self.assertEqual(result['devices'][0]['addresses'],[])
    def test_radio_confirmation_waits_for_observed_target(self):
        with patch.object(n,'radio_state',side_effect=[(True,False),(True,False),(True,True)]),patch.object(n.time,'sleep') as sleep:
            n.wait_for_radio(True)
            self.assertEqual(sleep.call_count,2)
    def test_hardware_blocked_radio_has_a_truthful_typed_error(self):
        with patch.object(n,'radio_state',return_value=(False,False)),patch.object(n.time,'sleep') as sleep:
            with self.assertRaises(n.NetworkError) as error:n.wait_for_radio(True)
            self.assertEqual(error.exception.code,'hardware-blocked');sleep.assert_not_called()
    def test_radio_request_confirms_target_before_returning_new_snapshot(self):
        with patch.object(n,'snapshot',return_value=BASE),patch.object(n,'nm') as nm,patch.object(n,'wait_for_radio') as wait:
            n.request(dict(action='wifi-radio',enabled=True))
            self.assertEqual(nm.call_args.args[0],['radio','wifi','on'])
            wait.assert_called_once_with(True)

if __name__=='__main__':unittest.main()
