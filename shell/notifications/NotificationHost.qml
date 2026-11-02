import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../logic/notifications.js" as Notifications
import "../services"
import "../themes"
import "../components"

PanelWindow {
    id: host

    color: Theme.transparent
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    visible: NotificationsModel.center.live.length > 0
    implicitWidth: 360 + Theme.surfaceShadowInset * 2
    implicitHeight: Math.max(1,Math.min(column.implicitHeight + Theme.surfaceShadowInset * 2,screen ? screen.height-margins.top-Theme.panelMargin : 700))

    surfaceFormat.opaque: false
    margins.top: Theme.barHeight + Theme.panelGap
    margins.right: Theme.panelMargin
    mask: Region { item:viewport; radius:Theme.radius }

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
        const target=SettingsStore.notificationScreenTarget
        if(target!=="focused" && target!=="primary") focusedName=target
        if(target==="primary") focusedName=screens.length>0 ? screens[0].name : ""
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
            appIcon: notification.appIcon,
            transient: notification.transient,
            appName: notification.appName,
            summary: notification.summary,
            body: notification.body,
            urgency: String(notification.urgency) === "2"
                || String(notification.urgency) === "Critical" ? "critical" : "normal",
            desktopEntry: notification.desktopEntry,
            actions: actions,
            // Quickshell 0.3.2 exposes the D-Bus millisecond value unchanged.
            // Normalize once into the reducer's seconds contract (native regression).
            expireTimeout: notification.expireTimeout < 0 ? SettingsStore.notificationDuration : notification.expireTimeout / 1000
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
            "desktopEntryChanged", "actionsChanged", "expireTimeoutChanged", "appIconChanged", "transientChanged"
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

    function trimNatives() {
        const ids=NotificationsModel.entries.map(function(item){return item.id})
        const discarded=nativeList.filter(function(item){return ids.indexOf(item.id)===-1})
        discarded.forEach(function(item){host.forget(item);Notifications.nativeClose(item,"expire")})
    }

    function refreshNotification(notification) {
        if (!notification || !Notifications.shouldTrack(NotificationsModel.center))
            return
        var route = NotificationsModel.receive(host.snapshot(notification))
        if(route === "drop") {
            host.forget(notification)
            Notifications.nativeClose(notification,"dismiss")
        }
        host.trimNatives()
    }

    function accept(notification) {
        if (!Notifications.shouldTrack(NotificationsModel.center)) return
        NotificationsModel.noteServer("running")
        var route = NotificationsModel.receive(host.snapshot(notification))
        if (route === "drop") return
        notification.tracked = true
        host.remember(notification)
        host.trimNatives()
    }

    function releaseAll() {
        var current = host.nativeList.slice()
        host.nativeList = []
        host.watchedList = []
        for (var index = 0; index < current.length; index++)
            Notifications.nativeClose(current[index], "dismiss")
    }

    function reconfigure() {
        NotificationsModel.refreshConfiguration()
        const current=host.nativeList.slice()
        current.forEach(function(nativeNotification) {
            const entries=Notifications.allEntries(NotificationsModel.center)
            const record=entries.find(function(item){return item.id===nativeNotification.id})
            if(!record) return
            const policy=Notifications.policyFor(NotificationsModel.center.policies,record.desktopEntry)
            if(policy==="hide") NotificationsModel.dismiss(record.id)
            else if(record.urgency!=="critical" && (NotificationsModel.center.dnd || policy==="quiet"))
                NotificationsModel.hideBanner(record.id)
        })
    }

    function closeNative(id,kind) {
        const nativeNotification=take(id)
        Notifications.nativeClose(nativeNotification,kind)
    }
    function invokeAction(id,identifier) {
        const nativeNotification=nativeList.find(function(item){return item && item.id===id})
        if(!nativeNotification || !nativeNotification.actions) return
        for(let index=0;index<nativeNotification.actions.length;index++) {
            const action=nativeNotification.actions[index]
            if(action && action.identifier===identifier && action.invoke) {
                const resident=nativeNotification.resident
                action.invoke()
                if(!resident) NotificationsModel.dismiss(id)
                return
            }
        }
    }
    Connections {
        target:NotificationsModel
        function onCenterChanged(){Qt.callLater(host.trimNatives)}
        function onCloseRequested(notificationId,kind) {host.closeNative(notificationId,kind)}
        function onActionRequested(notificationId,identifier) {host.invokeAction(notificationId,identifier)}
        function onClearRequested() {
            const historyIds=NotificationsModel.center.history.map(function(item){return item.id})
            host.nativeList.slice().forEach(function(item){if(historyIds.indexOf(item.id)!==-1) host.closeNative(item.id,"dismiss")})
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
        function onNotificationQuietUntilChanged() { host.reconfigure() }
    }

    NotificationServer {
        id: server
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        imageSupported: false
        inlineReplySupported: false
        persistenceSupported: true

        onNotification: function (notification) {
            host.accept(notification)
        }
    }

    BackdropEffect {targetWindow:host;surface:viewport;cornerRadius:Theme.radius;enabled:SettingsStore.panelBlur>0}
    Flickable {
        id:viewport
        anchors.fill:parent
        contentWidth:width
        contentHeight:column.implicitHeight+Theme.surfaceShadowInset*2
        clip:true
        boundsBehavior:Flickable.StopAtBounds
        Controls.ScrollBar.vertical:Controls.ScrollBar {policy:Controls.ScrollBar.AsNeeded}
    Column {
        id:column
        x:Theme.surfaceShadowInset;y:Theme.surfaceShadowInset
        width:360
        spacing:Theme.panelSpacing
        Repeater {
            model:NotificationsModel.center.live
            delegate:Item {
                id:banner
                required property var modelData
                width:column.width;height:card.implicitHeight+Theme.panelPadding*2
                SurfaceShadow {anchors.fill:parent;visible:Theme.shadowOpacity>0}
                Rectangle {anchors.fill:parent;radius:Theme.radius;color:Theme.floaterSurface}
                NotificationCard {
                    id:card
                    x:Theme.panelPadding;y:Theme.panelPadding
                    width:parent.width-Theme.panelPadding*2
                    entry:banner.modelData
                }
                Timer {
                    interval:Math.max(1,banner.modelData.expireMs-(Date.now()-banner.modelData.receivedAt))
                    running:banner.modelData.expireMs>0 && !card.hovered
                    repeat: false
                    onTriggered:NotificationsModel.hideBanner(banner.modelData.id)
                }
            }
        }
    }
    }
}
