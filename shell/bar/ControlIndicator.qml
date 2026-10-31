import QtQuick
import "../themes"

MouseArea {
    id: root

    signal activated()

    implicitWidth: Theme.barIcon
    implicitHeight: Theme.barHeight
    width: implicitWidth
    height: implicitHeight
    hoverEnabled: true
    activeFocusOnTab: true
    cursorShape: Qt.PointingHandCursor
    Accessible.role: Accessible.Button
    Accessible.name: "Control center"
    Accessible.description: "Open audio and status"

    onClicked: activated()

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            activated()
            event.accepted = true
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: 3

            delegate: Rectangle {
                width: Math.max(2, 2 * Theme.iconScale)
                height: width
                color: root.containsMouse || root.activeFocus ? Theme.textHover : Theme.textMuted

                Behavior on color {
                    enabled: Theme.motionHover > 0
                    ColorAnimation {
                        duration: Theme.motionHover
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.transparent
        border.width: root.activeFocus ? 1 : 0
        border.color: Theme.textPrimary
    }
}
