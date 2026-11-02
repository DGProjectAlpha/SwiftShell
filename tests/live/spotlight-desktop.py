#!/usr/bin/env python3
"""Real Spotlight window activation and precise Settings navigation, no private content logged."""
import argparse,json,subprocess,sys,tempfile,time
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
root=Path(__file__).parents[2];sys.path.insert(0,str(root/'shell/helpers'))
from displayctl import ipc
cmd=['qs','ipc','-p',str(root/'shell'),'call','swiftshell']
def call(*args):return subprocess.check_output(cmd+list(args),text=True)
def state():return json.loads(call('diagnostics'))
def wait(predicate):
 for _ in range(160):
  if predicate():return
  time.sleep(.05)
 raise AssertionError('Desktop Spotlight action did not settle')
initial=state();original=json.loads(ipc('j/activewindow')).get('address','');title='SwiftShell owned search fixture 68f'
with tempfile.TemporaryDirectory(prefix='swiftshell-desktop-spotlight-') as d:
 folder=Path(d);qml=folder/'Fixture.qml'
 qml.write_text('''//@ pragma ShellId swiftshell-search-fixture
import QtQuick
import Quickshell
ShellRoot { FloatingWindow {visible:true;title:"'''+title+'''";implicitWidth:320;implicitHeight:180;color:"#202020";Text {anchors.centerIn:parent;text:"SwiftShell search test";color:"white"}} }
''')
 protocol=root/'tests/protocols/virtual-keyboard-unstable-v1.xml'
 subprocess.run(['wayland-scanner','client-header',str(protocol),str(folder/'keyboard-client.h')],check=True)
 subprocess.run(['wayland-scanner','private-code',str(protocol),str(folder/'keyboard-protocol.c')],check=True)
 subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(folder),str(root/'tests/helpers/spotlight-keyboard.c'),str(folder/'keyboard-protocol.c'),'-lwayland-client','-lxkbcommon','-o',str(folder/'keyboard')],check=True)
 with (folder/'runtime.log').open('w') as log:
  process=subprocess.Popen(['qs','-p',str(qml)],stdout=log,stderr=subprocess.STDOUT)
  try:
   wait(lambda:any(w.get('title')==title for w in json.loads(ipc('j/clients'))))
   address=next(w['address'] for w in json.loads(ipc('j/clients')) if w.get('title')==title)
   call('launcher','open');call('launcherQuery','owned search fixture 68f')
   wait(lambda:state()['spotlight']['card']['providers'] and state()['spotlight']['card']['providers'][0]['kind']=='window')
   subprocess.run([str(folder/'keyboard'),'enter'],check=True)
   wait(lambda:not state()['launcherOpen'] and json.loads(ipc('j/activewindow')).get('address')==address)
   print('PASS real Spotlight result activates the owned native window',flush=True)
   call('launcher','open');call('launcherQuery','window borders')
   wait(lambda:state()['spotlight']['card']['providers'] and state()['spotlight']['card']['providers'][0]['kind']=='setting-result')
   subprocess.run([str(folder/'keyboard'),'enter'],check=True)
   wait(lambda:state()['settingsOpen'] and state()['category']=='appearance' and not state()['windowBusy'])
   assert state()['window']['control']=='windowBorders'
   print('PASS actual Spotlight Settings result opens and focuses the specific appearance control',flush=True)
   call('launcher','open');call('launcherQuery','screenshot')
   wait(lambda:any(row['kind']=='screenshot' for row in state()['spotlight']['card']['providers']))
   subprocess.run([str(folder/'keyboard'),'escape'],check=True)
   print('PASS capability-detected screenshot actions appear without executing a capture',flush=True)
  finally:
   call('launcher','close')
   process.terminate()
   try:process.wait(timeout=3)
   except subprocess.TimeoutExpired:process.kill();process.wait()
   call('settings',initial['category'])
   wait(lambda:state()['settingsOpen'] and not state()['windowBusy'])
   if not initial['settingsOpen']:call('window','close')
   if original and any(w.get('address')==original for w in json.loads(ipc('j/clients'))):ipc('eval hl.dispatch(hl.dsp.focus({window='+json.dumps('address:'+original)+'}))')
