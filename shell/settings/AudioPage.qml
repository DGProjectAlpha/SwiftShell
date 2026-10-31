import QtQuick
import "../components"
import "../logic/settingsNav.js" as Nav
import "../themes"

Item {
    id: page

    property string query: ""
    property string highlightId: ""
    signal revealRequested(real y, real itemHeight)

    implicitWidth: 560
    implicitHeight: column.implicitHeight
    height: implicitHeight

    function shows(id) {
        return Nav.controlVisible(page.query, id)
    }

    function focusHighlight() {
        column.forceActiveFocus()
    }

    function moveHighlight(delta) {
        page.highlightId = Nav.moveSelection(page.query, page.highlightId, delta)
    }

    Column {
        id: column
        width: page.width
        spacing: Theme.panelSpacing
        activeFocusOnTab: true

        Text {
            width: parent.width
            text: "Audio"
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 4
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Output, input, and application streams follow PipeWire. Playback follows a connected player. Tray icons use the status notifier items this session already exposes. A missing module stays unavailable."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Loader {
            id: audioLoader
            width: parent.width
            active: page.shows("audioOutput") || page.shows("audioInput") || page.shows("audioStream")
            source: "../popovers/AudioSection.qml"
            visible: status === Loader.Ready
        }

        ServiceStatus {
            visible: audioLoader.status === Loader.Error
            name: "Audio"
            detail: "Unavailable"
        }

        Loader {
            id: mediaLoader
            width: parent.width
            active: page.shows("mediaPlayer")
            source: "../popovers/MediaSection.qml"
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
            active: page.shows("trayItems")
            source: "../popovers/TraySection.qml"
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
    }
}
