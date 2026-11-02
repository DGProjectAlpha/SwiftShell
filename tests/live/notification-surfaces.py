#!/usr/bin/env python3
"""Native notification pixels/input on a private bus and opaque owned background only."""
import argparse,json,os,re,shutil,struct,subprocess,sys,tempfile,time,zlib
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.add_argument('--isolated',action='store_true');args=parser.parse_args()
if not args.isolated:
 subprocess.run(['dbus-run-session','--',sys.executable,__file__,'--live','--isolated'],check=True);raise SystemExit()
ROOT=Path(__file__).parents[2];sys.path.insert(0,str(ROOT/'shell/helpers'))
from displayctl import ipc,logical_size
monitors=json.loads(ipc('j/monitors'));original=next(m['name'] for m in monitors if m['focused']);cursor=json.loads(ipc('j/cursorpos'))
def wait(predicate):
 for _ in range(160):
  try:
   result=predicate()
   if result:return result
  except (subprocess.CalledProcessError,ValueError,KeyError):pass
  time.sleep(.05)
 raise AssertionError('Owned notification surface did not settle')
def layers(namespace):return [item for output in json.loads(ipc('j/layers')).values() for group in output.get('levels',{}).values() for item in group if item.get('namespace')==namespace]
with tempfile.TemporaryDirectory(prefix='swiftshell-notification-surfaces-') as temporary:
 folder=Path(temporary);shell=folder/'shell';shutil.copytree(ROOT/'shell',shell)
 for file,old,new in [('notifications/NotificationHost.qml','swiftshell-notification','swiftshell-notification-visual-audit'),('popovers/PopoverHost.qml','swiftshell-popover','swiftshell-popover-visual-audit'),('bar/BarWindow.qml','swiftshell-bar','swiftshell-bar-visual-audit')]:
  path=shell/file;path.write_text(path.read_text().replace('namespace:"'+old+'"','namespace:"'+new+'"').replace('namespace: "'+old+'"','namespace: "'+new+'"'))
 for protocol,prefix,source,libs in [('wlr-virtual-pointer-unstable-v1.xml','pointer','settings-pointer.c',['-lwayland-client']),('virtual-keyboard-unstable-v1.xml','keyboard','spotlight-keyboard.c',['-lwayland-client','-lxkbcommon'])]:
  xml=ROOT/'tests/protocols'/protocol
  subprocess.run(['wayland-scanner','client-header',str(xml),str(folder/(prefix+'-client.h'))],check=True)
  subprocess.run(['wayland-scanner','private-code',str(xml),str(folder/(prefix+'-protocol.c'))],check=True)
  subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(folder),str(ROOT/'tests/helpers'/source),str(folder/(prefix+'-protocol.c')),*libs,'-o',str(folder/prefix)],check=True)
 def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
 image=folder/'owned.png';pixels=b''.join(b'\0'+bytes([60+y*2]*3)*160 for y in range(64))
 image.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',160,64,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(pixels))+chunk(b'IEND',b''))
 qml=shell/'NotificationSurfaceAudit.qml';qml.write_text('''//@ pragma UseQApplication
//@ pragma ShellId swiftshell-notification-surface-audit
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"
import "notifications"
import "bar"
ShellRoot {
 id:root
 property var output:Quickshell.screens.find(function(s){return s.name===Quickshell.env("SWIFTSHELL_AUDIT_OUTPUT")})
 Component.onCompleted:Quickshell.watchFiles=false
 PanelWindow {
  screen:root.output;visible:true;anchors {top:true;bottom:true;left:true;right:true}
  color:"#303030";exclusionMode:ExclusionMode.Ignore
  WlrLayershell.namespace:"swiftshell-notification-owned-pattern"
  WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
  Canvas {anchors.fill:parent;onPaint:{const c=getContext("2d");for(let y=0;y<height;y+=12)for(let x=0;x<width;x+=12){c.fillStyle=(x+y)%24===0 ? "#aaaaaa" : "#303030";c.fillRect(x,y,12,12)}}}
 }
 BarWindow {id:bar;modelData:root.output}
 NotificationHost {id:host}
 Connections {target:NotificationsModel;function onDrawerRequested(){bar.openNotifications()}}
 function find(item,name){if(item.objectName===name)return item;for(const child of item.children || []){const match=find(child,name);if(match)return match}return null}
 function cards(item){const out=[];if((item.objectName || "").indexOf("notificationCard-")===0)out.push(item);for(const child of item.children || [])out.push.apply(out,cards(child));return out}
 IpcHandler {
  target:"audit"
  function state():string {
   const card=root.cards(host.contentItem)[0],image=card ? root.find(card,"notificationImage") : null
   const reply=bar.menuDiagnostics().visible ? NotificationsModel.replyTarget : 0
   return JSON.stringify({ready:SettingsStore.persistenceState==="ready",live:NotificationsModel.center.live.length,ids:NotificationsModel.entries.map(function(item){return item.id}),hidden:card ? card.hiddenPreview : false,imageReady:!!image && image.status===Image.Ready && image.visible,menu:bar.menuDiagnostics(),replyTarget:reply})
  }
  function button(name:string):string {const card=root.cards(host.contentItem)[0],item=card ? root.find(card,name) : null;if(!item)return "null";const p=item.mapToItem(null,0,0);return JSON.stringify({x:p.x,y:p.y,width:item.width,height:item.height})}
  function preference(mode:string):void {SettingsStore.setNotificationPreferences({previewMode:mode})}
  function appearance(mode:string):void {const next=SettingsStore.snapshot().appearance;next.mode=mode;SettingsStore.setAppearance(next)}
  function close():void{bar.showPanel("close")}
 }
}
''')
 try:
  for monitor in monitors:
   name=monitor['name'];ipc('eval hl.dispatch(hl.dsp.focus({monitor='+json.dumps(name)+'}))')
   config=folder/name/'config/swiftshell';config.mkdir(parents=True)
   prefs=json.loads((ROOT/'shell/config/defaults.json').read_text());prefs['notifications'].update(ownership='on',screenTarget=name,bannerDuration=30);prefs['bar']['reserveSpace']=False;prefs['bar']['hiddenModules']=[item for item in prefs['bar']['moduleOrder'] if item!='notifications']
   (config/'settings.json').write_text(json.dumps(prefs))
   env=dict(os.environ,QT_QPA_PLATFORMTHEME='generic',QT_NO_XDG_DESKTOP_PORTAL='1',NO_AT_BRIDGE='1',XDG_CONFIG_HOME=str(config.parent),XDG_STATE_HOME=str(folder/name/'state'),XDG_CACHE_HOME=str(folder/name/'cache'),SWIFTSHELL_AUDIT_OUTPUT=name)
   log=folder/(name+'.log')
   with log.open('w') as stream:
    process=subprocess.Popen(['qs','-p',str(qml)],env=env,stdout=stream,stderr=subprocess.STDOUT)
    command=['qs','ipc','-p',str(qml),'call','audit']
    def call(*values):return subprocess.check_output(command+list(map(str,values)),env=env,text=True,stderr=subprocess.DEVNULL)
    def state():return json.loads(call('state'))
    def capture(kind,namespace):
     layer=wait(lambda:next(iter(layers(namespace)),None));pattern=layers('swiftshell-notification-owned-pattern')[0]
     assert layer['x']>=pattern['x'] and layer['y']>=pattern['y'] and layer['x']+layer['w']<=pattern['x']+pattern['w'] and layer['y']+layer['h']<=pattern['y']+pattern['h'],'Capture would include unowned pixels'
     path=Path('/tmp')/('swiftshell-notification-'+name+'-'+kind+'.png')
     subprocess.run(['grim','-g',f"{layer['x']},{layer['y']} {layer['w']}x{layer['h']}",str(path)],check=True)
     if kind=='dark':
      from PySide6.QtGui import QImage
      shot=QImage(str(path));values=[shot.pixelColor(x,y).lightness() for x in range(3,10) for y in range(shot.height()//4,shot.height()*3//4)]
      assert max(values)-min(values)>70,'Transparent shadow margin was incorrectly blurred'
     return layer
    try:
     wait(lambda:state()['ready'] and layers('swiftshell-notification-owned-pattern'))
     base=['gdbus','call','--session','--dest','org.freedesktop.Notifications','--object-path','/org/freedesktop/Notifications','--method','org.freedesktop.Notifications.Notify']
     def notify(summary='A message from the test app'):
      value=subprocess.check_output(base+['SwiftShell Test','0','mail-unread',summary,'A longer message wraps cleanly. Reply here or snooze it until later.',"['default','Open','inline-reply','Write a reply']","{'image-path': <"+repr(image.as_uri())+">}",'0'],env=env,text=True)
      return int(re.search(r'uint32 (\d+)',value).group(1))
     identifier=notify();wait(lambda:state()['imageReady'])
     time.sleep(.2);capture('dark','swiftshell-notification-visual-audit')
     call('appearance','light');time.sleep(.25);capture('light','swiftshell-notification-visual-audit')
     call('appearance','dark');call('preference','app-only');wait(lambda:state()['hidden'] and not state()['imageReady']);time.sleep(.1);capture('private','swiftshell-notification-visual-audit')
     call('preference','full');wait(lambda:state()['imageReady'])
     box=json.loads(call('button','notificationReplyOpen'));layer=layers('swiftshell-notification-visual-audit')[0]
     x=round(layer['x']+box['x']+box['width']/2);y=round(layer['y']+box['y']+box['height']/2);w,h=map(round,logical_size(monitor))
     subprocess.run([str(folder/'pointer'),str(x-monitor['x']),str(y-monitor['y']),str(w),str(h),'0','0',name,str(x),str(y),'left'],check=True)
     wait(lambda:state()['menu']['visible'] and state()['replyTarget']==identifier)
     subprocess.run([str(folder/'keyboard'),'calculation'],check=True)
     notify('An update arrives while replying');time.sleep(.2)
     capture('drawer','swiftshell-popover-visual-audit')
     subprocess.run([str(folder/'keyboard'),'enter'],check=True)
     wait(lambda:identifier not in state()['ids'])
     subprocess.run([str(folder/'keyboard'),'escape'],check=True);wait(lambda:not state()['menu']['visible'])
     print('PASS native image/privacy/light-dark surfaces, banner Reply→drawer keyboard input, draft retained through incoming update and Send/Escape on',name,flush=True)
    finally:
     process.terminate()
     try:process.wait(timeout=4)
     except subprocess.TimeoutExpired:process.kill();process.wait()
     shutil.copy2(log,Path('/tmp')/('swiftshell-notification-surface-'+name+'.log'))
   text=log.read_text();assert not any(error in text for error in ['TypeError:','ReferenceError:','Binding loop']),'Native notification surface runtime error; inspect isolated log locally'
 finally:
  ipc('eval hl.dispatch(hl.dsp.focus({monitor='+json.dumps(original)+'}))')
  ipc('eval hl.dispatch(hl.dsp.cursor.move({x='+str(cursor['x'])+',y='+str(cursor['y'])+'}))')
