import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).parents[1]/'shell/helpers'))
import sessionctl as session


class FakeProcess:
    def __init__(self,code=None):self.code=code;self.stopped=False
    def poll(self):return self.code
    def terminate(self):self.stopped=True;self.code=0
    def wait(self,timeout=2):return self.code


class FakeRuntime:
    def __init__(self):
        self.events=[];self.ticks=0;self.accept_after=.1;self.has_hypr=True;self.has_greeter=True
        self.support={'CanSuspend':'yes','CanReboot':'yes','CanPowerOff':'yes'}
        self.process=FakeProcess()
    def session(self):self.events.append('session');return {'Id':'owned','User':str(os.getuid())}
    def hyprland(self):return self.has_hypr
    def greeter(self):return self.has_greeter
    def bus(self,method,*args):self.events.append(method);return self.support[method]
    def suspend_to_greeter(self):self.events.append('inhibit-suspend-worker')
    def start_suspend(self):self.events.append('Suspend');return self.process
    def preparing_for_sleep(self):return self.accept_after is not None and self.ticks>=self.accept_after
    def clock(self):return self.ticks
    def wait(self):self.ticks+=.1
    def exit_compositor(self):self.events.append('logout-current-compositor')
    def finish_session_for_sleep(self,identifier):
        assert identifier=='owned'
        self.exit_compositor()
    def run(self,args,timeout=12):self.events.append(tuple(args));return ''


