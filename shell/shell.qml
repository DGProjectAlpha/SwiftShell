//@ pragma ShellId swiftshell

import Quickshell
import QtQuick
import "bar"
import "launcher"
import "services"

ShellRoot {
    id: root

    Component.onCompleted: {
        NotificationsModel.configure(SettingsStore.notificationOwnership, SettingsStore.notificationDnd, SettingsStore.notificationPoliciesJson)
        console.info("SwiftShell: M1 prototype started");
        console.info("SwiftShell: calendar, control center, and launcher are available");
        console.info("SwiftShell: bar monitor preference", SettingsStore.targetMonitor === "" ? "automatic" : SettingsStore.targetMonitor);
        console.info("SwiftShell: screen count", Quickshell.screens ? Quickshell.screens.length : 0);
    }

    Component.onDestruction: console.info("SwiftShell: prototype stopped")

    BarHost {}
    LauncherWindow {}

    Connections {
        target: LauncherModel
        function onSettingsRequested() { SettingsModel.show() }
    }

    Loader {
        id: wallpaperLoader
        active: SettingsStore.wallpaperEnabled
        source: "wallpaper/WallpaperHost.qml"
        onStatusChanged: {
            if (status === Loader.Error)
                console.warn("SwiftShell: the wallpaper surface did not load")
        }
    }

    Connections {
        target: SettingsStore
        function onNotificationOwnershipChanged() {
            NotificationsModel.configure(SettingsStore.notificationOwnership, SettingsStore.notificationDnd, SettingsStore.notificationPoliciesJson)
        }
        function onNotificationDndChanged() {
            NotificationsModel.configure(SettingsStore.notificationOwnership, SettingsStore.notificationDnd, SettingsStore.notificationPoliciesJson)
        }
        function onNotificationPoliciesJsonChanged() {
            NotificationsModel.configure(SettingsStore.notificationOwnership, SettingsStore.notificationDnd, SettingsStore.notificationPoliciesJson)
        }
    }

    Loader {
        id: notificationLoader
        active: SettingsStore.notificationOwnership === "on"
        source: "notifications/NotificationHost.qml"
        onStatusChanged: {
            if (status === Loader.Error)
                console.warn("SwiftShell: the notification server was not created. Another owner was left in place.")
        }
    }

    Loader {
        id: settingsLoader
        active: SettingsModel.open
        source: "settings/SettingsWindow.qml"
        onStatusChanged: {
            if (status === Loader.Error)
                SettingsModel.noteLoadFailed()
        }
    }
}
