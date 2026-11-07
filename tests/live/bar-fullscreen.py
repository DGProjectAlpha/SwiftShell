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
parser.add_argument('--allow-active-game',action='store_true',help='Owner-authorized HDMI-only fixture while DP-1 is gaming')
parser.add_argument('--input-check',action='store_true',help='Send clicks only to the owned HDMI fullscreen fixture/bar')
args=parser.parse_args()
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'shell/helpers'))
from displayctl import ipc,logical_size
monitors=json.loads(ipc('j/monitors'))
monitor=next((item for item in monitors if item['name']=='HDMI-A-1'),None)
assert monitor,'This gaming-safe fixture runs only on HDMI-A-1'
primary=next((item for item in monitors if item['name']=='DP-1'),None)
assert primary and (args.allow_active_game or primary['activeWorkspace'].get('name') in ['1','2','3']),'Do not map a fixture while the real gaming workspace is active without explicit authorization'
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
    original_cursor=json.loads(ipc('j/cursorpos'))
    original_focus=next(m['name'] for m in monitors if m.get('focused'))
    if args.input_check:
        protocol=root/'tests/protocols/wlr-virtual-pointer-unstable-v1.xml'
        subprocess.run(['wayland-scanner','client-header',str(protocol),str(folder/'pointer-client.h')],check=True)
        subprocess.run(['wayland-scanner','private-code',str(protocol),str(folder/'pointer-protocol.c')],check=True)
        subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(folder),str(root/'tests/helpers/settings-pointer.c'),str(folder/'pointer-protocol.c'),'-o',str(folder/'pointer'),'-lwayland-client'],check=True)
    shutil.copytree(root/'shell',folder/'shell')
    config=folder/'config/swiftshell';config.mkdir(parents=True)
    prefs=json.loads((root/'shell/config/defaults.json').read_text())
    prefs['bar']['showFocusedTitle']=False
    prefs['bar']['fullscreenPeek']=True
    prefs['bar']['reserveSpace']=False
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
 property int appClicks:0
 FloatingWindow {
  id:fixture
  screen:root.target
  title:"SwiftShell Fullscreen Stability Fixture"
  fullscreen:false;visible:false;color:"#151515";surfaceFormat.opaque:true
  Component.onCompleted:Qt.callLater(function(){fixture.visible=true})
  Rectangle {anchors.fill:parent;color:"#151515"}
  MouseArea {anchors.fill:parent;onClicked:root.appClicks++}
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
  function state():string{return JSON.stringify({appClicks:root.appClicks,clockTargets:bar.clockItem ? bar.clockItem.clickTargets() : null,bar:bar.renderingDiagnostics(),connections:root.connections,dismissals:root.dismissals,width:bar.width,height:bar.height,menu:bar.menuDiagnostics(),ready:SettingsStore.persistenceState==="ready"})}
  function panel():void{bar.showPanel("clock")}
  function fullscreen():void{fixture.fullscreen=true}
  function unfullscreen():void{fixture.fullscreen=false}
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
        def click_clock_position():
            owned=client()
            current=next(m for m in json.loads(ipc('j/monitors')) if m['name']==monitor['name'])
            assert owned and owned['pid']==process.pid and owned['monitor']==monitor['id'] and owned['fullscreen']==2
            assert owned['workspace']['address']==current['activeWorkspace']['address'],'Owned fixture is no longer visible; refusing input'
            rect=state()['clockTargets']['time']
            native=layer()
            origin=native[1] if native else monitor
            x=round(origin['x']-monitor['x']+rect['x']+rect['width']/2)
            y=round(origin['y']-monitor['y']+rect['y']+rect['height']/2)
            # A newly mapped layer beneath a stationary pointer does not imply
            # a fresh pointer enter. Approach it from inside our owned client.
            assert ipc('eval hl.dispatch(hl.dsp.cursor.move({x='+str(monitor['x']+x)+',y='+str(monitor['y']+100)+'}))').strip()=='ok'
            command=[str(folder/'pointer'),str(x),str(y),str(round(width)),str(round(height)),'0','0',monitor['name'],str(monitor['x']+x),str(monitor['y']+y)]
            for _ in range(3):
                result=subprocess.run(command)
                if result.returncode==0:return
                if result.returncode!=6:result.check_returncode()
                time.sleep(.15)
            result.check_returncode()
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
            assert client()['fullscreen']==2 and baseline_layer is None
            assert not initial['bar']['peek']
            assert not initial['bar']['acceptsInput']
            if args.input_check:
                click_clock_position()
                wait(lambda:state()['appClicks']==1,'Hidden bar stole the fullscreen application click')
                assert not state()['menu']['visible']
            cursor(monitor['x']+width/2,monitor['y']+1)
            wait(lambda:state()['bar']['peek'] and (row:=layer()) and row[0]==3 and row[1]['alpha']==1,'Edge intent did not visibly reveal the bar above the owned fullscreen client')
            revealed=state()
            assert revealed['bar']['acceptsInput']
            if args.input_check:
                click_clock_position()
                wait(lambda:state()['menu']['visible'],'Revealed bar did not accept its Clock click; '+json.dumps({k:v for k,v in state().items() if k in ('appClicks','clockTargets','width','height','menu')}))
                assert state()['appClicks']==1,'Revealed bar leaked its click to the application'
                call('dismiss')
                wait(lambda:not state()['menu']['visible'],'Clock popup did not dismiss')
            # A hidden surface can be frame-throttled indefinitely. A scoped
            # remap commits its overlay role without waiting for game frames.
            assert (revealed['width'],revealed['height'])==(initial['width'],initial['height'])
            assert client()['fullscreen']==2
            cursor(monitor['x']+width/2,monitor['y']+height/2)
            wait(lambda:not state()['bar']['peek'] and layer() is None,'Hidden bar remained mapped after leaving')
            assert not state()['bar']['acceptsInput']
            if args.input_check:
                click_clock_position()
                wait(lambda:state()['appClicks']==2,'Hidden bar stole a click after closing peek')
            call('panel')
            wait(lambda:state()['menu']['visible'],'Owned Clock panel did not open')
            call('dismiss')
            wait(lambda:not state()['menu']['visible'] and state()['dismissals']==(2 if args.input_check else 1),'Shared blank-bar dismissal did not close the native panel')
            assert client()['fullscreen']==2
            call('unfullscreen')
            wait(lambda:not state()['bar']['fullscreen'] and state()['bar']['acceptsInput'] and layer() is not None,'Normal desktop bar did not restore after fullscreen')
            output=(folder/'runtime.log').read_text()
            assert not any(error in output for error in ['TypeError','ReferenceError','Binding loop','Failed to load configuration'])
            print('PASS HDMI owned fullscreen: real metadata, visible overlay peek at alpha=1, stable size, hidden surface absent, normal desktop restoration and shared popout dismissal; no game input',flush=True)
            if args.input_check:print('PASS native input: hidden bar passes clicks to the owned fullscreen app; revealed Clock consumes its click; hiding restores click-through',flush=True)
        except Exception:
            Path('/tmp/swiftshell-fullscreen-bar-runtime.log').write_text((folder/'runtime.log').read_text())
            raise
        finally:
            try:
                if args.input_check:
                    ipc('eval hl.dispatch(hl.dsp.cursor.move({x='+str(original_cursor['x'])+',y='+str(original_cursor['y'])+'}))')
                    ipc('eval hl.dispatch(hl.dsp.focus({monitor='+json.dumps(original_focus)+'}))')
            finally:
                process.terminate()
                try:process.wait(timeout=3)
                except subprocess.TimeoutExpired:process.kill();process.wait()
