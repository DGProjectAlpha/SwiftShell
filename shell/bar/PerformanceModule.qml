import QtQuick
import "../services"
import "../themes"
MouseArea {
    id:root
    property color textPrimary:Theme.textPrimary
    property color textMuted:Theme.textMuted
    property color textHover:Theme.textPrimary
    signal activated()
    implicitWidth:metrics.implicitWidth
    implicitHeight:Theme.barHeight
    width:implicitWidth;height:implicitHeight
    hoverEnabled:true;activeFocusOnTab:true;cursorShape:Qt.PointingHandCursor
    Accessible.role:Accessible.Button
    Accessible.name:"Performance: CPU "+SystemPerformance.percent(SystemPerformance.cpu.usage)+", GPU "+SystemPerformance.percent(SystemPerformance.gpu.usage)+", memory "+SystemPerformance.percent(SystemPerformance.memory.usage)
    Component.onCompleted:SystemPerformance.startViewing()
    Component.onDestruction:SystemPerformance.stopViewing()
    onClicked:activated()
    Keys.onPressed:function(event) {
        if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter || event.key===Qt.Key_Space){activated();event.accepted=true}
    }
    Row {
        id:metrics
        anchors.verticalCenter:parent.verticalCenter
        spacing:Math.max(6,Theme.barFont*.65)
        Repeater {
            model:["C","G","M"]
            delegate:Text {
                required property string modelData
                required property int index
                objectName:"performanceBarMetric-"+modelData
                readonly property var usage:index===0 ? SystemPerformance.cpu.usage : index===1 ? SystemPerformance.gpu.usage : SystemPerformance.memory.usage
                width:Theme.barFont*3.8
                text:modelData+" "+SystemPerformance.percent(usage)
                color:root.containsMouse || root.activeFocus ? root.textHover : root.textPrimary
                font.family:Theme.fontFamily;font.pixelSize:Theme.barFont
                horizontalAlignment:Text.AlignLeft
            }
        }
    }
    Rectangle {anchors.fill:parent;anchors.margins:2;radius:4;color:"transparent";border.width:root.activeFocus ? 1 : 0;border.color:root.textPrimary}
}