class SessionActionTests(unittest.TestCase):
    def test_lock_signs_out_to_greeter_without_a_locker(self):
        runtime=FakeRuntime();result=session.perform('lock',runtime)
        self.assertTrue(result['ok']);self.assertIn('logout-current-compositor',runtime.events)
    def test_suspend_uses_delay_inhibitor_worker(self):
        runtime=FakeRuntime();session.perform('suspend',runtime)
        self.assertIn('inhibit-suspend-worker',runtime.events)
        self.assertNotIn('logout-current-compositor',runtime.events)
    def test_worker_waits_for_sleep_acceptance_before_signout(self):
        runtime=FakeRuntime();session.suspend_greeter(runtime)
        self.assertLess(runtime.events.index('Suspend'),runtime.events.index('logout-current-compositor'))
        self.assertGreaterEqual(runtime.ticks,.1)
    def test_sleep_denial_keeps_current_session_open(self):
        runtime=FakeRuntime();runtime.process.code=1
        with self.assertRaisesRegex(session.ActionError,'refused'):session.suspend_greeter(runtime)
        self.assertNotIn('logout-current-compositor',runtime.events)
    def test_sleep_authorization_timeout_keeps_session_open(self):
        runtime=FakeRuntime();runtime.accept_after=None
        with self.assertRaisesRegex(session.ActionError,'not accepted'):session.suspend_greeter(runtime)
        self.assertNotIn('logout-current-compositor',runtime.events);self.assertTrue(runtime.process.stopped)
    def test_missing_greeter_disables_signout_actions(self):
        runtime=FakeRuntime();runtime.has_greeter=False
        for action in ('lock','logout','suspend'):
            self.assertFalse(session.snapshot(runtime)['actions'][action]['available'])
            with self.assertRaises(session.ActionError):session.perform(action,runtime)
    def test_unavailable_suspend_does_not_signout(self):
        runtime=FakeRuntime();runtime.support['CanSuspend']='na'
        with self.assertRaisesRegex(session.ActionError,'not supported'):session.perform('suspend',runtime)
        self.assertNotIn('inhibit-suspend-worker',runtime.events)
    def test_logout_ends_only_the_current_compositor(self):
        runtime=FakeRuntime();session.perform('logout',runtime)
        self.assertIn('logout-current-compositor',runtime.events)
        self.assertFalse(any(isinstance(event,tuple) for event in runtime.events))
    def test_existing_reboot_and_poweroff_routes_are_retained(self):
        for action in ['reboot','poweroff']:
            runtime=FakeRuntime();session.perform(action,runtime)
            self.assertIn(('systemctl','--no-ask-password',action),runtime.events)
    def test_every_dry_run_is_non_disruptive(self):
        for action in session.ACTIONS:
            runtime=FakeRuntime();result=session.perform(action,runtime,dry_run=True)
            self.assertTrue(result['dryRun'])
            self.assertNotIn('locker',runtime.events);self.assertNotIn('Suspend',runtime.events)
            self.assertNotIn('logout-current-compositor',runtime.events)
            self.assertFalse(any(isinstance(event,tuple) for event in runtime.events))
    def test_arbitrary_action_is_rejected(self):
        runtime=FakeRuntime()
        with self.assertRaises(session.ActionError):session.perform('logout; bad',runtime)
        self.assertEqual(runtime.events,[])
    def test_stale_or_foreign_environment_session_is_not_used(self):
        runtime=session.Runtime();uid=os.getuid()
        rows={'foreign':{'Id':'foreign','User':str(uid+1),'Type':'wayland','Class':'user','Active':'yes'},'own':{'Id':'own','User':str(uid),'Type':'wayland','Class':'user','Active':'yes'}}
        with patch.dict(os.environ,{'XDG_SESSION_ID':'foreign'}),patch.object(runtime,'properties',side_effect=lambda key:rows[key]),patch.object(runtime,'bus',return_value=[['own',uid,'user','seat0','/own']]):
            self.assertEqual(runtime.session()['Id'],'own')
    def test_ambiguous_graphical_sessions_are_rejected(self):
        runtime=session.Runtime();uid=os.getuid()
        with patch.dict(os.environ,{'XDG_SESSION_ID':''}),patch.object(runtime,'properties',side_effect=lambda key:{'Id':key,'User':str(uid),'Type':'wayland','Class':'user','Active':'yes'}),patch.object(runtime,'bus',return_value=[['one',uid],['two',uid]]):
            with self.assertRaisesRegex(session.ActionError,'safely'):runtime.session()
    def test_sleep_is_wrapped_in_a_delay_inhibitor_without_service_changes(self):
        runtime=session.Runtime()
        with patch.object(session.shutil,'which',return_value='/usr/bin/systemd-inhibit'),patch.object(runtime,'run') as run:
            runtime.suspend_to_greeter()
            args=run.call_args.args[0]
            self.assertEqual(args[0],'systemd-inhibit');self.assertIn('--mode=delay',args)
            self.assertIn('--what=sleep',args);self.assertEqual(args[-1],'suspend-greeter')
            self.assertNotIn('sudo',args);self.assertNotIn('systemd-run',args)
    def test_sleep_waits_for_compositor_exit_before_releasing_inhibitor(self):
        runtime=session.Runtime()
        with patch.object(runtime,'exit_compositor') as exit_,patch.object(runtime,'hyprland',side_effect=[True,False]),patch.object(runtime,'wait') as wait:
            runtime.finish_session_for_sleep('owned')
            exit_.assert_called_once();wait.assert_called_once()
    def test_sleep_exit_fallback_targets_only_validated_session(self):
        runtime=session.Runtime()
        with patch.object(runtime,'exit_compositor',side_effect=session.ActionError('refused')),patch.object(runtime,'run') as run:
            runtime.finish_session_for_sleep('owned')
            run.assert_called_once_with(['loginctl','terminate-session','owned'])
    def test_readonly_greeter_and_prepare_flags_use_actual_bus_formats(self):
        runtime=session.Runtime()
        with patch.object(runtime,'run',return_value=json.dumps({'type':'ao','data':['/org/freedesktop/DisplayManager/Seat0']})):
            self.assertTrue(runtime.greeter())
        with patch.object(runtime,'run',return_value=json.dumps({'type':'b','data':False})):
            self.assertFalse(runtime.preparing_for_sleep())
        with patch.object(runtime,'run',return_value=json.dumps({'type':'b','data':True})):
            self.assertTrue(runtime.preparing_for_sleep())
    def test_authorization_failure_is_actionable(self):
        result=subprocess.CompletedProcess([],1,'','Interactive authentication required')
        with patch.object(session.subprocess,'run',return_value=result):
            with self.assertRaisesRegex(session.ActionError,'authorization'):session.Runtime().run(['fixed-command'])
    def test_incomplete_bus_reply_has_a_readable_error(self):
        runtime=session.Runtime()
        with patch.object(runtime,'run',return_value='{}'):
            with self.assertRaisesRegex(session.ActionError,'could not be read'):runtime.bus('CanSuspend')
    def test_successful_void_suspend_reply_is_not_treated_as_a_failure(self):
        result=subprocess.CompletedProcess([],0,'','')
        with patch.object(session.subprocess,'run',return_value=result):
            self.assertIsNone(session.Runtime().bus('Suspend'))
    def test_suspend_uses_interactive_authorization_without_forcing(self):
        result=subprocess.CompletedProcess([],0,json.dumps({'type':'','data':[None]}),'')
        with patch.object(session.subprocess,'run',return_value=result) as run:
            session.Runtime().bus('Suspend')
            args=run.call_args.args[0]
            self.assertIn('--allow-interactive-authorization=yes',args)
            self.assertEqual(args[-3:],['Suspend','b','true'])
            self.assertFalse(any('force' in arg or 'inhibitors=no' in arg for arg in args))


if __name__=='__main__':unittest.main()
