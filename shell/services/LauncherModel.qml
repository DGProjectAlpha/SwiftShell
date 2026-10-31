pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../logic/launcher.js" as Launcher
import "../logic/monitors.js" as Monitors

Singleton {
    id: root

    property bool open: false
    property string query: ""
    property int selected: 0
    property string confirmId: ""
    property var screen: null
    property var applications: []
    property var recentIds: []
    property bool requestReady: false
    property string seenRequest: ""
    property bool warnedEntries: false
    property bool warnedScreen: false
    property bool warnedRecent: false
    property bool warnedRecentSave: false
    property bool indexPending: false
    property int indexedCount: -1
    property string notice: ""

    signal controlRequested()
    signal settingsRequested()
    signal inputRequested()

    function indexApplications() {
        let model = null;
        try {
            model = DesktopEntries.applications;
        } catch (error) {
            model = null;
        }
        const read = Launcher.readApplicationModel(model);
        if (!read.available) {
            if (!root.warnedEntries) {
                console.warn("SwiftShell: desktop entries are unavailable");
                root.warnedEntries = true;
            }
            root.indexPending = false;
            return;
        }

        const snap = Launcher.snapshotApplications(read.entries);
        const count = snap.applications.length;
        if (count === 0) {
            const waiting = root.indexedCount < 0;
            root.applications = [];
            root.indexPending = waiting;
            if (root.indexedCount !== 0) {
                console.info(waiting
                    ? "SwiftShell: launcher indexed 0 applications; waiting for the desktop entry scan"
                    : "SwiftShell: launcher indexed 0 applications");
                root.indexedCount = 0;
            }
            return;
        }

        root.indexPending = false;
        root.warnedEntries = false;
        root.applications = snap.applications;
        if (count !== root.indexedCount) {
            console.info("SwiftShell: launcher indexed", count, "applications");
            if (snap.skipped > 0)
                console.info("SwiftShell: launcher skipped", snap.skipped, "desktop entries");
            root.indexedCount = count;
        }
    }

    function setQuery(text) {
        root.query = typeof text === "string" ? text : "";
        root.selected = 0;
        root.confirmId = "";
        root.notice = "";
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
        let monitors = [];
        try {
            monitors = Hyprland.monitors.values;
        } catch (error) {
            monitors = [];
        }
        if (screen.name) {
            for (let i = 0; i < monitors.length; i++) {
                if (monitors[i] && monitors[i].name === screen.name)
                    return monitors[i];
            }
        }
        return null;
    }

    function screenRecords() {
        const screens = Quickshell.screens;
        const count = screens ? screens.length : 0;
        const records = [];
        for (let i = 0; i < count; i++) {
            const screen = screens[i];
            const monitor = root.monitorObjectForScreen(screen);
            let description = "";
            try {
                description = monitor && monitor.description ? String(monitor.description) : "";
            } catch (error) {
                description = "";
            }
            records.push(Monitors.describeScreen(
                screen,
                monitor && monitor.name ? monitor.name : "",
                description
            ));
        }
        return records;
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
        if (name === "" && description === "")
            return null;
        return { name: name, description: description };
    }

    function placeLauncher() {
        return Monitors.resolveLauncherScreen(root.screenRecords(), root.readFocusedOutput(), root.screen);
    }

    function screenIsLive(screen) {
        return Monitors.screenListed(screen, Quickshell.screens);
    }

    function dropIfScreenGone() {
        if (!root.open || root.screenIsLive(root.screen))
            return;
        console.info("SwiftShell: launcher closed because its screen disconnected");
        root.closeLauncher();
    }

    function openLauncher() {
        const resolved = root.placeLauncher();
        if (!resolved.screen || !root.screenIsLive(resolved.screen)) {
            if (!root.warnedScreen) {
                console.warn("SwiftShell: launcher has no target screen");
                root.warnedScreen = true;
            }
            if (root.open)
                root.closeLauncher();
            return;
        }
        root.warnedScreen = false;
        root.screen = resolved.screen;
        root.indexApplications();
        root.query = "";
        root.selected = 0;
        root.confirmId = "";
        root.notice = "";
        root.open = true;
        root.inputRequested();
        console.info("SwiftShell: launcher opened on", resolved.mode, resolved.label);
    }

    function closeLauncher() {
        if (!root.open && root.query === "" && root.notice === "")
            return;
        root.open = false;
        root.query = "";
        root.selected = 0;
        root.confirmId = "";
        root.notice = "";
        console.info("SwiftShell: launcher closed");
    }

    function remember(id) {
        root.recentIds = Launcher.pushRecent(root.recentIds, id);
        recentSettings.ids = root.recentIds;
        recentFile.writeAdapter();
    }

    function lookupEntry(id) {
        if (typeof id !== "string" || id === "")
            return null;
        const candidates = [id];
        if (id.length > 8 && id.slice(id.length - 8) === ".desktop")
            candidates.push(id.slice(0, id.length - 8));
        else
            candidates.push(id + ".desktop");
        for (let i = 0; i < candidates.length; i++) {
            try {
                const entry = DesktopEntries.byId(candidates[i]);
                if (entry)
                    return entry;
            } catch (error) {
                continue;
            }
        }
        return null;
    }

    function launchApplication(id, label) {
        const entry = root.lookupEntry(id);
        const shown = typeof label === "string" && label !== "" ? label : "the application";
        if (!entry) {
            root.notice = "Could not launch " + shown;
            console.warn("SwiftShell: launcher could not find", id);
            return;
        }
        let commandLength = 0;
        try {
            commandLength = entry.command ? entry.command.length : 0;
        } catch (error) {
            commandLength = 0;
        }
        if (commandLength === 0) {
            root.notice = "Could not launch " + shown;
            console.warn("SwiftShell: application has no command", id);
            return;
        }
        try {
            if (entry.runInTerminal === true)
                console.info("SwiftShell: Quickshell 0.2 execute ignores the terminal flag for", id);
            entry.execute();
        } catch (error) {
            root.notice = "Could not launch " + shown;
            console.warn("SwiftShell: application launch failed", id);
            return;
        }
        root.remember(id);
        root.closeLauncher();
    }

    function runPower(id) {
        const step = Launcher.powerInvocation(root.confirmId, id);
        root.confirmId = step.confirmId;
        if (!step.run) {
            if (step.error !== "") {
                root.notice = step.error;
                console.warn("SwiftShell: power action refused", id);
            }
            return;
        }
        try {
            Quickshell.execDetached({ command: step.argv });
        } catch (error) {
            root.confirmId = "";
            root.notice = "Could not run the power action";
            console.warn("SwiftShell: power action failed", id);
            return;
        }
        console.info("SwiftShell: power action", id);
        root.closeLauncher();
    }

    function activate(row) {
        if (!row)
            return;
        if (row.kind === "settings") {
            root.closeLauncher();
            root.settingsRequested();
            return;
        }
        if (row.kind === "power") {
            root.runPower(row.id);
            return;
        }
        if (row.kind === "application")
            root.launchApplication(row.id, row.name);
    }

    function noteRequest(token) {
        const step = Launcher.requestAction(root.open, token, root.seenRequest, root.requestReady);
        root.seenRequest = step.seen;
        root.requestReady = step.ready;
        if (step.action === "open") {
            console.info("SwiftShell: launcher requested");
            root.openLauncher();
        } else if (step.action === "close") {
            console.info("SwiftShell: launcher dismissed by request");
            root.closeLauncher();
        }
    }

    Component.onCompleted: root.indexApplications()

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.indexApplications(); }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() { root.dropIfScreenGone(); }
    }

    FileView {
        id: recentFile
        path: StandardPaths.writableLocation(StandardPaths.GenericStateLocation) + "/swiftshell/recent.json"
        watchChanges: true
        atomicWrites: true
        onLoaded: root.recentIds = Launcher.normalizeIdList(recentSettings.ids, Launcher.MAX_RECENT)
        onLoadFailed: function (error) {
            root.recentIds = [];
            if (!root.warnedRecent) {
                console.info("SwiftShell: no recent application list yet");
                root.warnedRecent = true;
            }
        }
        onSaveFailed: function (error) {
            if (!root.warnedRecentSave) {
                console.warn("SwiftShell: recent applications were not saved");
                root.warnedRecentSave = true;
            }
        }

        JsonAdapter {
            id: recentSettings
            property list<string> ids: []
        }
    }

    FileView {
        id: requestFile
        path: StandardPaths.writableLocation(StandardPaths.GenericStateLocation) + "/swiftshell/launcher.request"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.noteRequest(requestAdapter.text)
        onLoadFailed: function (error) {
            root.noteRequest("");
        }

        JsonAdapter {
            id: requestAdapter
            property string text: ""
        }
    }
}
