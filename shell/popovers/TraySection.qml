import QtQuick
import Quickshell.Services.SystemTray
import "../components"
import "../logic/tray.js" as Tray
import "../themes"

Column {
    id: root

    spacing: Theme.panelSpacing
    width: parent ? parent.width : Theme.controlWidth
    property var hostWindow: null

    readonly property var rows: Tray.trayRows(SystemTray.items, 12)
    readonly property int overflow: Tray.trayOverflow(SystemTray.items, 12)

    function itemAt(id) {
        var values = []
        try {
            values = Tray.objectValues(SystemTray.items)
        } catch (error) {
            values = []
        }
        for (var index = 0; index < values.length; index++) {
            if (values[index] && values[index].id === id)
                return values[index]
        }
        return null
    }

    function invoke(row) {
        var item = itemAt(row.id)
        if (!item)
            return
        try {
            if (row.action === "menu" && item.hasMenu === true && root.hostWindow)
                item.display(root.hostWindow, 0, 0)
            else if (row.action === "activate" && item.onlyMenu !== true)
                item.activate()
        } catch (error) {
            console.warn("SwiftShell: the tray item was not activated")
        }
    }

    SectionHeader {
        width: parent.width
        text: "Tray"
    }

    ServiceStatus {
        visible: root.rows.length === 0
        name: "Tray"
        detail: "No tray icons"
    }

    Repeater {
        model: root.rows

        delegate: FlatButton {
            required property var modelData
            width: parent.width
            label: modelData.title
            onActivated: root.invoke(modelData)
        }
    }

    Text {
        visible: root.overflow > 0
        width: parent.width
        text: "+" + root.overflow + " more"
        color: Theme.panelMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }
}
