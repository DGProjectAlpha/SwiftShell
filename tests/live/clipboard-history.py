#!/usr/bin/env python3
"""Owned synthetic history and native pinned window; never reads desktop clipboard."""
import argparse,json,os,shutil,subprocess,sys,tempfile,time
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);args=parser.parse_args()
ROOT=Path(__file__).parents[2];sys.path.insert(0,str(ROOT/'shell/helpers'))
from displayctl import ipc
monitors=json.loads(ipc('j/monitors'));original_focus=next(m['name'] for m in monitors if m['focused']);original_active=json.loads(ipc('j/activewindow')).get('address')
with tempfile.TemporaryDirectory(prefix='swiftshell-clipboard-audit-') as temporary:
 folder=Path(temporary);shell=folder/'shell';shutil.copytree(ROOT/'shell',shell)
 config=folder/'config/swiftshell';config.mkdir(parents=True);shutil.copy2(ROOT/'shell/config/defaults.json',config/'settings.json')
 # A fixture transport is essential: no wl-paste or desktop clipboard content is
 # ever read. Copy is separately verified against Qt's private offscreen clipboard.
 (shell/'helpers/desktoptools.py').write_text('import json,sys\nprint(json.dumps({"ok":True,"clipboard":True,"skip":True}))\n')
 qml=shell/'ClipboardAudit.qml';qml.write_text('''//@ pragma UseQApplication
//@ pragma ShellId swiftshell-clipboard-audit
import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "clipboard"
ShellRoot {
 Component.onCompleted:Quickshell.watchFiles=false
 ClipboardWindow {id:window}
 IpcHandler {
  target:"audit"
  function state():string{return JSON.stringify({ready:SettingsStore.persistenceState==="ready",count:ClipboardModel.entries.length,enabled:ClipboardModel.recording,open:ClipboardModel.windowOpen,mapped:ClipboardModel.windowReady,blur:window.blurApplied,error:!!ClipboardModel.windowError})}
  function fixture():void{SettingsStore.setClipboardHistory(true);DesktopTools.history=[{id:"owned-fixture",time:Date.now(),text:"SwiftShell owned clipboard fixture\\nSecond line"}]}
  function copy():bool{return ClipboardModel.copy("owned-fixture") && Quickshell.clipboardText==="SwiftShell owned clipboard fixture\\nSecond line"}
  function open():void{ClipboardModel.showWindow()}
  function close():void{ClipboardModel.hideWindow()}
  function disable():void{SettingsStore.setClipboardHistory(false)}
 }
}
''')
 for protocol,prefix,source,libs in [('virtual-keyboard-unstable-v1.xml','keyboard','launcher-keyboard.c',['-lwayland-client','-lxkbcommon'])]:
  xml=ROOT/'tests/protocols'/protocol
  subprocess.run(['wayland-scanner','client-header',str(xml),str(folder/(prefix+'-client.h'))],check=True)
  subprocess.run(['wayland-scanner','private-code',str(xml),str(folder/(prefix+'-protocol.c'))],check=True)
  subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(folder),str(ROOT/'tests/helpers'/source),str(folder/(prefix+'-protocol.c')),*libs,'-o',str(folder/prefix)],check=True)
 base=dict(os.environ,QT_QPA_PLATFORMTHEME='generic',QT_NO_XDG_DESKTOP_PORTAL='1',NO_AT_BRIDGE='1',XDG_CONFIG_HOME=str(folder/'config'),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'))
 def execute(offscreen):
  env=dict(base)
  if offscreen:env['QT_QPA_PLATFORM']='offscreen'
  log=folder/('offscreen.log' if offscreen else 'native.log')
  with log.open('w') as stream:
   process=subprocess.Popen(['qs','-p',str(qml)],env=env,stdout=stream,stderr=subprocess.STDOUT)
   command=['qs','ipc','-p',str(qml),'call','audit']
   def call(*args):return subprocess.check_output(command+list(args),env=env,text=True,stderr=subprocess.DEVNULL).strip()
   def state():return json.loads(call('state'))
   def wait(predicate):
    for _ in range(180):
     try:
      if predicate():return
     except (subprocess.CalledProcessError,ValueError,KeyError):pass
     if process.poll() is not None:raise AssertionError('Owned clipboard fixture exited')
     time.sleep(.05)
    raise AssertionError('Owned clipboard state did not settle')
   try:
    wait(lambda:state()['ready']);call('fixture');wait(lambda:state()['count']==1)
    if offscreen:
     assert call('copy')=='true'
     print('PASS synthetic history copy through real Qt private offscreen clipboard; desktop clipboard untouched',flush=True)
    else:
     for monitor in monitors:
      # Own temporary geometry only: test first placement independently on each output.
      (folder/'state/swiftshell/clipboard-window.json').unlink(missing_ok=True)
      ipc('eval hl.dispatch(hl.dsp.focus({monitor='+json.dumps(monitor['name'])+'}))')
      call('open');wait(lambda:state()['mapped'])
      owned=next(w for w in json.loads(ipc('j/clients')) if w.get('pid')==process.pid and w.get('title')=='SwiftShell Clipboard')
      assert owned['monitor']==monitor['id']
      assert owned['floating'] and owned['size'][0]>=360 and owned['size'][1]>=360
      assert state()['blur']
      call('open');wait(lambda:json.loads(ipc('j/activewindow')).get('address')==owned['address'])
      subprocess.run([str(folder/'keyboard'),'escape'],check=True)
      wait(lambda:not state()['open'])
      call('open');wait(lambda:state()['mapped'])
      call('close');wait(lambda:not state()['open'])
      print('PASS native Clipboard floating/focus/shared blur/Escape/close on '+monitor['name'],flush=True)
    call('disable');wait(lambda:state()['count']==0)
   finally:
    try:call('close')
    except subprocess.CalledProcessError:pass
    process.terminate()
    try:process.wait(timeout=3)
    except subprocess.TimeoutExpired:process.kill();process.wait()
   text=log.read_text()
   assert not any(token in text for token in ['TypeError','ReferenceError','Binding loop','Failed to load configuration']), 'Owned clipboard fixture had runtime errors'
 try:
  execute(True);execute(False)
 finally:
  if original_active and any(w['address']==original_active for w in json.loads(ipc('j/clients'))):ipc('eval hl.dispatch(hl.dsp.focus({window='+json.dumps('address:'+original_active)+'}))')
  ipc('eval hl.dispatch(hl.dsp.focus({monitor='+json.dumps(original_focus)+'}))')
