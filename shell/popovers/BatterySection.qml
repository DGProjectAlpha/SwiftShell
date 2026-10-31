import QtQuick
import Quickshell.Services.UPower
import "../components"
import "../logic/power.js" as Power
import "../themes"

Column {
    id: root

    spacing: Theme.panelSpacing
    width: parent ? parent.width : Theme.controlWidth

    readonly property var report: Power.batteryReport(UPower.displayDevice, UPower.onBattery)

    SectionHeader {
        width: parent.width
        text: "Battery"
    }

    ServiceStatus {
        name: "Battery"
        detail: root.report.available ? root.report.text + ", " + root.report.detail : root.report.detail
    }
}
