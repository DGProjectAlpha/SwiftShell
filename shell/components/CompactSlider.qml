import QtQuick
import "../themes"

FocusScope {
    id: control

    property real value: 0
    property string valueName: "Volume"
    property bool adjusting: false
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
        value = next
        moved(next)
    }

    function nudge(delta) {
        if (!enabled)
            return
        adjusting = true
        const next = Math.min(1, Math.max(0, value + delta))
        value = next
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
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 3
        radius: 1.5
        color: Theme.settingsMuted
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, control.value * parent.width)
        height: 3
        radius: 1.5
        color: control.enabled ? Theme.settingsText : Theme.settingsMuted
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(10, 10 * Theme.iconScale)
        height: Math.max(10, 10 * Theme.iconScale)
        radius: width/2
        x: Math.max(0, control.value * (parent.width - width))
        color: control.enabled ? Theme.settingsText : Theme.settingsMuted
        border.width: control.activeFocus ? 1 : 0
        border.color: Theme.settingsText
    }

    MouseArea {
        anchors.fill: parent
        enabled: control.enabled
        hoverEnabled: true
        focus: false
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: function (mouse) {
            control.forceActiveFocus()
            control.setFromX(mouse.x)
        }
        onPositionChanged: function (mouse) {
            if (pressed)
                control.setFromX(mouse.x)
        }
        onReleased: control.adjusting = false
        onCanceled: control.adjusting = false
    }
}
