#!/usr/bin/env python3
"""Observe cursor/scanout coupling between two strictly owned fullscreen clients."""
import argparse
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


def monitors():return json.loads(ipc('j/monitors'))
def clients():return json.loads(ipc('j/clients'))
def dispatch(code):assert ipc('eval hl.dispatch('+code+')').strip()=='ok'


initial=monitors()
selected=[next(m for m in initial if m['name']==name)for name in ['DP-1','HDMI-A-1']]
assert selected[0]['activeWorkspace'].get('name')in['1','2','3'],'Do not replace the real gaming workspace with a fixture'
assert selected[1]['activeWorkspace'].get('name')in['4','5','6'],'HDMI must use an owner-approved test workspace'
before_options={name:json.loads(ipc('j/getoption '+name)).get('int')for name in ['render:direct_scanout','misc:vrr']}
cursor=json.loads(ipc('j/cursorpos'))
previous_focus=json.loads(ipc('j/activewindow')).get('address')
prefix='SwiftShell Scanout Fixture '+str(os.getpid())+' '
rule_names=[]
records=[]
process=None
last_cursor=None
restore_input=False

try:
    for index,monitor in enumerate(selected):
        variable='_G.__swiftshell_scanout_fixture_'+str(os.getpid())+'_'+str(index)
        code=variable+'=hl.window_rule({name="swiftshell-scanout-fixture-'+str(os.getpid())+'-'+str(index)+'",monitor='+json.dumps(monitor['name'])+',match={class='+json.dumps(r'^org\.quickshell$')+',title='+json.dumps('^'+prefix+monitor['name']+'$')+'},no_initial_focus=true,no_anim=true,content="game"})'
        assert ipc('eval '+code).strip()=='ok'
        rule_names.append(variable)
    with tempfile.TemporaryDirectory(prefix='swiftshell-scanout-fixture-') as directory:
        folder=Path(directory)
        qml=folder/'Scanout.qml'
        qml.write_text('''//@ pragma ShellId swiftshell-scanout-audit
import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
 id:root
 property int tick:0
 FloatingWindow {
  id:first
  screen:Quickshell.screens.find(function(s){return s.name==="DP-1"})
  title:"TITLEDP-1";visible:true;fullscreen:false;color:"#171717";surfaceFormat.opaque:true
  Rectangle {anchors.fill:parent;color:root.tick%2 ? "#171717" : "#181818"}
 }
 FloatingWindow {
  id:second
  screen:Quickshell.screens.find(function(s){return s.name==="HDMI-A-1"})
  title:"TITLEHDMI-A-1";visible:true;fullscreen:false;color:"#171717";surfaceFormat.opaque:true
  Rectangle {anchors.fill:parent;color:root.tick%2 ? "#171717" : "#181818"}
 }
 IpcHandler {target:"audit";function fullscreen():void{first.fullscreen=true;second.fullscreen=true}}
 Timer {interval:50;running:true;repeat:true;onTriggered:root.tick++}
 Timer {interval:20000;running:true;onTriggered:Qt.quit()}
}
'''.replace('TITLE',prefix))
        with (folder/'runtime.log').open('w')as log:
            process=subprocess.Popen(['qs','-p',str(qml)],stdout=log,stderr=subprocess.STDOUT)
            def owned():return [c for c in clients()if c.get('pid')==process.pid and c.get('title','').startswith(prefix)]
            for _ in range(100):
                if len(owned())==2:break
                if process.poll()is not None:raise AssertionError('Owned scanout fixtures exited before mapping')
                time.sleep(.05)
            else:raise AssertionError('Owned scanout fixtures did not map')
            for monitor in selected:
                candidate=next(c for c in owned()if c['title']==prefix+monitor['name'])
                if candidate['monitor']!=monitor['id']:
                    target=monitor['activeWorkspace'].get('id')
                    assert target in [1,2,3,4,5,6] and candidate['pid']==process.pid
                    dispatch('hl.dsp.window.move({window='+json.dumps('address:'+candidate['address'])+',workspace='+str(target)+',follow=false})')
            for _ in range(100):
                if all(any(c['title']==prefix+m['name']and c['monitor']==m['id']for c in owned())for m in selected):break
                time.sleep(.05)
            else:raise AssertionError('A fixture stayed on an unexpected output; no cursor input was sent')
            subprocess.run(['qs','ipc','-p',str(qml),'call','audit','fullscreen'],check=True,capture_output=True)
            for _ in range(100):
                if all(c.get('fullscreen')==2 for c in owned()):break
                time.sleep(.05)
            else:raise AssertionError('Owned clients did not enter actual fullscreen')
            for monitor in selected*3:
                current=monitors()
                assert all(next(m for m in current if m['name']==old['name'])['activeWorkspace'].get('name')==old['activeWorkspace'].get('name')for old in selected),'Workspace changed; do not inject into a user game'
                candidate=next(c for c in owned()if c['title']==prefix+monitor['name'])
                assert candidate['monitor']==monitor['id']and candidate['fullscreen']==2
                width,height=logical_size(monitor)
                x,y=round(monitor['x']+width*.5),round(monitor['y']+height*.5)
                dispatch('hl.dsp.cursor.move({x='+str(x)+',y='+str(y)+'})')
                last_cursor={'x':x,'y':y}
                time.sleep(.35)
                actual=json.loads(ipc('j/cursorpos'))
                assert abs(actual['x']-x)<=2 and abs(actual['y']-y)<=2
                snapshot=monitors()
                records.append({'cursorOutput':monitor['name'],'outputs':[{'output':m['name'],'scanout':str(m.get('directScanoutTo','0'))!='0','softwareCursorBlock':'SW'in(m.get('directScanoutBlockedBy')or[]),'blockers':m.get('directScanoutBlockedBy')or[],'vrr':m.get('vrr')}for m in snapshot]})
            focused=json.loads(ipc('j/activewindow'))
            current=monitors()
            restore_input=focused.get('pid')==process.pid and all(next(m for m in current if m['name']==old['name'])['activeWorkspace'].get('name')==old['activeWorkspace'].get('name')for old in selected)
            assert {name:json.loads(ipc('j/getoption '+name)).get('int')for name in before_options}==before_options
            errors=(folder/'runtime.log').read_text()
            assert not any(error in errors for error in ['TypeError','ReferenceError','Failed to load configuration'])
        active_modes={name:{entry['scanout']for record in records for entry in record['outputs']if entry['output']==name}for name in ['DP-1','HDMI-A-1']}
        toggled=any(len(modes)>1 for modes in active_modes.values())
        Path('/tmp/swiftshell-owned-scanout-observation.json').write_text(json.dumps({'options':before_options,'cursorLinkedScanoutTransitions':toggled,'samples':records},indent=2))
        print('PASS owned fullscreen cursor observation; direct-scanout transitions '+('observed'if toggled else 'not observed')+'; VRR/scanout settings unchanged',flush=True)
finally:
    if process:
        can_restore=False
        if last_cursor and restore_input:
            actual=json.loads(ipc('j/cursorpos'))
            can_restore=abs(actual['x']-last_cursor['x'])<=2 and abs(actual['y']-last_cursor['y'])<=2 and json.loads(ipc('j/activewindow')).get('pid')==process.pid
        process.terminate()
        try:process.wait(timeout=3)
        except subprocess.TimeoutExpired:process.kill();process.wait()
        if can_restore:
            current=monitors()
            if all(next(m for m in current if m['name']==old['name'])['activeWorkspace'].get('name')==old['activeWorkspace'].get('name')for old in selected):
                dispatch('hl.dsp.cursor.move({x='+str(cursor['x'])+',y='+str(cursor['y'])+'})')
                if previous_focus and any(c['address']==previous_focus for c in clients()):dispatch('hl.dsp.focus({window='+json.dumps('address:'+previous_focus)+'})')
    for variable in reversed(rule_names):
        assert ipc('eval if '+variable+' then '+variable+':set_enabled(false);'+variable+'=nil end').strip()=='ok'
