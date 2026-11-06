#!/usr/bin/env python3
"""Native session UI/Process regression with a deliberately non-operational backend.

The copied helper only records action IDs and returns a synthetic refusal. This
fixture can never invoke a real lock, sleep, logout, restart or power-off request.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--live',action='store_true',required=True)
    parser.parse_args()
    root=Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix='swiftshell-session-native-') as temporary:
        folder=Path(temporary);shell=folder/'shell';shutil.copytree(root/'shell',shell)
        config=folder/'config/swiftshell';config.mkdir(parents=True)
        shutil.copy2(root/'shell/config/defaults.json',config/'settings.json')
        # Never delegate mutations to the production helper during a UI test.
        (shell/'helpers/sessionctl.py').write_text('''import json,os,sys
from pathlib import Path
action=sys.argv[1]
with (Path(os.environ["SWIFTSHELL_SESSION_FIXTURE"])/"operations.log").open("a") as stream:stream.write(action+"\\n")
if action=="snapshot":
 print(json.dumps({"ok":True,"actions":{key:{"available":True,"reason":""} for key in ["lock","suspend","logout","reboot","poweroff"]}}))
else:
 print(json.dumps({"ok":False,"message":"Owned fixture refused "+action+"; no system action was performed."}));sys.exit(1)
''')
        qml=shell/'Audit.qml'
        qml.write_text('''//@ pragma ShellId swiftshell-session-action-audit
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"
import "popovers"
ShellRoot {
 PanelWindow {
  screen:Quickshell.screens.find(function(s){return s.name==="HDMI-A-1"}) || Quickshell.screens[0]
  anchors {top:true;left:true} margins {top:60;left:80}
  exclusionMode:ExclusionMode.Ignore
  WlrLayershell.namespace:"swiftshell-owned-session-audit"
  WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
  implicitWidth:340;implicitHeight:460;color:"#202020"
  PowerSection {id:section;x:20;y:20;width:300}
 }
 TestCase {id:finder;when:false}
 IpcHandler {
  target:"audit"
  function activate(id:string):bool {const item=finder.findChild(section,"session-action-"+id);if(!item || !item.enabled)return false;item.activated();return true}
  function launcher(id:string):void {LauncherModel.runPower(id)}
  function state():string {return JSON.stringify({ready:SessionActions.ready,busy:SessionActions.busy,refreshing:SessionActions.refreshing,confirm:section.confirmId,error:SessionActions.error,status:finder.findChild(section,"sessionActionStatus").text,launcherNotice:LauncherModel.notice,launcherConfirm:LauncherModel.confirmId})}
  function quit():void {Qt.quit()}
 }
}
''')
        env=dict(os.environ,XDG_CONFIG_HOME=str(config.parent),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'),SWIFTSHELL_SESSION_FIXTURE=str(folder))
        command=['qs','ipc','-p',str(qml),'call','audit']
        def call(*args):return subprocess.check_output(command+list(args),env=env,text=True,stderr=subprocess.DEVNULL).strip()
        def state():return json.loads(call('state'))
        def operations():return (folder/'operations.log').read_text().splitlines()
        def wait(predicate):
            for _ in range(120):
                try:
                    if predicate():return
                except (subprocess.CalledProcessError,ValueError,FileNotFoundError):pass
                time.sleep(.05)
            raise AssertionError('Native session action fixture did not settle.')
        with (folder/'runtime.log').open('w') as log:
            process=subprocess.Popen(['qs','-p',str(qml)],env=env,stdout=log,stderr=log)
            try:
                wait(lambda:state()['ready'] and not state()['refreshing'])
                assert call('activate','logout')=='true'
                assert state()['confirm']=='logout' and 'logout' not in operations()
                assert call('activate','logout')=='true'
                wait(lambda:not state()['busy'] and 'refused logout' in state()['error'])
                assert state()['status']==state()['error']
                assert call('activate','lock')=='true'
                assert state()['confirm']=='lock'
                assert call('activate','lock')=='true'
                wait(lambda:not state()['busy'] and 'refused lock' in state()['error'])
                assert operations().count('lock')==1
                for _ in range(2):assert call('activate','suspend')=='true'
                wait(lambda:not state()['busy'] and 'refused suspend' in state()['status'])
                call('launcher','logout');assert state()['launcherConfirm']=='logout'
                call('launcher','logout')
                wait(lambda:not state()['busy'] and 'refused logout' in state()['launcherNotice'])
                assert operations().count('logout')==2 and operations().count('suspend')==1
                assert set(operations())=={'snapshot','lock','suspend','logout'}
                call('quit');process.wait(timeout=4)
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:process.wait(timeout=3)
                    except subprocess.TimeoutExpired:process.kill();process.wait()
        text=(folder/'runtime.log').read_text()
        assert not any(error in text for error in ['TypeError','ReferenceError','Binding loop','Failed to load configuration']),text
        print('PASS native session UI: logout confirmation, confirmed return-to-login, suspend refusal, shared Spotlight/bar errors; no real system action',flush=True)


if __name__=='__main__':main()
