import QtQuick
import Quickshell.Bluetooth
import "../components"
import "../logic/bluetooth.js" as BluetoothLogic
import "../themes"

Column {
    id: root

    spacing: Theme.panelSpacing
    width: parent ? parent.width : Theme.controlWidth
    property string notice: ""

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var summary: BluetoothLogic.adapterSummary(adapter)
    readonly property var rows: BluetoothLogic.deviceRows(Bluetooth.devices)

    function deviceAt(key) {
        var values = BluetoothLogic.objectValues(Bluetooth.devices)
        for (var index = 0; index < values.length; index++) {
            if (BluetoothLogic.deviceKey(values[index], index) === key)
                return values[index]
        }
        return null
    }

    function run(key, action) {
        var device = deviceAt(key)
        var command = BluetoothLogic.deviceCommand(device, action)
        if (command === "")
            return
        try {
            if (command === "connect")
                device.connect()
            else if (command === "disconnect")
                device.disconnect()
            else if (command === "pair")
                device.pair()
            else if (command === "forget")
                device.forget()
            else if (command === "cancel")
                device.cancelPair()
            root.notice = ""
        } catch (error) {
            root.notice = "Bluetooth did not accept that."
            console.warn("SwiftShell: bluetooth action was not accepted")
        }
    }

    SectionHeader {
        width: parent.width
        text: "Bluetooth"
    }

    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Devices BlueZ already knows are listed. This shell does not start a scan."
        color: Theme.panelMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }

    ServiceStatus {
        visible: !root.summary.present
        name: "Adapter"
        detail: "Unavailable"
    }

    FlatButton {
        visible: root.summary.present
        label: root.summary.enabled ? "Turn adapter off" : "Turn adapter on"
        onActivated: {
            if (!root.adapter)
                return
            try {
                root.adapter.enabled = !root.summary.enabled
                root.notice = ""
            } catch (error) {
                root.notice = "The adapter was not changed."
                console.warn("SwiftShell: bluetooth adapter was not changed")
            }
        }
    }

    Repeater {
        model: root.rows

        delegate: Column {
            required property var modelData
            width: parent.width
            spacing: 4

            Text {
                width: parent.width
                text: modelData.name + (modelData.battery == null ? "" : " " + modelData.battery + "%")
                color: Theme.panelText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
            }

            Row {
                spacing: Theme.panelSpacing

                FlatButton {
                    visible: !modelData.connected
                    label: "Connect"
                    onActivated: root.run(modelData.key, "connect")
                }

                FlatButton {
                    visible: modelData.connected
                    label: "Disconnect"
                    onActivated: root.run(modelData.key, "disconnect")
                }

                FlatButton {
                    visible: !modelData.paired && !modelData.pairing
                    label: "Pair"
                    onActivated: root.run(modelData.key, "pair")
                }

                FlatButton {
                    visible: modelData.pairing
                    label: "Cancel"
                    onActivated: root.run(modelData.key, "cancel")
                }

                FlatButton {
                    visible: modelData.paired
                    label: "Forget"
                    onActivated: root.run(modelData.key, "forget")
                }
            }
        }
    }

    Text {
        visible: root.notice !== ""
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.notice
        color: Theme.panelText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }
}
