#!/usr/bin/env python3
"""Actual Quickshell notification protocol in a private D-Bus session; never owns the desktop bus."""
import argparse,json,os,re,shutil,subprocess,sys,tempfile,time
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.add_argument('--isolated',action='store_true');args=parser.parse_args()
if not args.isolated:
    subprocess.run(['dbus-run-session','--',sys.executable,__file__,'--live','--isolated'],check=True)
    raise SystemExit()
root=Path(__file__).parents[2]
with tempfile.TemporaryDirectory(prefix='swiftshell-notification-protocol-') as directory:
    folder=Path(directory);shutil.copytree(root/'shell',folder/'shell')
    config=folder/'config/swiftshell';config.mkdir(parents=True)
    prefs=json.loads((root/'shell/config/defaults.json').read_text());prefs['notifications']['ownership']='on'
    (config/'settings.json').write_text(json.dumps(prefs))
    qml='''//@ pragma UseQApplication
//@ pragma ShellId swiftshell-notification-protocol-audit
import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "notifications"
Scope {
    Component.onCompleted:Quickshell.watchFiles=false
    NotificationHost {id:host;visible:false}
    Connections {target:SettingsStore;function onNotificationOwnershipChanged(){NotificationsModel.refreshConfiguration()}}
    IpcHandler {
        target:"audit"
        function state():string{return JSON.stringify({ready:SettingsStore.persistenceState==="ready",live:NotificationsModel.center.live.length,history:NotificationsModel.center.history.length,natives:host.nativeList.length,entries:NotificationsModel.entries.map(function(item){return {id:item.id,nativeAlive:item.nativeAlive,actions:item.actions.length,expireMs:item.expireMs,snoozedUntil:item.snoozedUntil}})})}
        function action(id:int):void{NotificationsModel.invoke(id,"default")}
        function snooze(id:int):void{NotificationsModel.snooze(id,5)}
        function wake(id:int):void{NotificationsModel.showNow(id)}
        function quiet(value:bool):void{SettingsStore.setNotificationDnd(value);NotificationsModel.refreshConfiguration()}
    }
}
'''
    audit=folder/'shell/NotificationAudit.qml';audit.write_text(qml)
    env=dict(os.environ,QT_QPA_PLATFORMTHEME='generic',QT_NO_XDG_DESKTOP_PORTAL='1',NO_AT_BRIDGE='1',XDG_CONFIG_HOME=str(folder/'config'),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'))
    log=folder/'runtime.log'
    with log.open('w') as output:
        process=subprocess.Popen(['qs','-p',str(audit)],env=env,stdout=output,stderr=subprocess.STDOUT)
        action_client=None
        try:
            command=['qs','ipc','-p',str(audit),'call','audit']
            def call(*argv):return subprocess.check_output(command+list(map(str,argv)),env=env,text=True,stderr=subprocess.DEVNULL)
            def state():return json.loads(call('state'))
            def wait(predicate):
                for _ in range(160):
                    try:
                        if predicate():return
                    except (subprocess.CalledProcessError,json.JSONDecodeError):pass
                    if process.poll() is not None:raise AssertionError('Native notification host exited')
                    time.sleep(.05)
                raise AssertionError('Notification state did not settle: '+json.dumps(state()))
            wait(lambda:state()['ready'])
            base=['gdbus','call','--session','--dest','org.freedesktop.Notifications','--object-path','/org/freedesktop/Notifications','--method']
            def notify(replaces=0,hints='{}',expiry=1000):
                reply=subprocess.check_output(base+['org.freedesktop.Notifications.Notify','SwiftShell Test',str(replaces),'','Protocol fixture','No user content',"['default', 'Open']",hints,str(expiry)],env=env,text=True)
                return int(re.search(r'uint32 (\d+)',reply).group(1))
            def entry(id):return next(item for item in state()['entries'] if item['id']==id)
            first=notify(expiry=0);wait(lambda:state()['live']==1)
            assert notify(first,expiry=0)==first
            wait(lambda:len(state()['entries'])==1)
            call('snooze',first);wait(lambda:state()['live']==0 and entry(first)['snoozedUntil']>0)
            call('wake',first);wait(lambda:state()['live']==1 and entry(first)['snoozedUntil']==0)
            subprocess.run(base+['org.freedesktop.Notifications.CloseNotification',str(first)],env=env,check=True,capture_output=True)
            wait(lambda:state()['live']==0 and not entry(first)['nativeAlive'])
            timed=notify();wait(lambda:state()['live']==1)
            wait(lambda:state()['live']==0 and entry(timed)['nativeAlive'] and entry(timed)['actions']==1)
            transient=notify(hints="{'transient': <true>}");wait(lambda:state()['live']==1)
            wait(lambda:state()['live']==0 and transient not in [item['id'] for item in state()['entries']])
            call('quiet','true');quiet=notify(expiry=0)
            wait(lambda:state()['live']==0 and entry(quiet)['nativeAlive'])
            call('quiet','false')
            action_client=subprocess.Popen(['notify-send','--wait','--action=default=Open','--expire-time=0','SwiftShell action test','No user content'],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
            wait(lambda:state()['live']==1)
            target=next(item['id'] for item in state()['entries'] if item['id'] not in [first,timed,quiet])
            call('action',target)
            stdout,stderr=action_client.communicate(timeout=3)
            assert action_client.returncode==0 and stdout.strip()=='default','Application did not receive its default action'
            for _ in range(70):notify(expiry=0)
            wait(lambda:state()['natives']<=64)
            assert state()['history']<=60 and state()['live']<=4
            print('PASS native private-bus notification receipt, replacement, timeout/history action retention, client close, transient, DND, snooze/wake, application action signal and bounded burst')
        finally:
            if action_client and action_client.poll() is None:action_client.terminate();action_client.wait(timeout=3)
            process.terminate()
            try:process.wait(timeout=5)
            except subprocess.TimeoutExpired:process.kill();process.wait(timeout=3)
    text=log.read_text()
    assert 'TypeError:' not in text and 'ReferenceError:' not in text and 'Binding loop' not in text,'Native QML runtime reported an error'
