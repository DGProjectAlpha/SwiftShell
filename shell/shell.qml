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
            return JSON.stringify({settingsPersistence:SettingsStore.persistenceState,barSurfaces:barHost.surfaceDiagnostics(),layerBlurAvailable:SurfaceService.blurAvailable,launcherOpen:LauncherModel.open,launcherOutput:LauncherModel.screen ? LauncherModel.screen.name : "",launcherHasFocus:launcherWindow.searchHasFocus,windowBusy:WindowService.busy || WindowService.queue.length>0 || !!(w && !w.placementReady),settingsOpen:SettingsModel.open,category:SettingsStore.settingsWindowCategory,blurAvailable:WindowService.blurAvailable,blurRegionApplied:WindowService.blurRegionApplied,blurReason:WindowService.blurReason,windowError:WindowService.error,
                panelBlur:SettingsStore.panelBlur,shadowOpacity:SettingsStore.shadowOpacity,shadowSoftness:SettingsStore.shadowSoftness,window:w ? {width:w.width,height:w.height,pageStatus:w.pageStatus,searchHasFocus:w.searchHasFocus,colorPickerOpen:w.activePage() && w.activePage().colorPickerOpen === true,colorPicker:w.activePage() && w.activePage().colorPickerGeometry ? w.activePage().colorPickerGeometry() : null,maximized:WindowService.maximized,qtMaximized:w.maximized,shadowInset:w.shadowInset,resizeRequests:w.resizeRequests,lastResizeAccepted:w.lastResizeAccepted} : null})
        }
        function moduleSide(id: string, side: string): void { if(side === "inherit")SettingsStore.inheritModuleSide(id);else SettingsStore.setModuleSide(id,side) }
        function moduleVisibility(output: string, hiddenJson: string): void {
            try {SettingsStore.setHiddenForOutput(output,JSON.parse(hiddenJson))} catch(error) {}
        }
        function moduleInherit(output: string): void { SettingsStore.inheritHidden(output) }
        function barPanel(output: string, id: string): void { barHost.showPanel(output,id) }
        function clockOptions(hours24: bool, seconds: bool, date: bool, format: string): void {
            if(SettingsStore.setClockOptions(seconds,date,format)) SettingsStore.setUse24Hour(hours24)
        }
        function barSurface(output: string, mode: string, color: string, opacity: real): void {
            SettingsStore.setBarSurface(output,mode,color,opacity)
        }
        function barInherit(output: string): void { SettingsStore.clearBarSurface(output) }
        function launcher(action: string): void {
            if (action === "open") LauncherModel.openLauncher()
            else if (action === "close") LauncherModel.closeLauncher()
            else if (action === "toggle") LauncherModel.toggleLauncher()
        }
        function appearance(key: string, value: real): void {
            if (["panelBlur","panelOpacity","radius","shadowOpacity","shadowSoftness"].indexOf(key)<0) return
            if(SettingsModel.nativeWindow) SettingsModel.appearanceEditRequested(key,value)
            else {
                const next=SettingsStore.snapshot().appearance
                next[key]=value
                SettingsStore.setAppearance(next)
            }
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

    BarHost { id: barHost }
    LauncherWindow { id: launcherWindow }

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
