import QtQuick
import "../themes"
MouseArea {
    id:root
    property string kind:"audio"
    property string label:"Audio"
    property bool muted:false
    property bool connected:true
    property color textPrimary:Theme.textPrimary
    property color textMuted:Theme.textMuted
    property color textHover:Theme.textPrimary
    readonly property color foreground:containsMouse || activeFocus ? textHover : textPrimary
    signal activated()
    implicitWidth:Math.max(Theme.barIcon,Theme.barHeight*.8)
    implicitHeight:Theme.barHeight
    width:implicitWidth;height:implicitHeight
    hoverEnabled:true;activeFocusOnTab:true;cursorShape:Qt.PointingHandCursor
    Accessible.role:Accessible.Button
    Accessible.name:label
    onClicked:activated()
    Keys.onPressed:function(event) {
        if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter || event.key===Qt.Key_Space){activated();event.accepted=true}
    }
    Canvas {
        id:glyph
        anchors.centerIn:parent
        width:Theme.barIcon;height:Theme.barIcon
        onWidthChanged:requestPaint()
        onHeightChanged:requestPaint()
        Connections {
            target:root
            function onForegroundChanged(){glyph.requestPaint()}
            function onKindChanged(){glyph.requestPaint()}
            function onMutedChanged(){glyph.requestPaint()}
            function onConnectedChanged(){glyph.requestPaint()}
        }
        onPaint: {
            const c=getContext("2d");c.reset();c.scale(width/24,height/24)
            c.strokeStyle=root.foreground;c.lineWidth=1.7;c.lineCap="round";c.lineJoin="round"
            if(root.kind==="notifications") {
                c.beginPath();c.moveTo(5,17);c.lineTo(7,14);c.lineTo(7,9);c.arc(12,9,5,Math.PI,0);c.lineTo(17,14);c.lineTo(19,17);c.closePath();c.stroke()
                c.beginPath();c.arc(12,19,2,0,Math.PI);c.stroke()
            } else if(root.kind==="power") {
                c.beginPath();c.arc(12,13,8,-Math.PI*.31,Math.PI*1.31);c.stroke()
                c.beginPath();c.moveTo(12,2);c.lineTo(12,11);c.stroke()
            } else if(root.kind==="network") {
                c.strokeRect(8,2,8,6);c.beginPath();c.moveTo(12,8);c.lineTo(12,14);c.moveTo(4,14);c.lineTo(20,14);c.moveTo(4,14);c.lineTo(4,17);c.moveTo(20,14);c.lineTo(20,17);c.stroke()
                c.strokeRect(1,17,6,5);c.strokeRect(17,17,6,5)
                if(!root.connected){c.beginPath();c.moveTo(2,2);c.lineTo(22,22);c.stroke()}
            } else {
                c.beginPath();c.moveTo(3,9);c.lineTo(7,9);c.lineTo(12,5);c.lineTo(12,19);c.lineTo(7,15);c.lineTo(3,15);c.closePath();c.stroke()
                c.beginPath()
                if(root.muted){c.moveTo(17,9);c.lineTo(22,15);c.moveTo(22,9);c.lineTo(17,15)}
                else {c.arc(12,12,6,-.7,.7);c.moveTo(19.65,5.56);c.arc(12,12,10,-.7,.7)}
                c.stroke()
            }
        }
    }
    Rectangle {anchors.centerIn:parent;width:parent.width;height:parent.height-4;radius:4;color:"transparent";border.width:root.activeFocus ? 1 : 0;border.color:root.foreground}
}
