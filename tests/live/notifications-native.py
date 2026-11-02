#!/usr/bin/env python3
"""Actual Quickshell notification protocol in a private D-Bus session; never owns the desktop bus."""
import argparse,json,os,re,shutil,subprocess,sys,tempfile,time,struct,zlib
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
    id:root
    property int soundEvents:0
    Connections {target:NotificationsModel;function onSoundPlayed(){root.soundEvents++}}
    Component.onCompleted:Quickshell.watchFiles=false
    NotificationHost {id:host;visible:false}
    Connections {target:SettingsStore;function onNotificationOwnershipChanged(){NotificationsModel.refreshConfiguration()}}
    IpcHandler {
        target:"audit"
        function state():string{return JSON.stringify({ready:SettingsStore.persistenceState==="ready",soundReady:NotificationsModel.soundReady,soundEvents:root.soundEvents,live:NotificationsModel.center.live.length,liveIds:NotificationsModel.center.live.map(function(item){return item.id}),quiet:NotificationsModel.quiet,quietUntil:SettingsStore.notificationQuietUntil,history:NotificationsModel.center.history.length,natives:host.nativeList.length,entries:NotificationsModel.entries.map(function(item){return {id:item.id,nativeAlive:item.nativeAlive,actions:item.actions.length,expireMs:item.expireMs,snoozedUntil:item.snoozedUntil,image:!!item.image,reply:item.hasInlineReply,suppressSound:item.suppressSound}})})}
        function action(id:int):void{NotificationsModel.invoke(id,"default")}
        function snooze(id:int):void{NotificationsModel.snooze(id,5)}
        function wake(id:int):void{NotificationsModel.showNow(id)}
        function reply(id:int,text:string):bool{return NotificationsModel.sendReply(id,text)}
        function preferences(value:string):bool{return SettingsStore.setNotificationPreferences(JSON.parse(value))}
        function local():void{NotificationsModel.publishLocal("Clock policy fixture","No user content","timer")}
        function shortSnooze(id:int):void{NotificationsModel.snooze(id,1/60)}
        function shortPause():void{SettingsStore.setNotificationPreferences({quietUntil:Date.now()+1000})}
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
            def notify(replaces=0,hints='{}',expiry=1000,actions="['default', 'Open']"):
                reply=subprocess.check_output(base+['org.freedesktop.Notifications.Notify','SwiftShell Test',str(replaces),'','Protocol fixture','No user content',actions,hints,str(expiry) if expiry>=0 else "int32 "+str(expiry)],env=env,text=True)
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
            # Local Clock entries share policy edits and scheduled quiet hours.
            call('local');wait(lambda:any(item['id']<0 for item in state()['entries']))
            call('quiet','true');wait(lambda:state()['live']==0)
            call('quiet','false');assert state()['live']==0
            assert call('preferences',json.dumps({'quietHoursEnabled':True,'quietStart':0,'quietEnd':0,'quietDays':127})).strip()=='true'
            scheduled=notify(expiry=0);wait(lambda:scheduled in [item['id'] for item in state()['entries']])
            assert state()['live']==0
            assert call('preferences',json.dumps({'quietHoursEnabled':False})).strip()=='true'
            # Native image/inline-reply transport, using a generated fixture only.
            def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
            image=folder/'owned.png';pixels=b''.join(b'\0'+b'\xaa\xaa\xaa'*32 for _ in range(16))
            image.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',32,16,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(pixels))+chunk(b'IEND',b''))
            image_hint="{'image-path': <"+repr(image.as_uri())+">, 'resident': <true>, 'suppress-sound': <true>}"
            rich=notify(hints=image_hint,expiry=0,actions="['default', 'Open', 'inline-reply', 'Reply to fixture']")
            wait(lambda:entry(rich)['image'] and entry(rich)['reply'] and entry(rich)['suppressSound'])
            monitor=subprocess.Popen(['gdbus','monitor','--session','--dest','org.freedesktop.Notifications','--object-path','/org/freedesktop/Notifications'],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
            try:
                time.sleep(.2)
                assert call('reply',rich,'owned inline reply').strip()=='true'
                time.sleep(.2)
            finally:monitor.terminate();events,errors=monitor.communicate(timeout=3)
            assert 'NotificationReplied' in events and 'owned inline reply' in events,'Native inline reply signal was not delivered'
            raw_image=notify(expiry=0,hints="{'image-data': <(int32 2, int32 2, int32 6, false, int32 8, int32 3, [byte 160, 160, 160, 80, 80, 80, 80, 80, 80, 160, 160, 160])>}")
            wait(lambda:entry(raw_image)['image'])
            subprocess.run(base+['org.freedesktop.Notifications.CloseNotification',str(raw_image)],env=env,check=True,capture_output=True)
            wait(lambda:not entry(raw_image)['image'])
            # Replacements settle before policy eviction; never close in a native property group.
            for index in range(15):assert notify(rich,hints=image_hint,expiry=0,actions="['inline-reply', 'Reply to fixture']")==rich
            wait(lambda:entry(rich)['reply'])
            subprocess.run(base+['org.freedesktop.Notifications.CloseNotification',str(rich)],env=env,check=True,capture_output=True)
            wait(lambda:not entry(rich)['nativeAlive'] and not entry(rich)['reply'] and not entry(rich)['image'])
            deadline=notify(expiry=0);wait(lambda:deadline in state()['liveIds'])
            call('shortSnooze',deadline);wait(lambda:entry(deadline)['snoozedUntil']>0)
            wait(lambda:entry(deadline)['snoozedUntil']==0 and deadline in state()['liveIds'])
            call('shortPause');wait(lambda:state()['quiet'] and state()['quietUntil']>0)
            wait(lambda:not state()['quiet'] and state()['quietUntil']==0)
            assert deadline not in state()['liveIds'],'Ending a pause must not replay archived banners'
            assert call('preferences',json.dumps({'soundEnabled':True,'soundVolume':0})).strip()=='true'
            wait(lambda:state()['soundReady'])
            normal_sound=notify(expiry=0);wait(lambda:state()['soundEvents']==1)
            notify(normal_sound,expiry=0);time.sleep(.6);assert state()['soundEvents']==1
            notify(hints="{'suppress-sound': <true>}",expiry=0);time.sleep(.6);assert state()['soundEvents']==1
            call('quiet','true');notify(hints="{'urgency': <byte 2>}",expiry=0);time.sleep(.6);assert state()['soundEvents']==1
            call('quiet','false');notify(expiry=0);wait(lambda:state()['soundEvents']==2)
            assert call('preferences',json.dumps({'soundEnabled':False})).strip()=='true'
            critical_default=notify(hints="{'urgency': <byte 2>}",expiry=-1)
            wait(lambda:entry(critical_default)['expireMs']==0 and critical_default in state()['liveIds'])
            for _ in range(70):notify(expiry=0)
            wait(lambda:state()['natives']<=64)
            assert state()['history']<=60 and state()['live']<=4
            print('PASS native private-bus notification receipt, replacement, timeout/history action retention, client close, transient, DND, snooze/wake, application action signal, Clock/DND/schedule policy, image/inline reply, replacement safety, deadline wake/pause expiry, silent/DND/replacement sound rules and bounded burst')
        finally:
            if action_client and action_client.poll() is None:action_client.terminate();action_client.wait(timeout=3)
            process.terminate()
            try:process.wait(timeout=5)
            except subprocess.TimeoutExpired:process.kill();process.wait(timeout=3)
    text=log.read_text()
    assert 'TypeError:' not in text and 'ReferenceError:' not in text and 'Binding loop' not in text,'Native QML runtime reported an error'
