import QtQuick
import "../themes"

FocusScope {
    id: control

    property real value: 0
    property bool enabled: true
    signal moved(real next)

    implicitWidth: 160
    implicitHeight: Theme.controlHeight
    activeFocusOnTab: true
    Accessible.role: Accessible.Slider
    Accessible.name: "Volume"
    Accessible.value: Math.round(value * 100)

    function setFromX(x) {
        if (!enabled || width <= 0)
            return
        moved(Math.min(1, Math.max(0, x / width)))
    }

    function nudge(delta) {
        if (!enabled)
            return
        moved(Math.min(1, Math.max(0, value + delta)))
    }

    Keys.onLeftPressed: nudge(-0.05)
    Keys.onRightPressed: nudge(0.05)
    Keys.onDownPressed: nudge(-0.05)
    Keys.onUpPressed: nudge(0.05)

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        color: Theme.panelMuted
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, control.value * parent.width)
        height: 1
        color: control.enabled ? Theme.panelText : Theme.panelMuted
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(4, 6 * Theme.iconScale)
        height: Math.max(4, 6 * Theme.iconScale)
        x: Math.max(0, control.value * (parent.width - width))
        color: control.enabled ? Theme.panelText : Theme.panelMuted
        border.width: control.activeFocus ? 1 : 0
        border.color: Theme.panelText
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
    }
}
