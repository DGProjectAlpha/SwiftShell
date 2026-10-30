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
    readonly property var workspaceItems: Workspaces.buildWorkspaceItems(SettingsStore.workspaceIds, HyprlandModel.liveWorkspaces, monitorKey)
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
        LauncherModel.screen = window.screen;
        LauncherModel.openLauncher();
    }

    function syncExclusion() {
        const update = Bar.exclusionUpdate(reserveSpace, Theme.barHeight);
        if (update.property === "exclusiveZone") {
            exclusiveZone = update.value;
            console.info("SwiftShell: bar reserves", update.value, "logical px on", monitorKey);
            return;
        }
        exclusionMode = ExclusionMode.Ignore;
        console.info("SwiftShell: bar reserves no space on", monitorKey);
    }

    Component.onCompleted: {
        LauncherModel.screen = window.screen;
        syncExclusion();
    }
    onScreenChanged: LauncherModel.screen = window.screen
    onReserveSpaceChanged: syncExclusion()

    Rectangle {
        z: -1
        visible: Theme.topGradient
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

        WorkspaceIndicators {
            Layout.alignment: Qt.AlignVCenter
            workspaces: window.workspaceItems
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            FocusedTitle {
                anchors.fill: parent
                title: SettingsStore.showFocusedTitle ? window.windowTitle : ""
            }
        }

        MouseArea {
            id: searchButton
            Layout.alignment: Qt.AlignVCenter
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
                    window.openLauncher();
                    event.accepted = true;
                }
            }

            BarLabel {
                id: searchLabel
                anchors.centerIn: parent
                text: "Search"
                color: searchButton.containsMouse ? Theme.textHover : Theme.textMuted
            }
        }

        ClockModule {
            id: clockModule
            Layout.alignment: Qt.AlignVCenter
            onActivated: {
                LauncherModel.closeLauncher();
                popovers.toggle("calendar", clockModule);
            }
        }

        ControlIndicator {
            id: controlIndicator
            Layout.alignment: Qt.AlignVCenter
            onActivated: {
                LauncherModel.closeLauncher();
                popovers.toggle("control", controlIndicator);
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
            popovers.toggle("control", controlIndicator);
        }
    }
}
