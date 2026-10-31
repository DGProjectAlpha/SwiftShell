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

    function preferredScreen() {
        var screens = Quickshell.screens || []
        var focused = HyprlandModel.focusedOutput
        var focusedName = focused && focused.name ? String(focused.name) : ""
        for (var index = 0; index < screens.length; index++) {
            var screen = screens[index]
            if (screen && (screen.name === focusedName
                    || HyprlandModel.hyprlandNameForScreen(screen) === focusedName))
                return screen
        }
        return screens.length > 0 ? screens[0] : null
    }

    readonly property var targetScreen: {
        HyprlandModel.outputRevision
        return host.preferredScreen()
    }
    screen: targetScreen

    property var nativeList: []
    property var watchedList: []

    function snapshot(notification) {
        var actions = []
        var listed = notification.actions
        if (listed && listed.length) {
            for (var index = 0; index < listed.length && actions.length < 4; index++)
                actions.push(listed[index])
        }
        return {
            id: notification.id,
            appName: notification.appName,
            summary: notification.summary,
            body: notification.body,
            urgency: String(notification.urgency) === "2"
                || String(notification.urgency) === "Critical" ? "critical" : "normal",
            desktopEntry: notification.desktopEntry,
            actions: actions,
            expireTimeout: notification.expireTimeout
        }
    }

    function connectSignal(notification, name, callback) {
        try {
            var signal = notification[name]
            if (signal && signal.connect)
                signal.connect(callback)
        } catch (error) {
            console.warn("SwiftShell: a notification update signal was unavailable")
        }
    }

    function watch(notification) {
        if (host.watchedList.indexOf(notification) !== -1)
            return
        host.watchedList = host.watchedList.concat([notification])
        var refresh = function () { host.refreshNotification(notification) }
        var names = [
            "appNameChanged", "summaryChanged", "bodyChanged", "urgencyChanged",
            "desktopEntryChanged", "actionsChanged", "expireTimeoutChanged"
        ]
        for (var index = 0; index < names.length; index++)
            host.connectSignal(notification, names[index], refresh)
        if (notification.closed && notification.closed.connect) {
            notification.closed.connect(function () {
                host.forget(notification)
                NotificationsModel.closed(notification.id)
            })
        }
    }

    function remember(notification) {
        var next = []
        for (var index = 0; index < nativeList.length; index++) {
            if (nativeList[index] && nativeList[index].id !== notification.id)
                next.push(nativeList[index])
        }
        next.push(notification)
        nativeList = next
        host.watch(notification)
    }

    function forget(notification) {
        var natives = []
        var watched = []
        for (var index = 0; index < host.nativeList.length; index++) {
            if (host.nativeList[index] !== notification)
                natives.push(host.nativeList[index])
        }
        for (var watchedIndex = 0; watchedIndex < host.watchedList.length; watchedIndex++) {
            if (host.watchedList[watchedIndex] !== notification)
                watched.push(host.watchedList[watchedIndex])
        }
        host.nativeList = natives
        host.watchedList = watched
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
        if (found)
            host.forget(found)
        return found
    }

    function refreshNotification(notification) {
        if (!notification || !Notifications.shouldTrack(NotificationsModel.center))
            return
        var route = NotificationsModel.receive(host.snapshot(notification))
        if (route === "banner")
            return
        var previous = host.take(notification.id)
        try {
            if (notification.tracked)
                notification.tracked = false
            if (previous && previous !== notification && previous.tracked)
                previous.tracked = false
        } catch (error) {
            console.warn("SwiftShell: a hidden notification could not be released")
        }
    }

    function accept(notification) {
        if (!Notifications.shouldTrack(NotificationsModel.center))
            return
        NotificationsModel.noteServer("running")
        var route = NotificationsModel.receive(host.snapshot(notification))
        if (route !== "banner")
            return
        notification.tracked = true
        host.remember(notification)
    }

    function releaseAll() {
        var current = host.nativeList.slice()
        host.nativeList = []
        host.watchedList = []
        for (var index = 0; index < current.length; index++)
            Notifications.nativeClose(current[index], "dismiss")
    }

    function reconfigure() {
        NotificationsModel.configure(SettingsStore.notificationOwnership,
                                     SettingsStore.notificationDnd,
                                     SettingsStore.notificationPoliciesJson)
        var current = host.nativeList.slice()
        for (var index = 0; index < current.length; index++)
            host.refreshNotification(current[index])
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

    Component.onCompleted: {
        NotificationsModel.configure(SettingsStore.notificationOwnership,
                                     SettingsStore.notificationDnd,
                                     SettingsStore.notificationPoliciesJson)
        NotificationsModel.noteServer("waiting")
    }
    Component.onDestruction: {
        host.releaseAll()
        NotificationsModel.noteServer("off")
    }

    Connections {
        target: SettingsStore
        function onNotificationDndChanged() { host.reconfigure() }
        function onNotificationPoliciesJsonChanged() { host.reconfigure() }
    }

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
            host.accept(notification)
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
