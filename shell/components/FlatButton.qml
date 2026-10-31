import QtQuick
import "../themes"

MouseArea {
    id: control

    property string label: ""
    property bool emphasized: false
    signal activated()

    implicitWidth: Math.max(labelText.implicitWidth + Theme.panelPadding, Theme.controlHeight)
    implicitHeight: Theme.controlHeight
    width: implicitWidth
    height: implicitHeight
    enabled: true
    hoverEnabled: true
    activeFocusOnTab: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    opacity: enabled ? 1 : 0.45
    Accessible.role: Accessible.Button
    Accessible.name: label

    onClicked: {
        if (enabled)
            activated()
    }

    Keys.onPressed: function (event) {
        if (!enabled)
            return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            activated()
            event.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.transparent
        radius: Theme.controlRadius
        border.width: control.activeFocus ? 1 : 0
        border.color: Theme.panelText
    }

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.panelPadding / 2
        anchors.rightMargin: Theme.panelPadding / 2
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: control.label
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: control.emphasized ? Font.Medium : Font.Normal
        color: control.enabled && (control.containsMouse || control.activeFocus) ? Theme.panelHover : Theme.panelText

        Behavior on color {
            enabled: Theme.motionHover > 0
            ColorAnimation {
                duration: Theme.motionHover
                easing.type: Easing.OutCubic
            }
        }
    }
}
