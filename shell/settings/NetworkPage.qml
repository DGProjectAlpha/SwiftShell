import QtQuick
import "../components"
import "../logic/link.js" as Link
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

    function focusHighlight() {}

    function moveHighlight(delta) {
        page.highlightId = Nav.moveSelection(page.query, page.highlightId, delta)
    }

    Column {
        id: column
        width: page.width
        spacing: Theme.panelSpacing

        Text {
            width: parent.width
            text: "Network"
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 4
            font.weight: Font.Medium
        }

        ServiceStatus {
            name: "Network"
            detail: "Unavailable"
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: Link.NETWORK_REASON
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            width: parent.width
            text: "Brightness"
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            font.weight: Font.Medium
        }

        ServiceStatus {
            name: "Brightness"
            detail: "Unavailable"
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: Link.BRIGHTNESS_REASON
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
