import QtQuick
import Quickshell.Services.SystemTray
import "../logic/tray.js" as Tray
import "../themes"

Item {
    id: root

    property var hostWindow: null
    property color textPrimary: Theme.textPrimary
    property color textMuted: Theme.textMuted
    readonly property var rows: Tray.trayRows(SystemTray.items, 4)
    readonly property int overflow: Tray.trayOverflow(SystemTray.items, 4)

    implicitWidth: rows.length === 0 ? 0 : row.implicitWidth
    implicitHeight: Theme.barHeight
    visible: rows.length > 0

    function itemAt(id) {
        var values = Tray.objectValues(SystemTray.items)
        for (var index = 0; index < values.length; index++) {
            if (values[index] && values[index].id === id)
                return values[index]
        }
        return null
    }

    function invoke(entry, local) {
        var item = itemAt(entry.id)
        if (!item)
            return
        try {
            if (entry.action === "menu" && item.hasMenu === true && hostWindow) {
                var menu = Tray.menuPoint(local ? local.x : 0, local ? local.y : 0)
                item.display(hostWindow, menu.x, menu.y)
            }
            else if (entry.action === "activate" && item.onlyMenu !== true)
                item.activate()
        } catch (error) {
            console.warn("SwiftShell: the tray item was not activated")
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Repeater {
            model: root.rows

            delegate: MouseArea {
                required property var modelData
                width: Theme.barIcon
                height: Theme.barHeight
                hoverEnabled: true
                Accessible.role: Accessible.Button
                Accessible.name: modelData.title
                onClicked: root.invoke(modelData, mapToItem(root.hostWindow ? root.hostWindow.contentItem : null, width / 2, height))

                Image {
                    anchors.centerIn: parent
                    visible: modelData.icon !== ""
                    source: modelData.icon
                    width: Theme.barIcon
                    height: Theme.barIcon
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    anchors.centerIn: parent
                    visible: modelData.icon === ""
                    text: modelData.title.length > 0 ? modelData.title.charAt(0) : ""
                    color: root.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        Text {
            visible: root.overflow > 0
            anchors.verticalCenter: parent.verticalCenter
            text: "+" + root.overflow
            color: root.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
