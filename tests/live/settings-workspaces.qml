//@ pragma ShellId swiftshell-settings-audit
import QtQuick
import Quickshell
import "services" as Services
import "settings" as Settings

// The runner copies this into an isolated shell tree and supplies temporary XDG dirs.
ShellRoot {
    id: audit
    property bool written: false
    readonly property string expected: '{"DP-1":["1","2","3","gaming"],"HDMI-A-1":null}'
    Settings.SettingsWindow { visible: false }
    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (Services.SettingsStore.persistenceState !== "ready") return;
            if (Quickshell.env("SWIFTSHELL_AUDIT_READBACK") === "1") {
                if (Services.SettingsStore.workspaceOutputsJson === audit.expected
                    && Services.SettingsStore.settingsWindowCategory === "workspaces"
                    && Services.SettingsStore.barSurfaceMode === "solid"
                    && Services.SettingsStore.barSurfaceColor === "#dedede"
                    && Services.SettingsStore.clockSeconds && Services.SettingsStore.clockDate
                    && Services.SettingsStore.clockDateFormat === "iso" && !Services.SettingsStore.use24Hour
                    && Services.SettingsStore.searchLabel
                    && JSON.parse(Services.SettingsStore.moduleSidesJson).clock === "center"
                    && JSON.parse(Services.SettingsStore.hiddenOutputsJson)["DP-1"][0] === "tray"
                    && JSON.parse(Services.SettingsStore.barSurfaceOutputsJson)["DP-1"].mode === "frosted")
                    console.info("Workspace settings audit: restart readback passed");
                else console.warn("Workspace settings audit: restart readback FAILED");
                Qt.quit();
            } else if (!audit.written) {
                audit.written = true;
                // Multiple synchronous edits reproduced a stale JsonAdapter cache write.
                Services.SettingsStore.setSettingsCategory("workspaces");
                Services.SettingsStore.setClockOptions(true,true,"iso");
                Services.SettingsStore.setUse24Hour(false);
                Services.SettingsStore.setSearchLabel(true);
                Services.SettingsStore.setModuleSide("clock","center");
                Services.SettingsStore.setHiddenForOutput("DP-1",["tray"]);
                Services.SettingsStore.setBarSurface("", "solid", "#dedede", .8);
                Services.SettingsStore.setBarSurface("DP-1", "frosted", "#222222", .4);
                Services.SettingsStore.setWorkspaceOutput("DP-1", ["1", "2", "3", "gaming"]);
                Services.SettingsStore.setWorkspaceOutput("HDMI-A-1", null);
            } else {
                console.info("Workspace settings audit: save completed");
                Qt.quit();
            }
        }
    }
    Timer {
        interval: 6000
        running: true
        onTriggered: { console.warn("Workspace settings audit: timed out"); Qt.quit(); }
    }
}
