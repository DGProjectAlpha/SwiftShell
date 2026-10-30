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
            detail: "Not connected in this milestone"
        }

        ServiceStatus {
            name: "Bluetooth"
            detail: "Not connected in this milestone"
        }

        ServiceStatus {
            name: "Brightness"
            detail: "Unavailable"
        }

        ServiceStatus {
            name: "Media"
            detail: "Not connected in this milestone"
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

        ServiceStatus {
            name: "Settings"
            detail: "Edited in the settings file"
        }

        ServiceStatus {
            name: "Power"
            detail: "Not available in this milestone"
        }
    }
}
