import QtQuick
import Quickshell
import "."
import "../services"
import "../themes"

FloatingWindow {
    id: window

    title: "SwiftShell Settings"
    visible: SettingsModel.open
    minimumSize: Qt.size(640, 440)

    Component.onCompleted: {
        window.width = SettingsStore.settingsWindowWidth
        window.height = SettingsStore.settingsWindowHeight
        content.forceActiveFocus()
    }

    function rememberSize() {
        SettingsStore.setSettingsWindowSize(Math.round(window.width), Math.round(window.height))
    }

    function raiseWindow() {
        try {
            if (typeof window.requestActivate === "function")
                window.requestActivate()
        } catch (error) {
            // Quickshell 0.2 does not document a raise method. The compositor still owns stacking.
        }
    }

    onClosed: {
        window.rememberSize()
        SettingsModel.hide()
    }

    Connections {
        target: SettingsModel
        function onFocusTicketChanged() {
            if (!SettingsModel.open)
                return
            window.raiseWindow()
            content.forceActiveFocus()
        }
    }

    Rectangle {
        id: content
        anchors.fill: parent
        color: Theme.panelColor
        focus: true

        Keys.onEscapePressed: function (event) {
            window.rememberSize()
            SettingsModel.hide()
            event.accepted = true
        }

        AppearancePage {
            anchors.fill: parent
            anchors.margins: Theme.panelPadding
        }
    }
}
