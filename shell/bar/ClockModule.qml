import QtQuick
import Quickshell
import "../components"
import "../logic/clock.js" as Clock
import "../services"
import "../themes"

MouseArea {
    id: root

    signal activated()

    implicitWidth: label.implicitWidth
    implicitHeight: Theme.barHeight
    width: implicitWidth
    height: implicitHeight
    hoverEnabled: true
    activeFocusOnTab: true
    cursorShape: Qt.PointingHandCursor
    Accessible.role: Accessible.Button
    Accessible.name: "Clock " + label.text
    Accessible.description: "Open the calendar"

    onClicked: activated()

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            activated()
            event.accepted = true
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    BarLabel {
        id: label
        anchors.centerIn: parent
        text: Clock.formatTime(clock.date, SettingsStore.use24Hour)
        color: root.containsMouse || root.activeFocus ? Theme.textHover : Theme.textPrimary

        Behavior on color {
            enabled: Theme.motionHover > 0
            ColorAnimation {
                duration: Theme.motionHover
                easing.type: Easing.OutCubic
            }
        }
    }
}
