import QtQuick
import Quickshell
import "../logic/monitors.js" as Monitors
import "../services"

Scope {
    id: root

    property bool refreshingScreens: false
    property var targetScreens: []
    property string announcedPlacement: ""

    function sameScreens(left, right) {
        const a = left || [];
        const b = right || [];
        if (a.length !== b.length)
            return false;
        for (let i = 0; i < a.length; i++) {
            if (a[i] !== b[i])
                return false;
        }
        return true;
    }

    function screenRecords() {
        const screens = Quickshell.screens;
        const count = screens ? screens.length : 0;
        const records = [];
        for (let i = 0; i < count; i++) {
            const screen = screens[i];
            records.push(Monitors.describeScreen(
                screen,
                HyprlandModel.hyprlandNameForScreen(screen),
                HyprlandModel.descriptionForScreen(screen)
            ));
        }
        return records;
    }

    function announce(placement) {
        const key = placement.mode + "\n" + (placement.label || "");
        if (key === root.announcedPlacement)
            return;
        root.announcedPlacement = key;
        if (placement.mode === "missing") {
            console.warn("SwiftShell: no screen is available for the bar");
            return;
        }
        if (placement.mode === "preference")
            console.info("SwiftShell: bar placed on preferred monitor", placement.label);
        else if (placement.mode === "focused")
            console.info("SwiftShell: bar placed on focused monitor", placement.label);
        else
            console.info("SwiftShell: bar placed on fallback monitor", placement.label);
    }

    function refreshTargetScreens() {
        if (root.refreshingScreens)
            return;
        root.refreshingScreens = true;
        const placement = Monitors.selectBarPlacement(
            root.screenRecords(),
            SettingsStore.targetMonitor,
            HyprlandModel.readFocusedOutput(),
            SettingsStore.barPlacement
        );
        const matched = placement.screens && placement.screens.length ? placement.screens : [];
        if (!root.sameScreens(root.targetScreens, matched))
            root.targetScreens = matched;
        root.refreshingScreens = false;
        root.announce(placement);
    }

    Component.onCompleted: refreshTargetScreens()

    Connections {
        target: Quickshell
        function onScreensChanged() { root.refreshTargetScreens(); }
    }

    Connections {
        target: HyprlandModel
        function onOutputRevisionChanged() { root.refreshTargetScreens(); }
    }

    Connections {
        target: SettingsStore
        function onTargetMonitorChanged() { root.refreshTargetScreens(); }
        function onBarPlacementChanged() { root.refreshTargetScreens(); }
    }

    Variants {
        model: root.targetScreens
        BarWindow {}
    }
}
