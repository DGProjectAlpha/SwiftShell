pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
Singleton {
    id: root
    property real lastPositiveBlur:1
    property real previousBlur:1
    property int lastBorderWidth:2
    function preferredBlur() {return managed.size !== undefined ? Math.max(.01,(managed.size-1)/11) : lastPositiveBlur}
    onObservedChanged:if(observed.border>0)lastBorderWidth=observed.border
    property bool available: false
    property string error: ""
    property var observed: ({})
    property var managed: ({})
    property var pending: ({})
    property string requestedAction: ""
    property bool reloadPending:false
    property bool restorePending:false
    property string activeAction: ""
    readonly property bool busy: worker.running
    function request(action, patch) {
        if(action==="restore") {
            pending={};restorePending=true;requestedAction=reloadPending ? "reload" : "restore"
        } else if(action==="apply") {
            pending=Object.assign({},pending,patch || {});restorePending=false;requestedAction=reloadPending ? "reload" : "apply"
        } else if(action==="reload") {
            // Preserve unsent edits across compositor reload; apply after rebasing.
            reloadPending=true;requestedAction="reload"
        } else if(requestedAction!=="apply" && requestedAction!=="reload" && requestedAction!=="restore") {
            requestedAction=action
        }
        debounce.restart()
    }
    function launch() {
        if(worker.running) return
        if(!requestedAction) return
        activeAction=requestedAction;requestedAction=""
        if(activeAction==="reload")reloadPending=false
        if(activeAction==="restore")restorePending=false
        const payload=activeAction==="apply" ? pending : {}
        if(activeAction==="apply")pending={}
        worker.command=["python3",Quickshell.shellDir+"/helpers/appearancectl.py",activeAction,JSON.stringify(payload)]
        worker.running=true
    }
    function restore() { pending={};request("restore",{}) }
    Component.onCompleted:request("resume",{})
    Connections {
        target:SettingsStore
        function onRadiusChanged() { if(SettingsStore.acceptWrites)root.request("apply",{radius:SettingsStore.radius}) }
        function onPanelBlurChanged() {
            const previous=root.previousBlur,value=SettingsStore.panelBlur
            root.previousBlur=value
            if(value>0)root.lastPositiveBlur=value
            // Re-enabling an unmanaged compositor blur must preserve its profile.
            if(SettingsStore.acceptWrites && value>0 && (previous>0 || root.managed.size!==undefined))root.request("apply",{strength:value})
        }
    }
    Connections {
        target:Hyprland
        function onRawEvent(event) { if(event.name==="configreloaded")root.request("reload",{}) }
    }
    Timer { id:debounce;interval:180;onTriggered:root.launch() }
    Process {
        id:worker
        stdout:StdioCollector {id:reply;waitForEnd:true}
        onExited:function(code,status) {
            try {
                const result=JSON.parse(reply.text)
                if(code!==0 || !result.ok)throw new Error(result.message || "Desktop appearance is unavailable.")
                root.available=result.available;root.observed=result.observed;root.managed=result.managed;root.error=""
            } catch(error) {root.error=error.message;root.available=false}
            if(root.reloadPending)root.requestedAction="reload"
            else if(root.restorePending)root.requestedAction="restore"
            else if(Object.keys(root.pending).length)root.requestedAction="apply"
            if(root.requestedAction)Qt.callLater(root.launch)
        }
    }
}
