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
        spacing: Theme.settingsSpacing
        activeFocusOnTab: true

        Text {
            width: parent.width
            text: "Audio"
            color: Theme.settingsText
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSize + 4
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Adjust speakers, microphone and application volume. Control playback from connected players."
            color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
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
