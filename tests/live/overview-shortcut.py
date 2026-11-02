#!/usr/bin/env python3
"""Real Alt+Tab activation on each monitor; requires the explicit owned handoff."""
import argparse,json,subprocess,sys,tempfile,time
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
root=Path(__file__).parents[2];sys.path.insert(0,str(root/'shell/helpers'))
from displayctl import ipc
cmd=['qs','ipc','-p',str(root/'shell'),'call','swiftshell']
def call(*args):return subprocess.check_output(cmd+list(args),text=True)
def state():return json.loads(call('diagnostics'))
def wait(predicate):
 for _ in range(120):
  if predicate():return
  time.sleep(.05)
 raise AssertionError('Overview shortcut did not settle')
status=json.loads(subprocess.check_output(['python3',str(root/'shell/helpers/overviewctl.py'),'status'],text=True))
assert status['enabled'] and status['active'],'Enable the explicit overview handoff first'
monitors=json.loads(ipc('j/monitors'));focused=next(m['name'] for m in monitors if m['focused'])
active=json.loads(ipc('j/activewindow')).get('address','')
with tempfile.TemporaryDirectory(prefix='swiftshell-overview-chord-') as d:
 folder=Path(d);protocol=root/'tests/protocols/virtual-keyboard-unstable-v1.xml'
 subprocess.run(['wayland-scanner','client-header',str(protocol),str(folder/'keyboard-client.h')],check=True)
 subprocess.run(['wayland-scanner','private-code',str(protocol),str(folder/'keyboard-protocol.c')],check=True)
 subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(folder),str(root/'tests/helpers/spotlight-keyboard.c'),str(folder/'keyboard-protocol.c'),'-lwayland-client','-lxkbcommon','-o',str(folder/'keyboard')],check=True)
 try:
  call('launcher','close')
  for monitor in monitors:
   call('barPanel',monitor['name'],'close')
   call('overview','close')
   assert ipc('eval hl.dispatch(hl.dsp.focus({monitor='+json.dumps(monitor['name'])+'}))').strip()=='ok'
   subprocess.run([str(folder/'keyboard'),'overview'],check=True)
   wait(lambda:state()['overview']['open'] and state()['overview']['windows']>0 and state()['overview']['previewsReady']>0)
   assert state()['overview']['blurApplied']
   subprocess.run([str(folder/'keyboard'),'overview'],check=True)
   assert state()['overview']['open'],'Repeated Alt+Tab should navigate, not close'
   subprocess.run([str(folder/'keyboard'),'escape'],check=True)
   wait(lambda:not state()['overview']['open'])
   print('PASS actual Alt+Tab, live previews, repeated chord navigation and Escape on',monitor['name'],flush=True)
 finally:
  call('overview','close')
  ipc('eval hl.dispatch(hl.dsp.focus({monitor='+json.dumps(focused)+'}))')
  if active:ipc('eval hl.dispatch(hl.dsp.focus({window='+json.dumps('address:'+active)+'}))')
