#!/usr/bin/env python3
"""Return to the system login screen; scoped sleep and session actions.

Lock intentionally signs out, as requested by the owner. Suspend signs out
behind a logind sleep-delay inhibitor, so waking returns to the boot greeter.
No credentials, service configuration or compositor files are changed.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import sys
from displayctl import ipc

ACTIONS=('lock','suspend','logout','reboot','poweroff')
DEST='org.freedesktop.login1'
MANAGER='/org/freedesktop/login1'
IFACE='org.freedesktop.login1.Manager'


class ActionError(ValueError):
    pass


class Runtime:
    def run(self,args,timeout=12):
        try:
            result=subprocess.run(args,stdin=subprocess.DEVNULL,capture_output=True,text=True,timeout=timeout)
        except subprocess.TimeoutExpired:
            raise ActionError('The session request timed out. Check the desktop authorization prompt and try again.') from None
        except OSError:
            raise ActionError('A required session tool is unavailable.') from None
        if result.returncode:
            text=' '.join(result.stderr.split())[:320]
            if re.search('authenti|permission|access denied|not authorized',text,re.I):
                raise ActionError('The session request needs authorization or was denied. Check the desktop authentication prompt.')
            raise ActionError(text or 'The session request was refused.')
        return result.stdout

    def bus(self,method,*args):
        signature=['s',args[0]] if method=='GetSession' else ['b','true'] if method=='Suspend' else []
        raw=self.run(['busctl','--system','--json=short','--allow-interactive-authorization=yes','call',DEST,MANAGER,IFACE,method]+signature,timeout=45 if method=='Suspend' else 8)
        # Successful void D-Bus calls may produce no JSON at all.
        if method=='Suspend':return None
        result=json.loads(raw)
        if not isinstance(result,dict) or not isinstance(result.get('data'),list) or not result['data']:
            raise ActionError('The system session service could not be read.')
        return result['data'][0]

    def properties(self,identifier):
        text=self.run(['loginctl','show-session',identifier,'-p','Id','-p','User','-p','Type','-p','Class','-p','Active','-p','Remote'])
        return dict(line.split('=',1) for line in text.splitlines() if '=' in line)

    def session(self):
        preferred=os.environ.get('XDG_SESSION_ID','')
        def eligible(identifier):
            if not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}',identifier):return None
            try:value=self.properties(identifier)
            except ActionError:return None
            if value.get('Id')!=identifier or value.get('User')!=str(os.getuid()) or value.get('Type') not in ('wayland','x11') or value.get('Class')!='user' or value.get('Active')!='yes' or value.get('Remote')=='yes':return None
            return value
        if preferred:
            selected=eligible(preferred)
            if selected:return selected
        candidates=[]
        for entry in self.bus('ListSessions'):
            if len(entry)>=2 and entry[1]==os.getuid():
                selected=eligible(entry[0])
                if selected:candidates.append(selected)
        if len(candidates)!=1:raise ActionError('The current graphical session could not be identified safely.')
        return candidates[0]

    def hyprland(self):
        if not os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):return False
        try:return bool(json.loads(ipc('j/version')).get('version'))
        except (OSError,ValueError,RuntimeError):return False

    def greeter(self):
        try:
            seats=json.loads(self.run(['busctl','--system','--json=short','get-property',
                'org.freedesktop.DisplayManager','/org/freedesktop/DisplayManager',
                'org.freedesktop.DisplayManager','Seats']))['data']
            return bool(seats)
        except (ActionError,ValueError,KeyError,TypeError):return False

    def suspend_to_greeter(self):
        if not shutil.which('systemd-inhibit'):
            raise ActionError('Sleep coordination is unavailable. Return to login, then use the login screen to sleep.')
        self.run(['systemd-inhibit','--what=sleep','--mode=delay','--who=SwiftShell',
                  '--why=Return to the login screen before sleeping',
                  sys.executable,str(Path(__file__).resolve()),'suspend-greeter'],timeout=65)

    def start_suspend(self):
        return subprocess.Popen(['busctl','--system','--allow-interactive-authorization=yes','call',
            DEST,MANAGER,IFACE,'Suspend','b','true'],stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)

    def preparing_for_sleep(self):
        raw=self.run(['busctl','--system','--json=short','get-property',DEST,MANAGER,IFACE,'PreparingForSleep'])
        return json.loads(raw).get('data') is True

    def clock(self):return time.monotonic()
    def wait(self):time.sleep(.08)
    def exit_compositor(self):
        if ipc('eval hl.dispatch(hl.dsp.exit())').strip()!='ok':raise ActionError('The compositor refused to end this session.')

    def finish_session_for_sleep(self,identifier):
        # Keep the inhibitor until the compositor is gone, not just until its
        # exit request is acknowledged. Fallback is scoped to our validated ID.
        try:self.exit_compositor()
        except (ActionError,OSError,RuntimeError):
            self.run(['loginctl','terminate-session',identifier]);return
        deadline=self.clock()+2
        while self.hyprland():
            if self.clock()>=deadline:
                self.run(['loginctl','terminate-session',identifier]);return
            self.wait()


def capability(runtime,method):
    try:
        answer=runtime.bus(method)
        if answer in ('yes','challenge'):return {'available':True,'reason':''}
        return {'available':False,'reason':'This action is not supported by the system.' if answer=='na' else 'This action is not permitted in this session.'}
    except (ActionError,ValueError,KeyError,TypeError):return {'available':False,'reason':'The system session service is unavailable.'}


def snapshot(runtime=None):
    runtime=runtime or Runtime()
    try:session=runtime.session();session_error=''
    except ActionError as error:session=None;session_error=str(error)
    hypr=runtime.hyprland()
    greeter=runtime.greeter()
    reason='' if session and hypr and greeter else session_error or 'The system login screen is unavailable.'
    actions={key:{'available':not reason,'reason':reason} for key in ('lock','logout')}
    for action,method in [('suspend','CanSuspend'),('reboot','CanReboot'),('poweroff','CanPowerOff')]:actions[action]=capability(runtime,method)
    if actions['suspend']['available'] and reason:actions['suspend']={'available':False,'reason':reason}
    return {'ok':True,'actions':actions}


def suspend_greeter(runtime=None):
    """Executed under systemd-inhibit's delay FD; never sleeps before acceptance.

    Request Suspend while the graphical session/authorization agent still exists.
    Only after logind acknowledges PreparingForSleep do we end this compositor.
    The inhibitor delays physical sleep until this command/session exits. No new
    service, elevated helper or persistent sleep hook is installed.
    """
    runtime=runtime or Runtime()
    owned=runtime.session()
    if not runtime.hyprland() or not runtime.greeter():
        raise ActionError('The current desktop cannot return to the login screen.')
    process=runtime.start_suspend()
    deadline=runtime.clock()+45
    try:
        while not runtime.preparing_for_sleep():
            if process.poll() is not None:
                raise ActionError('Sleep was refused or authorization was cancelled. Your desktop is still open.')
            if runtime.clock()>=deadline:
                raise ActionError('Sleep was not accepted. Your desktop is still open.')
            runtime.wait()
        runtime.finish_session_for_sleep(owned['Id'])
    finally:
        # Releasing the delay inhibitor completes an accepted sleep request.
        # Before acceptance, stop a pending authorization request on error.
        if process.poll() is None:
            process.terminate()
            try:process.wait(timeout=2)
            except subprocess.TimeoutExpired:process.kill();process.wait()


def perform(action,runtime=None,dry_run=False):
    if action not in ACTIONS:raise ActionError('Choose a supported session action.')
    runtime=runtime or Runtime()
    state=snapshot(runtime)
    target=state['actions'][action]
    if not target['available']:raise ActionError(target['reason'])
    # Resolve/verify again at the point of action; never terminate another user
    # or trust a stale session id from the shell environment.
    runtime.session()
    if dry_run:
        return {'ok':True,'dryRun':True,'action':action,'route':{'lock':'current-hyprland-exit-to-greeter','suspend':'inhibited-signout-logind-suspend','logout':'current-hyprland-exit','reboot':'systemctl-reboot','poweroff':'systemctl-poweroff'}[action]}
    if action=='suspend':runtime.suspend_to_greeter()
    elif action in ('lock','logout'):runtime.exit_compositor()
    elif action in ('reboot','poweroff'):runtime.run(['systemctl','--no-ask-password',action],timeout=45)
    return {'ok':True,'action':action,'message':{'lock':'Signing out to the system login screen…','suspend':'Suspend was accepted by the system.','logout':'Ending this desktop session…','reboot':'Restart was requested.','poweroff':'Shut down was requested.'}[action]}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=('snapshot','suspend-greeter')+ACTIONS)
    parser.add_argument('--dry-run',action='store_true')
    args=parser.parse_args()
    try:
        if args.action=='suspend-greeter':
            if args.dry_run:raise ActionError('Use suspend --dry-run to inspect this action.')
            suspend_greeter();result={'ok':True}
        else:result=snapshot() if args.action=='snapshot' else perform(args.action,dry_run=args.dry_run)
        print(json.dumps(result,separators=(',',':')))
    except (ActionError,ValueError,KeyError,TypeError,OSError) as error:
        message=str(error) if isinstance(error,ActionError) else 'Session controls are unavailable. Refresh and try again.'
        print(json.dumps({'ok':False,'message':message}));return 1
    return 0


if __name__=='__main__':raise SystemExit(main())
