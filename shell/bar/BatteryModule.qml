import QtQuick
import Quickshell.Services.UPower
import "../logic/power.js" as Power
import "../themes"

Item {
    id: root
    readonly property var barSizing:Theme.barMetricsFor(root)

    readonly property var report: Power.batteryReport(UPower.displayDevice, UPower.onBattery)
    property color textPrimary: Theme.textPrimary

    implicitWidth: report.available ? label.implicitWidth : 0
    implicitHeight: root.barSizing.height
    visible: report.available

    Text {
        renderType:Theme.barTextRendering(root);antialiasing:true;font.hintingPreference:Font.PreferVerticalHinting
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: root.report.text
        color: root.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: root.barSizing.bodyFont
    }
}
