import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../logic/notifications.js" as Notifications
import "../services"
import "../themes"

PanelWindow {
    id: host

    color: Theme.transparent
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    visible: NotificationsModel.center.live.length > 0
    implicitWidth: 360
    implicitHeight: Math.max(1, column.implicitHeight + Theme.panelPadding)

    anchors {
        top: true
        right: true
    }

    WlrLayershell.namespace: "swiftshell-notification"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    NotificationServer {
        id: server
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: false
        imageSupported: false
        inlineReplySupported: false
        persistenceSupported: false

        onNotification: function (notification) {
            if (!Notifications.shouldTrack(NotificationsModel.center))
                return
            var actions = []
            var listed = notification.actions
            if (listed && listed.length) {
                for (var index = 0; index < listed.length && actions.length < 4; index++) {
                    var name = listed[index] && listed[index].text ? listed[index].text : ""
                    if (name !== "")
                        actions.push(name)
                }
            }
            NotificationsModel.receive({
                id: notification.id,
                appName: notification.appName,
                summary: notification.summary,
                body: notification.body,
                urgency: String(notification.urgency) === "2" || String(notification.urgency) === "Critical" ? "critical" : "normal",
                desktopEntry: notification.desktopEntry,
                actions: actions
            })
            notification.tracked = true
        }
    }

    Column {
        id: column
        width: host.width
        spacing: Theme.panelSpacing

        Repeater {
            model: NotificationsModel.center.live

            delegate: Rectangle {
                required property var modelData
                width: column.width
                height: card.implicitHeight + Theme.panelPadding * 2
                radius: Theme.radius
                color: Theme.panelColor

                Column {
                    id: card
                    width: parent.width - Theme.panelPadding * 2
                    x: Theme.panelPadding
                    y: Theme.panelPadding
                    spacing: 4

                    Text {
                        width: parent.width - 28
                        text: modelData.preview === true ? "Preview" : modelData.appName
                        color: Theme.panelMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width - 28
                        text: modelData.summary
                        color: Theme.panelText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }

                    Text {
                        width: parent.width
                        text: modelData.body
                        color: Theme.panelMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                }

                MouseArea {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: 28
                    height: 28
                    Accessible.role: Accessible.Button
                    Accessible.name: "Dismiss"
                    onClicked: NotificationsModel.dismiss(modelData.id)
                }
            }
        }
    }
}
