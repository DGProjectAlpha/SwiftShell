import QtQuick
import Quickshell
import "../logic/monitors.js" as Monitors
import "../services"

Scope {
    id: root

    property bool warnedMissing: false
    property bool announcedMatch: false

    readonly property var targetScreens: {
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
        return matched;
    }

    function warnIfMissing() {
        if (root.targetScreens.length === 0) {
            if (!root.warnedMissing) {
                console.warn("SwiftShell: no output matched the target monitor", SettingsStore.targetMonitor);
                root.warnedMissing = true;
            }
            return;
        }

        if (!root.announcedMatch || root.warnedMissing)
            console.info("SwiftShell: bar placed on", SettingsStore.targetMonitor);
        root.warnedMissing = false;
        root.announcedMatch = true;
    }

    onTargetScreensChanged: warnIfMissing()
    Component.onCompleted: warnIfMissing()

    Variants {
        model: root.targetScreens
        BarWindow {}
    }
}
