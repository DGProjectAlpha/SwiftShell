pragma Singleton

import QtQuick
import Quickshell
import "../logic/notifications.js" as Notifications

Singleton {
    id: root

    property var center: Notifications.emptyCenter()

    function configure(ownership, dnd) {
        root.center = Notifications.reduceNotifications(root.center, {
            type: "configure",
            ownership: ownership,
            dnd: dnd === true
        })
    }

    function receive(raw) {
        root.center = Notifications.reduceNotifications(root.center, { type: "receive", notification: raw })
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

    function clearHistory() {
        root.center = Notifications.reduceNotifications(root.center, { type: "clear-history" })
    }
}
