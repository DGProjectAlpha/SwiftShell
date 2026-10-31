import QtQuick
import "../components"
import "../logic/capabilities.js" as Capabilities
import "../logic/settings.js" as Settings
import "../services"
import "../themes"

Item {
    id: page

    implicitWidth: 560
    implicitHeight: column.implicitHeight
    height: implicitHeight

    Column {
        id: column
        width: page.width
        spacing: Theme.panelSpacing

        Text {
            width: parent.width
            text: "Appearance"
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 4
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "These controls update the running shell and are saved. Other categories are not in this window yet."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        SettingsRow {
            width: parent.width
            label: "Theme"

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
        }

        SettingsToggle {
            label: "Reduced motion"
            checked: SettingsStore.reducedMotion
            onToggled: function (next) { SettingsStore.setReducedMotion(next) }
        }

        SettingsToggle {
            label: "Top edge gradient"
            checked: SettingsStore.topGradient
            onToggled: function (next) { SettingsStore.setTopGradient(next) }
        }

        SettingsRow {
            width: parent.width
            label: "Panel opacity"

            CompactSlider {
                valueName: "Panel opacity"
                value: Settings.unitFromOpacity(SettingsStore.panelOpacity)
                onMoved: function (next) { SettingsStore.setPanelOpacity(Settings.opacityFromUnit(next)) }
            }
        }

        SettingsRow {
            width: parent.width
            label: "Corner radius"

            CompactSlider {
                valueName: "Corner radius"
                value: Settings.unitFromRadius(SettingsStore.radius)
                onMoved: function (next) { SettingsStore.setRadius(Settings.radiusFromUnit(next)) }
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: Capabilities.capabilityReport().backdropBlur.reason
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
