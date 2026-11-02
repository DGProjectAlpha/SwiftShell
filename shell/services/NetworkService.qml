pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
Singleton {
    id:root
    property bool available:false
    property string error:""
    property string errorCode:""
    property string notice:""
    property string reason:"Checking network devices…"
    property var devices:[]
    property var networks:[]
    property var profiles:[]
    property bool wifiEnabled:false
    property bool wifiHardware:false
    property string state:""
    property string connectivity:""
    property int viewers:0
    property bool refreshPending:false
    property var payload:({})
    property var requestContext:({})
    property var lastFailure:({})
    property string action:""
    property bool cancelRequested:false
    property var cancelPayload:({})
    readonly property bool busy:worker.running || cancellation.running
    readonly property bool operationBusy:worker.running && action!=="snapshot"
    readonly property bool cancelling:cancelRequested && busy
    readonly property bool canCancel:worker.running && !cancelRequested && ["wifi-connect","device-connect","profile-connect"].indexOf(action)>=0
    readonly property string progressText: {
        if(cancelling)return "Cancelling connection…"
        if(!busy)return notice
        return ({snapshot:"Updating connections…",scan:"Looking for nearby networks…","wifi-connect":"Connecting to Wi-Fi…","device-connect":"Connecting device…","device-disconnect":"Disconnecting device…","profile-connect":"Connecting saved profile…","wifi-radio":"Changing Wi-Fi…"})[action] || "Updating network…"
    }
    signal completed(string action,bool success)
    function request(next,values) {
        if(busy) {if(next==="snapshot")refreshPending=true;return false}
        action=next
        const fields=values || {}
        // Never retain credentials in retry/cancel context or progress state.
        requestContext={action:next,device:fields.device || "",id:fields.id || ""}
        payload=Object.assign({action:next},fields)
        cancelRequested=false
        if(next!=="snapshot") {error="";errorCode="";notice="";lastFailure={}}
        worker.running=true
        return true
    }
    function refresh() {request("snapshot",{})}
    function perform(next,values) {return request(next,values)}
    function clearError(){error="";errorCode="";lastFailure={}}
    function cancel() {
        if(!canCancel)return false
        cancelRequested=true
        cancelPayload={action:"cancel-connect",device:requestContext.device,id:requestContext.id}
        cancellation.running=true
        return true
    }
    function applySnapshot(result) {
        root.available=result.available===true;root.reason=result.reason || ""
        root.devices=result.devices || [];root.networks=result.networks || [];root.profiles=result.profiles || []
        root.wifiEnabled=result.wifiEnabled===true;root.wifiHardware=result.wifiHardware===true
        root.state=result.state || "";root.connectivity=result.connectivity || ""
    }
    function finishPending() {
        if(busy)return
        root.cancelRequested=false;root.requestContext={}
        if(root.refreshPending) {root.refreshPending=false;Qt.callLater(root.refresh)}
    }
    function startViewing() {viewers++;refresh()}
    function stopViewing() {viewers=Math.max(0,viewers-1)}
    Timer {id:changes;interval:220;onTriggered:root.refresh()}
    Process {
        id:worker
        objectName:"networkWorker"
        command:["python3",Quickshell.shellDir+"/helpers/networkctl.py"]
        stdinEnabled:true
        onStarted: {worker.write(JSON.stringify(root.payload)+"\n");root.payload={}}
        stdout:StdioCollector {id:reply;objectName:"networkReply";waitForEnd:true}
        onExited:function(code,status) {
            let success=false
            root.payload={}
            try {
                const result=JSON.parse(reply.text)
                if(code!==0 || !result.ok) {
                    if(!root.cancelRequested) {
                        root.error=result.message || "The network change did not finish. Try again."
                        root.errorCode=result.code || "operation-failed"
                        root.lastFailure=root.action!=="snapshot" ? Object.assign({},root.requestContext) : {}
                    }
                    if(root.action==="snapshot") {root.available=false;root.reason=root.error}
                } else {
                    root.applySnapshot(result)
                    if(root.action!=="snapshot") {root.error="";root.errorCode="";root.lastFailure={}}
                    success=true
                }
            } catch(error) {
                if(!root.cancelRequested)root.error="The network service did not return a usable result. Try again."
                if(root.action==="snapshot") {root.available=false;root.reason=root.error}
            }
            root.completed(root.action,success)
            root.finishPending()
        }
    }
    Process {
        id:cancellation
        objectName:"networkCancellation"
        command:["python3",Quickshell.shellDir+"/helpers/networkctl.py"]
        stdinEnabled:true
        onStarted:{cancellation.write(JSON.stringify(root.cancelPayload)+"\n");root.cancelPayload={}}
        stdout:StdioCollector {id:cancelReply;objectName:"networkCancelReply";waitForEnd:true}
        onExited:function(code,status) {
            root.cancelPayload={}
            try {
                const result=JSON.parse(cancelReply.text)
                if(code!==0 || !result.ok)throw new Error(result.message || "Cancellation could not be confirmed. Check the connection status.")
                root.applySnapshot(result);root.notice=result.message || "Connection status updated."
                root.error="";root.errorCode=""
            }catch(error){root.error=error.message;root.errorCode="cancel-unconfirmed";root.cancelRequested=false}
            root.finishPending()
        }
    }
    // Event text may contain connection names. It is neither forwarded nor saved.
    Process {
        id:events
        command:["nmcli","--colors","no","monitor"]
        running:root.viewers>0 && root.available
        stdout:SplitParser {onRead:function(data){changes.restart()}}
    }
}
