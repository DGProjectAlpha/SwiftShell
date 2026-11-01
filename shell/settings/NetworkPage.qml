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
        spacing: Theme.settingsSpacing

        Text {
            width: parent.width
            text: "Network"
            color: Theme.settingsText
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSize + 4
            font.weight: Font.Medium
        }

        ServiceStatus {
            name: "Network"
            detail: "Unavailable"
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Network controls are not available in SwiftShell yet. Use your system network settings."
            color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }

        Text {
            width: parent.width
            text: "Brightness"
            color: Theme.settingsText
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSize + 2
            font.weight: Font.Medium
        }

        ServiceStatus {
            name: "Brightness"
            detail: "Unavailable"
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Brightness control is not available for these displays."
            color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }
    }
}
