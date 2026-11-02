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
    readonly property string status: ClockService.timerStatus
    property int selectedSeconds: Math.round(ClockService.state.timer.duration / 1000)
    function start() { ClockService.timer("start", selectedSeconds * 1000) }
    Column {
        id: column
        width: root.width
        spacing: 14
        Item { width: 1; height: 10 }
        Text {
            objectName: "countdownReadout"
            width: parent.width; height: 80
            text: Tools.durationText(root.status === "ready" ? root.selectedSeconds * 1000 : ClockService.remaining, false)
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            color: Theme.settingsText; font.family: "Noto Sans Mono"
            font.pixelSize: 48; font.weight: Font.Light
            Accessible.role: Accessible.StaticText; Accessible.name: "Time remaining " + text
        }
        Text {
            width: parent.width
            text: root.status === "finished" ? "Time’s up" : (root.status === "running" ? "Counting down" : root.status === "paused" ? "Paused" : "Make a little time")
            horizontalAlignment: Text.AlignHCenter; color: root.status === "finished" ? Theme.settingsText : Theme.settingsMuted
            font.family: Theme.settingsFontFamily; font.pixelSize: Theme.settingsFontSize
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            visible: root.status === "ready"
            Repeater {
                model: [{label: "Hours", divisor: 3600, maximum: 167}, {label: "Minutes", divisor: 60, maximum: 59}, {label: "Seconds", divisor: 1, maximum: 59}]
                delegate: Column {
                    required property var modelData
                    spacing: 5
                    Controls.SpinBox {
                        id: durationPart
                        objectName: "timer" + modelData.label
                        width: 100; height: 38
                        from: 0; to: modelData.maximum
                        editable: true
                        value: Math.floor(root.selectedSeconds / modelData.divisor) % (modelData.divisor === 3600 ? 168 : 60)
                        onValueModified: {
                            const previous = Math.floor(root.selectedSeconds / modelData.divisor) % (modelData.divisor === 3600 ? 168 : 60);
                            root.selectedSeconds += (value - previous) * modelData.divisor;
                        }
                        Accessible.name: modelData.label
                        font.family: Theme.settingsFontFamily; font.pixelSize: Theme.settingsFontSize + 2
                        contentItem: TextInput {
                            text: durationPart.textFromValue(durationPart.value, durationPart.locale)
                            font: durationPart.font; color: Theme.settingsText
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            readOnly: !durationPart.editable
                            validator: durationPart.validator
                            inputMethodHints: Qt.ImhDigitsOnly
                            selectByMouse: true
                        }
                        background: Rectangle { radius: Theme.controlRadius; color: Theme.settingsHover; border.width: durationPart.activeFocus ? 1 : 0; border.color: Theme.settingsMuted }
                        up.indicator: Rectangle {
                            x: parent.width - width; width: 24; height: parent.height
                            radius: Theme.controlRadius; color: durationPart.up.pressed ? Theme.settingsSelected : "transparent"
                            Text { anchors.centerIn: parent; text: "+"; color: Theme.settingsText; font.pixelSize: 16 }
                        }
                        down.indicator: Rectangle {
                            width: 24; height: parent.height; radius: Theme.controlRadius
                            color: durationPart.down.pressed ? Theme.settingsSelected : "transparent"
                            Text { anchors.centerIn: parent; text: "−"; color: Theme.settingsText; font.pixelSize: 16 }
                        }
                    }
                    Text {
                        width: 100; text: modelData.label; horizontalAlignment: Text.AlignHCenter
                        color: Theme.settingsMuted; font.family: Theme.settingsFontFamily; font.pixelSize: Theme.settingsFontSizeSmall
                    }
                }
            }
        }
        Row {
            visible: root.status === "ready"
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Repeater {
                model: [1, 5, 15, 25]
                delegate: FlatButton {
                    required property int modelData
                    label: modelData + " min"
                    emphasized: root.selectedSeconds === modelData * 60
                    onActivated: root.selectedSeconds = modelData * 60
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            FlatButton {
                objectName: "timerPrimary"
                width: 130; height: 36
                label: root.status === "running" ? "Pause" : (root.status === "paused" ? "Resume" : root.status === "finished" ? "Restart" : "Start timer")
                emphasized: true
                enabled: ClockService.loaded && root.selectedSeconds > 0
                onActivated: {
                    if (root.status === "running") ClockService.timer("pause");
                    else if (root.status === "paused") ClockService.timer("resume");
                    else root.start();
                }
            }
            FlatButton {
                objectName: "timerReset"
                visible: root.status !== "ready"
                width: 100; height: 36
                label: root.status === "finished" ? "Dismiss" : "Cancel"
                onActivated: ClockService.timer("reset")
            }
        }
        Text {
            width: parent.width
            text: root.status === "running" ? "Keeps time while the panel is closed or the desktop sleeps."
                : (root.status === "finished" ? ClockService.notificationMessage : "A desktop notification appears when your timer finishes.")
            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
            color: Theme.settingsMuted; font.family: Theme.settingsFontFamily; font.pixelSize: Theme.settingsFontSizeSmall
        }
    }
}
