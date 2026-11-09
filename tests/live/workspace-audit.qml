//@ pragma ShellId swiftshell-workspace-audit
import QtQuick
import Quickshell
import "services" as Services
import "logic/workspaces.js" as Workspaces

// Windowless, read-only live IPC probe. Does not import SettingsStore or dispatch.
ShellRoot {
    property bool finished: false
    function inspect() {
        if (finished || Services.HyprlandModel.monitorChoices.length === 0) return;
        finished = true;
        const monitors = Services.HyprlandModel.monitorChoices;
        const live = Services.HyprlandModel.liveWorkspaces;
        for (const m of monitors) {
            const items = Workspaces.perMonitorItems("{}", [], "", live, m.name);
            console.info("Workspace audit:", m.name, "scale", m.scale,
                         "keys", items.map(function (w) { return w.key }).join(","),
                         "active", items.filter(function (w) { return w.active }).map(function (w) { return w.key }).join(","));
        }
        const focused = Services.HyprlandModel.readFocusedOutput();
        console.info("Workspace audit: focused", focused ? focused.name : "unavailable");
        Qt.quit();
    }
    Connections {
        target: Services.HyprlandModel
        function onMonitorChoicesChanged() { inspect(); }
    }
    Timer {
        interval: 6000
        running: true
        repeat: false
        onTriggered: {
            console.warn("Workspace audit: timed out", Services.HyprlandModel.workspaceError);
            Qt.quit();
        }
    }
}
