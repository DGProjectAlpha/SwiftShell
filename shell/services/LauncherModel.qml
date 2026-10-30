pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import "../logic/launcher.js" as Launcher

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

    signal controlRequested()

    function copyList(value) {
        const out = [];
        if (!value || typeof value.length !== "number")
            return out;
        for (let i = 0; i < value.length; i++) {
            if (typeof value[i] === "string")
                out.push(value[i]);
        }
        return out;
    }

    function indexApplications() {
        let values = null;
        try {
            values = DesktopEntries.applications.values;
        } catch (error) {
            values = null;
        }
        if (!values) {
            if (!root.warnedEntries) {
                console.warn("SwiftShell: desktop entries are unavailable");
                root.warnedEntries = true;
            }
            root.applications = [];
            return;
        }

        const out = [];
        const seen = {};
        for (let i = 0; i < values.length; i++) {
            const entry = values[i];
            if (!entry)
                continue;
            const id = entry.id || "";
            if (id === "" || seen[id])
                continue;
            seen[id] = true;
            let command = [];
            try {
                command = root.copyList(entry.command);
            } catch (error) {
                command = [];
            }
            out.push({
                id: id,
                name: entry.name || "",
                genericName: entry.genericName || "",
                comment: entry.comment || "",
                icon: entry.icon || "",
                categories: root.copyList(entry.categories),
                keywords: root.copyList(entry.keywords),
                terminal: entry.runInTerminal === true,
                command: command
            });
        }
        root.applications = out;
        console.info("SwiftShell: launcher indexed", out.length, "applications");
    }

    function setQuery(text) {
        root.query = typeof text === "string" ? text : "";
        root.selected = 0;
        root.confirmId = "";
    }

    function openLauncher() {
        if (!root.screen) {
            if (!root.warnedScreen) {
                console.warn("SwiftShell: launcher has no target screen");
                root.warnedScreen = true;
            }
            return;
        }
        root.warnedScreen = false;
        root.indexApplications();
        root.query = "";
        root.selected = 0;
        root.confirmId = "";
        root.open = true;
        console.info("SwiftShell: launcher opened");
    }

    function closeLauncher() {
        if (!root.open && root.query === "" && root.applications.length === 0)
            return;
        root.open = false;
        root.query = "";
        root.selected = 0;
        root.confirmId = "";
        root.applications = [];
        console.info("SwiftShell: launcher closed");
    }

    function remember(id) {
        root.recentIds = Launcher.pushRecent(root.recentIds, id);
        recentSettings.ids = root.recentIds;
        recentFile.writeAdapter();
    }

    function launchApplication(id) {
        let entry = null;
        try {
            entry = DesktopEntries.byId(id);
        } catch (error) {
            entry = null;
        }
        if (!entry) {
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
            console.warn("SwiftShell: application has no command", id);
            return;
        }
        try {
            if (entry.runInTerminal === true)
                console.info("SwiftShell: Quickshell 0.2 execute ignores the terminal flag for", id);
            entry.execute();
        } catch (error) {
            console.warn("SwiftShell: application launch failed", id);
            return;
        }
        root.remember(id);
        root.closeLauncher();
    }

    function runPower(id) {
        const step = Launcher.powerStep(root.confirmId, id);
        root.confirmId = step.confirmId;
        if (!step.run || !step.argv)
            return;
        try {
            Quickshell.execDetached({ command: step.argv });
        } catch (error) {
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
            root.controlRequested();
            return;
        }
        if (row.kind === "power") {
            root.runPower(row.id);
            return;
        }
        if (row.kind === "application")
            root.launchApplication(row.id);
    }

    function noteRequest(token) {
        const next = typeof token === "string" ? token : "";
        if (!root.requestReady) {
            root.seenRequest = next;
            root.requestReady = true;
            return;
        }
        if (next !== "" && next !== root.seenRequest) {
            root.seenRequest = next;
            console.info("SwiftShell: launcher requested");
            root.openLauncher();
        }
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
