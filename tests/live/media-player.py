#!/usr/bin/env python3
"""Native MPRIS controls using a private bus, synthetic players and owned pixels."""
import argparse,json,os,shutil,struct,subprocess,sys,tempfile,time,zlib
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.add_argument('--isolated',action='store_true');args=parser.parse_args()
if not args.isolated:
 subprocess.run(['dbus-run-session','--',sys.executable,__file__,'--live','--isolated'],check=True);raise SystemExit()
ROOT=Path(__file__).parents[2];sys.path.insert(0,str(ROOT/'shell/helpers'))
from displayctl import ipc,logical_size
monitors=json.loads(ipc('j/monitors'));focused=next(m['name'] for m in monitors if m['focused']);cursor=json.loads(ipc('j/cursorpos'))
def wait(predicate):
 for _ in range(180):
  try:
   result=predicate()
   if result:return result
  except (subprocess.CalledProcessError,ValueError,KeyError,StopIteration):pass
  time.sleep(.05)
 raise AssertionError('Owned media fixture did not settle')
def layer(namespace):
 return next((item for output in json.loads(ipc('j/layers')).values() for group in output.get('levels',{}).values() for item in group if item.get('namespace')==namespace),None)
with tempfile.TemporaryDirectory(prefix='swiftshell-media-native-') as temporary:
 folder=Path(temporary);shell=folder/'shell';shutil.copytree(ROOT/'shell',shell)
 for protocol,prefix,source,libs in [('wlr-virtual-pointer-unstable-v1.xml','pointer','settings-pointer.c',['-lwayland-client']),('virtual-keyboard-unstable-v1.xml','keyboard','launcher-keyboard.c',['-lwayland-client','-lxkbcommon'])]:
  xml=ROOT/'tests/protocols'/protocol
  subprocess.run(['wayland-scanner','client-header',str(xml),str(folder/(prefix+'-client.h'))],check=True)
  subprocess.run(['wayland-scanner','private-code',str(xml),str(folder/(prefix+'-protocol.c'))],check=True)
  subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(folder),str(ROOT/'tests/helpers'/source),str(folder/(prefix+'-protocol.c')),*libs,'-o',str(folder/prefix)],check=True)
 def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
 art=folder/'owned-art.png';pixels=b''.join(b'\0'+b''.join(bytes([80 if (x//8+y//8)%2 else 175,95 if (x//8+y//8)%2 else 185,110 if (x//8+y//8)%2 else 195]) for x in range(96)) for y in range(96))
 art.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',96,96,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(pixels))+chunk(b'IEND',b''))
 qml=shell/'MediaAudit.qml';qml.write_text('''//@ pragma UseQApplication
//@ pragma ShellId swiftshell-media-audit
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"
import "popovers"
import "components"
ShellRoot {
 id:root
 property var output:Quickshell.screens.find(function(s){return s.name===Quickshell.env("SWIFTSHELL_AUDIT_OUTPUT")})
 Component.onCompleted:Quickshell.watchFiles=false
 PanelWindow {
  screen:root.output;visible:true;anchors {top:true;bottom:true;left:true;right:true}
  color:"#303030";exclusionMode:ExclusionMode.Ignore
  WlrLayershell.namespace:"swiftshell-media-owned-pattern"
  WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
  Canvas {anchors.fill:parent;onPaint:{const c=getContext("2d");for(let y=0;y<height;y+=12)for(let x=0;x<width;x+=12){c.fillStyle=(x+y)%24===0 ? "#777777" : "#303030";c.fillRect(x,y,12,12)}}}
 }
 PanelWindow {
  id:window;screen:root.output;visible:true;anchors {top:true;left:true} margins {left:120;top:130}
  implicitWidth:surface.implicitWidth;implicitHeight:surface.implicitHeight;color:"transparent";surfaceFormat.opaque:false;exclusionMode:ExclusionMode.Ignore
  WlrLayershell.namespace:"swiftshell-media-audit";WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.keyboardFocus:WlrKeyboardFocus.Exclusive
  Item {id:captureRoot;anchors.fill:parent
  Canvas {anchors.fill:parent;onPaint:{const c=getContext("2d");for(let y=0;y<height;y+=12)for(let x=0;x<width;x+=12){c.fillStyle=(x+y)%24===0 ? "#777777" : "#303030";c.fillRect(x,y,12,12)}}}
  BackdropEffect {id:blur;targetWindow:window;surface:surface.blurSurface;cornerRadius:SettingsStore.radius;enabled:SettingsStore.panelBlur>0}
  PopoverSurface {id:surface;MediaSection {id:section;width:360}}
  }
 }
 function find(item,name){if(item.objectName===name)return item;for(let i=0;i<item.children.length;i++){const found=find(item.children[i],name);if(found)return found}return null}
 IpcHandler {
  target:"audit"
  function state():string{return JSON.stringify({ready:SettingsStore.persistenceState==="ready",media:section.diagnostics(),blur:blur.applied,source:MediaService.selectedId})}
  function box(name:string):string{const item=root.find(window.contentItem,name);if(!item)return "null";const point=item.mapToItem(window.contentItem,0,0);return JSON.stringify({x:point.x,y:point.y,width:item.width,height:item.height,enabled:item.enabled})}
  function source(id:string):bool{return MediaService.selectSource(id)}
  function capture(path:string):bool{return captureRoot.grabToImage(function(result){result.saveToFile(path)})}
  function gesture(action:string):void{if(action==="begin")section.beginSeek();else section.commitSeek(.75)}
  function theme(mode:string):void{SettingsStore.setAppearance(Object.assign({},SettingsStore.snapshot().appearance,{mode:mode}))}
 }
}
''')
 fixturelog=(folder/'fixture.log').open('w');fixture=subprocess.Popen([sys.executable,str(ROOT/'tests/helpers/mpris-fixture.py'),'--art',art.as_uri()],stdout=fixturelog,stderr=subprocess.STDOUT)
 base=['gdbus','call','--session','--object-path','/org/mpris/MediaPlayer2','--method']
 def fixture_call(method,*values,player='Primary'):
  return subprocess.check_output(base+['org.swiftshell.MediaFixture.'+method,'--dest','org.mpris.MediaPlayer2.'+player]+list(values),text=True,stderr=subprocess.DEVNULL)
 def fixture_state(player='Primary'):
  import ast
  return json.loads(ast.literal_eval(fixture_call('State',player=player))[0])
 try:
  wait(lambda:fixture_state())
  for monitor in monitors:
   name=monitor['name'];ipc('eval hl.dispatch(hl.dsp.focus({monitor='+json.dumps(name)+'}))')
   config=folder/name/'config/swiftshell';config.mkdir(parents=True);shutil.copy2(ROOT/'shell/config/defaults.json',config/'settings.json')
   env=dict(os.environ,QT_QPA_PLATFORMTHEME='generic',QT_NO_XDG_DESKTOP_PORTAL='1',NO_AT_BRIDGE='1',XDG_CONFIG_HOME=str(config.parent),XDG_STATE_HOME=str(folder/name/'state'),XDG_CACHE_HOME=str(folder/name/'cache'),SWIFTSHELL_AUDIT_OUTPUT=name)
   runtime=folder/(name+'.log')
   with runtime.open('w') as stream:
    process=subprocess.Popen(['qs','-p',str(qml)],env=env,stdout=stream,stderr=subprocess.STDOUT)
    command=['qs','ipc','-p',str(qml),'call','audit']
    def call(*values):return subprocess.check_output(command+list(map(str,values)),env=env,text=True,stderr=subprocess.DEVNULL).strip()
    def state():return json.loads(call('state'))
    def pointer(box,start=.5,end=None):
     surface=layer('swiftshell-media-audit');x=round(surface['x']+box['x']+box['width']*start);y=round(surface['y']+box['y']+box['height']/2)
     dx=0 if end is None else round(box['width']*(end-start));w,h=map(round,logical_size(monitor))
     values=[str(folder/'pointer'),str(x-monitor['x']),str(y-monitor['y']),str(w),str(h),str(dx),'0',name,str(x),str(y),'left']
     for _ in range(3):
      result=subprocess.run(values)
      if result.returncode==0:return
      if result.returncode!=6:result.check_returncode()
      time.sleep(.1)
     result.check_returncode()
    def capture(kind):
     surface=layer('swiftshell-media-audit');pattern=layer('swiftshell-media-owned-pattern')
     assert surface['x']>=pattern['x'] and surface['y']>=pattern['y'] and surface['x']+surface['w']<=pattern['x']+pattern['w'] and surface['y']+surface['h']<=pattern['y']+pattern['h']
     path=Path('/tmp')/('swiftshell-media-'+name+'-'+kind+'.png')
     # Grab only this QML item tree, not compositor pixels. An opaque checkerboard
     # is part of this same window, so neither wallpaper nor other layers enter it.
     assert call('capture',str(path))=='true'
     wait(lambda:path.exists() and path.stat().st_size>0)
    try:
     wait(lambda:state()['ready'] and state()['media']['players']==2 and state()['media']['artReady'] and layer('swiftshell-media-audit'))
     assert state()['media']['seek'] and state()['blur']
     capture('art')
     fixture_call('Change','clear');pointer(json.loads(call('box','mediaPlayPause')))
     wait(lambda:any(item[0] in ['toggle','play','pause'] for item in fixture_state()['calls']))
     pointer(json.loads(call('box','mediaPrevious')));pointer(json.loads(call('box','mediaNext')))
     wait(lambda:len(fixture_state()['calls'])==3)
     fixture_call('Change','clear')
     pointer(json.loads(call('box','mediaSeek')),.2,.75)
     wait(lambda:any(item[0]=='seek' for item in fixture_state()['calls']))
     seeks=[item for item in fixture_state()['calls'] if item[0]=='seek'];assert len(seeks)==1 and abs(seeks[0][2]-180_000_000)<2_000_000
     fixture_call('Change','clear');call('gesture','begin');fixture_call('Change','track');time.sleep(.15);call('gesture','commit');assert not fixture_state()['calls']
     fixture_call('Change','no-seek');wait(lambda:not state()['media']['seek']);assert not json.loads(call('box','mediaSeek'))['enabled'];fixture_call('Change','seek')
     call('source','org.mpris.MediaPlayer2.Secondary');wait(lambda:state()['media']['manualSource']);call('source','')
     fixture_call('Change','no-art');wait(lambda:not state()['media']['hasArt']);capture('fallback')
     call('theme','light');time.sleep(.2);capture('light');call('theme','dark');time.sleep(.2);capture('dark')
     print('PASS native MPRIS discovery/art, play-pause/previous/next, release-only pointer seek seconds→microseconds, stale-track guard, disabled seek, source selection and themed fallback on '+name,flush=True)
    finally:
     process.terminate()
     try:process.wait(timeout=3)
     except subprocess.TimeoutExpired:process.kill();process.wait()
     shutil.copy2(runtime,Path('/tmp')/('swiftshell-media-'+name+'.log'))
    text=runtime.read_text();assert not any(token in text for token in ['TypeError','ReferenceError','Binding loop','Failed to load configuration']),'Native media fixture had runtime errors'
    # Restore synthetic source between outputs without touching real media.
    fixture_call('Change','playing');fixture_call('Change','seek');fixture_call('Change','art')
 finally:
  fixture.terminate()
  try:fixture.wait(timeout=3)
  except subprocess.TimeoutExpired:fixture.kill();fixture.wait()
  fixturelog.close()
  shutil.copy2(folder/"fixture.log",Path("/tmp/swiftshell-media-fixture.log"))
  ipc('eval hl.dispatch(hl.dsp.cursor.move({x='+str(cursor['x'])+',y='+str(cursor['y'])+'}))')
  ipc('eval hl.dispatch(hl.dsp.focus({monitor='+json.dumps(focused)+'}))')
