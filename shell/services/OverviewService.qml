pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../logic/overview.js" as Overview
import "../logic/workspaces.js" as Workspaces
Singleton {
    id:root
    property bool open:false
    property var screen:null
    property int selected:0
    readonly property bool shortcutBusy:shortcut.running
    property bool shortcutSyncPending:false
    property bool shortcutActive:false
    property bool shortcutEnabled:false
    property bool shortcutCanEnable:false
    property string shortcutError:""
    property string shortcutAction:""
    function shortcutRequest(action) {
        if(shortcut.running){if(action==="sync")shortcutSyncPending=true;return false;}
        shortcutAction=action;shortcutError="";
        shortcut.command=["python3",Quickshell.shellDir+"/helpers/overviewctl.py",action];
        shortcut.running=true;return true;
    }
    function enableShortcut(){return shortcutRequest("enable");}
    function restoreShortcut(){return shortcutRequest("restore");}
    Component.onCompleted:shortcutRequest("sync")
    Process {
        id:shortcut
        stdout:StdioCollector {id:shortcutReply;waitForEnd:true}
        onExited:function(code,status) {
            try {
                const result=JSON.parse(shortcutReply.text);
                if(code!==0 || !result.ok)throw new Error(result.message || "Overview shortcut is unavailable.");
                root.shortcutActive=result.active===true;root.shortcutEnabled=result.enabled===true;
                root.shortcutCanEnable=result.canEnable===true;root.shortcutError="";
            } catch(error){root.shortcutError=error.message;}
            if(root.shortcutSyncPending){root.shortcutSyncPending=false;Qt.callLater(function(){root.shortcutRequest("sync");});}
        }
    }
    readonly property var monitor:HyprlandModel.monitorSnapshot.find(function(m){return root.screen && m.name===root.screen.name}) || null
    readonly property var workspaces: {
        if(!monitor)return [];
        const configured=Workspaces.perMonitorItems(SettingsStore.workspaceOutputsJson,SettingsStore.workspaceIds,SettingsStore.targetMonitor,HyprlandModel.liveWorkspaces,monitor.name);
        // Explicit bar filtering must not make live occupied desktops inaccessible.
        const result=configured.slice();
        for(const item of HyprlandModel.liveWorkspaces)
            if(item.monitorName===monitor.name && !result.some(function(row){return row.key===item.key}))result.push(item);
        return result;
    }
    readonly property var windows: {
        const out=[];
        for(const top of Hyprland.toplevels.values) {
            const data=top.lastIpcObject || {};
            const key=Overview.workspaceKey(data);
            if(!key || data.mapped===false || data.hidden===true)continue;
            out.push({address:top.address,workspace:key,geometry:data,handle:top.wayland || null,title:top.title || "Window",active:top.activated===true});
        }
        return out;
    }
    signal opened()
    function openOverview() {
        const focused=Hyprland.focusedMonitor || HyprlandModel.focusedOutput;
        screen=Quickshell.screens.find(function(s){return focused && s.name===focused.name}) || Quickshell.screens[0] || null;
        if(!screen)return false;
        HyprlandModel.refresh();
        selected=Math.max(0,workspaces.findIndex(function(w){return w.active}));
        open=true;opened();return true;
    }
    function closeOverview(){open=false;screen=null;}
    function shortcut(){if(!open)openOverview();else selected=(selected+1)%Math.max(1,workspaces.length)}
    function toggle(){if(open)closeOverview();else openOverview();}
    function chooseWorkspace(index) {
        const ws=workspaces[index];
        if(!ws || !monitor)return;
        HyprlandModel.activateWorkspace(ws.key,SettingsStore.workspaceDispatch,monitor.name);
        closeOverview();
    }
    function chooseWindow(window) {
        if(!window)return;
        closeOverview();
        if(window.handle)window.handle.activate();
        else HyprlandModel.activateWindow(window.address);
    }
    Timer {interval:120;running:root.open;repeat:false;onTriggered:root.selected=Math.max(0,root.workspaces.findIndex(function(w){return w.active}))}
    Timer {id:refresh;interval:80;onTriggered:Hyprland.refreshToplevels()}
    Connections {
        target:Hyprland
        function onRawEvent(event) {
            if(event.name==="configreloaded")root.shortcutRequest("sync");
            if(root.open && /^(openwindow|closewindow|movewindow|activewindow|workspace|focusedmon|monitor|changefloatingmode|resize|move)/.test(event.name))refresh.restart();
        }
    }
    Connections {
        target:Quickshell
        function onScreensChanged(){if(root.open && (!root.screen || Quickshell.screens.indexOf(root.screen)<0))root.closeOverview();}
    }
}
