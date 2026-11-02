#!/usr/bin/env python3
"""Native overview: actual window previews, compositor blur and Escape on both scales.

No private window pixels are captured to files or emitted. All preferences/state
are disposable; only temporary focus changes are made and then restored.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
ROOT=Path(__file__).parents[2]
sys.path.insert(0,str(ROOT/'shell/helpers'))
from displayctl import ipc
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
monitors=json.loads(ipc('j/monitors'))
focused=next(m['name'] for m in monitors if m.get('focused'))
active=json.loads(ipc('j/activewindow')).get('address','')

def wait(predicate,message):
    for _ in range(120):
        try:
            value=predicate()
            if value:return value
        except (subprocess.CalledProcessError,ValueError):pass
        time.sleep(.05)
    raise AssertionError(message)

with tempfile.TemporaryDirectory(prefix='swiftshell-overview-') as d:
    folder=Path(d);shell=folder/'shell';shutil.copytree(ROOT/'shell',shell)
    config=folder/'config/swiftshell';config.mkdir(parents=True)
    shutil.copy2(ROOT/'shell/config/defaults.json',config/'settings.json')
    (shell/'OverviewAudit.qml').write_text('''//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services
import "overview"
ShellRoot {
 OverviewWindow {id:overview}
 IpcHandler {
  target:"audit"
  function openOutput(output: string): void {
   Services.HyprlandModel.refresh();
   Services.OverviewService.screen=Quickshell.screens.find(function(s){return s.name===output}) || null;
   Services.OverviewService.open=Services.OverviewService.screen!==null;
  }
  function close():void {Services.OverviewService.closeOverview();}
  function status():string{return JSON.stringify(overview.diagnostics());}
 }
}''')
    protocol=ROOT/'tests/protocols/virtual-keyboard-unstable-v1.xml'
    subprocess.run(['wayland-scanner','client-header',str(protocol),str(folder/'keyboard-client.h')],check=True)
    subprocess.run(['wayland-scanner','private-code',str(protocol),str(folder/'keyboard-protocol.c')],check=True)
    subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(folder),str(ROOT/'tests/helpers/spotlight-keyboard.c'),str(folder/'keyboard-protocol.c'),'-lwayland-client','-lxkbcommon','-o',str(folder/'keyboard')],check=True)
    env=dict(os.environ,XDG_CONFIG_HOME=str(folder/'config'),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'))
    command=['qs','ipc','-p',str(shell/'OverviewAudit.qml'),'call','audit']
    def call(*args):return subprocess.check_output(command+list(args),text=True)
    def state():return json.loads(call('status'))
    with (folder/'audit.log').open('w') as log:
        process=subprocess.Popen(['qs','-p',str(shell/'OverviewAudit.qml')],env=env,stdout=log,stderr=log)
        try:
            wait(state,'Overview audit failed to load')
            for monitor in monitors:
                output=monitor['name']
                assert ipc('eval hl.dispatch(hl.dsp.focus({monitor='+json.dumps(output)+'}))').strip()=='ok'
                call('openOutput',output)
                snapshot=wait(lambda:state() if state()['open'] and state()['workspaces']>0 and state()['blurApplied'] else None,'Overview failed to map with real compositor blur')
                if snapshot['windows']:
                    snapshot=wait(lambda:state() if state()['previewsReady']==state()['windows'] else None,'Native window previews did not acquire content')
                subprocess.run([str(folder/'keyboard'),'escape'],check=True)
                wait(lambda:not state()['open'],'Escape failed to dismiss overview')
                print('PASS native overview on',output,'workspaces',snapshot['workspaces'],'windows',snapshot['windows'],'ready previews',snapshot['previewsReady'],'actual blur and keyboard Escape',flush=True)
        finally:
            process.terminate()
            try:process.wait(timeout=5)
            except subprocess.TimeoutExpired:process.kill();process.wait()
            assert ipc('eval hl.dispatch(hl.dsp.focus({monitor='+json.dumps(focused)+'}))').strip()=='ok'
            if active:ipc('eval hl.dispatch(hl.dsp.focus({window='+json.dumps('address:'+active)+'}))')
        output=(folder/'audit.log').read_text()
        assert 'Binding loop' not in output and 'TypeError' not in output and 'ReferenceError' not in output,output
