import QtQuick
import "../themes"

FocusScope {
    id: control

    property real value: 0
    property string valueName: "Volume"
    property bool adjusting: false
    property real interactionValue:value
    readonly property real displayValue:adjusting ? interactionValue : value
    readonly property bool hovered:pointer.containsMouse
    signal interactionStarted()
    signal interactionFinished()
    signal moved(real next)

    implicitWidth: 160
    implicitHeight: Theme.controlHeight
    activeFocusOnTab: true
    Accessible.role: Accessible.Slider
    Accessible.name: valueName + " " + Math.round(value * 100)

    function setFromX(x) {
        if (!enabled || width <= 0)
            return
        adjusting = true
        const next = Math.min(1, Math.max(0, x / width))
        interactionValue = next
        moved(next)
    }

    function nudge(delta) {
        if (!enabled)
            return
        adjusting = true
        const next = Math.min(1, Math.max(0, value + delta))
        interactionValue = next
        moved(next)
        adjusting = false
    }

    Keys.onLeftPressed: nudge(-0.05)
    Keys.onRightPressed: nudge(0.05)
    Keys.onDownPressed: nudge(-0.05)
    Keys.onUpPressed: nudge(0.05)
    Keys.onPressed: function (event) {
        const alt = (event.modifiers & Qt.AltModifier) !== 0
        if (!alt)
            return
        if (event.key === Qt.Key_J || event.key === Qt.Key_L)
            nudge(0.05)
        else if (event.key === Qt.Key_K || event.key === Qt.Key_H)
            nudge(-0.05)
        else
            return
        event.accepted = true
    }

    Rectangle {
        objectName:"sliderTrack"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: control.adjusting ? 6 : control.hovered ? 5 : 4
        radius: height/2
        Behavior on height {NumberAnimation {duration:Theme.motionHover}}
        color: Theme.settingsMuted
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, control.displayValue * parent.width)
        height: control.adjusting ? 6 : control.hovered ? 5 : 4
        radius: height/2
        Behavior on height {NumberAnimation {duration:Theme.motionHover}}
        color: control.enabled ? Theme.controlAccent : Theme.settingsMuted
    }

    Rectangle {
        objectName:"sliderThumb"
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(12, (control.adjusting ? 18 : control.hovered ? 15 : 12) * Theme.iconScale)
        height: width
        Behavior on width {NumberAnimation {duration:Theme.motionHover}}
        radius: width/2
        x: Math.max(0, control.displayValue * (parent.width - width))
        color: control.enabled ? Theme.controlAccent : Theme.settingsMuted
        border.width: control.activeFocus ? 1 : 0
        border.color: Theme.settingsText
    }

    MouseArea {
        id:pointer
        preventStealing:true
        anchors.fill: parent
        enabled: control.enabled
        hoverEnabled: true
        focus: false
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: function (mouse) {
            control.forceActiveFocus()
            control.interactionStarted()
            control.setFromX(mouse.x)
        }
        onPositionChanged: function (mouse) {
            if (pressed)
                control.setFromX(mouse.x)
        }
        onReleased: {control.adjusting=false;control.interactionFinished()}
        onCanceled: {control.adjusting=false;control.interactionFinished()}
        onWheel:function(wheel) {wheel.accepted=pressed}
    }
}
