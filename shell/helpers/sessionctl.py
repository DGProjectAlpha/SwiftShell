#!/usr/bin/env python3
"""Scoped session actions with a real lock barrier and visible backend failures.

No credentials are accepted here. Hyprlock owns its PAM conversation. No service,
compositor configuration or monitor setting is changed by this adapter.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
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

    def locked(self):
        try:return json.loads(ipc('j/locked')).get('locked') is True
        except (OSError,ValueError,RuntimeError):raise ActionError('The compositor could not confirm a secure screen lock.') from None

    def locker(self):
        executable=shutil.which('hyprlock')
        if not executable:return None
        config=Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'hypr/hyprlock.conf'
        if not config.is_file():config=Path(__file__).resolve().parents[1]/'config/hyprlock.conf'
        if not config.is_file():return None
        return [executable,'--quiet','--grace','0','--immediate-render','--config',str(config)]

    def spawn_locker(self,command):
        return subprocess.Popen(command,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)

    def clock(self):return time.monotonic()
    def wait(self):time.sleep(.08)
    def exit_compositor(self):
        if ipc('eval hl.dispatch(hl.dsp.exit())').strip()!='ok':raise ActionError('The compositor refused to end this session.')


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
    locker=runtime.locker() if hypr else None
    lock_reason='' if session and locker else session_error or ('Install hyprlock to enable secure locking.' if hypr else 'Secure locking is not available for this compositor.')
    actions={'lock':{'available':not lock_reason,'reason':lock_reason},'logout':{'available':bool(session and hypr),'reason':'' if session and hypr else session_error or 'Logout is not available for this compositor.'}}
    for action,method in [('suspend','CanSuspend'),('reboot','CanReboot'),('poweroff','CanPowerOff')]:actions[action]=capability(runtime,method)
    if actions['suspend']['available'] and lock_reason:actions['suspend']={'available':False,'reason':'Locking must be available before suspending. '+lock_reason}
    return {'ok':True,'actions':actions}


def lock(runtime):
    if runtime.locked():return
    command=runtime.locker()
    if not command:raise ActionError('Install hyprlock to enable secure locking.')
    try:process=runtime.spawn_locker(command)
    except OSError:raise ActionError('The screen locker could not be started.') from None
    deadline=runtime.clock()+10
    while runtime.clock()<deadline:
        if runtime.locked():return
        if process.poll() is not None:raise ActionError('The screen locker exited before locking. Check your lock-screen configuration.')
        runtime.wait()
    raise ActionError('The screen locker did not confirm a secure lock. The session action was cancelled.')


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
        return {'ok':True,'dryRun':True,'action':action,'route':{'lock':'hyprlock','suspend':'locked-logind-suspend','logout':'current-hyprland-exit','reboot':'systemctl-reboot','poweroff':'systemctl-poweroff'}[action]}
    if action in ('lock','suspend'):lock(runtime)
    if action=='suspend':
        if not runtime.locked():raise ActionError('The screen was unlocked before suspend. Sleep was cancelled.')
        runtime.bus('Suspend')
    elif action=='logout':runtime.exit_compositor()
    elif action in ('reboot','poweroff'):runtime.run(['systemctl','--no-ask-password',action],timeout=45)
    return {'ok':True,'action':action,'message':{'lock':'Screen locked.','suspend':'Suspend was accepted by the system.','logout':'Ending this desktop session…','reboot':'Restart was requested.','poweroff':'Shut down was requested.'}[action]}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=('snapshot',)+ACTIONS)
    parser.add_argument('--dry-run',action='store_true')
    args=parser.parse_args()
    try:
        result=snapshot() if args.action=='snapshot' else perform(args.action,dry_run=args.dry_run)
        print(json.dumps(result,separators=(',',':')))
    except (ActionError,ValueError,KeyError,TypeError,OSError) as error:
        message=str(error) if isinstance(error,ActionError) else 'Session controls are unavailable. Refresh and try again.'
        print(json.dumps({'ok':False,'message':message}));return 1
    return 0


if __name__=='__main__':raise SystemExit(main())
