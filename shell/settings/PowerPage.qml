import QtQuick
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

        Loader {
            id: batteryLoader
            width: parent.width
            active: page.shows("battery")
            source: "../popovers/BatterySection.qml"
            visible: status === Loader.Ready
        }

        Text {
            width: parent.width
            visible: batteryLoader.status === Loader.Error
            wrapMode: Text.WordWrap
            text: "Battery is unavailable."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Loader {
            width: parent.width
            active: page.shows("sessionPower")
            source: "../popovers/PowerSection.qml"
        }
    }
}
