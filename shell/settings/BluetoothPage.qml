import QtQuick
import "../logic/settingsNav.js" as Nav
import "../themes"

Item {
    id: page

    property string query: ""
    property string highlightId: ""
    signal revealRequested(real y, real itemHeight)

    implicitWidth: 560
    implicitHeight: loader.item ? loader.item.implicitHeight : statusText.implicitHeight
    height: implicitHeight

    function shows(id) {
        return Nav.controlVisible(page.query, id)
    }

    function focusHighlight() {
        if (loader.item)
            loader.item.forceActiveFocus()
    }

    function moveHighlight(delta) {
        page.highlightId = Nav.moveSelection(page.query, page.highlightId, delta)
    }

    Loader {
        id: loader
        width: page.width
        source: "../popovers/BluetoothSection.qml"
        visible: status === Loader.Ready
    }

    Text {
        id: statusText
        width: page.width
        visible: loader.status === Loader.Error
        wrapMode: Text.WordWrap
        text: "Bluetooth is unavailable."
        color: Theme.panelMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }
}
