pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../logic/workspaces.js" as Workspaces

Singleton {
    id: root

    readonly property bool connected: Hyprland.eventSocketPath !== ""

    // Read raw JSON: 0.57 string addresses cannot be reconstructed from legacy ids.
    property var monitorSnapshot: []
    property var liveWorkspaces: []
    property string workspaceError: ""
    property bool snapshotPending: false
    property int snapshotStage: 0
    property var stagedMonitors: []
    property var stagedWorkspaces: []
    property var monitorChoices: []

    function requestSnapshot() {
        if (!root.connected) return;
        if (snapshotProcess.running) { root.snapshotPending = true; return; }
        root.snapshotStage = 0;
        snapshotProcess.command = ["hyprctl", "-j", "monitors"];
        snapshotProcess.running = true;
    }

    function finishSnapshot(code) {
        try {
            if (code !== 0) throw new Error();
            const data = JSON.parse(snapshotOutput.text);
            if (!Array.isArray(data)) throw new Error();
            if (root.snapshotStage === 0) root.stagedMonitors = data;
            else if (root.snapshotStage === 1) root.stagedWorkspaces = data;
            else {
                root.liveWorkspaces = Workspaces.snapshotItems(root.stagedMonitors, root.stagedWorkspaces, data);
                root.monitorSnapshot = root.stagedMonitors;
                const choices = root.monitorSnapshot.filter(function (m) { return !m.disabled; }).map(function (m) {
                    return { name: m.name, label: (m.model || m.description || m.name) + " · " + m.name, scale: m.scale };
                });
                // Preserve settings editor focus while workspace/focus events arrive.
                if (JSON.stringify(choices) !== JSON.stringify(root.monitorChoices)) root.monitorChoices = choices;
                root.workspaceError = "";
                root.outputRevision += 1;
            }
            if (root.snapshotStage < 2) {
                root.snapshotStage += 1;
                snapshotProcess.command = ["hyprctl", "-j", root.snapshotStage === 1 ? "workspaces" : "workspacerules"];
                snapshotProcess.running = true;
                return;
            }
        } catch (error) {
            root.workspaceError = "Workspace discovery failed; showing the last successful snapshot.";
            console.warn("SwiftShell: workspace IPC snapshot failed");
        }
        if (root.snapshotPending) {
            root.snapshotPending = false;
            snapshotDebounce.restart();
        }
    }

    Process {
        id: snapshotProcess
        stdout: StdioCollector { id: snapshotOutput; waitForEnd: true }
        // Do not forward stderr: compositor diagnostics may contain private data.
        onExited: function (exitCode, exitStatus) { root.finishSnapshot(exitCode); }
    }

    Timer {
        id: snapshotDebounce
        interval: 80
        repeat: false
        onTriggered: root.requestSnapshot()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // Event-triggered, coalesced reads, never periodic polling.
            if (/^(workspace|focusedmon|monitor|createworkspace|destroyworkspace|moveworkspace|renameworkspace|configreloaded|openwindow|closewindow|movewindow|urgent)/.test(event.name))
                snapshotDebounce.restart();
        }
    }

    readonly property var liveToplevels: {
        const values = Hyprland.toplevels.values;
        const out = [];
        for (let i = 0; i < values.length; i++)
            out.push(snapshotToplevel(values[i]));
        return out;
    }

    function snapshotToplevel(toplevel) {
        let title = "";
        let activated = false;
        let monitorName = "";
        let workspaceId = -1;

        try {
            title = toplevel.title || "";
        } catch (error) {
            title = "";
        }
        try {
            activated = toplevel.activated === true;
        } catch (error) {
            activated = false;
        }
        try {
            if (toplevel.monitor && toplevel.monitor.name)
                monitorName = toplevel.monitor.name;
        } catch (error) {
            monitorName = "";
        }
        try {
            if (toplevel.workspace && toplevel.workspace.id !== undefined)
                workspaceId = toplevel.workspace.id;
        } catch (error) {
            workspaceId = -1;
        }

        if (title === "" || monitorName === "") {
            try {
                const attached = toplevel.HyprlandToplevel;
                if (attached) {
                    if (title === "" && attached.title)
                        title = attached.title;
                    if (!activated && attached.activated === true)
                        activated = true;
                    if (monitorName === "" && attached.monitor && attached.monitor.name)
                        monitorName = attached.monitor.name;
                    if (workspaceId < 0 && attached.workspace && attached.workspace.id !== undefined)
                        workspaceId = attached.workspace.id;
                }
            } catch (error) {
                // This Quickshell build does not expose the attached Hyprland toplevel.
            }
        }

        return {
            title: title,
            activated: activated,
            monitorName: monitorName,
            workspaceId: workspaceId
        };
    }

    function monitorObjectForScreen(screen) {
        if (!screen)
            return null;

        try {
            const direct = Hyprland.monitorFor(screen);
            if (direct)
                return direct;
        } catch (error) {
            // monitorFor is absent on a stub or an older build.
        }

        const monitors = Hyprland.monitors.values;
        if (screen.name) {
            for (let i = 0; i < monitors.length; i++) {
                if (monitors[i] && monitors[i].name === screen.name)
                    return monitors[i];
            }
        }
        return null;
    }

    function hyprlandNameForScreen(screen) {
        const monitor = root.monitorObjectForScreen(screen);
        return monitor && monitor.name ? monitor.name : (screen && screen.name ? screen.name : "");
    }

    function descriptionForScreen(screen) {
        const observed = root.monitorSnapshot.find(function (m) { return screen && m.name === screen.name; });
        if (observed) return observed.description || "";
        const monitor = root.monitorObjectForScreen(screen);
        try {
            return monitor && monitor.description ? String(monitor.description) : "";
        } catch (error) {
            return "";
        }
    }

    function readFocusedOutput() {
        for (const monitor of root.monitorSnapshot) {
            if (monitor.focused) return { name: monitor.name, description: monitor.description || "", id: monitor.id };
        }
        return null;
    }

    readonly property var focusedOutput: readFocusedOutput()

    property int outputRevision: 0
    property bool warnedDispatchDown: false
    property string announcedDispatchMode: ""

    function detectedLua() {
        try {
            const value = Hyprland["usingLua"];
            if (value === true)
                return true;
            if (value === false)
                return false;
        } catch (error) {
            return null;
        }
        return null;
    }

    function activateWorkspace(id, configuredMode, monitorName) {
        if (!root.connected) {
            if (!root.warnedDispatchDown) {
                console.warn("SwiftShell: Hyprland IPC is unavailable; workspace activation was not sent");
                root.warnedDispatchDown = true;
            }
            return;
        }

        root.warnedDispatchDown = false;
        const mode = Workspaces.resolveDispatchMode(configuredMode, root.detectedLua());
        const command = Workspaces.dispatchAddressCommand(id, configuredMode, root.detectedLua());
        if (command === "") {
            console.warn("SwiftShell: ignored workspace activation for", id);
            return;
        }

        if (root.announcedDispatchMode !== mode) {
            console.info("SwiftShell: workspace dispatch mode", mode);
            root.announcedDispatchMode = mode;
        }

        try {
            const focusMonitor = Workspaces.dispatchMonitorCommand(monitorName, configuredMode, root.detectedLua());
            if (focusMonitor !== "") Hyprland.dispatch(focusMonitor);
            Hyprland.dispatch(command);
        } catch (error) {
            console.warn("SwiftShell: workspace", id, "was not activated");
            return;
        }

        Qt.callLater(function () { root.refresh(); });
    }

    function refresh() {
        snapshotDebounce.restart();
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        root.outputRevision += 1;
    }

    onFocusedOutputChanged: root.outputRevision += 1

    onConnectedChanged: {
        if (connected) {
            console.info("SwiftShell: Hyprland event socket is available");
            refresh();
        } else {
            console.warn("SwiftShell: Hyprland event socket is unavailable; workspace clicks will be ignored");
            root.outputRevision += 1;
        }
    }

    Component.onCompleted: {
        if (connected)
            refresh();
    }
}
