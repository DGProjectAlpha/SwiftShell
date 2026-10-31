import QtQuick
import QtTest
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower

TestCase {
    name: "ShellLoad"
    when: windowShown

    // Every shell QML document. The static check requires this list to match the tree.
    readonly property var shellFiles: [
        "shell/shell.qml",
        "shell/bar/BarHost.qml",
        "shell/bar/BarWindow.qml",
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
        "shell/settings/AppearancePage.qml",
        "shell/settings/BarPage.qml",
        "shell/settings/ImageDialog.qml",
        "shell/settings/DisplaysPage.qml",
        "shell/settings/ShortcutsPage.qml",
        "shell/settings/SettingsWindow.qml",
        "shell/settings/WallpaperPage.qml",
        "shell/wallpaper/SlideshowClock.qml",
        "shell/wallpaper/WallpaperHost.qml",
        "shell/wallpaper/WallpaperSurface.qml"
    ]

    // These compile with the Qt Quick stubs. shell.qml, BarHost, and BarWindow also
    // reference WlrLayershell, which is a C++ attached property and is not stubbed.
    readonly property var readyFiles: [
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
        "shell/settings/AudioPage.qml",
        "shell/settings/NetworkPage.qml",
        "shell/settings/BluetoothPage.qml",
        "shell/settings/PowerPage.qml",
        "shell/settings/NotificationsPage.qml",
        "shell/settings/AppearancePage.qml",
        "shell/settings/BarPage.qml",
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
        if (path === "shell/settings/ImageDialog.qml")
            return message.indexOf('module "QtQuick.Dialogs" is not installed') !== -1
        if (path === "shell/notifications/NotificationHost.qml")
            return message.indexOf('module "Quickshell.Services.Notifications" is not installed') !== -1
                || expectedWlrFailure(message)
        if (path === "shell/shell.qml"
                || path === "shell/bar/BarHost.qml"
                || path === "shell/bar/BarWindow.qml"
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
        return message.indexOf("BarWindow.qml:32") !== -1
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
        verify(gridRowCount(calendar.children[0]) >= 5)

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
        tryVerify(function() { return slider.width === 248 && slider.height === 28 }, 1000)
        compare(slider.implicitHeight, 28)

        var surfaceComponent = componentFor("shell/popovers/PopoverSurface.qml")
        var calendarCard = surfaceComponent.createObject(this)
        var calendarColumn = calendarCard.children[1].children[0]
        calendarComponent.createObject(calendarColumn)
        tryVerify(function() { return calendarColumn.implicitWidth >= 196 }, 1000)
        var card = calendarCard.children[1]
        // Default settings: panel padding 12 on each side, shadow softness 10.
        compare(card.width, calendarColumn.implicitWidth + 24)
        compare(calendarCard.implicitWidth, card.width + 10)
        compare(calendarCard.implicitHeight, card.height + 10)
        verify(calendarCard.implicitHeight > calendar.implicitHeight)

        var controlCard = surfaceComponent.createObject(this)
        var controlColumn = controlCard.children[1].children[0]
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

    function test_popup_host_tracks_panel_implicit_size() {
        var bar = Qt.createQmlObject("import QtQuick; Item { property Item contentItem: null; property var screen: null }", this, "bar")
        bar.contentItem = bar
        bar.screen = Qt.createQmlObject("import QtQuick; QtObject { property real width: 1920; property real height: 1080 }", this, "screen")
        var anchor = Qt.createQmlObject("import QtQuick; Item { width: 48; height: 28 }", bar, "anchor")
        var popup = componentFor("shell/popovers/PopoverHost.qml").createObject(this, { barWindow: bar })
        verify(popup !== null)
        popup.toggle("calendar", anchor)
        tryVerify(function() { return popup.implicitWidth >= 196 + 34 && popup.implicitHeight > 80 }, 1000)
        var calendarWidth = popup.implicitWidth
        popup.toggle("control", anchor)
        tryVerify(function() { return popup.implicitWidth >= 248 + 34 && popup.implicitWidth !== calendarWidth }, 1000)
        popup.destroy()
        anchor.destroy()
        bar.screen.destroy()
        bar.destroy()
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

    function test_settings_page_names_the_blur_limit() {
        var page = componentFor("shell/settings/AppearancePage.qml").createObject(this)
        verify(page !== null)
        verify(findText(page, "translucent scrim", 0))
        verify(findText(page, "not a rounded blur mask", 0))
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
        verify(findText(wallpaper, "does not stop that program", 0))
        verify(findText(wallpaper, "No outputs are connected", 0))
        verify(wallpaper.shows("wallpaperPath"))
        var displays = componentFor("shell/settings/DisplaysPage.qml").createObject(this)
        verify(displays !== null)
        verify(findText(displays, "not sent", 0))
        verify(findText(displays, "No outputs are connected", 0))
        var shortcuts = componentFor("shell/settings/ShortcutsPage.qml").createObject(this)
        verify(shortcuts !== null)
        verify(findText(shortcuts, "does not install", 0))
        var audioPage = componentFor("shell/settings/AudioPage.qml").createObject(this)
        verify(audioPage !== null)
        verify(findText(audioPage, "follow PipeWire", 0))
        verify(audioPage.shows("mediaPlayer"))
        audioPage.query = "microphone"
        verify(audioPage.shows("audioInput"))
        verify(!audioPage.shows("mediaPlayer"))
        var network = componentFor("shell/settings/NetworkPage.qml").createObject(this)
        verify(network !== null)
        verify(findText(network, "does not store", 0))
        verify(findText(network, "hardware brightness", 0))
        var bluetoothPage = componentFor("shell/settings/BluetoothPage.qml").createObject(this)
        verify(bluetoothPage !== null)
        verify(findText(bluetoothPage, "does not start a scan", 0))
        var powerPage = componentFor("shell/settings/PowerPage.qml").createObject(this)
        verify(powerPage !== null)
        verify(findText(powerPage, "ask once more", 0))
        var notes = componentFor("shell/settings/NotificationsPage.qml").createObject(this)
        verify(notes !== null)
        verify(findText(notes, "does not own notifications", 0))
        verify(findText(notes, "Not SwiftShell", 0))
        verify(findText(notes, "sounds are not played", 0))
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
        var emptyTray = componentFor("shell/bar/TrayModule.qml").createObject(this)
        verify(emptyTray !== null)
        verify(emptyTray.implicitWidth === 0)
        SystemTray.items.values = [{
            id: "net",
            title: "Network",
            onlyMenu: false,
            hasMenu: true,
            icon: ""
        }]
        var tray = componentFor("shell/bar/TrayModule.qml").createObject(this)
        verify(tray !== null)
        verify(tray.implicitWidth > 0)
        verify(tray.rows.length === 1)

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
