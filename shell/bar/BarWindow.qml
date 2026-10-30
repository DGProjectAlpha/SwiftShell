import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../logic/bar.js" as Bar
import "../logic/windows.js" as Windows
import "../logic/workspaces.js" as Workspaces
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

    Component.onCompleted: syncExclusion()
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

        ClockModule {
            id: clockModule
            Layout.alignment: Qt.AlignVCenter
            onActivated: popovers.toggle("calendar", clockModule)
        }

        ControlIndicator {
            id: controlIndicator
            Layout.alignment: Qt.AlignVCenter
            onActivated: popovers.toggle("control", controlIndicator)
        }
    }

    PopoverHost {
        id: popovers
        barWindow: window
    }
}
