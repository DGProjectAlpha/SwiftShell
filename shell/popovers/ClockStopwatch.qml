import QtQuick
import QtQuick.Controls.Basic as Controls
import "../components"
import "../logic/clocktools.js" as Tools
import "../services"
import "../themes"

Item {
    id: root
    implicitWidth: 360
    implicitHeight: column.implicitHeight
    Component.onCompleted: ClockService.viewers++
    Component.onDestruction: { if (ClockService) ClockService.viewers = Math.max(0, ClockService.viewers - 1) }
    readonly property bool running: ClockService.state.stopwatch.status === "running"
    Column {
        id: column
        width: root.width
        spacing: 14
        Item { width: 1; height: 10 }
        Text {
            objectName: "stopwatchReadout"
            width: parent.width; height: 80
            text: Tools.durationText(ClockService.elapsed, true)
            color: Theme.settingsText; font.family: "Noto Sans Mono"
            font.pixelSize: 40; font.weight: Font.Light
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            Accessible.role: Accessible.StaticText; Accessible.name: "Elapsed time " + text
        }
        Row {
            spacing: 10; anchors.horizontalCenter: parent.horizontalCenter
            FlatButton {
                objectName: "stopwatchPrimary"
                label: root.running ? "Pause" : (ClockService.elapsed > 0 ? "Resume" : "Start")
                width: 130; height: 36; emphasized: true
                enabled: ClockService.loaded
                onActivated: ClockService.stopwatch(root.running ? "pause" : "start")
            }
            FlatButton {
                objectName: "stopwatchLapReset"
                label: root.running ? "Lap" : "Reset"
                width: 100; height: 36
                enabled: root.running ? ClockService.state.stopwatch.laps.length < 50 : ClockService.elapsed > 0
                onActivated: ClockService.stopwatch(root.running ? "lap" : "reset")
            }
        }
        Text {
            width: parent.width
            text: ClockService.state.stopwatch.laps.length === 0 ? "Your laps will appear here." : "Laps · " + ClockService.state.stopwatch.laps.length
            horizontalAlignment: Text.AlignHCenter; color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily; font.pixelSize: Theme.settingsFontSizeSmall
        }
        ListView {
            id: laps
            objectName: "stopwatchLaps"
            width: parent.width
            height: Math.min(180, contentHeight)
            model: ClockService.state.stopwatch.laps
            verticalLayoutDirection: ListView.BottomToTop
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: Controls.ScrollBar { width: 4; contentItem: Rectangle {radius: 2; color: Theme.settingsMuted; opacity: .5} background: Item {} }
            delegate: Item {
                required property int index
                required property double modelData
                width: laps.width; height: 30
                Text {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "Lap " + (index + 1); color: Theme.settingsMuted
                    font.family: Theme.settingsFontFamily; font.pixelSize: Theme.settingsFontSizeSmall
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter
                    text: "+" + Tools.durationText(modelData - (index > 0 ? ClockService.state.stopwatch.laps[index - 1] : 0), true)
                    color: Theme.settingsMuted; font.family: "Noto Sans Mono"; font.pixelSize: Theme.settingsFontSizeSmall
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                    text: Tools.durationText(modelData, true); color: Theme.settingsText
                    font.family: "Noto Sans Mono"; font.pixelSize: Theme.settingsFontSizeSmall
                }
            }
        }
        Text {
            width: parent.width
            text: "Elapsed time and laps are kept when SwiftShell restarts."
            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
            color: Theme.settingsMuted; font.family: Theme.settingsFontFamily; font.pixelSize: Theme.settingsFontSizeSmall
        }
    }
}
