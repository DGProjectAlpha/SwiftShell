import QtQuick
import "../components"
import "../services"
import "../themes"

Item {
    id: root

    implicitWidth: Theme.controlWidth
    implicitHeight: column.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Column {
        id: column
        width: root.width
        spacing: Theme.panelSpacing

        // Height follows the loaded audio section. Loader.implicitHeight is read-only.
        Loader {
            id: audioLoader
            width: parent.width
            source: "AudioSection.qml"
            visible: status === Loader.Ready
        }

        ServiceStatus {
            visible: audioLoader.status === Loader.Error
            name: "Audio"
            detail: "Unavailable"
        }

        SectionHeader {
            width: parent.width
            text: "Status"
        }

        ServiceStatus {
            name: "Network"
            detail: "Unavailable"
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Network and brightness are unavailable on this Quickshell floor. No scan is running, and the picture is not dimmed."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Loader {
            id: bluetoothLoader
            width: parent.width
            source: "BluetoothSection.qml"
            visible: status === Loader.Ready
        }

        ServiceStatus {
            visible: bluetoothLoader.status === Loader.Error
            name: "Bluetooth"
            detail: "Unavailable"
        }

        Loader {
            id: batteryLoader
            width: parent.width
            source: "BatterySection.qml"
            visible: status === Loader.Ready
        }

        ServiceStatus {
            visible: batteryLoader.status === Loader.Error
            name: "Battery"
            detail: "Unavailable"
        }

        Loader {
            id: mediaLoader
            width: parent.width
            source: "MediaSection.qml"
            visible: status === Loader.Ready
        }

        ServiceStatus {
            visible: mediaLoader.status === Loader.Error
            name: "Media"
            detail: "Unavailable"
        }

        Loader {
            id: trayLoader
            width: parent.width
            source: "TraySection.qml"
            visible: status === Loader.Ready
            onLoaded: {
                if (item)
                    item.hostWindow = Window.window
            }
        }

        ServiceStatus {
            visible: trayLoader.status === Loader.Error
            name: "Tray"
            detail: "Unavailable"
        }

        ServiceStatus {
            name: "Do Not Disturb"
            detail: "Not connected in this milestone"
        }

        SectionHeader {
            width: parent.width
            text: "Appearance"
        }

        Row {
            spacing: Theme.panelSpacing

            FlatButton {
                label: "Dark"
                emphasized: SettingsStore.appearanceMode !== "light"
                onActivated: SettingsStore.setAppearanceMode("dark")
            }

            FlatButton {
                label: "Light"
                emphasized: SettingsStore.appearanceMode === "light"
                onActivated: SettingsStore.setAppearanceMode("light")
            }
        }

        FlatButton {
            label: SettingsStore.reducedMotion ? "Use motion" : "Reduce motion"
            onActivated: SettingsStore.setReducedMotion(!SettingsStore.reducedMotion)
        }

        FlatButton {
            label: SettingsStore.topGradient ? "Hide gradient" : "Show gradient"
            onActivated: SettingsStore.setTopGradient(!SettingsStore.topGradient)
        }

        Text {
            visible: Theme.adaptiveReason !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            text: Theme.adaptiveReason
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        SectionHeader {
            width: parent.width
            text: "Session"
        }

        FlatButton {
            label: "Settings"
            onActivated: SettingsModel.show()
        }

        Loader {
            id: powerLoader
            width: parent.width
            source: "PowerSection.qml"
            visible: status === Loader.Ready
        }

        ServiceStatus {
            visible: powerLoader.status === Loader.Error
            name: "Power"
            detail: "Unavailable"
        }
    }
}
