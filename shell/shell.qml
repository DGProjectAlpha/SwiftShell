//@ pragma UseQApplication
//@ pragma ShellId swiftshell

import Quickshell
import Quickshell.Io
import QtQuick
import "bar"
import "launcher"
import "overview"
import "screenshots"
import "clipboard"
import "services"

ShellRoot {
    id: root
    readonly property bool desktopToolsReady:DesktopTools.clipboardAvailable
    readonly property bool clockToolsReady: ClockService.loaded
    readonly property bool desktopAppearanceReady: DesktopAppearance.available
    readonly property bool shortcutsReady: ShortcutsService.available

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
            return JSON.stringify({desktopTools:{screenshot:screenshotWindow.diagnostics(),clipboard:{open:ClipboardModel.windowOpen,ready:ClipboardModel.windowReady,count:ClipboardModel.entries.length,enabled:ClipboardModel.recording,error:ClipboardModel.windowError},performance:{available:SystemPerformance.available,sampling:SystemPerformance.sampling,cpu:SystemPerformance.cpu,memory:SystemPerformance.memory,gpus:SystemPerformance.gpus,error:SystemPerformance.error}},overview:overviewWindow.diagnostics(),notifications:{owner:SettingsStore.notificationOwnership,server:NotificationsModel.serverState,unread:NotificationsModel.unreadCount,entries:NotificationsModel.entries.map(function(item){return {id:item.id,local:item.local,snoozed:item.snoozedUntil>0,actions:item.actions.length}})},spotlight:launcherWindow.diagnostics(),settingsReloads:SettingsStore.externalReloads,settingsOwnReloads:SettingsStore.ignoredOwnReloads,desktopAppearance:{available:DesktopAppearance.available,observed:DesktopAppearance.observed,managed:DesktopAppearance.managed,error:DesktopAppearance.error},settingsPersistence:SettingsStore.persistenceState,barSurfaces:barHost.surfaceDiagnostics(),layerBlurAvailable:SurfaceService.blurAvailable,launcherOpen:LauncherModel.open,launcherOutput:LauncherModel.screen ? LauncherModel.screen.name : "",launcherHasFocus:launcherWindow.searchHasFocus,windowBusy:WindowService.busy || WindowService.queue.length>0 || !!(w && !w.placementReady),settingsOpen:SettingsModel.open,category:SettingsStore.settingsWindowCategory,blurAvailable:WindowService.blurAvailable,blurRegionApplied:WindowService.blurRegionApplied,blurReason:WindowService.blurReason,windowError:WindowService.error,
                panelBlur:SettingsStore.panelBlur,shadowOpacity:SettingsStore.shadowOpacity,shadowSoftness:SettingsStore.shadowSoftness,window:w ? {frame:w.frameGeometry ? w.frameGeometry() : null,control:w.activePage() ? w.activePage().highlightId : "",pageGeometry:w.activePage() && w.activePage().geometry ? w.activePage().geometry() : null,width:w.width,height:w.height,pageStatus:w.pageStatus,searchHasFocus:w.searchHasFocus,colorPickerOpen:w.activePage() && w.activePage().colorPickerOpen === true,colorPicker:w.activePage() && w.activePage().colorPickerGeometry ? w.activePage().colorPickerGeometry() : null,maximized:WindowService.maximized,qtMaximized:w.maximized,shadowInset:w.shadowInset,resizeRequests:w.resizeRequests,lastResizeAccepted:w.lastResizeAccepted} : null})
        }
        function moduleSide(id: string, side: string): void { if(side === "inherit")SettingsStore.inheritModuleSide(id);else SettingsStore.setModuleSide(id,side) }
        function moduleVisibility(output: string, hiddenJson: string): void {
            try {SettingsStore.setHiddenForOutput(output,JSON.parse(hiddenJson))} catch(error) {}
        }
        function moduleInherit(output: string): void { SettingsStore.inheritHidden(output) }
        function notification(action: string, id: int): void {
            if(action === "dismiss")NotificationsModel.dismiss(id)
            else if(action === "open")NotificationsModel.invoke(id,"default")
            else if(action === "snooze")NotificationsModel.snooze(id,5)
            else if(action === "wake")NotificationsModel.showNow(id)
        }
        function overview(action: string): void {
            if(action === "enable-shortcut")OverviewService.enableShortcut()
            else if(action === "restore-shortcut")OverviewService.restoreShortcut()
            else if(action === "shortcut-status")OverviewService.shortcutRequest("status")
            else if(action === "close")OverviewService.closeOverview()
            else if(action === "open")OverviewService.openOverview()
            else if(action === "shortcut")OverviewService.shortcut()
            else OverviewService.toggle()
        }
        function barLayout(output: string, edge: string, scale: real): bool {
            const layout=SettingsStore.layoutForOutput(output)
            return SettingsStore.setOutputLayout(output,edge,scale,layout.order,layout.sides)
        }
        function barLayoutInherit(output: string): void {SettingsStore.inheritOutputLayout(output)}
        function barPanel(output: string, id: string): void { barHost.showPanel(output,id) }
        function clockOptions(hours24: bool, seconds: bool, date: bool, format: string): void {
            if(SettingsStore.setClockOptions(seconds,date,format)) SettingsStore.setUse24Hour(hours24)
        }
        function barSurface(output: string, mode: string, color: string, opacity: real): void {
            SettingsStore.setBarSurface(output,mode,color,opacity)
        }
        function barInherit(output: string): void { SettingsStore.clearBarSurface(output) }
        function clockTool(action: string, value: string): string {
            if (action === "snapshot") return JSON.stringify(ClockService.state)
            if(action === "stopwatch" && ["start","pause","lap","reset"].indexOf(value)>=0){ClockService.stopwatch(value);return "ok"}
            if (action === "restore") return ClockService.restore(value) ? "ok" : "invalid"
            return "unsupported"
        }
        function developmentWatching(enabled: bool): void { Quickshell.watchFiles=enabled }
        function clipboardWindow(action: string): void {if(action==="open")ClipboardModel.showWindow();else if(action==="close")ClipboardModel.hideWindow()}
        function automaticContrast(enabled: bool): void { const next=SettingsStore.snapshot().appearance;next.automaticText=enabled;SettingsStore.setAppearance(next) }
        function desktopAppearance(action: string): void {
            if(action==="restore")DesktopAppearance.restore()
            else if(action==="status")DesktopAppearance.request("status",{})
        }
        function workspaceOutput(output: string, keysJson: string): string { try { return JSON.stringify({accepted:SettingsStore.setWorkspaceOutput(output,JSON.parse(keysJson))}) } catch(error) { return JSON.stringify({accepted:false,error:String(error)}) } }
        function launcherPins(idsJson: string): void { try { SettingsStore.setPinnedIds(JSON.parse(idsJson)) } catch(error) {} }
        function launcherFavorite(id: string): void { LauncherModel.toggleFavorite(id) }
        function launcherQuery(text: string): void { LauncherModel.setQuery(text) }
        function launcherMode(mode: string): void { if(["all","favorites","recent"].indexOf(mode)>=0)LauncherModel.gridMode=mode }
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
            const allowed = ["appearance","bar","spotlight","wallpaper","displays","workspaces","shortcuts","defaultApps","audio","network","bluetooth","power","notifications", "weather"]
            if (allowed.indexOf(category) >= 0) SettingsStore.setSettingsCategory(category)
            SettingsModel.show()
            SettingsModel.windowActionRequested("clear-search")
        }
    }

    Connections {target:DesktopTools;function onCaptureRequested(){LauncherModel.closeLauncher();OverviewService.closeOverview();barHost.closePanels()}}
    BarHost { id: barHost }
    LauncherWindow { id: launcherWindow }
    OverviewWindow {id:overviewWindow}
    ScreenshotWindow {id:screenshotWindow}
    ClipboardWindow {id:clipboardWindow}
    Connections {
        target:OverviewService
        function onOpened(){LauncherModel.closeLauncher();barHost.closePanels()}
    }
    Connections {
        target:NotificationsModel
        function onDrawerRequested(){barHost.showNotifications(HyprlandModel.readFocusedOutput())}
        function onLocalActionRequested(kind) {
            const output=HyprlandModel.readFocusedOutput()
            barHost.showClockTool(output,kind)
        }
    }

    Connections {
        target: LauncherModel
        function onSettingsRequested() { SettingsModel.show(LauncherModel.screen ? HyprlandModel.hyprlandNameForScreen(LauncherModel.screen) : "") }
        function onOpenChanged(){if(LauncherModel.open)OverviewService.closeOverview()}
    }

    Connections {target:SettingsModel;function onOpenChanged(){if(SettingsModel.open)OverviewService.closeOverview()}}

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
