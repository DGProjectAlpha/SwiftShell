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

    property var nativeList: []

    function remember(notification) {
        var next = []
        for (var index = 0; index < nativeList.length; index++) {
            if (nativeList[index] && nativeList[index].id !== notification.id)
                next.push(nativeList[index])
        }
        next.push(notification)
        nativeList = next
    }

    function take(id) {
        var found = null
        var next = []
        for (var index = 0; index < nativeList.length; index++) {
            var item = nativeList[index]
            if (item && item.id === id)
                found = item
            else if (item)
                next.push(item)
        }
        nativeList = next
        return found
    }

    function requestClose(id, kind) {
        var nativeNotification = take(id)
        Notifications.nativeClose(nativeNotification, kind)
        if (kind === "expire")
            NotificationsModel.expire(id)
        else
            NotificationsModel.dismiss(id)
    }

    function noteClosed(id) {
        take(id)
        NotificationsModel.closed(id)
    }

    function invokeAction(id, identifier) {
        var nativeNotification = null
        for (var index = 0; index < nativeList.length; index++) {
            if (nativeList[index] && nativeList[index].id === id)
                nativeNotification = nativeList[index]
        }
        if (!nativeNotification || !nativeNotification.actions)
            return
        for (var actionIndex = 0; actionIndex < nativeNotification.actions.length; actionIndex++) {
            var action = nativeNotification.actions[actionIndex]
            if (action && action.identifier === identifier && action.invoke)
                action.invoke()
        }
    }

    Component.onCompleted: NotificationsModel.noteServer("running")
    Component.onDestruction: NotificationsModel.noteServer("off")

    NotificationServer {
        id: server
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        imageSupported: false
        inlineReplySupported: false
        persistenceSupported: false

        onNotification: function (notification) {
            if (!Notifications.shouldTrack(NotificationsModel.center))
                return
            var actions = []
            var listed = notification.actions
            if (listed && listed.length) {
                for (var index = 0; index < listed.length && actions.length < 4; index++)
                    actions.push(listed[index])
            }
            host.remember(notification)
            if (notification.closed)
                notification.closed.connect(function () { host.noteClosed(notification.id) })
            notification.tracked = true
            NotificationsModel.receive({
                id: notification.id,
                appName: notification.appName,
                summary: notification.summary,
                body: notification.body,
                urgency: String(notification.urgency) === "2" || String(notification.urgency) === "Critical" ? "critical" : "normal",
                desktopEntry: notification.desktopEntry,
                actions: actions,
                expireTimeout: notification.expireTimeout
            })
        }
    }

    Column {
        id: column
        width: host.width
        spacing: Theme.panelSpacing

        Repeater {
            model: NotificationsModel.center.live

            delegate: Rectangle {
                id: banner
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

                    Row {
                        spacing: 8
                        visible: modelData.actions && modelData.actions.length > 0

                        Repeater {
                            model: modelData.actions

                            delegate: MouseArea {
                                id: actionButton
                                required property var modelData
                                width: Math.min(96, actionText.implicitWidth + 8)
                                height: 22
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.text
                                onClicked: host.invokeAction(banner.modelData.id, modelData.identifier)

                                Text {
                                    id: actionText
                                    anchors.centerIn: parent
                                    text: actionButton.modelData.text
                                    color: Theme.panelText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Timer {
                    interval: modelData.expireMs > 0 ? modelData.expireMs : 60000
                    running: modelData.expireMs > 0
                    repeat: false
                    onTriggered: host.requestClose(modelData.id, "expire")
                }

                MouseArea {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: 28
                    height: 28
                    Accessible.role: Accessible.Button
                    Accessible.name: "Dismiss"
                    onClicked: host.requestClose(modelData.id, "dismiss")
                }
            }
        }
    }
}
