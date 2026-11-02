import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).parents[1]/'shell/helpers'))
import powerprofilesctl as power


def snapshot(active='balanced', ids=('power-saver','balanced','performance'), inhibited='', degraded='', holds=()):
    return {'type':'a{sv}','data':[{'ActiveProfile':{'type':'s','data':active},
        'Profiles':{'type':'aa{sv}','data':[{'Profile':{'type':'s','data':profile}} for profile in ids]},
        'PerformanceInhibited':{'type':'s','data':inhibited},
        'PerformanceDegraded':{'type':'s','data':degraded},
        'ActiveProfileHolds':{'type':'aa{sv}','data':list(holds)}}]}

class PowerProfilesTests(unittest.TestCase):
    def test_snapshot_only_reports_advertised_choices_and_actual_state(self):
        with patch.object(power,'command',return_value=__import__('json').dumps(snapshot(ids=('power-saver','balanced')))) as execute:
            report=power.run()
            self.assertEqual(report['active'],'balanced')
            self.assertEqual([profile['id'] for profile in report['profiles']],['power-saver','balanced'])
            self.assertEqual(execute.call_count,1)
            self.assertIn('GetAll',execute.call_args.args[0])
    def test_inhibited_performance_is_disabled_but_degraded_is_informational(self):
        with patch.object(power,'command',return_value=__import__('json').dumps(snapshot(inhibited='lap-detected',degraded='high-operating-temperature'))):
            report=power.run()
            self.assertFalse(report['profiles'][-1]['enabled'])
            self.assertEqual(report['degraded'],'high-operating-temperature')
            with self.assertRaisesRegex(ValueError,'currently unavailable'):power.run('set','performance')
    def test_only_allowlisted_profile_can_be_written(self):
        with patch.object(power,'command') as execute:
            for bad in ['performance; command','--help','unknown','']:
                with self.assertRaises(ValueError):power.run('set',bad)
            execute.assert_not_called()
    def test_set_uses_typed_property_and_confirms_readback(self):
        import json
        with patch.object(power,'command',side_effect=[json.dumps(snapshot()),'',json.dumps(snapshot(active='performance'))]) as execute:
            report=power.run('set','performance')
            self.assertEqual(report['active'],'performance')
            self.assertEqual(execute.call_args_list[1].args[0],['set-property',power.ENDPOINTS[0][0],power.ENDPOINTS[0][1],power.ENDPOINTS[0][0],'ActiveProfile','s','performance'])
    def test_same_profile_does_not_write(self):
        import json
        with patch.object(power,'command',return_value=json.dumps(snapshot())) as execute:
            self.assertTrue(power.run('set','balanced')['ok'])
            self.assertEqual(execute.call_count,1)
    def test_failed_readback_returns_actual_profile_truthfully(self):
        import json
        with patch.object(power,'command',side_effect=[json.dumps(snapshot()),'',json.dumps(snapshot())]):
            result=power.run('set','performance')
            self.assertFalse(result['ok']);self.assertEqual(result['active'],'balanced')
    def test_legacy_endpoint_fallback_and_missing_service(self):
        import json
        with patch.object(power,'command',side_effect=[ValueError('missing'),json.dumps(snapshot())]) as execute:
            self.assertTrue(power.run()['available'])
            self.assertEqual(execute.call_args.args[0][1],power.ENDPOINTS[1][0])
        with patch.object(power,'command',side_effect=FileNotFoundError):
            with self.assertRaisesRegex(ValueError,'not available'):power.run()
    def test_backend_error_does_not_log_command_or_stderr(self):
        import subprocess
        with patch.object(power.subprocess,'run',return_value=subprocess.CompletedProcess([],1,'','private error payload')):
            with self.assertRaisesRegex(ValueError,'unavailable or access was denied') as error:power.command(['call','allowed'])
            self.assertNotIn('private',str(error.exception))

if __name__=='__main__':unittest.main()
