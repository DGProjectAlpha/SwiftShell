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

    function hyprlandNameForScreen(screen) {
        const monitors = Hyprland.monitors.values;
        if (!screen)
            return "";

        let resolved = "";
        try {
            const direct = Hyprland.monitorFor(screen);
            if (direct && direct.name)
                resolved = direct.name;
        } catch (error) {
            resolved = "";
        }

        if (resolved === "" && screen.name) {
            for (let i = 0; i < monitors.length; i++) {
                if (monitors[i] && monitors[i].name === screen.name)
                    return monitors[i].name;
            }
        }

        return resolved;
    }

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
