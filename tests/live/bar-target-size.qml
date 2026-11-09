//@ pragma ShellId swiftshell-target-size-audit
import QtQuick
import Quickshell
import Quickshell.Wayland
import "components"
import "bar"
import "services"

// Render controlled labels/icons using the actual hidden BarWindow's metrics.
// Temporary settings are supplied by test-bar-text-native.py. No user surfaces
// are captured, no keyboard focus is requested, and no pointer input is accepted.
ShellRoot {
    id:audit
    property int completed:0
    Variants {
        model:Quickshell.screens
        PanelWindow {
            id:probe
            required property var modelData
            property int sizeIndex:0
            property bool waiting:false
            property bool capturing:false
            readonly property var sizes:[28,32,42]
            screen:modelData
            implicitWidth:900;implicitHeight:80
            anchors.top:true
            margins.top:70
            color:"#202020"
            exclusionMode:ExclusionMode.Ignore
            WlrLayershell.namespace:"swiftshell-target-size-audit"
            WlrLayershell.layer:WlrLayer.Overlay
            WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
            mask:Region {}
            BarWindow {id:measured;modelData:probe.modelData;visible:false}
            Rectangle {
                id:sample
                anchors.fill:parent;color:"#202020"
                readonly property var barMetrics:measured.barMetrics
                readonly property int barTextRenderType:measured.barTextRenderType
                Text {x:12;y:5;text:probe.sizes[probe.sizeIndex]+" px · output DPR "+probe.devicePixelRatio;color:"#c4c4c4";font.pixelSize:11}
                Row {
                    id:row
                    x:12;y:26;spacing:16
                    BarLabel {id:label;text:"Audio 12:34 Workspace — Maps"}
                    WidgetIndicator {id:icon;kind:"notifications"}
                    ClockModule {showDate:false;showSeconds:false}
                }
            }
            Timer {
                interval:120;running:probe.sizeIndex<probe.sizes.length;repeat:true
                onTriggered: {
                    if(SettingsStore.persistenceState!=="ready" || probe.capturing)return
                    const size=probe.sizes[probe.sizeIndex]
                    if(!probe.waiting) {
                        if(!SettingsStore.setBarSizeForOutput(measured.monitorKey,size))throw new Error("Target size rejected")
                        probe.waiting=true;return
                    }
                    if(measured.implicitHeight!==size || measured.contentScale!==1 || label.font.pixelSize!==measured.barMetrics.font
                            || icon.height!==measured.barMetrics.height || row.scale!==1 || sample.scale!==1)
                        throw new Error("Target-size geometry or untransformed rendering failed")
                    if(probe.devicePixelRatio===1 && label.renderType!==Text.NativeRendering)throw new Error("Native rendering missing at custom target size")
                    const path=Quickshell.env("SWIFTSHELL_TEXT_AUDIT_DIR")+"/"+probe.modelData.name+"-"+size+".png"
                    probe.capturing=true
                    sample.grabToImage(function(result){
                        const saved=result.saveToFile(path)
                        console.info("Text audit: "+probe.modelData.name+"-"+size+" DPR="+probe.devicePixelRatio+" captured="+saved)
                        console.info("Target-size audit: height="+size+" font="+label.font.pixelSize+" icon="+measured.barMetrics.icon+" transform="+measured.contentScale)
                        probe.capturing=false;probe.waiting=false;probe.sizeIndex++
                        if(probe.sizeIndex===probe.sizes.length) {audit.completed++;if(audit.completed===Quickshell.screens.length)Qt.quit()}
                    })
                }
            }
        }
    }
    Timer {interval:10000;running:true;onTriggered:{console.warn("Text audit timed out");Qt.quit()}}
}
