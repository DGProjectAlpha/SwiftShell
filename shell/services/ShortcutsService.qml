pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
Singleton {
    id:root
    property var effective:[]
    property var actions:[]
    property var warnings:[]
    property bool available:false
    property bool canUndo:false
    property string error:""
    property string action:""
    property bool syncPending:false
    readonly property bool busy:bridge.running
    signal completed(string action,bool success)
    function request(next,id,modifiers,key) {
        if(bridge.running) {if(next==="sync")syncPending=true;return false}
        const args=["python3",Quickshell.shellDir+"/helpers/shortcutsctl.py",next]
        if(id)args.push("--id",id)
        if(modifiers)args.push("--modifiers",JSON.stringify(modifiers))
        if(key)args.push("--key",key)
        action=next;error="";bridge.command=args;bridge.running=true
        return true
    }
    function refresh() {request("snapshot")}
    function apply(id,modifiers,key) {request("apply",id,modifiers,key)}
    function remove(id) {request("remove",id)}
    function undo() {request("undo")}
    function synchronize() {request("sync")}
    Component.onCompleted: synchronize()
    Connections {
        target:Hyprland
        function onRawEvent(event) {if(event.name==="configreloaded")resync.restart()}
    }
    Timer {id:resync;interval:300;onTriggered:root.synchronize()}
    Process {
        id:bridge
        stdout:StdioCollector {id:reply;waitForEnd:true}
        onExited:function(code,status) {
            let success=false
            try {
                const result=JSON.parse(reply.text)
                if(code!==0 || !result.ok)throw new Error(result.message || "Desktop shortcuts are unavailable.")
                root.effective=result.effective || [];root.actions=result.actions || [];root.warnings=result.warnings || []
                root.available=result.available===true;root.canUndo=result.canUndo===true
                root.error="";success=true
            } catch(failure) {root.error=failure.message}
            root.completed(root.action,success)
            if(root.syncPending) {root.syncPending=false;Qt.callLater(root.synchronize)}
        }
    }
}
