#!/usr/bin/env python3
"""Native screenshot review/copy/Save As using only opaque owned test pixels.

The PNG clipboard sink is private; the desktop clipboard is never changed.
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

parser = argparse.ArgumentParser()
parser.add_argument("--live", action="store_true", required=True)
parser.add_argument("--interactive", action="store_true")
args=parser.parse_args()
from fullscreen_guard import require_idle_desktop
require_idle_desktop()
ROOT = Path(__file__).parents[2]
sys.path.insert(0, str(ROOT / "shell/helpers"))
from displayctl import ipc


def wait(predicate):
    for _ in range(160):
        try:
            result = predicate()
            if result:
                return result
        except (subprocess.CalledProcessError, ValueError, KeyError):
            pass
        time.sleep(0.05)
    raise AssertionError("Screenshot review did not settle")


monitors = json.loads(ipc("j/monitors"))
original_monitor = next(monitor["name"] for monitor in monitors if monitor["focused"])
with tempfile.TemporaryDirectory(prefix="swiftshell-screenshot-review-") as temporary:
    folder = Path(temporary)
    shell = folder / "shell"
    shutil.copytree(ROOT / "shell", shell)
    window = shell / "screenshots/ScreenshotWindow.qml"
    window.write_text(window.read_text().replace('namespace:"swiftshell-screenshot"', 'namespace:"swiftshell-screenshot-audit"'))
    binary = folder / "bin"
    binary.mkdir()
    selector = binary / "slurp"
    selector.write_text('#!/usr/bin/env python3\nimport os\nprint(os.environ["SWIFTSHELL_SCREENSHOT_GEOMETRY"])\n')
    selector.chmod(0o700)
    if args.interactive:
        selector.unlink()
    copier = binary / "wl-copy"
    copier.write_text('''#!/usr/bin/env python3
import os,sys
from pathlib import Path
from PySide6.QtGui import QImage
image=QImage.fromData(sys.stdin.buffer.read())
assert not image.isNull()
colors={image.pixelColor(x,y).lightness() for x in range(image.width()) for y in range(image.height())}
assert max(colors)>180 and min(colors)<80
Path(os.environ["SWIFTSHELL_SCREENSHOT_COPY_MARKER"]).write_text("copied PNG")
''')
    copier.chmod(0o700)
    if args.interactive:
        protocol=ROOT/"tests/protocols/wlr-virtual-pointer-unstable-v1.xml"
        subprocess.run(["wayland-scanner","client-header",str(protocol),str(folder/"pointer-client.h")],check=True)
        subprocess.run(["wayland-scanner","private-code",str(protocol),str(folder/"pointer-protocol.c")],check=True)
        subprocess.run(["cc","-Wall","-Wextra","-Werror","-I"+str(folder),str(ROOT/"tests/helpers/settings-pointer.c"),str(folder/"pointer-protocol.c"),"-lwayland-client","-o",str(folder/"pointer")],check=True)
    if args.interactive:
        protocol=ROOT/"tests/protocols/virtual-keyboard-unstable-v1.xml"
        subprocess.run(["wayland-scanner","client-header",str(protocol),str(folder/"keyboard-client.h")],check=True)
        subprocess.run(["wayland-scanner","private-code",str(protocol),str(folder/"keyboard-protocol.c")],check=True)
        subprocess.run(["cc","-Wall","-Wextra","-Werror","-I"+str(folder),str(ROOT/"tests/helpers/launcher-keyboard.c"),str(folder/"keyboard-protocol.c"),"-lwayland-client","-lxkbcommon","-o",str(folder/"keyboard")],check=True)
    qml = shell / "ScreenshotAudit.qml"
    qml.write_text('''//@ pragma UseQApplication
//@ pragma ShellId swiftshell-screenshot-audit
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"
import "screenshots"
import "launcher"
ShellRoot {
 id:root
 property string lastAction:""
 property var output:Quickshell.screens.find(function(s){return s.name===Quickshell.env("SWIFTSHELL_SCREENSHOT_OUTPUT")})
 Component.onCompleted:Quickshell.watchFiles=false
 PanelWindow {
  screen:root.output;visible:true;anchors {top:true;bottom:true;left:true;right:true}
  color:"#202020";exclusionMode:ExclusionMode.Ignore
  WlrLayershell.namespace:"swiftshell-screenshot-owned-pattern"
  WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
  Canvas {anchors.fill:parent;onPaint:{const c=getContext("2d");for(let y=0;y<height;y+=8)for(let x=0;x<width;x+=8){c.fillStyle=(x+y)%16===0 ? "#eeeeee" : "#202020";c.fillRect(x,y,8,8)}}}
 }
 ScreenshotWindow {id:review}
 LauncherWindow {id:spotlight;companionWindows:review.visible ? [review] : []}
 function find(item,name){if(item.objectName===name)return item;for(let i=0;i<item.children.length;i++){const match=find(item.children[i],name);if(match)return match}return null}
 IpcHandler {
  target:"audit"
  function state():string {const image=root.find(review.contentItem,"screenshotPreview");return JSON.stringify({spotlight:LauncherModel.open,searchFocus:spotlight.searchHasFocus,lastAction:root.lastAction,output:root.output ? root.output.name : "",ready:SettingsStore.persistenceState==="ready",available:ScreenshotService.available,open:ScreenshotService.open,busy:ScreenshotService.busy,hasImage:ScreenshotService.hasImage,imageReady:!!image && image.status===Image.Ready,failed:ScreenshotService.failed,message:ScreenshotService.message,token:ScreenshotService.token,review:review.diagnostics()})}
  function action(next:string):void {
   root.lastAction=next
   if(next==="open-review")ScreenshotService.show(root.output.name)
   else if(next==="capture")ScreenshotService.capture("region",root.output.name)
   else if(next==="copy")ScreenshotService.copy()
   else if(next==="save-dialog")ScreenshotService.saveAs()
   else if(next==="discard")ScreenshotService.discard()
   else if(next==="close")ScreenshotService.close()
   else if(next==="spotlight")LauncherModel.openLauncher()
   else if(next==="close-spotlight")LauncherModel.closeLauncher()
  }
  function accept(destination:string):void {
   const loader=root.find(review.contentItem,"screenshotSaveDialogLoader")
   loader.item.selectedFile=destination
   loader.item.accepted()
   loader.item.close()
  }
 }
}
''')
    for monitor in monitors:
        name = monitor["name"]
        ipc("eval hl.dispatch(hl.dsp.focus({monitor=" + json.dumps(name) + "}))")
        marker = folder / (name + "-copied")
        env = dict(os.environ, XDG_CONFIG_HOME=str(folder / name / "config"),
                   XDG_STATE_HOME=str(folder / name / "state"), XDG_CACHE_HOME=str(folder / name / "cache"),
                   PATH=str(binary) + os.pathsep + os.environ["PATH"], QT_QPA_PLATFORMTHEME="generic",
                   QT_NO_XDG_DESKTOP_PORTAL="1", NO_AT_BRIDGE="1", SWIFTSHELL_SCREENSHOT_OUTPUT=name,
                   SWIFTSHELL_SCREENSHOT_GEOMETRY=f'{monitor["x"]+32},{monitor["y"]+32} 64x64',
                   SWIFTSHELL_SCREENSHOT_COPY_MARKER=str(marker))
        log_path = folder / (name + ".log")
        with log_path.open("w") as log:
            process = subprocess.Popen(["qs", "-p", str(qml)], env=env, stdout=log, stderr=subprocess.STDOUT)
            command = ["qs", "ipc", "-p", str(qml), "call", "audit"]

            def call(*args):
                return subprocess.check_output(command + list(args), env=env, text=True, stderr=subprocess.DEVNULL)

            def state():
                return json.loads(call("state"))

            try:
                wait(lambda: state()["ready"] and state()["available"])
                call("action", "open-review")
                wait(lambda: state()["review"]["visible"])
                call("action", "spotlight")
                wait(lambda: state()["spotlight"] and state()["searchFocus"])
                time.sleep(.3)
                assert state()["review"]["visible"], "Opening Spotlight dismissed Capture"
                call("action", "close-spotlight")
                wait(lambda: not state()["spotlight"])
                assert state()["review"]["visible"], "Closing Spotlight dismissed Capture"
                time.sleep(0.25)
                backgrounds=[item for output in json.loads(ipc("j/layers")).values() for group in output.get("levels",{}).values() for item in group if item.get("namespace")=="swiftshell-screenshot-owned-pattern"]
                pattern=next(item for item in backgrounds if item["x"]<=monitor["x"]+32 and item["y"]<=monitor["y"]+32 and item["x"]+item["w"]>=monitor["x"]+96 and item["y"]+item["h"]>=monitor["y"]+96)
                call("action", "spotlight")
                wait(lambda: state()["spotlight"] and state()["searchFocus"])
                call("action", "capture")
                if args.interactive:
                    wait(lambda:state()["busy"] and not state()["review"]["visible"])
                    time.sleep(.8)
                    namespaces=[item.get("namespace","") for output in json.loads(ipc("j/layers")).values() for group in output.get("levels",{}).values() for item in group]
                    assert "selection" in namespaces,"Real area selector did not map"
                    from displayctl import logical_size
                    mw,mh=map(round,logical_size(monitor))
                    x=monitor["x"]+32;y=monitor["y"]+32
                    assert pattern["x"]<=x and pattern["y"]<=y and x+64<=pattern["x"]+pattern["w"] and y+64<=pattern["y"]+pattern["h"]
                    selection=[str(folder/"pointer"),"32","32",str(mw),str(mh),"64","64",name,str(x),str(y)]
                    for _ in range(3):
                        result=subprocess.run(selection)
                        if result.returncode==0:break
                        if result.returncode!=6:result.check_returncode()
                        time.sleep(.15)
                    result.check_returncode()
                wait(lambda: state()["hasImage"] and state()["imageReady"] and not state()["busy"])
                assert not state()["failed"], state()["message"]
                assert state()["spotlight"], "Capture dismissed the target Spotlight panel"
                call("action", "close-spotlight")
                time.sleep(0.2)
                frame=state()["review"]["frame"]
                x=monitor["x"]+round(frame["x"]);y=monitor["y"]+round(frame["y"])
                width=round(frame["width"]);height=round(frame["height"])
                assert x>=pattern["x"] and y>=pattern["y"] and x+width<=pattern["x"]+pattern["w"] and y+height<=pattern["y"]+pattern["h"],"Capture would include unowned pixels"
                subprocess.run(["grim","-g",f"{x},{y} {width}x{height}",str(Path("/tmp")/("swiftshell-screenshot-"+name+"-review.png"))],check=True)
                call("action", "copy")
                wait(lambda: marker.exists() and not state()["busy"])
                assert not state()["failed"], state()["message"]
                call("action", "save-dialog")
                wait(lambda: state()["review"]["saving"])
                destination = folder / (name + " saved $literal.png")
                # Real dialog creation plus its accepted handler and real atomic PNG export.
                # This is not a claim of a physical pointer clicking the platform Save button.
                call("accept", destination.as_uri())
                wait(lambda: destination.exists() and not state()["busy"])
                assert not state()["failed"], state()["message"]
                from PySide6.QtGui import QImage
                image = QImage(str(destination))
                assert not image.isNull()
                assert image.width() > 0 and image.height() > 0
                print("PASS " + name + ": native screenshot preview, private PNG clipboard transport, native Save As handler and real PNG export", flush=True)
                call("action", "discard")
                wait(lambda: not state()["hasImage"] and not state()["busy"])
                if args.interactive:
                    def selecting():
                        return any(item.get("namespace")=="selection" for output in json.loads(ipc("j/layers")).values() for group in output.get("levels",{}).values() for item in group)
                    call("action","capture")
                    wait(selecting)
                    subprocess.run([str(folder/"keyboard"),"escape"],check=True)
                    wait(lambda:not state()["busy"] and state()["open"])
                    assert not state()["failed"],"Escape is a cancellation, not an error"
                    call("action","capture")
                    wait(selecting)
                    call("action","close")
                    wait(lambda:not state()["busy"] and not selecting())
                    assert not state()["open"]
                    print("PASS "+name+": real crosshair selection, Escape cancellation and closing removes selector/busy state",flush=True)
                call("action", "close")
            finally:
                try:
                    call("action","close")
                    wait(lambda:not state()["busy"])
                except (subprocess.SubprocessError,AssertionError):
                    pass
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        errors = [line for line in log_path.read_text().splitlines() if any(error in line for error in ("TypeError", "ReferenceError", "Binding loop", "Failed to load configuration", "is not a type"))]
        assert not errors, "\n".join(errors)
ipc("eval hl.dispatch(hl.dsp.focus({monitor=" + json.dumps(original_monitor) + "}))")
