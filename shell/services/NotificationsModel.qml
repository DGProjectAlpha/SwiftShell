pragma Singleton

import QtQuick
import Quickshell
import "../logic/notifications.js" as Notifications

Singleton {
    id: root

    property var center: Notifications.emptyCenter()
    property string serverState: "off"

    function noteServer(state) {
        if (state === "waiting" || state === "running" || state === "failed")
            root.serverState = state
        else
            root.serverState = "off"
    }

    function configure(ownership, dnd, policiesJson) {
        root.center = Notifications.reduceNotifications(root.center, {
            type: "configure",
            ownership: ownership,
            dnd: dnd === true,
            policies: policiesJson || "{}"
        })
    }

    function receive(raw) {
        root.center = Notifications.reduceNotifications(root.center, { type: "receive", notification: raw })
        var route = root.center.lastRoute || {}
        return route.id === raw.id ? route.disposition : "ignored"
    }

    function preview() {
        root.center = Notifications.reduceNotifications(root.center, {
            type: "preview",
            notification: {
                appName: "SwiftShell",
                summary: "Preview",
                body: "This is a preview. It was not sent by another application.",
                urgency: "normal"
            }
        })
    }

    function dismiss(id) {
        root.center = Notifications.reduceNotifications(root.center, { type: "dismiss", id: id })
    }

    function expire(id) {
        root.center = Notifications.reduceNotifications(root.center, { type: "expire", id: id })
    }

    function closed(id) {
        root.center = Notifications.reduceNotifications(root.center, { type: "closed", id: id })
    }

    function clearHistory() {
        root.center = Notifications.reduceNotifications(root.center, { type: "clear-history" })
    }
}
