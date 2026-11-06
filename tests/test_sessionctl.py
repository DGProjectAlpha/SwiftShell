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
    def __init__(self,code=None):self.code=code
    def poll(self):return self.code


class FakeRuntime:
    def __init__(self):
        self.events=[];self.is_locked=False;self.ticks=0;self.lock_after=.1;self.locker_code=None
        self.support={'CanSuspend':'yes','CanReboot':'yes','CanPowerOff':'yes'}
        self.provider=['hyprlock','--config','owned.conf'];self.has_hypr=True
    def session(self):self.events.append('session');return {'Id':'owned','User':str(os.getuid())}
    def hyprland(self):return self.has_hypr
    def locker(self):return self.provider
    def bus(self,method,*args):
        self.events.append(method)
        if method=='Suspend':
            if not self.is_locked:raise AssertionError('Sleep must not precede secure locking')
            return None
        return self.support[method]
    def locked(self):return self.is_locked
    def spawn_locker(self,command):self.events.append('locker');return FakeProcess(self.locker_code)
    def clock(self):return self.ticks
    def wait(self):
        self.ticks+=.1
        if self.lock_after is not None and self.ticks>=self.lock_after:self.is_locked=True
    def exit_compositor(self):self.events.append('logout-current-compositor')
    def run(self,args,timeout=12):self.events.append(tuple(args));return ''


class SessionActionTests(unittest.TestCase):
    def test_lock_requires_real_compositor_acknowledgement(self):
        runtime=FakeRuntime();result=session.perform('lock',runtime)
        self.assertTrue(result['ok']);self.assertTrue(runtime.is_locked)
        self.assertEqual(runtime.events.count('locker'),1)
    def test_existing_secure_lock_is_reused(self):
        runtime=FakeRuntime();runtime.is_locked=True
        self.assertTrue(session.perform('lock',runtime)['ok']);self.assertNotIn('locker',runtime.events)
    def test_suspend_waits_for_lock_and_uses_logind(self):
        runtime=FakeRuntime();session.perform('suspend',runtime)
        self.assertLess(runtime.events.index('locker'),runtime.events.index('Suspend'))
        self.assertFalse(any(isinstance(event,tuple) for event in runtime.events))
    def test_failed_locker_never_suspends(self):
        runtime=FakeRuntime();runtime.locker_code=1
        with self.assertRaisesRegex(session.ActionError,'exited before locking'):session.perform('suspend',runtime)
        self.assertNotIn('Suspend',runtime.events)
    def test_locker_timeout_never_reports_success_or_suspends(self):
        runtime=FakeRuntime();runtime.lock_after=None
        with self.assertRaisesRegex(session.ActionError,'did not confirm'):session.perform('suspend',runtime)
        self.assertNotIn('Suspend',runtime.events)
    def test_missing_locker_is_explained_in_both_capabilities(self):
        runtime=FakeRuntime();runtime.provider=None
        state=session.snapshot(runtime)
        for action in ['lock','suspend']:
            self.assertFalse(state['actions'][action]['available']);self.assertIn('Install hyprlock',state['actions'][action]['reason'])
        with self.assertRaises(session.ActionError):session.perform('lock',runtime)
    def test_suspend_denial_is_preserved_without_bypassing_inhibitors(self):
        runtime=FakeRuntime();original=runtime.bus
        def refused(method,*args):
            if method=='Suspend':raise session.ActionError('Sleep is inhibited by an application.')
            return original(method,*args)
        runtime.bus=refused
        with self.assertRaisesRegex(session.ActionError,'inhibited'):session.perform('suspend',runtime)
    def test_unavailable_suspend_does_not_lock_first(self):
        runtime=FakeRuntime();runtime.support['CanSuspend']='na'
        with self.assertRaisesRegex(session.ActionError,'not supported'):session.perform('suspend',runtime)
        self.assertNotIn('locker',runtime.events)
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
    def test_existing_user_locker_configuration_takes_precedence(self):
        with tempfile.TemporaryDirectory() as directory,patch.dict(os.environ,{'XDG_CONFIG_HOME':directory}),patch.object(session.shutil,'which',return_value='/usr/bin/hyprlock'):
            own=Path(directory)/'hypr/hyprlock.conf';own.parent.mkdir();own.write_text('# existing owner settings')
            command=session.Runtime().locker()
            self.assertEqual(command[-1],str(own));self.assertEqual(own.read_text(),'# existing owner settings')
            self.assertIn('--quiet',command);self.assertIn('--grace',command)
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
