pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id:root
    property var actions:({})
    property bool ready:false
    property string operation:""
    property string error:""
    property string notice:""
    readonly property bool busy:bridge.running && operation!=="snapshot"
    readonly property bool refreshing:bridge.running && operation==="snapshot"
    signal completed(string action,bool success)

    function available(id){return ready && !!actions[id] && actions[id].available===true}
    function reason(id){return !ready ? "Checking session controls…" : actions[id] ? actions[id].reason || "" : error || "This action is unavailable."}
    function refresh() {
        if(bridge.running)return false
        operation="snapshot";bridge.command=["python3",Quickshell.shellDir+"/helpers/sessionctl.py","snapshot"];bridge.running=true
        return true
    }
    function perform(id) {
        if(["lock","suspend","logout","reboot","poweroff"].indexOf(id)<0){error="Choose a supported session action.";return false}
        if(bridge.running){error=refreshing ? "Session controls are still being checked. Try again in a moment." : "Another session action is in progress.";return false}
        if(!available(id)){error=reason(id);return false}
        operation=id;error="";notice="Requesting session action…"
        bridge.command=["python3",Quickshell.shellDir+"/helpers/sessionctl.py",id];bridge.running=true
        return true
    }
    Component.onCompleted:refresh()
    Process {
        id:bridge
        objectName:"sessionActionBridge"
        stdout:StdioCollector {id:reply;objectName:"sessionActionReply";waitForEnd:true}
        onExited:function(code,status) {
            const action=root.operation
            let success=false
            try {
                let result=null
                try {result=JSON.parse(reply.text)}catch(parseError){}
                if(!result || typeof result!=="object")throw new Error("Session controls did not respond. Refresh and try again.")
                if(code!==0 || result.ok!==true)throw new Error(result.message || "The session action was refused.")
                if(action==="snapshot"){root.actions=result.actions || {};root.ready=true}
                root.error="";root.notice=result.message || "";success=true
            } catch(failure) {
                root.error=failure.message;root.notice=""
                if(action==="snapshot"){root.actions={};root.ready=true}
            }
            root.completed(action,success)
        }
    }
}
