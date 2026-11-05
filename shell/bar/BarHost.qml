import QtQuick
import Quickshell
import "../logic/monitors.js" as Monitors
import "../services"

Scope {
    id: root

    function surfaceDiagnostics() {
        return bars.instances.map(function(w){return {output:w.monitorKey,edge:w.edge,contentScale:w.contentScale,rendering:w.renderingDiagnostics(),width:w.width,mode:w.barSurface.mode,color:w.barSurface.color,alpha:w.barSurface.alpha,blurApplied:w.surfaceBlurApplied,height:w.height,tray:w.trayItem && w.trayItem.geometry ? w.trayItem.geometry() : [],clock:w.clockItem ? w.clockItem.labelText : "",clockPrecision:w.clockItem ? w.clockItem.updatePrecision : -1,clockTargets:w.clockItem ? w.clockItem.clickTargets() : null,foreground:{left:w.foregroundFor("workspaces",false),center:w.foregroundFor("title",false),right:w.foregroundFor("clock",false)},contrastAvailable:w.outputAnalysis.available,layout:w.moduleLayout(),quickTools:w.quickToolTargets(),modules:{left:w.modulesOn("left"),center:w.modulesOn("center"),right:w.modulesOn("right")},menu:w.menuDiagnostics()}})
    }
    function showPanel(output,id) {
        const selected=bars.instances.find(function(w){return w.monitorKey===output})
        if(selected) selected.showPanel(id)
    }
    function closePanels() {for(const w of bars.instances)w.showPanel("close")}
    function showNotifications(output) {
        const selected=bars.instances.find(function(w){return w.monitorKey===output}) || bars.instances[0]
        if(selected)selected.openNotifications()
    }
    function showClockTool(output,tab) {
        const selected=bars.instances.find(function(w){return w.monitorKey===output}) || bars.instances[0]
        if(selected)selected.openClockTool(tab)
    }
    property bool refreshingScreens: false
    property var targetScreens: []
    property string announcedPlacement: ""

    function sameScreens(left, right) {
        const a = left || [];
        const b = right || [];
        if (a.length !== b.length)
            return false;
        for (let i = 0; i < a.length; i++) {
            if (a[i] !== b[i])
                return false;
        }
        return true;
    }

    function screenRecords() {
        const screens = Quickshell.screens;
        const count = screens ? screens.length : 0;
        const records = [];
        for (let i = 0; i < count; i++) {
            const screen = screens[i];
            records.push(Monitors.describeScreen(
                screen,
                HyprlandModel.hyprlandNameForScreen(screen),
                HyprlandModel.descriptionForScreen(screen)
            ));
        }
        return records;
    }

    function announce(placement) {
        const key = placement.mode + "\n" + (placement.label || "");
        if (key === root.announcedPlacement)
            return;
        root.announcedPlacement = key;
        if (placement.mode === "missing") {
            console.warn("SwiftShell: no screen is available for the bar");
            return;
        }
        if (placement.mode === "preference")
            console.info("SwiftShell: bar placed on preferred monitor", placement.label);
        else if (placement.mode === "focused")
            console.info("SwiftShell: bar placed on focused monitor", placement.label);
        else if (placement.mode === "all")
            console.info("SwiftShell: bars placed on all connected monitors");
        else if (placement.mode === "primary")
            console.info("SwiftShell: bar placed on primary screen", placement.label);
        else
            console.info("SwiftShell: bar placed on fallback monitor", placement.label);
    }

    function refreshTargetScreens() {
        if (root.refreshingScreens)
            return;
        root.refreshingScreens = true;
        const placement = Monitors.selectBarPlacement(
            root.screenRecords(),
            SettingsStore.targetMonitor,
            HyprlandModel.readFocusedOutput(),
            SettingsStore.barPlacement
        );
        const matched = placement.screens && placement.screens.length ? placement.screens : [];
        if (!root.sameScreens(root.targetScreens, matched))
            root.targetScreens = matched;
        root.refreshingScreens = false;
        root.announce(placement);
    }

    Component.onCompleted: refreshTargetScreens()

    Connections {
        target: Quickshell
        function onScreensChanged() { root.refreshTargetScreens(); }
    }

    Connections {
        target: HyprlandModel
        function onOutputRevisionChanged() { root.refreshTargetScreens(); }
    }

    Connections {
        target: SettingsStore
        function onTargetMonitorChanged() { root.refreshTargetScreens(); }
        function onBarPlacementChanged() { root.refreshTargetScreens(); }
    }

    Variants {
        id: bars
        model: root.targetScreens
        BarWindow {}
    }
}
