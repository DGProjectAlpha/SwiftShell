#!/usr/bin/env python3
"""Compare real bar font rasterization and geometry using only owned framebuffer pixels."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from PySide6.QtGui import QImage

parser = argparse.ArgumentParser()
parser.add_argument("--live", action="store_true", required=True)
parser.parse_args()
root = Path(__file__).resolve().parents[2]


def edge_pixels(image, x, y, width, height, dpr):
    values = []
    for row in range(round(y * dpr), round((y + height) * dpr)):
        for column in range(round(x * dpr), round((x + width) * dpr)):
            values.append(image.pixelColor(column, row).red())
    foreground = [value for value in values if value > 8]
    assert len(foreground) > 500, "Owned text did not render"
    return values, sum(value < 230 for value in foreground) / len(foreground)


with tempfile.TemporaryDirectory(prefix="swiftshell-bar-rendering-") as directory:
    folder = Path(directory)
    shutil.copytree(root / "shell", folder / "shell")
    config = folder / "config/swiftshell"
    config.mkdir(parents=True)
    shutil.copy2(root / "shell/config/defaults.json", config / "settings.json")
    qml = folder / "shell/BarRenderingAudit.qml"
    qml.write_text('''//@ pragma ShellId swiftshell-bar-rendering-audit
import QtQuick
import Quickshell
import Quickshell.Wayland
import "bar"
import "components"
import "logic/bar.js" as Bar
ShellRoot {
 id:root
 property int captured:0
 Variants {
  model:Quickshell.screens
  delegate:PanelWindow {
   id:window
   required property var modelData
   screen:modelData
   visible:true;implicitWidth:700;implicitHeight:300;color:"#000000"
   anchors {top:true;left:true}
   exclusionMode:ExclusionMode.Ignore
   WlrLayershell.namespace:"swiftshell-bar-rendering-audit"
   WlrLayershell.layer:WlrLayer.Overlay
   WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
   property real contentScale:1
   property bool vertical:false
   property real railWidth:168
   readonly property int barTextRenderType:Bar.textRenderMode(devicePixelRatio,contentScale,typeof Text["CurveRendering"]==="number")==="curve" ? Text["CurveRendering"] : Text.QtRendering
   function componentFor(id){return sampleModule}
   Component {id:sampleModule;Item {implicitWidth:139.375;implicitHeight:30;BarLabel {text:"SwiftShell 12:34";color:"white"}}}
   Rectangle {
    id:frame
    anchors.fill:parent;color:"#000000"
    readonly property int barTextRenderType:window.barTextRenderType
    Text {x:12;y:20;text:"Previous renderer";color:"#999999";font.pixelSize:12}
    Item {
     x:180;y:20;width:500;height:50
     Text {text:"Mon 2 Nov · 12:34 CPU 31% GPU 44°C";font.family:"Noto Sans Mono";font.pixelSize:13;font.weight:Font.Normal;renderType:Text.QtRendering;color:"white"}
     Text {y:20;text:"Workspaces 1 2 3 · Search SwiftShell";font.family:"Noto Sans";font.pixelSize:13;font.weight:Font.Normal;renderType:Text.QtRendering;color:"white"}
    }
    Text {x:12;y:100;text:"Bar renderer";color:"#999999";font.pixelSize:12}
    Item {
     x:180;y:100;width:500;height:50
     BarLabel {text:"Mon 2 Nov · 12:34 CPU 31% GPU 44°C";font.family:"Noto Sans Mono";font.pixelSize:13;font.weight:Font.Normal;color:"white"}
     BarLabel {y:20;text:"Workspaces 1 2 3 · Search SwiftShell";font.family:"Noto Sans";font.pixelSize:13;font.weight:Font.Normal;color:"white"}
    }
    ModuleStrip {id:modules;x:20.375;y:200.375;barWindow:window;modules:["search","clock","network"]}
   }
   Timer {
    interval:900;running:true
    onTriggered:frame.grabToImage(function(result){
     const saved=result.saveToFile("/tmp/swiftshell-bar-render-"+window.screen.name+".png")
     console.info("BAR_RENDER_RESULT "+JSON.stringify({output:window.screen.name,dpr:window.devicePixelRatio,screenDpr:window.screen.devicePixelRatio,width:window.width,height:window.height,mode:window.barTextRenderType===Text.QtRendering ? "distance-field" : "curve",geometry:modules.renderingGeometry(),saved:saved}))
     root.captured++;if(root.captured===Quickshell.screens.length)Qt.quit()
    })
   }
  }
 }
 Timer {interval:5000;running:true;onTriggered:Qt.quit()}
}
''')
    env = dict(os.environ, XDG_CONFIG_HOME=str(folder / "config"), XDG_STATE_HOME=str(folder / "state"), XDG_CACHE_HOME=str(folder / "cache"))
    result = subprocess.run(["qs", "-p", str(qml)], env=env, capture_output=True, text=True, timeout=8)
    output = result.stdout + result.stderr
    assert result.returncode == 0
    assert not any(error in output for error in ["TypeError", "ReferenceError", "Binding loop", "Failed to load configuration"])
    records = [json.loads(line.split("BAR_RENDER_RESULT ", 1)[1]) for line in output.splitlines() if "BAR_RENDER_RESULT " in line]
    assert len(records) >= 1, "Owned rendering fixture did not capture"
    for record in records:
        assert record["saved"]
        dpr = record["dpr"]
        image = QImage("/tmp/swiftshell-bar-render-" + record["output"] + ".png")
        assert not image.isNull()
        assert abs(image.width() - round(record["width"] * dpr)) <= 1
        assert abs(image.height() - round(record["height"] * dpr)) <= 1
        before, old_edges = edge_pixels(image, 180, 20, 500, 50, dpr)
        after, new_edges = edge_pixels(image, 180, 100, 500, 50, dpr)
        if dpr == 1:
            assert record["mode"] == "curve"
            assert new_edges < old_edges * .98, "Low-DPI bar text did not reduce intermediate-gray edge coverage"
            assert all(abs(item["x"] - round(item["x"])) < .001 and abs(item["y"] - round(item["y"])) < .001 for item in record["geometry"])
        else:
            assert record["mode"] == "distance-field"
            assert before == after, "Fractional-DPI text rasterization changed"
            assert abs(record["geometry"][0]["x"] - 20.375) < .001
        print("PASS owned native bar rendering " + record["output"] + ": DPR " + str(dpr) + ", intermediate-gray edge fraction " + str(round(old_edges, 4)) + " → " + str(round(new_edges, 4)) + ", " + record["mode"])
