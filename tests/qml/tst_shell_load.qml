import QtQuick
import QtTest
import "../../shell/logic/settingsNav.js" as Navigation
import "../../shell/services" as Services
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower

TestCase {
    name: "ShellLoad"
    when: windowShown

    // Every shell QML document. The static check requires this list to match the tree.
    readonly property var shellFiles: [
        "shell/settings/WeatherPage.qml",
        "shell/services/WeatherService.qml",
        "shell/services/BarPeekController.qml",
        "shell/popovers/WeatherPanel.qml",
        "shell/components/WeatherHours.qml",
        "shell/components/WeatherGlyph.qml",
        "shell/components/PrecipitationChart.qml",
        "shell/bar/WeatherModule.qml",
        "shell/components/MediaTransportButton.qml",
        "shell/services/AudioService.qml",
        "shell/components/TrayMenuWindow.qml",
        "shell/components/TrayMenuContent.qml",
        "shell/components/TrayMenu.qml",
        "shell/services/MediaService.qml",
        "shell/components/MediaSeekBar.qml",
        "shell/settings/BarModuleOrderList.qml",
        "shell/bar/PerformanceModule.qml",
        "shell/components/PerformanceGlyph.qml",
        "shell/components/PerformanceMetric.qml",
        "shell/popovers/PerformancePanel.qml",
        "shell/services/SystemPerformance.qml",
        "shell/services/ClipboardModel.qml",
        "shell/services/ScreenshotService.qml",
        "shell/clipboard/ClipboardPanel.qml",
        "shell/clipboard/ClipboardWindow.qml",
        "shell/screenshots/ScreenshotPanel.qml",
        "shell/screenshots/ScreenshotSaveDialog.qml",
        "shell/screenshots/ScreenshotWindow.qml",

        "shell/services/OverviewService.qml",
        "shell/overview/OverviewPreview.qml",
        "shell/overview/OverviewWindowTile.qml",
        "shell/overview/OverviewWorkspace.qml",
        "shell/overview/OverviewWindow.qml",
        "shell/components/TrayItemControl.qml",
        "shell/bar/WidgetIndicator.qml",
        "shell/popovers/AudioPanel.qml",
        "shell/popovers/NetworkPanel.qml",
        "shell/popovers/PowerPanel.qml",
        "shell/components/PowerProfileOptions.qml",
        "shell/services/PowerProfiles.qml",
        "shell/services/NetworkService.qml",

        "shell/settings/SpotlightPage.qml",
        "shell/popovers/ClockFace.qml",
        "shell/popovers/ClockCalendar.qml",
        "shell/popovers/ClockTimer.qml",
        "shell/popovers/ClockStopwatch.qml",
        "shell/services/ClockService.qml",
        "shell/services/DesktopTools.qml",
        "shell/services/DefaultAppsService.qml",
        "shell/services/ShortcutsService.qml",
        "shell/services/DesktopAppearance.qml",
        "shell/launcher/LauncherCard.qml",
        "shell/settings/WorkspaceOrderList.qml",
        "shell/settings/DefaultAppsPage.qml",

        "shell/shell.qml",
        "shell/WorkspaceAudit.qml",
        "shell/bar/BarHost.qml",
        "shell/bar/BarWindow.qml",
        "shell/bar/ModuleStrip.qml",
        "shell/bar/BarContextMenu.qml",
        "shell/bar/WorkspaceIndicators.qml",
        "shell/bar/ClockModule.qml",
        "shell/bar/FocusedTitle.qml",
        "shell/bar/ControlIndicator.qml",
        "shell/bar/MediaModule.qml",
        "shell/bar/TrayModule.qml",
        "shell/bar/BatteryModule.qml",
        "shell/components/BarLabel.qml",
        "shell/components/FlatButton.qml",
        "shell/components/ChoiceBox.qml",
        "shell/components/SurfaceShadow.qml",
        "shell/components/KeyedModel.qml",
        "shell/components/BackdropEffect.qml",
        "shell/components/CompactSlider.qml",
        "shell/components/SettingsSection.qml",
        "shell/settings/SettingsPreview.qml",
        "shell/components/SectionHeader.qml",
        "shell/components/ServiceStatus.qml",
        "shell/components/SettingsRow.qml",
        "shell/components/SettingsToggle.qml",
        "shell/popovers/PopoverHost.qml",
        "shell/popovers/PopoverSurface.qml",
        "shell/popovers/CalendarPanel.qml",
        "shell/popovers/ControlCenterPanel.qml",
        "shell/popovers/AudioSection.qml",
        "shell/popovers/MediaSection.qml",
        "shell/popovers/TraySection.qml",
        "shell/popovers/BluetoothSection.qml",
        "shell/popovers/BatterySection.qml",
        "shell/popovers/PowerSection.qml",
        "shell/themes/Theme.qml",
        "shell/services/SettingsStore.qml",
        "shell/services/HyprlandModel.qml",
        "shell/services/DisplayService.qml",
        "shell/services/WindowService.qml",
        "shell/services/SurfaceService.qml",
        "shell/services/LauncherModel.qml",
        "shell/services/SettingsModel.qml",
        "shell/services/ColorAnalysis.qml",
        "shell/services/WallpaperModel.qml",
        "shell/services/NotificationsModel.qml",
        "shell/launcher/LauncherWindow.qml",
        "shell/settings/AudioPage.qml",
        "shell/settings/NetworkPage.qml",
        "shell/settings/BluetoothPage.qml",
        "shell/settings/PowerPage.qml",
        "shell/settings/NotificationsPage.qml",
        "shell/notifications/NotificationHost.qml",
        "shell/notifications/NotificationCard.qml",
        "shell/notifications/NotificationSound.qml",
        "shell/notifications/NotificationDrawer.qml",
        "shell/settings/AppearancePage.qml",
        "shell/settings/BarPage.qml",
        "shell/settings/WorkspacesPage.qml",
        "shell/settings/ImageDialog.qml",
        "shell/settings/ColorPicker.qml",
        "shell/settings/FolderPicker.qml",
        "shell/settings/FolderScanner.qml",
        "shell/settings/DisplaysPage.qml",
        "shell/settings/ShortcutsPage.qml",
        "shell/settings/SettingsWindow.qml",
        "shell/settings/BlurAdapter.qml",
        "shell/settings/SettingsShadow.qml",
        "shell/settings/WallpaperPage.qml",
        "shell/wallpaper/SlideshowClock.qml",
        "shell/wallpaper/WallpaperHost.qml",
        "shell/wallpaper/WallpaperSurface.qml"
    ]

    // These compile with the Qt Quick stubs. shell.qml, BarHost, and BarWindow also
    // reference WlrLayershell, which is a C++ attached property and is not stubbed.
    readonly property var readyFiles: [
        "shell/settings/WeatherPage.qml",
        "shell/popovers/WeatherPanel.qml",
        "shell/components/PrecipitationChart.qml",
        "shell/components/WeatherHours.qml",
        "shell/components/WeatherGlyph.qml",
        "shell/bar/WeatherModule.qml",
        "shell/components/MediaTransportButton.qml",
        "shell/components/TrayMenuContent.qml",
        "shell/components/TrayMenu.qml",
        "shell/components/MediaSeekBar.qml",
        "shell/settings/BarModuleOrderList.qml",
        "shell/bar/PerformanceModule.qml",
        "shell/components/PerformanceGlyph.qml",
        "shell/components/PerformanceMetric.qml",
        "shell/popovers/PerformancePanel.qml",
        "shell/clipboard/ClipboardPanel.qml",
        "shell/clipboard/ClipboardWindow.qml",
        "shell/screenshots/ScreenshotPanel.qml",
        "shell/components/TrayItemControl.qml",
        "shell/bar/WidgetIndicator.qml",
        "shell/popovers/AudioPanel.qml",
        "shell/popovers/NetworkPanel.qml",
        "shell/popovers/PowerPanel.qml",
        "shell/components/PowerProfileOptions.qml",

        "shell/settings/SpotlightPage.qml",
        "shell/popovers/ClockFace.qml",
        "shell/popovers/ClockCalendar.qml",
        "shell/popovers/ClockTimer.qml",
        "shell/popovers/ClockStopwatch.qml",
        "shell/launcher/LauncherCard.qml",
        "shell/settings/WorkspaceOrderList.qml",
        "shell/settings/DefaultAppsPage.qml",

        "shell/bar/WorkspaceIndicators.qml",
        "shell/bar/ClockModule.qml",
        "shell/bar/FocusedTitle.qml",
        "shell/bar/ControlIndicator.qml",
        "shell/bar/MediaModule.qml",
        "shell/bar/TrayModule.qml",
        "shell/bar/BatteryModule.qml",
        "shell/components/BarLabel.qml",
        "shell/components/FlatButton.qml",
        "shell/components/CompactSlider.qml",
        "shell/components/SettingsSection.qml",
        "shell/settings/SettingsPreview.qml",
        "shell/components/SectionHeader.qml",
        "shell/components/ServiceStatus.qml",
        "shell/components/SettingsRow.qml",
        "shell/components/SettingsToggle.qml",
        "shell/popovers/PopoverSurface.qml",
        "shell/popovers/CalendarPanel.qml",
        "shell/popovers/ControlCenterPanel.qml",
        "shell/popovers/AudioSection.qml",
        "shell/popovers/MediaSection.qml",
        "shell/popovers/TraySection.qml",
        "shell/popovers/BluetoothSection.qml",
        "shell/popovers/BatterySection.qml",
        "shell/popovers/PowerSection.qml",
        "shell/settings/AudioPage.qml",
        "shell/settings/NetworkPage.qml",
        "shell/settings/BluetoothPage.qml",
        "shell/settings/PowerPage.qml",
        "shell/settings/NotificationsPage.qml",
        "shell/settings/AppearancePage.qml",
        "shell/settings/BarPage.qml",
        "shell/settings/WorkspacesPage.qml",
        "shell/settings/DisplaysPage.qml",
        "shell/settings/ShortcutsPage.qml",
        "shell/settings/SettingsWindow.qml",
        "shell/settings/WallpaperPage.qml",
        "shell/wallpaper/SlideshowClock.qml"
    ]

    function componentFor(path) {
        return Qt.createComponent(Qt.resolvedUrl("../../" + path))
    }

    function errorText(component) {
        if (!component || component.status === Component.Ready)
            return ""
        return component.errorString()
    }

    function expectedUnavailable(path, message) {
        if(path === "shell/notifications/NotificationSound.qml" && message.indexOf("QtMultimedia")>=0 && message.indexOf("not installed")>=0)return true
        if (path === "shell/settings/SettingsShadow.qml" || path === "shell/components/SurfaceShadow.qml")
            return message.indexOf('module "QtQuick.Effects" is not installed') !== -1
                || message.indexOf('RectangularShadow is not a type') !== -1
        if (path === "shell/settings/ImageDialog.qml"
                || path === "shell/settings/FolderPicker.qml"
                || path === "shell/screenshots/ScreenshotSaveDialog.qml")
            return message.indexOf('module "QtQuick.Dialogs" is not installed') !== -1
        if (path === "shell/settings/FolderScanner.qml")
            return message.indexOf('module "Qt.labs.folderlistmodel" is not installed') !== -1
        if (path === "shell/notifications/NotificationHost.qml")
            return message.indexOf('module "Quickshell.Services.Notifications" is not installed') !== -1
                || message.indexOf('module "Quickshell.Services.Notifications" plugin "quickshell-service-notificationsplugin" not found') !== -1
                || expectedWlrFailure(message)
        if (path === "shell/components/BackdropEffect.qml") return expectedWlrFailure(message)
        if (path === "shell/shell.qml"
                || path === "shell/bar/BarHost.qml"
                || path === "shell/bar/BarWindow.qml"
                || path === "shell/popovers/PopoverHost.qml"
                || path === "shell/overview/OverviewWindow.qml"
                || path === "shell/screenshots/ScreenshotWindow.qml"
                || path === "shell/components/TrayMenuWindow.qml"
                || path === "shell/launcher/LauncherWindow.qml"
                || path === "shell/wallpaper/WallpaperHost.qml"
                || path === "shell/wallpaper/WallpaperSurface.qml")
            return expectedWlrFailure(message)
        return false
    }

    function expectedWlrFailure(message) {
        if (message.indexOf("WlrLayershell") !== -1)
            return true
        if (message.indexOf("Non-existent attached object") === -1)
            return false
        return message.indexOf("PopoverHost.qml:") !== -1
            || message.indexOf("BarWindow.qml:") !== -1
            || message.indexOf("OverviewWindow.qml:17") !== -1
            || message.indexOf("ScreenshotWindow.qml:18") !== -1
            || message.indexOf("TrayMenuWindow.qml:") !== -1
            || message.indexOf("LauncherWindow.qml:19") !== -1
            || message.indexOf("NotificationHost.qml:24") !== -1
            || message.indexOf("WallpaperSurface.qml:25") !== -1
    }

    function test_top_level_files_resolve_project_types() {
        var paths = [
            "shell/shell.qml",
            "shell/bar/BarHost.qml",
            "shell/bar/BarWindow.qml",
            "shell/launcher/LauncherWindow.qml",
            "shell/services/LauncherModel.qml"
        ]
        for (var index = 0; index < paths.length; index++) {
            var path = paths[index]
            var message = errorText(componentFor(path))
            // The original startup failure was "BarLabel is not a type" in BarWindow.qml.
            // WlrLayershell is a C++ attached type and may still be absent from the stub.
            verify(message.indexOf("BarLabel") === -1, path + "\n" + message)
        }
    }

    function test_documents_do_not_assign_readonly_properties() {
        for (var index = 0; index < shellFiles.length; index++) {
            var path = shellFiles[index]
            var component = componentFor(path)
            var message = errorText(component)
            verify(message.indexOf("read-only property") === -1, path + "\n" + message)
            verify(component.status === Component.Ready || expectedUnavailable(path, message),
                   path + " failed for an unapproved reason:\n" + message)
        }
    }

    function test_image_dialog_dependency_is_explicit() {
        var path = "shell/settings/ImageDialog.qml"
        var component = componentFor(path)
        var message = errorText(component)
        if (component.status === Component.Ready) {
            compare(message, "")
            return
        }
        verify(expectedUnavailable(path, message), path + "\n" + message)
    }

    function test_panel_documents_instantiate() {
        for (var index = 0; index < readyFiles.length; index++) {
            var path = readyFiles[index]
            var component = componentFor(path)
            compare(errorText(component), "", path)
            verify(component.status === Component.Ready, path)
        }
    }

    function gridRowCount(column) {
        var count = 0
        for (var index = 0; index < column.children.length; index++) {
            var child = column.children[index]
            if (child.children && child.children.length >= 7) {
                compare(child.height, 28)
                count += 1
            }
        }
        return count
    }

    function findSlider(node, depth) {
        if (!node || depth > 24)
            return null
        if (node.adjusting === false && node.implicitWidth === 160 && node.implicitHeight === 28)
            return node
        var kids = node.children
        if (kids) {
            for (var index = 0; index < kids.length; index++) {
                var found = findSlider(kids[index], depth + 1)
                if (found)
                    return found
            }
        }
        if (node.item)
            return findSlider(node.item, depth + 1)
        return null
    }

    function test_calendar_control_and_slider_sizes() {
        var calendarComponent = componentFor("shell/popovers/CalendarPanel.qml")
        var calendar = calendarComponent.createObject(this)
        verify(calendar !== null)
        compare(calendar.width, calendar.implicitWidth)
        compare(calendar.height, calendar.implicitHeight)
        verify(calendar.implicitWidth >= 196)
        verify(calendar.implicitWidth < 400)
        compare(calendar.activeTab, "clock")
        calendar.showTab("calendar")
        var month = findChild(calendar, "clockCalendar")
        verify(month !== null)
        verify(month.monthModel.weeks.length >= 4)
        verify(month.monthModel.weeks.length <= 6)

        var controlComponent = componentFor("shell/popovers/ControlCenterPanel.qml")
        var control = controlComponent.createObject(this)
        verify(control !== null)
        compare(control.implicitWidth, 248)
        compare(control.width, 248)
        compare(control.height, control.implicitHeight)
        verify(control.implicitHeight > 80)
        compare(control.children[0].width, 248)
        compare(control.children[0].children[0].width, 248)

        var audioHost = Qt.createQmlObject("import QtQuick; Item { width: 248; height: 200 }", this, "audio-host")
        var audio = componentFor("shell/popovers/AudioSection.qml").createObject(audioHost)
        verify(audio !== null)
        compare(audio.width, 248)
        var slider = findSlider(audio, 0)
        verify(slider !== null)
        tryVerify(function() { return slider.width > 120 && slider.width < 248 && slider.height === 28 }, 1000)
        compare(slider.implicitHeight, 28)

        var surfaceComponent = componentFor("shell/popovers/PopoverSurface.qml")
        var calendarCard = surfaceComponent.createObject(this)
        var calendarColumn = findChild(calendarCard,"popoverBody")
        var embeddedCalendar = calendarComponent.createObject(calendarColumn)
        embeddedCalendar.showTab("calendar")
        tryVerify(function() { return calendarColumn.implicitWidth >= 196 }, 1000)
        var card = calendarCard.children[1]
        // Material padding and a full transparent inset keep the Gaussian shadow unclipped.
        compare(card.width, calendarColumn.implicitWidth + 24)
        compare(calendarCard.implicitWidth, card.width + calendarCard.shadowMargin*2)
        compare(calendarCard.implicitHeight, card.height + calendarCard.shadowMargin*2)
        tryVerify(function() { return calendarCard.implicitHeight > calendar.implicitHeight }, 1000)

        var controlCard = surfaceComponent.createObject(this)
        var controlColumn = findChild(controlCard,"popoverBody")
        var loader = Qt.createQmlObject("import QtQuick; Loader {}", controlColumn, "control-loader")
        loader.sourceComponent = controlComponent
        tryVerify(function() { return loader.item !== null && loader.implicitWidth === 248 }, 1000)
        tryVerify(function() { return controlCard.implicitWidth >= 248 + 34 && controlCard.implicitHeight > control.implicitHeight }, 1000)

        calendar.destroy()
        control.destroy()
        audio.destroy()
        audioHost.destroy()
        calendarCard.destroy()
        controlCard.destroy()
    }

    function test_popup_host_resolves_native_layer_surface() {
        const component=componentFor("shell/popovers/PopoverHost.qml")
        const message=errorText(component)
        verify(component.status === Component.Ready || expectedUnavailable("shell/popovers/PopoverHost.qml",message),message)
    }

    function findText(node, needle, depth) {
        if (!node || depth > 24)
            return false
        if (node.text && String(node.text).indexOf(needle) !== -1)
            return true
        var kids = node.children
        if (kids) {
            for (var index = 0; index < kids.length; index++) {
                if (findText(kids[index], needle, depth + 1))
                    return true
            }
        }
        if (node.item)
            return findText(node.item, needle, depth + 1)
        return false
    }

    function test_every_sidebar_category_routes_and_search_stays_available() {
        var settings=componentFor("shell/settings/SettingsWindow.qml").createObject(this)
        var search=findChild(settings,"settingsSearch")
        verify(search !== null)
        var categories=Navigation.categories()
        for(var i=0;i<categories.length;i++) {
            var button=findChild(settings,categories[i].id+"Navigation")
            verify(button !== null,categories[i].label)
            button.activated()
            compare(Services.SettingsStore.settingsWindowCategory,categories[i].id)
            verify(settings.activePage() !== null)
        }
        search.text="workspaces"
        compare(Services.SettingsStore.settingsWindowCategory,"workspaces")
        findChild(settings,"displaysNavigation").activated()
        compare(search.text,"")
        compare(Services.SettingsStore.settingsWindowCategory,"displays")
        settings.destroy()
    }

    function test_hyprland_forced_qt_maximized_flag_does_not_hide_shadow() {
        Services.WindowService.maximized=false
        var settings=componentFor("shell/settings/SettingsWindow.qml").createObject(this,{maximized:true})
        verify(settings.shadowInset>0)
        Services.WindowService.maximized=true
        compare(settings.shadowInset,0)
        Services.WindowService.maximized=false
        settings.destroy()
    }

    function test_workspaces_sidebar_button_opens_page() {
        var settings = componentFor("shell/settings/SettingsWindow.qml").createObject(this, {visible:true})
        verify(settings !== null)
        var button = findChild(settings, "workspacesNavigation")
        verify(button !== null, "Workspaces must be accessible from the sidebar")
        verify(button.width >= 130, "Sidebar entries must fill the navigation column")
        var siblings = button.parent.children
        var position = -1
        for (var i = 0; i < siblings.length; i++) {
            if (siblings[i] === button) position = i
        }
        verify(position > 0 && position < siblings.length - 1)
        compare(siblings[position - 1].Accessible.name, "Displays")
        compare(siblings[position + 1].Accessible.name, "Shortcuts")
        Services.SettingsStore.setSettingsCategory("bar")
        button.activated()
        compare(Services.SettingsStore.settingsWindowCategory, "workspaces")
        compare(settings.activePage(), findChild(settings, "workspacesPage"))
        verify(button.emphasized)
        settings.destroy()
    }

    function test_workspaces_page_uses_live_monitors_and_persists_overrides() {
        Services.HyprlandModel.monitorChoices = [
            {name: "DP-1", label: "HP X32 · DP-1", scale: 1},
            {name: "HDMI-A-1", label: "PM161Q C · HDMI-A-1", scale: 1.25}
        ]
        Services.HyprlandModel.liveWorkspaces = [
            {key:"gaming", id:-1, name:"gaming", monitorName:"DP-1", active:true, focused:true, windows:2},
            {key:"4", id:4, name:"4", monitorName:"HDMI-A-1", active:true, focused:false, windows:0}
        ]
        var page = componentFor("shell/settings/WorkspacesPage.qml").createObject(this, {width:560})
        verify(page !== null)
        verify(findText(page, "HP X32", 0))
        verify(findText(page, "gaming · active", 0))
        page.selectedOutput="HDMI-A-1"
        wait(0)
        verify(findText(page, "PM161Q C", 0))
        verify(findText(page, "4 · active · empty", 0))
        verify(Services.SettingsStore.setWorkspaceOutput("DP-1", ["2", "gaming"]))
        compare(JSON.parse(Services.SettingsStore.workspaceOutputsJson)["DP-1"].join(","), "2,gaming")
        verify(!Services.SettingsStore.setWorkspaceOutput("DP-1", ["2", "2"]))
        verify(Services.SettingsStore.setWorkspaceOutput("DP-1", ["name:gaming", " 2 "]))
        compare(JSON.parse(Services.SettingsStore.workspaceOutputsJson)["DP-1"].join(","), "gaming,2")
        verify(Services.SettingsStore.setWorkspaceOutput("DP-1", null))
        compare(JSON.parse(Services.SettingsStore.workspaceOutputsJson)["DP-1"], null)
        Services.SettingsStore.setTargetMonitor("DP-1")
        Services.SettingsStore.setBarPlacement("all")
        compare(Services.SettingsStore.targetMonitor, "")
        compare(Services.SettingsStore.barPlacement, "all")
        page.destroy()
        Services.HyprlandModel.monitorChoices = []
        Services.HyprlandModel.liveWorkspaces = []
    }

    function test_settings_page_names_the_blur_limit() {
        var page = componentFor("shell/settings/AppearancePage.qml").createObject(this)
        verify(page !== null)
        verify(findText(page, "Backdrop blur", 0))
        verify(findText(page, Services.SurfaceService.reason, 0))
        verify(findText(page, "High contrast", 0))
        verify(page.shows("textContrast"))
        verify(!findText(page, "Gaussian", 0))
        verify(page.shows("backdropBlur"))
        verify(page.shows("panelOpacity"))
        page.query = "opacity"
        verify(page.shows("panelOpacity"))
        verify(!page.shows("backdropBlur"))
        verify(!page.shows("mode"))
        page.query = "not-a-setting"
        verify(!page.shows("panelOpacity"))

        var toggled = false
        var toggle = componentFor("shell/components/SettingsToggle.qml").createObject(this, { label: "Reduced motion", checked: false })
        verify(toggle !== null)
        toggle.toggled.connect(function() { toggled = true })
        toggle.flip()
        verify(toggled)

        var settings = componentFor("shell/settings/SettingsWindow.qml").createObject(this)
        verify(settings !== null)
        compare(settings.title, "SwiftShell Settings")
        verify(settings.minimumSize.width === 640)
        verify(settings.minimumSize.height === 440)

        var wallpaper = componentFor("shell/settings/WallpaperPage.qml").createObject(this)
        verify(wallpaper !== null)
        verify(findText(wallpaper, "Choose a shared background", 0))
        verify(findText(wallpaper, "No outputs are connected", 0))
        verify(wallpaper.shows("wallpaperPath"))
        var displays = componentFor("shell/settings/DisplaysPage.qml").createObject(this)
        verify(displays !== null)
        verify(findText(displays, "Arrange your screens", 0))
        verify(findText(displays, "No outputs are connected", 0))
        var shortcuts = componentFor("shell/settings/ShortcutsPage.qml").createObject(this)
        verify(shortcuts !== null)
        verify(findText(shortcuts, "Changes apply immediately", 0))
        var audioPage = componentFor("shell/settings/AudioPage.qml").createObject(this)
        verify(audioPage !== null)
        verify(findText(audioPage, "Adjust speakers", 0))
        verify(audioPage.shows("mediaPlayer"))
        audioPage.query = "microphone"
        verify(audioPage.shows("audioInput"))
        verify(!audioPage.shows("mediaPlayer"))
        var network = componentFor("shell/settings/NetworkPage.qml").createObject(this)
        verify(network !== null)
        verify(findText(network, "Network & Devices", 0))
        verify(findText(network, "Wi-Fi", 0))
        var bluetoothPage = componentFor("shell/settings/BluetoothPage.qml").createObject(this)
        verify(bluetoothPage !== null)
        verify(findText(bluetoothPage, "Bluetooth", 0))
        var powerPage = componentFor("shell/settings/PowerPage.qml").createObject(this)
        verify(powerPage !== null)
        verify(findText(powerPage, "Power", 0))
        var notes = componentFor("shell/settings/NotificationsPage.qml").createObject(this)
        verify(notes !== null)
        verify(findText(notes, "Choose how notifications appear", 0))
        verify(findText(notes, "Handled outside SwiftShell", 0))
        verify(findText(notes, "History and reply drafts stay in memory", 0))
        UPower.displayDevice.ready = false
        var emptyBattery = componentFor("shell/bar/BatteryModule.qml").createObject(this)
        verify(emptyBattery !== null)
        verify(emptyBattery.implicitWidth === 0)
        UPower.displayDevice.ready = true
        UPower.displayDevice.percentage = 42
        var battery = componentFor("shell/bar/BatteryModule.qml").createObject(this)
        verify(battery !== null)
        verify(battery.implicitWidth > 0)
        compare(battery.report.text, "42%")

        Mpris.players.values = []
        var emptyMedia = componentFor("shell/bar/MediaModule.qml").createObject(this)
        verify(emptyMedia !== null)
        verify(emptyMedia.implicitWidth === 0)
        Mpris.players.values = [{
            isPlaying: true,
            trackTitle: "Song",
            trackArtist: "Band",
            canTogglePlaying: true
        }]
        var media = componentFor("shell/bar/MediaModule.qml").createObject(this)
        verify(media !== null)
        verify(media.implicitWidth > 0)
        verify(media.line.indexOf("Song") !== -1)

        SystemTray.items.values = []
        var emptyTray = componentFor("shell/bar/TrayModule.qml").createObject(this,{trayModel:SystemTray.items.values})
        verify(emptyTray !== null)
        tryCompare(emptyTray,"implicitWidth",0)
        SystemTray.items.values = [{
            id: "net",
            title: "Network",
            onlyMenu: false,
            hasMenu: true,
            icon: ""
        }]
        var tray = componentFor("shell/bar/TrayModule.qml").createObject(this,{trayModel:SystemTray.items.values})
        verify(tray !== null)
        verify(tray.implicitWidth > 0)
        compare(tray.itemCount,1)

        emptyBattery.destroy()
        battery.destroy()
        emptyMedia.destroy()
        media.destroy()
        emptyTray.destroy()
        tray.destroy()
        Mpris.players.values = []
        SystemTray.items.values = []
        UPower.displayDevice.ready = false

        wallpaper.query = "cover"
        verify(wallpaper.shows("wallpaperFit"))
        verify(!wallpaper.shows("wallpaperPath"))

        page.destroy()
        toggle.destroy()
        settings.destroy()
        wallpaper.destroy()
        displays.destroy()
        shortcuts.destroy()
        audioPage.destroy()
        network.destroy()
        bluetoothPage.destroy()
        powerPage.destroy()
        notes.destroy()
    }
}
