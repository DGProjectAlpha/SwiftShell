import QtQuick
import Quickshell.Services.UPower
import "../logic/power.js" as Power
import "../themes"

Item {
    id: root

    readonly property var report: Power.batteryReport(UPower.displayDevice, UPower.onBattery)
    property color textPrimary: Theme.textPrimary

    implicitWidth: report.available ? label.implicitWidth : 0
    implicitHeight: Theme.barHeight
    visible: report.available

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: root.report.text
        color: root.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }
}
