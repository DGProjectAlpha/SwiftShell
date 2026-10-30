import QtQuick
import Quickshell
import "../components"
import "../logic/clock.js" as Clock
import "../services"
import "../themes"

Item {
    implicitWidth: label.implicitWidth
    implicitHeight: Theme.barHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    BarLabel {
        id: label
        anchors.centerIn: parent
        text: Clock.formatTime(clock.date, SettingsStore.use24Hour)
        Accessible.role: Accessible.StaticText
        Accessible.name: "Clock " + text
    }
}
