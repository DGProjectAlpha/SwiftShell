import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell
import "../components"
import "../logic/clock.js" as Clock
import "../services"
import "../themes"

MouseArea {
    id: root

    readonly property int updatePrecision:clock.precision
    readonly property string labelText:(SettingsStore.clockDate ? Qt.formatDate(clock.date,Clock.datePattern(SettingsStore.clockDateFormat))+" · " : "")+Clock.formatTime(clock.date,SettingsStore.use24Hour,SettingsStore.clockSeconds)
    signal activated()
    property color textPrimary: Theme.textPrimary
    property color textHover: Theme.textHover

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

    Controls.ToolTip.visible:containsMouse
    Controls.ToolTip.text:Qt.formatDate(clock.date,"dddd, d MMMM yyyy")
    Controls.ToolTip.delay:600
    onClicked: activated()

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            activated()
            event.accepted = true
        }
    }

    SystemClock {
        id: clock
        precision: SettingsStore.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    BarLabel {
        id: label
        anchors.centerIn: parent
        text: root.labelText
        font.family:"Noto Sans Mono"
        color: root.containsMouse || root.activeFocus ? root.textHover : root.textPrimary

        Behavior on color {
            enabled: Theme.motionHover > 0
            ColorAnimation {
                duration: Theme.motionHover
                easing.type: Easing.OutCubic
            }
        }
    }
}
