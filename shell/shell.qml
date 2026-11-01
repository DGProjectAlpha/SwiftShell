//@ pragma ShellId swiftshell

import Quickshell
import Quickshell.Io
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

    IpcHandler {
        target: "swiftshell"
        function diagnostics(): string {
            const w=SettingsModel.nativeWindow
            return JSON.stringify({settingsOpen:SettingsModel.open,category:SettingsStore.settingsWindowCategory,blurAvailable:WindowService.blurAvailable,blurRegionApplied:WindowService.blurRegionApplied,blurReason:WindowService.blurReason,windowError:WindowService.error,
                panelBlur:SettingsStore.panelBlur,shadowOpacity:SettingsStore.shadowOpacity,shadowSoftness:SettingsStore.shadowSoftness,window:w ? {width:w.width,height:w.height,pageStatus:w.pageStatus,searchHasFocus:w.searchHasFocus,maximized:WindowService.maximized,qtMaximized:w.maximized,shadowInset:w.shadowInset,resizeRequests:w.resizeRequests,lastResizeAccepted:w.lastResizeAccepted} : null})
        }
        function appearance(key: string, value: real): void {
            if (["panelBlur","panelOpacity","radius","shadowOpacity","shadowSoftness"].indexOf(key)>=0)
                SettingsModel.appearanceEditRequested(key,value)
        }
        function window(action: string): void {
            SettingsModel.windowActionRequested(action)
        }
        function settings(category: string): void {
            const allowed = ["appearance","bar","wallpaper","displays","workspaces","shortcuts","audio","network","bluetooth","power","notifications"]
            if (allowed.indexOf(category) >= 0) SettingsStore.setSettingsCategory(category)
            SettingsModel.show()
            SettingsModel.windowActionRequested("clear-search")
        }
    }

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
            if (SettingsStore.notificationOwnership !== "on")
                NotificationsModel.noteServer("off")
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
            if (status === Loader.Error) {
                NotificationsModel.noteServer("failed")
                console.warn("SwiftShell: the notification server was not created. Another owner was left in place.")
            }
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
