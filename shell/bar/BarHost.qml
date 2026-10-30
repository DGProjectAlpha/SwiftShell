import QtQuick
import Quickshell
import "../logic/monitors.js" as Monitors
import "../services"

Scope {
    id: root

    property bool warnedMissing: false
    property bool announcedMatch: false
    property bool refreshingScreens: false
    property var targetScreens: []

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

    function refreshTargetScreens() {
        if (root.refreshingScreens)
            return;
        root.refreshingScreens = true;

        const matched = [];
        const screens = Quickshell.screens;
        const count = screens ? screens.length : 0;
        for (let i = 0; i < count; i++) {
            const screen = screens[i];
            const hyprlandName = HyprlandModel.hyprlandNameForScreen(screen);
            const screenName = screen && screen.name ? screen.name : "";
            if (Monitors.matchesTarget(screenName, hyprlandName, SettingsStore.targetMonitor))
                matched.push(screen);
        }

        if (!root.sameScreens(root.targetScreens, matched))
            root.targetScreens = matched;

        root.refreshingScreens = false;
        root.warnIfMissing();
    }

    function warnIfMissing() {
        if (root.targetScreens.length === 0) {
            if (!root.warnedMissing) {
                const screens = Quickshell.screens;
                const count = screens ? screens.length : 0;
                console.warn("SwiftShell: no output matched the target monitor", SettingsStore.targetMonitor, "among", count, "screens");
                root.warnedMissing = true;
            }
            return;
        }

        if (!root.announcedMatch || root.warnedMissing)
            console.info("SwiftShell: bar placed on", SettingsStore.targetMonitor);
        root.warnedMissing = false;
        root.announcedMatch = true;
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
    }

    Variants {
        model: root.targetScreens
        BarWindow {}
    }
}
