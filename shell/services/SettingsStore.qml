pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import "../logic/settings.js" as Settings

Singleton {
    id: root

    readonly property string settingsPath: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/swiftshell/settings.json"
    readonly property int version: adapter.version
    readonly property bool use24Hour: clockSettings.use24Hour
    readonly property bool showWeekNumbers: clockSettings.showWeekNumbers
    readonly property string weekStart: clockSettings.weekStart
    readonly property string targetMonitor: barSettings.targetMonitor
    readonly property bool reserveSpace: barSettings.reserveSpace
    readonly property bool showFocusedTitle: barSettings.showFocusedTitle
    readonly property var workspaceIds: Settings.normalizeWorkspaceIds(barSettings.workspaceIds)
    readonly property string appearanceMode: appearanceSettings.mode
    readonly property string appearanceTint: appearanceSettings.tint
    readonly property real panelOpacity: appearanceSettings.panelOpacity
    readonly property real panelBlur: appearanceSettings.panelBlur
    readonly property int radius: appearanceSettings.radius
    readonly property real shadowOpacity: appearanceSettings.shadowOpacity
    readonly property int shadowSoftness: appearanceSettings.shadowSoftness
    readonly property real motionScale: appearanceSettings.motionScale
    readonly property bool reducedMotion: appearanceSettings.reducedMotion
    readonly property int panelPadding: appearanceSettings.panelPadding
    readonly property int panelSpacing: appearanceSettings.panelSpacing
    readonly property int fontSize: appearanceSettings.fontSize
    readonly property string fontWeight: appearanceSettings.fontWeight
    readonly property real iconScale: appearanceSettings.iconScale
    readonly property bool topGradient: appearanceSettings.topGradient

    property bool writing: false
    property bool suppressReload: false

    function snapshot() {
        return {
            version: adapter.version,
            clock: {
                use24Hour: clockSettings.use24Hour,
                showWeekNumbers: clockSettings.showWeekNumbers,
                weekStart: clockSettings.weekStart
            },
            bar: {
                targetMonitor: barSettings.targetMonitor,
                reserveSpace: barSettings.reserveSpace,
                showFocusedTitle: barSettings.showFocusedTitle,
                workspaceIds: barSettings.workspaceIds
            },
            appearance: {
                mode: appearanceSettings.mode,
                tint: appearanceSettings.tint,
                panelOpacity: appearanceSettings.panelOpacity,
                panelBlur: appearanceSettings.panelBlur,
                radius: appearanceSettings.radius,
                shadowOpacity: appearanceSettings.shadowOpacity,
                shadowSoftness: appearanceSettings.shadowSoftness,
                motionScale: appearanceSettings.motionScale,
                reducedMotion: appearanceSettings.reducedMotion,
                panelPadding: appearanceSettings.panelPadding,
                panelSpacing: appearanceSettings.panelSpacing,
                fontSize: appearanceSettings.fontSize,
                fontWeight: appearanceSettings.fontWeight,
                iconScale: appearanceSettings.iconScale,
                topGradient: appearanceSettings.topGradient
            }
        };
    }

    function setAppearanceMode(mode) {
        appearanceSettings.mode = mode === "light" ? "light" : "dark"
    }

    function setReducedMotion(value) {
        appearanceSettings.reducedMotion = value === true
    }

    function setTopGradient(value) {
        appearanceSettings.topGradient = value === true
    }

    function setShowWeekNumbers(value) {
        clockSettings.showWeekNumbers = value === true
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
                property bool showWeekNumbers: false
                property string weekStart: "locale"
            }

            property JsonObject bar: JsonObject {
                id: barSettings
                property string targetMonitor: "HDMI-A-1"
                property bool reserveSpace: false
                property bool showFocusedTitle: true
                property list<int> workspaceIds: [4, 5, 6]
            }

            property JsonObject appearance: JsonObject {
                id: appearanceSettings
                property string mode: "dark"
                property string tint: "neutral"
                property real panelOpacity: 0.92
                property real panelBlur: 1
                property int radius: 10
                property real shadowOpacity: 0.16
                property int shadowSoftness: 10
                property real motionScale: 1
                property bool reducedMotion: false
                property int panelPadding: 12
                property int panelSpacing: 8
                property int fontSize: 12
                property string fontWeight: "regular"
                property real iconScale: 1
                property bool topGradient: false
            }
        }
    }
}
