import QtQuick
import "../components"
import "../services"
import "../themes"
MouseArea {
    id:root
    readonly property var barSizing:Theme.barMetricsFor(root)
    function sized(value) {return Math.round(value*barSizing.sizeScale)}
    property color textPrimary:Theme.textPrimary
    property color textMuted:Theme.textMuted
    property color textHover:Theme.textPrimary
    readonly property int valueSize:root.barSizing.valueFont
    readonly property int temperatureSize:root.barSizing.temperatureFont
    readonly property color foreground:containsMouse || activeFocus ? textHover : textPrimary
    function compactTemperature(value) {return typeof value==="number" && isFinite(value) ? Math.round(value)+"°C" : "—"}
    signal activated()
    implicitWidth:metrics.implicitWidth
    implicitHeight:root.barSizing.height
    width:implicitWidth;height:implicitHeight
    hoverEnabled:true;activeFocusOnTab:true;cursorShape:Qt.PointingHandCursor
    Accessible.role:Accessible.Button
    Accessible.name:"Performance: CPU load "+SystemPerformance.percent(SystemPerformance.cpu.usage)+", CPU temperature "+SystemPerformance.temperature(SystemPerformance.cpu.temperature)+", GPU load "+SystemPerformance.percent(SystemPerformance.gpu.usage)+", GPU temperature "+SystemPerformance.temperature(SystemPerformance.gpu.temperature)+", memory load "+SystemPerformance.percent(SystemPerformance.memory.usage)
    Component.onCompleted:SystemPerformance.startViewing()
    Component.onDestruction:SystemPerformance.stopViewing()
    onClicked:activated()
    Keys.onPressed:function(event) {
        if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter || event.key===Qt.Key_Space){activated();event.accepted=true}
    }
    Row {
        id:metrics
        anchors.verticalCenter:parent.verticalCenter
        spacing:Math.max(root.sized(6),Math.round(root.barSizing.font*.5))
        Repeater {
            model:["cpu","gpu","ram"]
            delegate:Item {
                required property string modelData
                required property int index
                objectName:"performanceBarMetric-"+modelData
                readonly property var usage:index===0 ? SystemPerformance.cpu.usage : index===1 ? SystemPerformance.gpu.usage : SystemPerformance.memory.usage
                readonly property var temperature:index===0 ? SystemPerformance.cpu.temperature : index===1 ? SystemPerformance.gpu.temperature : null
                readonly property bool thermal:index<2
                width:glyph.width+root.sized(3)+(thermal ? Math.max(thermalWidth.width,loadWidth.width) : loadWidth.width)
                height:root.barSizing.height
                PerformanceGlyph {
                    id:glyph
                    objectName:"performanceGlyph-"+modelData
                    kind:modelData
                    anchors.left:parent.left;anchors.verticalCenter:parent.verticalCenter
                    width:root.barSizing.performanceIcon;height:width
                    foreground:root.foreground
                }
                Column {
                    anchors.left:glyph.right;anchors.leftMargin:root.sized(3);anchors.verticalCenter:parent.verticalCenter
                    width:parent.width-glyph.width-root.sized(3)
                    spacing:0
                    Text {
                        objectName:"performanceLoad-"+modelData
                        renderType:Theme.barTextRendering(root);antialiasing:true;font.hintingPreference:Font.PreferVerticalHinting
                        width:parent.width;height:root.valueSize+root.sized(1)
                        text:SystemPerformance.percent(usage)
                        textFormat:Text.PlainText
                        color:root.foreground
                        font.family:Theme.fontFamily;font.pixelSize:root.valueSize;font.weight:Font.Medium
                        lineHeightMode:Text.FixedHeight;lineHeight:height
                        verticalAlignment:Text.AlignVCenter
                    }
                    Text {
                        objectName:"performanceTemperature-"+modelData
                        renderType:Theme.barTextRendering(root);antialiasing:true;font.hintingPreference:Font.PreferVerticalHinting
                        width:parent.width;height:root.temperatureSize+root.sized(1)
                        visible:thermal
                        text:root.compactTemperature(temperature)
                        textFormat:Text.PlainText
                        color:root.containsMouse || root.activeFocus ? root.textHover : root.textMuted
                        font.family:Theme.fontFamily;font.pixelSize:root.temperatureSize
                        lineHeightMode:Text.FixedHeight;lineHeight:height
                        verticalAlignment:Text.AlignVCenter
                    }
                }
            }
        }
    }
    TextMetrics {id:thermalWidth;font.family:Theme.fontFamily;font.pixelSize:root.temperatureSize;text:"100°C"}
    TextMetrics {id:loadWidth;font.family:Theme.fontFamily;font.pixelSize:root.valueSize;font.weight:Font.Medium;text:"100%"}
    Rectangle {anchors.fill:parent;anchors.margins:root.sized(2);radius:root.sized(4);color:"transparent";border.width:root.activeFocus ? 1 : 0;border.color:root.textPrimary}
}
