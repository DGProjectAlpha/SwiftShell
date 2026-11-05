#!/usr/bin/env python3
"""Owned HDMI fullscreen fixture; inject cursor samples only into its private helper."""
import argparse
from contextlib import contextmanager
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

parser=argparse.ArgumentParser()
parser.add_argument('--live',action='store_true',required=True)
parser.parse_args()
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'shell/helpers'))
from displayctl import ipc,logical_size
monitors=json.loads(ipc('j/monitors'))
monitor=next((item for item in monitors if item['name']=='HDMI-A-1'),None)
assert monitor,'This gaming-safe fixture runs only on HDMI-A-1'
primary=next((item for item in monitors if item['name']=='DP-1'),None)
assert primary and primary['activeWorkspace'].get('name') in ['1','2','3'],'Do not map a fixture while the real gaming workspace is active'
assert monitor['activeWorkspace'].get('name') in ['4','5','6'],'HDMI workspace must be one of the owner-approved test workspaces'
width,height=logical_size(monitor)
fixture_title='SwiftShell Fullscreen Stability Fixture '+str(os.getpid())


@contextmanager
def fixture_rule():
    # Wayland's initial screen request alone is insufficient on this compositor.
    # Match only this unique owned fixture before mapping, as Settings does.
    variable='_G.__swiftshell_fullscreen_fixture_'+str(os.getpid())
    code=variable+'=hl.window_rule({name="swiftshell-fullscreen-fixture-'+str(os.getpid())+'",monitor='+json.dumps(monitor['name'])+',match={class='+json.dumps(r'^org\.quickshell$')+',title='+json.dumps('^'+fixture_title+'$')+'},no_initial_focus=true,no_anim=true,content="game"})'
    assert ipc('eval '+code).strip()=='ok','Could not prepare the owned HDMI fullscreen fixture'
    try:
        yield
    finally:
        assert ipc('eval if '+variable+' then '+variable+':set_enabled(false);'+variable+'=nil end').strip()=='ok'

