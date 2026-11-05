import QtQuick
import QtQuick.Controls.Basic as Controls
import "../themes"
MouseArea {
    id:control
    property string kind:"play"
    property string label:"Play"
    property bool emphasized:false
    signal activated()
    implicitWidth:emphasized ? 64 : 48
    implicitHeight:48
    width:implicitWidth;height:implicitHeight
    hoverEnabled:true;activeFocusOnTab:true
    cursorShape:enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    opacity:enabled ? 1 : .35
    Accessible.role:Accessible.Button;Accessible.name:label
    Controls.ToolTip.visible:containsMouse || activeFocus
    Controls.ToolTip.text:label;Controls.ToolTip.delay:600
    onClicked:if(enabled)activated()
    Keys.onPressed:function(event){if(enabled && (event.key===Qt.Key_Return || event.key===Qt.Key_Enter || event.key===Qt.Key_Space)){activated();event.accepted=true}}
    Rectangle {
        anchors.fill:parent;radius:Math.max(6,Theme.controlRadius)
        color:control.pressed ? Theme.settingsSelected : control.containsMouse ? Theme.settingsHover : control.emphasized ? Theme.settingsSelected : "transparent"
        border.width:control.activeFocus ? 1 : 0;border.color:Theme.settingsText
    }
    Canvas {
        id:glyph;anchors.centerIn:parent;width:control.emphasized ? 25 : 22;height:width
        property color foreground:Theme.settingsText
        onForegroundChanged:requestPaint()
        Connections {target:control;function onKindChanged(){glyph.requestPaint()}}
        onPaint: {
            const c=getContext("2d");c.reset();c.scale(width/24,height/24);c.fillStyle=foreground
            if(control.kind==="pause"){c.fillRect(6,4.5,4,15);c.fillRect(14,4.5,4,15);return}
            if(control.kind==="previous"){c.translate(24,0);c.scale(-1,1)}
            if(control.kind==="next" || control.kind==="previous") {
                c.beginPath();c.moveTo(4.5,5);c.lineTo(16,12);c.lineTo(4.5,19);c.closePath();c.fill();c.fillRect(17.5,5,2.5,14)
            } else {c.beginPath();c.moveTo(7,4);c.lineTo(20,12);c.lineTo(7,20);c.closePath();c.fill()}
        }
    }
}
