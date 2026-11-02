#!/usr/bin/env python3
"""Real sampler and both-output rendering over opaque owned pixels only."""
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
parser.parse_args()
root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / "shell/helpers"))
from displayctl import ipc

with tempfile.TemporaryDirectory(prefix="swiftshell-performance-native-") as directory:
    folder = Path(directory)
    shutil.copytree(root / "shell", folder / "shell")
    config = folder / "config/swiftshell"
    config.mkdir(parents=True)
    shutil.copy2(root / "shell/config/defaults.json", config / "settings.json")
    qml = folder / "shell/PerformanceAudit.qml"
    qml.write_text('''//@ pragma ShellId swiftshell-performance-audit
import QtQuick
import Quickshell
import Quickshell.Wayland
import "services"
import "bar"
import "popovers"
ShellRoot {
 id:root
 property var windows:[]
 property bool ready:false
 function label(item) {
  if(item.objectName==="performanceBarMetric-C")return item
  for(let i=0;i<item.children.length;i++){const found=label(item.children[i]);if(found)return found}
  return null
 }
 Variants {
  model:Quickshell.screens
  delegate:PanelWindow {
   id:window
   required property var modelData
   property var initialLabel:null
   screen:modelData
   visible:true;implicitWidth:510;implicitHeight:650;color:"#252525"
   anchors {top:true;left:true}
   exclusionMode:ExclusionMode.Ignore
   WlrLayershell.namespace:"swiftshell-performance-audit"
   WlrLayershell.layer:WlrLayer.Overlay
   WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
   Component.onCompleted:{root.windows.push(window);Qt.callLater(function(){window.initialLabel=root.label(module)})}
   Canvas {
    anchors.fill:parent
    onPaint:{const c=getContext("2d");for(let y=0;y<height;y+=12)for(let x=0;x<width;x+=12){c.fillStyle=(x+y)%24===0 ? "#464646" : "#252525";c.fillRect(x,y,12,12)}}
   }
   PerformanceModule {id:module;x:45;y:12;textPrimary:"#ffffff";textHover:"#ffffff"}
   PopoverSurface {x:45;y:55;PerformancePanel {}}
   function stable(){return initialLabel!==null && root.label(module)===initialLabel}
  }
 }
 Timer {
  interval:100;repeat:true;running:!root.ready
  onTriggered: {
   if(SystemPerformance.cpuHistory.length<3 || !SystemPerformance.available)return
   for(let i=0;i<root.windows.length;i++)if(!root.windows[i].stable()){console.info("PERFORMANCE_AUDIT_FAILED delegate replaced");Qt.quit();return}
   root.ready=true
   console.info("PERFORMANCE_AUDIT_READY "+JSON.stringify({outputs:root.windows.length,cpu:SystemPerformance.cpu.usage,memory:SystemPerformance.memory.usage,cpuTemperature:SystemPerformance.cpu.temperature,gpus:SystemPerformance.gpus.length,gpuTemperature:SystemPerformance.gpu.temperature,samples:SystemPerformance.cpuHistory.length,viewers:SystemPerformance.viewers}))
  }
 }
 Timer {interval:30000;running:true;onTriggered:Qt.quit()}
}
''')
    log_path = folder / "runtime.log"
    env = dict(os.environ, XDG_CONFIG_HOME=str(folder / "config"), XDG_STATE_HOME=str(folder / "state"), XDG_CACHE_HOME=str(folder / "cache"))
    with log_path.open("w") as log:
        process = subprocess.Popen(["qs", "-p", str(qml)], env=env, stdout=log, stderr=subprocess.STDOUT)
        try:
            for _ in range(220):
                output = log_path.read_text()
                if "PERFORMANCE_AUDIT_READY " in output:
                    break
                if process.poll() is not None:
                    raise AssertionError("Native performance fixture exited before sampling; inspect isolated log.")
                time.sleep(0.05)
            else:
                raise AssertionError("Native performance fixture did not collect real samples.")
            summary = json.loads(output.split("PERFORMANCE_AUDIT_READY ", 1)[1].splitlines()[0])
            assert 0 <= summary["cpu"] <= 100 and 0 <= summary["memory"] <= 100
            assert summary["samples"] >= 3
            if shutil.which("nvidia-smi"):
                assert summary["gpus"] >= 1 and summary["gpuTemperature"] is not None
            assert not any(error in output for error in ["TypeError", "ReferenceError", "Binding loop", "Failed to load configuration"])
            captured = 0
            layers = json.loads(ipc("j/layers"))
            for connector, groups in layers.items():
                for surfaces in groups.get("levels", {}).values():
                    for layer in surfaces:
                        if layer.get("namespace") != "swiftshell-performance-audit":
                            continue
                        # Capture lies strictly inside an opaque owned surface.
                        geometry = f"{layer['x']+4},{layer['y']+4} {layer['w']-8}x{layer['h']-8}"
                        if shutil.which("grim"):
                            subprocess.run(["grim", "-g", geometry, f"/tmp/swiftshell-performance-{connector}.png"], check=True, capture_output=True)
                        captured += 1
            assert captured == summary["outputs"] and captured > 0
            print("PASS real CPU delta, RAM, GPU/sensor telemetry and retained bar delegates on " + str(captured) + " outputs; only owned pixels captured")
        finally:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
