pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../logic/workspaces.js" as Workspaces

Singleton {
    id: root

    readonly property bool connected: Hyprland.eventSocketPath !== ""

    readonly property var liveWorkspaces: {
        const values = Hyprland.workspaces.values;
        const out = [];
        for (let i = 0; i < values.length; i++) {
            const workspace = values[i];
            out.push({
                id: workspace.id,
                name: workspace.name,
                monitorName: workspace.monitor && workspace.monitor.name ? workspace.monitor.name : "",
                active: workspace.active === true,
                focused: workspace.focused === true,
                urgent: workspace.urgent === true
            });
        }
        return out;
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
        return monitor && monitor.name ? monitor.name : "";
    }

    function descriptionForScreen(screen) {
        const monitor = root.monitorObjectForScreen(screen);
        try {
            return monitor && monitor.description ? String(monitor.description) : "";
        } catch (error) {
            return "";
        }
    }

    function readFocusedOutput() {
        let monitor = null;
        try {
            monitor = Hyprland.focusedMonitor;
        } catch (error) {
            return null;
        }
        if (!monitor)
            return null;

        let name = "";
        let description = "";
        let id = -1;
        try {
            if (monitor.name)
                name = String(monitor.name);
        } catch (error) {
            name = "";
        }
        try {
            if (monitor.description)
                description = String(monitor.description);
        } catch (error) {
            description = "";
        }
        try {
            if (monitor.id !== undefined && monitor.id !== null)
                id = monitor.id;
        } catch (error) {
            id = -1;
        }
        if (name === "" && description === "")
            return null;
        return { name: name, description: description, id: id };
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

    function activateWorkspace(id, configuredMode) {
        if (!root.connected) {
            if (!root.warnedDispatchDown) {
                console.warn("SwiftShell: Hyprland IPC is unavailable; workspace activation was not sent");
                root.warnedDispatchDown = true;
            }
            return;
        }

        root.warnedDispatchDown = false;
        const mode = Workspaces.resolveDispatchMode(configuredMode, root.detectedLua());
        const command = Workspaces.dispatchWorkspaceCommand(id, configuredMode, root.detectedLua());
        if (command === "") {
            console.warn("SwiftShell: ignored workspace activation for", id);
            return;
        }

        if (root.announcedDispatchMode !== mode) {
            console.info("SwiftShell: workspace dispatch mode", mode);
            root.announcedDispatchMode = mode;
        }

        try {
            Hyprland.dispatch(command);
        } catch (error) {
            console.warn("SwiftShell: workspace", id, "was not activated");
            return;
        }

        Qt.callLater(function () { root.refresh(); });
    }

    function refresh() {
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
