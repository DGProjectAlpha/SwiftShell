#!/usr/bin/env python3
"""Real grim capture of an owned checkerboard only; never changes desktop clipboard."""
import argparse,json,os,shutil,subprocess,sys,tempfile,time
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
root=Path(__file__).parents[2]
sys.path.insert(0,str(root/'shell/helpers'))
from displayctl import ipc
monitor=next(m for m in json.loads(ipc('j/monitors')) if m['focused'])
with tempfile.TemporaryDirectory(prefix='swiftshell-screenshot-test-') as d:
 folder=Path(d);qml=folder/'Pattern.qml'
 qml.write_text('''//@ pragma ShellId swiftshell-screenshot-fixture
import QtQuick
import Quickshell
import Quickshell.Wayland
ShellRoot {
 PanelWindow {
  screen:Quickshell.screens.find(function(s){return s.name==="'''+monitor['name']+'''"})
  visible:true;implicitWidth:128;implicitHeight:128;color:"#202020"
  anchors {top:true;left:true}
  exclusionMode:ExclusionMode.Ignore
  WlrLayershell.namespace:"swiftshell-screenshot-fixture"
  WlrLayershell.layer:WlrLayer.Overlay
  WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
  Canvas {
   anchors.fill:parent
   onPaint:{const c=getContext("2d");for(let y=0;y<128;y+=8)for(let x=0;x<128;x+=8){c.fillStyle=(x+y)%16===0 ? "#eeeeee" : "#202020";c.fillRect(x,y,8,8)}}
  }
 }
}
''')
 log=(folder/'runtime.log').open('w');process=subprocess.Popen(['qs','-p',str(qml)],stdout=log,stderr=subprocess.STDOUT)
 try:
  for _ in range(120):
   layers=json.loads(ipc('j/layers'));found=[]
   for groups in layers.values():
    for surfaces in groups.get('levels',{}).values():
     found += [item for item in surfaces if item.get('namespace')=='swiftshell-screenshot-fixture']
   if found:break
   time.sleep(.05)
  else:raise AssertionError('Owned screenshot fixture did not map')
  layer=found[0];time.sleep(.3)
  # All requested pixels are strictly inside the opaque owned surface.
  geometry=f"{layer['x']+16},{layer['y']+16} 64x64"
  binary=folder/'bin';binary.mkdir()
  selector=binary/'slurp';selector.write_text('#!/usr/bin/env python3\nprint('+repr(geometry)+')\n');selector.chmod(0o700)
  # Image sink validates PNG content from real grim. No user clipboard writes.
  sink=binary/'wl-copy';sink.write_text('''#!/usr/bin/env python3
import sys
from PySide6.QtGui import QImage
image=QImage.fromData(sys.stdin.buffer.read())
assert not image.isNull()
colors={image.pixelColor(x,y).lightness() for x in range(image.width()) for y in range(image.height())}
assert max(colors)>180 and min(colors)<80
''');sink.chmod(0o700)
  env=dict(os.environ,PATH=str(binary)+os.pathsep+os.environ['PATH'])
  result=subprocess.run([sys.executable,str(root/'shell/helpers/desktoptools.py'),'region'],env=env,capture_output=True,text=True,check=True)
  assert json.loads(result.stdout)['ok'],result.stdout
  print('PASS real grim region capture and PNG clipboard transport using owned pixels and a private image sink',flush=True)
 finally:
  process.terminate()
  try:process.wait(timeout=3)
  except subprocess.TimeoutExpired:process.kill();process.wait()
  log.close()