with fixture_rule(),tempfile.TemporaryDirectory(prefix='swiftshell-fullscreen-bar-') as directory:
    folder=Path(directory)
    shutil.copytree(root/'shell',folder/'shell')
    config=folder/'config/swiftshell';config.mkdir(parents=True)
    prefs=json.loads((root/'shell/config/defaults.json').read_text())
    prefs['bar']['showFocusedTitle']=False
    prefs['bar']['fullscreenPeek']=True
    prefs['bar']['hiddenModules']=[name for name in prefs['bar']['moduleOrder'] if name not in ['clock','control']]
    (config/'settings.json').write_text(json.dumps(prefs))
    # The production cursor parser is unit-tested separately. This private helper
    # supplies logical coordinates without moving the physical pointer/game focus.
    point=folder/'shell/helpers/peek-point.json'
    def cursor(x,y):
        temporary=point.with_suffix('.tmp')
        temporary.write_text(json.dumps({'x':x,'y':y}))
        temporary.replace(point)
    cursor(monitor['x']+width/2,monitor['y']+height/2)
    (folder/'shell/helpers/cursorwatch.py').write_text('''import json,time
from pathlib import Path
p=Path(__file__).with_name('peek-point.json');old=None
while True:
 value=json.loads(p.read_text())
 if value!=old:print(json.dumps(value),flush=True);old=value
 time.sleep(.025)
''')
    qml=folder/'shell/FullscreenBarAudit.qml'
    qml.write_text('''//@ pragma ShellId swiftshell-fullscreen-bar-audit
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"
import "bar"
ShellRoot {
 id:root
 property var target:Quickshell.screens.find(function(screen){return screen.name==="HDMI-A-1"})
 property int connections:0
 property int dismissals:0
 FloatingWindow {
  id:fixture
  screen:root.target
  title:"SwiftShell Fullscreen Stability Fixture"
  fullscreen:false;visible:false;color:"#151515";surfaceFormat.opaque:true
  Component.onCompleted:Qt.callLater(function(){fixture.visible=true})
  Rectangle {anchors.fill:parent;color:"#151515"}
 }
 BarWindow {
  id:bar
  modelData:root.target
  WlrLayershell.namespace:"swiftshell-fullscreen-bar-audit"
  onWindowConnected:root.connections++
  onDismissPopoutsRequested:root.dismissals++
 }
 IpcHandler {
  target:"audit"
  function state():string{return JSON.stringify({bar:bar.renderingDiagnostics(),connections:root.connections,dismissals:root.dismissals,width:bar.width,height:bar.height,menu:bar.menuDiagnostics(),ready:SettingsStore.persistenceState==="ready"})}
  function panel():void{bar.showPanel("clock")}
  function fullscreen():void{fixture.fullscreen=true}
  function dismiss():void{bar.dismissPopouts()}
 }
 Timer {interval:20000;running:true;onTriggered:Qt.quit()}
}
'''.replace('SwiftShell Fullscreen Stability Fixture',fixture_title))
    env=dict(os.environ,XDG_CONFIG_HOME=str(folder/'config'),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'))
    with (folder/'runtime.log').open('w') as log:
        process=subprocess.Popen(['qs','-p',str(qml)],env=env,stdout=log,stderr=subprocess.STDOUT)
        command=['qs','ipc','-p',str(qml),'call','audit']
        def call(name):return subprocess.check_output(command+[name],text=True,stderr=subprocess.DEVNULL)
        def state():return json.loads(call('state'))
        def wait(predicate,message):
            for _ in range(100):
                if process.poll() is not None:raise AssertionError('Owned fixture exited before verification')
                try:
                    if predicate():return
                except (subprocess.CalledProcessError,ValueError,KeyError):pass
                time.sleep(.05)
            raise AssertionError(message)
        def client():return next((item for item in json.loads(ipc('j/clients')) if item.get('pid')==process.pid and item.get('title')==fixture_title),None)
        def layer():
            groups=json.loads(ipc('j/layers')).get('HDMI-A-1',{})
            return next(((int(level),item)for level,items in groups.get('levels',{}).items()for item in items if item.get('namespace')=='swiftshell-fullscreen-bar-audit'),None)
        try:
            wait(lambda:client() is not None,'Owned fullscreen client did not map')
            if client()['monitor']!=monitor['id']:
                owned=client()
                target=monitor['activeWorkspace'].get('id')
                assert target in [4,5,6] and owned['pid']==process.pid
                code='hl.dsp.window.move({window='+json.dumps('address:'+owned['address'])+',workspace='+str(target)+',follow=false})'
                assert ipc('eval hl.dispatch('+code+')').strip()=='ok'
                wait(lambda:client()['monitor']==monitor['id'],'The owned fixture did not move to its approved HDMI workspace')
            assert client()['monitor']==monitor['id'],'Owned fixture mapped away from HDMI; no input was sent: '+json.dumps({key:client().get(key)for key in ['class','initialClass','title','initialTitle','monitor','fullscreen']})
            call('fullscreen')
            wait(lambda:state()['ready'] and state()['bar']['fullscreen'],'Actual fullscreen metadata did not reach the owned bar')
            initial=state();baseline_layer=layer()
            assert client()['fullscreen']==2 and baseline_layer and baseline_layer[0]==2
            assert not initial['bar']['peek']
            cursor(monitor['x']+width/2,monitor['y']+1)
            wait(lambda:state()['bar']['peek'] and layer()[0]==3,'Edge intent did not reveal the bar above the owned fullscreen client')
            revealed=state()
            assert layer()[1]['address']==baseline_layer[1]['address'],'Peek recreated the native layer surface'
            assert revealed['connections']==initial['connections']
            assert (revealed['width'],revealed['height'])==(initial['width'],initial['height'])
            assert client()['fullscreen']==2
            cursor(monitor['x']+width/2,monitor['y']+height/2)
            wait(lambda:not state()['bar']['peek'] and layer()[0]==2,'Bar did not return below fullscreen after leaving')
            call('panel')
            wait(lambda:state()['menu']['visible'],'Owned Clock panel did not open')
            call('dismiss')
            wait(lambda:not state()['menu']['visible'] and state()['dismissals']==1,'Shared blank-bar dismissal did not close the native panel')
            assert client()['fullscreen']==2
            output=(folder/'runtime.log').read_text()
            assert not any(error in output for error in ['TypeError','ReferenceError','Binding loop','Failed to load configuration'])
            print('PASS HDMI owned fullscreen: real metadata, opt-in edge peek, same native layer/size, return below fullscreen and shared popout dismissal; no physical cursor or game input',flush=True)
        except Exception:
            Path('/tmp/swiftshell-fullscreen-bar-runtime.log').write_text((folder/'runtime.log').read_text())
            raise
        finally:
            process.terminate()
            try:process.wait(timeout=3)
            except subprocess.TimeoutExpired:process.kill();process.wait()
