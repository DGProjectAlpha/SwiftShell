pragma Singleton

import QtQuick
import QtCore
import Quickshell.Io
import "../logic/settings.js" as Settings

QtObject {
    id: root

    readonly property string settingsPath: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/swiftshell/settings.json"
    readonly property int version: adapter.version
    readonly property bool use24Hour: clockSettings.use24Hour
    readonly property string targetMonitor: barSettings.targetMonitor
    readonly property bool reserveSpace: barSettings.reserveSpace
    readonly property bool showFocusedTitle: barSettings.showFocusedTitle
    readonly property var workspaceIds: Settings.normalizeWorkspaceIds(barSettings.workspaceIds)

    property bool writing: false
    property bool suppressReload: false

    function snapshot() {
        return {
            version: adapter.version,
            clock: {
                use24Hour: clockSettings.use24Hour
            },
            bar: {
                targetMonitor: barSettings.targetMonitor,
                reserveSpace: barSettings.reserveSpace,
                showFocusedTitle: barSettings.showFocusedTitle,
                workspaceIds: barSettings.workspaceIds
            }
        };
    }

    FileView {
        id: settingsFile
        path: root.settingsPath
        watchChanges: true
        atomicWrites: true
        onFileChanged: {
            if (root.suppressReload) {
                root.suppressReload = false;
                return;
            }
            if (!root.writing)
                reload();
        }
        onAdapterUpdated: {
            if (root.writing)
                return;
            root.writing = true;
            root.suppressReload = true;
            writeAdapter();
        }
        onSaved: root.writing = false
        onSaveFailed: function (error) {
            root.writing = false;
            console.warn("SwiftShell: settings were not saved", error);
        }
        onLoaded: {
            const result = Settings.validateSettings(root.snapshot());
            if (!result.ok)
                console.warn("SwiftShell: settings need attention:", result.errors.join(", "));
            else
                console.info("SwiftShell: settings loaded");
        }
        onLoadFailed: function (error) {
            console.warn("SwiftShell: settings file is missing or unreadable; using built-in defaults", error);
        }

        JsonAdapter {
            id: adapter
            property int version: 1

            property JsonObject clock: JsonObject {
                id: clockSettings
                property bool use24Hour: true
            }

            property JsonObject bar: JsonObject {
                id: barSettings
                property string targetMonitor: "HDMI-A-1"
                property bool reserveSpace: false
                property bool showFocusedTitle: true
                property list<int> workspaceIds: [4, 5, 6]
            }
        }
    }
}
