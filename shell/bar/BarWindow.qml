import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../logic/bar.js" as Bar
import "../logic/windows.js" as Windows
import "../logic/workspaces.js" as Workspaces
import "../components"
import "../popovers"
import "../services"
import "../themes"

PanelWindow {
    id: window

    required property var modelData

    screen: modelData
    color: Theme.transparent
    focusable: false
    implicitHeight: Theme.barHeight
    property Item controlAnchor: null

    anchors {
        top: true
        left: true
        right: true
    }

    // Top stays under true fullscreen. Overlay would cover fullscreen clients.
    // keyboardFocus None keeps the bar from taking text input.
    WlrLayershell.namespace: "swiftshell-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property bool reserveSpace: SettingsStore.reserveSpace
    readonly property string hyprlandMonitorName: HyprlandModel.hyprlandNameForScreen(modelData)
    readonly property string monitorKey: hyprlandMonitorName !== "" ? hyprlandMonitorName : SettingsStore.targetMonitor
    readonly property var workspaceItems: Workspaces.indicatorItems(SettingsStore.workspaceIds, HyprlandModel.liveWorkspaces, monitorKey)
    readonly property int activeWorkspaceId: {
        for (let i = 0; i < workspaceItems.length; i++) {
            if (workspaceItems[i].active)
                return workspaceItems[i].id;
        }
        return -1;
    }
    readonly property string windowTitle: Windows.focusedTitle(HyprlandModel.liveToplevels, monitorKey, activeWorkspaceId)

    function openLauncher() {
        popovers.close();
        LauncherModel.openLauncher();
    }

    function syncExclusion() {
        const update = Bar.exclusionUpdate(reserveSpace, Theme.barHeight, exclusiveZone);
        if (update.mode === "normal") {
            // Writing exclusiveZone forces Normal, but assigning the same height again
            // does not call the setter. The mode write is what turns reservation back on.
            if (update.writeZone)
                exclusiveZone = update.zone;
            exclusionMode = ExclusionMode.Normal;
            console.info("SwiftShell: bar reserves", update.zone, "logical px on", monitorKey);
            return;
        }
        exclusionMode = ExclusionMode.Ignore;
        console.info("SwiftShell: bar reserves no space on", monitorKey, "(overlay)");
    }

    Component.onCompleted: syncExclusion()
    onReserveSpaceChanged: syncExclusion()
    onImplicitHeightChanged: syncExclusion()

    Rectangle {
        z: -1
        visible: Theme.topGradient || Theme.contrastScrim
        anchors.fill: parent
        color: Theme.transparent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.gradientTop }
            GradientStop { position: 1.0; color: Theme.transparent }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.marginH
        anchors.rightMargin: Theme.marginH
        spacing: Theme.moduleSpacing

        Repeater {
            model: SettingsStore.visibleModules

            delegate: Loader {
                required property var modelData
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: modelData === "title"
                Layout.fillHeight: modelData === "title"
                Layout.preferredHeight: Theme.barHeight
                sourceComponent: window.componentFor(modelData)
            }
        }
    }

    function componentFor(id) {
        if (id === "workspaces")
            return workspacesComponent
        if (id === "title")
            return titleComponent
        if (id === "search")
            return searchComponent
        if (id === "clock")
            return clockComponent
        if (id === "control")
            return controlComponent
        if (id === "media")
            return mediaComponent
        if (id === "tray")
            return trayComponent
        if (id === "battery")
            return batteryComponent
        return null
    }

    Component {
        id: workspacesComponent

        WorkspaceIndicators {
            workspaces: window.workspaceItems
        }
    }

    Component {
        id: titleComponent

        Item {
            implicitHeight: Theme.barHeight

            FocusedTitle {
                anchors.fill: parent
                title: SettingsStore.showFocusedTitle ? window.windowTitle : ""
            }
        }
    }

    Component {
        id: searchComponent

        MouseArea {
            id: searchButton
            implicitWidth: searchLabel.implicitWidth
            implicitHeight: Theme.barHeight
            width: implicitWidth
            height: implicitHeight
            hoverEnabled: true
            activeFocusOnTab: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: "Search"
            Accessible.description: "Open the launcher"

            onClicked: window.openLauncher()

            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    window.openLauncher()
                    event.accepted = true
                }
            }

            BarLabel {
                id: searchLabel
                anchors.centerIn: parent
                text: "Search"
                color: searchButton.containsMouse || searchButton.activeFocus ? Theme.textHover : Theme.textMuted
            }
        }
    }

    Component {
        id: clockComponent

        ClockModule {
            id: clockModule
            onActivated: {
                LauncherModel.closeLauncher()
                popovers.toggle("calendar", clockModule)
            }
        }
    }

    Component {
        id: mediaComponent

        Item {
            implicitWidth: mediaLoader.item ? mediaLoader.item.implicitWidth : 0
            implicitHeight: Theme.barHeight

            Loader {
                id: mediaLoader
                source: "MediaModule.qml"
                active: true
            }
        }
    }

    Component {
        id: trayComponent

        Item {
            implicitWidth: trayLoader.item ? trayLoader.item.implicitWidth : 0
            implicitHeight: Theme.barHeight

            Loader {
                id: trayLoader
                source: "TrayModule.qml"
                active: true
                onLoaded: {
                    if (item)
                        item.hostWindow = window
                }
            }
        }
    }

    Component {
        id: batteryComponent

        Item {
            implicitWidth: batteryLoader.item ? batteryLoader.item.implicitWidth : 0
            implicitHeight: Theme.barHeight

            Loader {
                id: batteryLoader
                source: "BatteryModule.qml"
                active: true
            }
        }
    }

    Component {
        id: controlComponent

        ControlIndicator {
            id: controlIndicator
            Component.onCompleted: window.controlAnchor = controlIndicator
            Component.onDestruction: {
                if (window.controlAnchor === controlIndicator)
                    window.controlAnchor = null
            }
            onActivated: {
                LauncherModel.closeLauncher()
                popovers.toggle("control", controlIndicator)
            }
        }
    }

    PopoverHost {
        id: popovers
        barWindow: window
    }

    Connections {
        target: LauncherModel
        function onControlRequested() {
            if (window.controlAnchor)
                popovers.toggle("control", window.controlAnchor)
        }
    }
}
