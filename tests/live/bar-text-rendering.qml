//@ pragma ShellId swiftshell-text-render-audit
import QtQuick
import Quickshell
import Quickshell.Wayland
import "components"
import "bar"

ShellRoot {
    id:audit
    property int completed:0
    Variants {
        model:Quickshell.screens
        PanelWindow {
            id:probe
            required property var modelData
            screen:modelData
            implicitWidth:900;implicitHeight:180
            anchors.top:true
            margins.top:70
            color:"#202020"
            exclusionMode:ExclusionMode.Ignore
            WlrLayershell.namespace:"swiftshell-text-render-audit"
            WlrLayershell.layer:WlrLayer.Overlay
            WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
            mask:Region {}
            Rectangle {
                id:sample
                anchors.fill:parent
                color:"#202020"
            Column {
                x:12;y:10;spacing:8
                Repeater {
                    model:[{label:"Curve",render:typeof Text["CurveRendering"]==="number" ? Text["CurveRendering"] : Text.QtRendering,hint:Font.PreferDefaultHinting},
                        {label:"Qt distance field",render:Text.QtRendering,hint:Font.PreferDefaultHinting},
                        {label:"Native vertical",render:Text.NativeRendering,hint:Font.PreferVerticalHinting},
                        {label:"Native full",render:Text.NativeRendering,hint:Font.PreferFullHinting}]
                    delegate:Row {
                        required property var modelData
                        spacing:20
                        Text {width:150;text:modelData.label;color:"#c4c4c4";font.family:"Noto Sans";font.pixelSize:12;renderType:Text.QtRendering}
                        Text {text:"Audio 12:34 Workspace — Maps";color:"#f2f2f2";font.family:"Noto Sans";font.pixelSize:12;renderType:modelData.render;font.hintingPreference:modelData.hint;antialiasing:true}
                        Text {text:"Sun 08 Nov · 17:39:24";color:"#f2f2f2";font.family:"Noto Sans Mono";font.pixelSize:12;renderType:modelData.render;font.hintingPreference:modelData.hint;antialiasing:true}
                        WidgetIndicator {width:24;height:24;kind:"notifications";Component.onCompleted:{for(const child of children)if(child.objectName==="barWidgetGlyph")child.antialiasing=false}}
                        WidgetIndicator {width:24;height:24;kind:"notifications"}
                    }
                }
            }
            }
            Timer {
                interval:750;running:true
                onTriggered: {
                    const path=Quickshell.env("SWIFTSHELL_TEXT_AUDIT_DIR")+"/"+probe.modelData.name+".png"
                    sample.grabToImage(function(result){
                        const saved=result.saveToFile(path)
                        console.info("Text audit: "+probe.modelData.name+" DPR="+probe.devicePixelRatio+" captured="+saved)
                        audit.completed++
                        if(audit.completed===Quickshell.screens.length)Qt.quit()
                    })
                }
            }
        }
    }
    Timer {interval:8000;running:true;onTriggered:{console.warn("Text audit timed out");Qt.quit()}}
}
