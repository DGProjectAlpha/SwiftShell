import QtQuick
import Quickshell
import "."
import "../components"
import "../logic/settings.js" as Settings
import "../logic/settingsNav.js" as Nav
import "../services"
import "../themes"

FloatingWindow {
    id: window

    title: "SwiftShell Settings"
    visible: SettingsModel.open
    minimumSize: Qt.size(640, 440)

    property var history: Settings.initialHistory(window.currentAppearance())
    readonly property bool canUndo: history && history.past && history.past.length > 0

    function currentAppearance() {
        return {
            mode: SettingsStore.appearanceMode,
            tint: SettingsStore.appearanceTint,
            panelOpacity: SettingsStore.panelOpacity,
            panelBlur: SettingsStore.panelBlur,
            radius: SettingsStore.radius,
            shadowOpacity: SettingsStore.shadowOpacity,
            shadowSoftness: SettingsStore.shadowSoftness,
            motionScale: SettingsStore.motionScale,
            reducedMotion: SettingsStore.reducedMotion,
            panelPadding: SettingsStore.panelPadding,
            panelSpacing: SettingsStore.panelSpacing,
            fontSize: SettingsStore.fontSize,
            fontWeight: SettingsStore.fontWeight,
            iconScale: SettingsStore.iconScale,
            topGradient: SettingsStore.topGradient,
            contrast: SettingsStore.textContrast,
            automaticText: SettingsStore.automaticText,
            automaticGradient: SettingsStore.automaticGradient,
            manualText: SettingsStore.manualText,
            manualMuted: SettingsStore.manualMuted,
            manualPanel: SettingsStore.manualPanel,
            manualGradient: SettingsStore.manualGradient
        }
    }

    function applyHistory(next) {
        history = next
        SettingsStore.setAppearance(history.present)
    }

    function commit(patch) {
        var present = Settings.initialHistory(history.present).present
        var keys = Object.keys(patch)
        for (var index = 0; index < keys.length; index++)
            present[keys[index]] = patch[keys[index]]
        window.applyHistory(Settings.reduceAppearanceHistory(history, { type: "edit", present: present }))
    }

    function undo() {
        window.applyHistory(Settings.reduceAppearanceHistory(history, { type: "undo" }))
    }

    function resetAppearance() {
        window.applyHistory(Settings.reduceAppearanceHistory(history, { type: "reset" }))
    }

    function activePage() {
        if (SettingsStore.settingsWindowCategory === "bar")
            return barPage
        if (SettingsStore.settingsWindowCategory === "wallpaper")
            return wallpaperPage
        if (SettingsStore.settingsWindowCategory === "displays")
            return displaysPage
        if (SettingsStore.settingsWindowCategory === "shortcuts")
            return shortcutsPage
        if (SettingsStore.settingsWindowCategory === "audio")
            return audioPage
        if (SettingsStore.settingsWindowCategory === "network")
            return networkPage
        if (SettingsStore.settingsWindowCategory === "bluetooth")
            return bluetoothPage
        if (SettingsStore.settingsWindowCategory === "power")
            return powerPage
        if (SettingsStore.settingsWindowCategory === "notifications")
            return notificationsPage
        return page
    }

    Component.onCompleted: {
        history = Settings.initialHistory(window.currentAppearance())
        window.width = SettingsStore.settingsWindowWidth
        window.height = SettingsStore.settingsWindowHeight
        search.forceActiveFocus()
    }

    function rememberSize() {
        SettingsStore.setSettingsWindowSize(Math.round(window.width), Math.round(window.height))
    }

    function raiseWindow() {
        try {
            if (typeof window.requestActivate === "function")
                window.requestActivate()
        } catch (error) {
            // Quickshell 0.2 does not document a raise method. The compositor still owns stacking.
        }
    }

    onClosed: {
        window.rememberSize()
        SettingsModel.hide()
    }

    Connections {
        target: SettingsModel
        function onFocusTicketChanged() {
            if (!SettingsModel.open)
                return
            window.raiseWindow()
            search.forceActiveFocus()
        }
    }

    Rectangle {
        id: content
        anchors.fill: parent
        color: Theme.panelColor
        focus: true

        Keys.onEscapePressed: function (event) {
            window.rememberSize()
            SettingsModel.hide()
            event.accepted = true
        }

        Keys.onPressed: function (event) {
            var alt = (event.modifiers & Qt.AltModifier) !== 0
            if (!alt)
                return
            if (event.key === Qt.Key_U)
                window.undo()
            else if (event.key === Qt.Key_R)
                window.resetAppearance()
            else
                return
            event.accepted = true
        }

        Item {
            id: frame
            anchors.fill: parent
            anchors.margins: Theme.panelPadding
            readonly property bool stacked: Nav.navigationLayout(width) === "stacked"

            Text {
                anchors.left: search.left
                anchors.right: search.right
                anchors.verticalCenter: search.verticalCenter
                visible: search.text === ""
                text: "Search settings"
                color: Theme.panelMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
            }

            TextInput {
                id: search
                width: parent.width
                height: Theme.controlHeight
                color: Theme.panelText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                selectByMouse: true
                activeFocusOnTab: true
                clip: true
                Accessible.name: "Search settings"
                onTextChanged: {
                    if (text.trim() === "")
                        return
                    var category = Nav.categoryFor(Nav.firstControlId(text))
                    if (category !== "" && category !== SettingsStore.settingsWindowCategory)
                        SettingsStore.setSettingsCategory(category)
                }

                Keys.onEscapePressed: function (event) {
                    if (text !== "") {
                        text = ""
                        event.accepted = true
                        return
                    }
                    window.rememberSize()
                    SettingsModel.hide()
                    event.accepted = true
                }

                Keys.onPressed: function (event) {
                    var alt = (event.modifiers & Qt.AltModifier) !== 0
                    if (alt && event.key === Qt.Key_J) {
                        window.activePage().moveHighlight(1)
                        event.accepted = true
                        return
                    }
                    if (alt && event.key === Qt.Key_K) {
                        window.activePage().moveHighlight(-1)
                        event.accepted = true
                        return
                    }
                    if (alt && event.key === Qt.Key_U) {
                        window.undo()
                        event.accepted = true
                        return
                    }
                    if (alt && event.key === Qt.Key_R) {
                        window.resetAppearance()
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        window.activePage().focusHighlight()
                        event.accepted = true
                    }
                }
            }

            Rectangle {
                id: searchLine
                anchors.top: search.bottom
                width: parent.width
                height: 1
                color: Theme.panelMuted
            }

            Item {
                id: side
                anchors.top: searchLine.bottom
                anchors.left: parent.left
                anchors.topMargin: Theme.panelSpacing
                width: frame.stacked ? parent.width : 148
                height: frame.stacked ? sideColumn.implicitHeight : parent.height - searchLine.y - searchLine.height - Theme.panelSpacing

                Column {
                    id: sideColumn
                    width: parent.width
                    spacing: Theme.panelSpacing

                    Text {
                        visible: SettingsStore.persistenceState === "error" || SettingsStore.persistenceState === "protected"
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: SettingsStore.persistenceMessage
                        color: Theme.panelText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    FlatButton {
                        width: parent.width
                        label: "Undo"
                        enabled: window.canUndo
                        onActivated: window.undo()
                    }

                    FlatButton {
                        width: parent.width
                        label: "Reset"
                        onActivated: window.resetAppearance()
                    }

                    FlatButton {
                        width: parent.width
                        label: "Appearance"
                        emphasized: SettingsStore.settingsWindowCategory === "appearance"
                        onActivated: {
                            SettingsStore.setSettingsCategory("appearance")
                            search.text = ""
                        }
                    }

                    FlatButton {
                        width: parent.width
                        label: "Top bar"
                        emphasized: SettingsStore.settingsWindowCategory === "bar"
                        onActivated: {
                            SettingsStore.setSettingsCategory("bar")
                            search.text = ""
                        }
                    }

                    FlatButton {
                        width: parent.width
                        label: "Wallpaper"
                        emphasized: SettingsStore.settingsWindowCategory === "wallpaper"
                        onActivated: {
                            SettingsStore.setSettingsCategory("wallpaper")
                            search.text = ""
                        }
                    }

                    FlatButton {
                        width: parent.width
                        label: "Displays"
                        emphasized: SettingsStore.settingsWindowCategory === "displays"
                        onActivated: {
                            SettingsStore.setSettingsCategory("displays")
                            search.text = ""
                        }
                    }

                    FlatButton {
                        width: parent.width
                        label: "Shortcuts"
                        emphasized: SettingsStore.settingsWindowCategory === "shortcuts"
                        onActivated: {
                            SettingsStore.setSettingsCategory("shortcuts")
                            search.text = ""
                        }
                    }

                    FlatButton {
                        width: parent.width
                        label: "Audio"
                        emphasized: SettingsStore.settingsWindowCategory === "audio"
                        onActivated: {
                            SettingsStore.setSettingsCategory("audio")
                            search.text = ""
                        }
                    }

                    FlatButton {
                        width: parent.width
                        label: "Network"
                        emphasized: SettingsStore.settingsWindowCategory === "network"
                        onActivated: {
                            SettingsStore.setSettingsCategory("network")
                            search.text = ""
                        }
                    }

                    FlatButton {
                        width: parent.width
                        label: "Bluetooth"
                        emphasized: SettingsStore.settingsWindowCategory === "bluetooth"
                        onActivated: {
                            SettingsStore.setSettingsCategory("bluetooth")
                            search.text = ""
                        }
                    }

                    FlatButton {
                        width: parent.width
                        label: "Power"
                        emphasized: SettingsStore.settingsWindowCategory === "power"
                        onActivated: {
                            SettingsStore.setSettingsCategory("power")
                            search.text = ""
                        }
                    }

                    FlatButton {
                        width: parent.width
                        label: "Notifications"
                        emphasized: SettingsStore.settingsWindowCategory === "notifications"
                        onActivated: {
                            SettingsStore.setSettingsCategory("notifications")
                            search.text = ""
                        }
                    }
                }
            }

            Flickable {
                id: scroller
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                anchors.left: frame.stacked ? parent.left : side.right
                anchors.leftMargin: frame.stacked ? 0 : Theme.panelSpacing
                anchors.right: parent.right
                anchors.top: frame.stacked ? side.bottom : searchLine.bottom
                anchors.topMargin: Theme.panelSpacing
                anchors.bottom: parent.bottom
                contentWidth: width
                contentHeight: window.activePage().implicitHeight

                AppearancePage {
                    id: page
                    y: 0
                    width: scroller.width
                    visible: SettingsStore.settingsWindowCategory === "appearance"
                    height: visible ? implicitHeight : 0
                    query: search.text
                    onEdited: function (patch) { window.commit(patch) }
                    onRevealRequested: function (y, itemHeight) {
                        scroller.contentY = Nav.scrollTarget(scroller.contentY, scroller.height, y, itemHeight)
                    }
                }

                BarPage {
                    id: barPage
                    y: 0
                    width: scroller.width
                    visible: SettingsStore.settingsWindowCategory === "bar"
                    height: visible ? implicitHeight : 0
                    query: search.text
                    onRevealRequested: function (y, itemHeight) {
                        scroller.contentY = Nav.scrollTarget(scroller.contentY, scroller.height, y, itemHeight)
                    }
                }

                WallpaperPage {
                    id: wallpaperPage
                    y: 0
                    width: scroller.width
                    visible: SettingsStore.settingsWindowCategory === "wallpaper"
                    height: visible ? implicitHeight : 0
                    query: search.text
                    onRevealRequested: function (y, itemHeight) {
                        scroller.contentY = Nav.scrollTarget(scroller.contentY, scroller.height, y, itemHeight)
                    }
                    onEdited: function (patch) { window.commit(patch) }
                }

                DisplaysPage {
                    id: displaysPage
                    y: 0
                    width: scroller.width
                    visible: SettingsStore.settingsWindowCategory === "displays"
                    height: visible ? implicitHeight : 0
                    query: search.text
                    onRevealRequested: function (y, itemHeight) {
                        scroller.contentY = Nav.scrollTarget(scroller.contentY, scroller.height, y, itemHeight)
                    }
                }

                ShortcutsPage {
                    id: shortcutsPage
                    y: 0
                    width: scroller.width
                    visible: SettingsStore.settingsWindowCategory === "shortcuts"
                    height: visible ? implicitHeight : 0
                    query: search.text
                    onRevealRequested: function (y, itemHeight) {
                        scroller.contentY = Nav.scrollTarget(scroller.contentY, scroller.height, y, itemHeight)
                    }
                }

                AudioPage {
                    id: audioPage
                    y: 0
                    width: scroller.width
                    visible: SettingsStore.settingsWindowCategory === "audio"
                    height: visible ? implicitHeight : 0
                    query: search.text
                    onRevealRequested: function (y, itemHeight) {
                        scroller.contentY = Nav.scrollTarget(scroller.contentY, scroller.height, y, itemHeight)
                    }
                }

                NetworkPage {
                    id: networkPage
                    y: 0
                    width: scroller.width
                    visible: SettingsStore.settingsWindowCategory === "network"
                    height: visible ? implicitHeight : 0
                    query: search.text
                }

                BluetoothPage {
                    id: bluetoothPage
                    y: 0
                    width: scroller.width
                    visible: SettingsStore.settingsWindowCategory === "bluetooth"
                    height: visible ? implicitHeight : 0
                    query: search.text
                }

                PowerPage {
                    id: powerPage
                    y: 0
                    width: scroller.width
                    visible: SettingsStore.settingsWindowCategory === "power"
                    height: visible ? implicitHeight : 0
                    query: search.text
                }

                NotificationsPage {
                    id: notificationsPage
                    y: 0
                    width: scroller.width
                    visible: SettingsStore.settingsWindowCategory === "notifications"
                    height: visible ? implicitHeight : 0
                    query: search.text
                }
            }
        }
    }
}
