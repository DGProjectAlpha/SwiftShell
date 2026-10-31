import QtQuick
import "../components"
import "../logic/notifications.js" as Notifications
import "../logic/settingsNav.js" as Nav
import "../services"
import "../themes"

Item {
    id: page

    property string query: ""
    property string highlightId: ""
    property string arm: ""
    property bool previewOpen: false
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
            text: "Notifications"
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 4
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "SwiftShell does not own notifications unless you confirm it. The default is off, so another program keeps the bus. Confirming tries to create a server. If that fails, this shell stops and leaves the current owner alone."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        ServiceStatus {
            name: "Owner"
            detail: SettingsStore.notificationOwnership === "on" ? "SwiftShell, after confirmation" : "Not SwiftShell"
        }

        FlatButton {
            visible: page.shows("notificationOwner")
            label: SettingsStore.notificationOwnership === "on" ? "Release notifications" : (page.arm === "own" ? "Confirm ownership" : "Own notifications")
            emphasized: page.arm === "own"
            onActivated: {
                if (SettingsStore.notificationOwnership === "on") {
                    page.arm = ""
                    SettingsStore.setNotificationOwnership("off")
                    NotificationsModel.configure("off", SettingsStore.notificationDnd)
                    return
                }
                if (page.arm !== "own") {
                    page.arm = "own"
                    return
                }
                page.arm = ""
                SettingsStore.setNotificationOwnership("on")
                NotificationsModel.configure("on", SettingsStore.notificationDnd)
            }
        }

        SettingsToggle {
            visible: page.shows("notificationDnd")
            label: "Do not disturb"
            checked: SettingsStore.notificationDnd
            onToggled: function (next) {
                SettingsStore.setNotificationDnd(next)
                NotificationsModel.configure(SettingsStore.notificationOwnership, next)
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: SettingsStore.notificationDnd ? "Critical banners still show. Other banners wait in history." : "Banners follow the notifications this shell has accepted."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        FlatButton {
            visible: page.shows("notificationPreview")
            label: "Show preview"
            onActivated: page.previewOpen = true
        }

        Rectangle {
            visible: page.previewOpen
            width: parent.width
            height: previewColumn.implicitHeight + Theme.panelPadding * 2
            radius: Theme.radius
            color: Theme.panelColor

            Column {
                id: previewColumn
                width: parent.width - Theme.panelPadding * 2
                x: Theme.panelPadding
                y: Theme.panelPadding
                spacing: 4

                Text {
                    width: parent.width
                    text: "Preview"
                    color: Theme.panelMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "This is a preview. It was not sent by another application, and showing it does not take the bus."
                    color: Theme.panelText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    textFormat: Text.PlainText
                }

                FlatButton {
                    label: "Dismiss preview"
                    onActivated: page.previewOpen = false
                }
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "The preview card is labeled Preview. It is not a notification from another application, and showing it does not take the bus."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Repeater {
            model: NotificationsModel.center.history

            delegate: Text {
                required property var modelData
                width: column.width
                text: (modelData.preview === true ? "Preview. " : "") + modelData.appName + ": " + modelData.summary
                color: Theme.panelText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        FlatButton {
            visible: NotificationsModel.center.history.length > 0
            label: "Clear history"
            onActivated: NotificationsModel.clearHistory()
        }
    }
}
