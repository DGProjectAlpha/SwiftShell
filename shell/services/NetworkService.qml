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
    property string wifiScanMessage:""
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
    property var queuedRequest:null
    property var radioTarget:null
    property string action:""
    property bool cancelRequested:false
    property var cancelPayload:({})
    readonly property bool active:worker.running || cancellation.running
    readonly property bool busy:active || queuedRequest!==null || radioTarget!==null
    readonly property bool operationBusy:cancellation.running || worker.running && action!=="snapshot" || queuedRequest!==null || radioTarget!==null
    readonly property bool cancelling:cancelRequested && active
    readonly property bool wifiChanging:radioTarget!==null || worker.running && action==="wifi-radio"
    readonly property bool requestedWifiEnabled:radioTarget!==null ? radioTarget : worker.running && action==="wifi-radio" ? requestContext.enabled===true : wifiEnabled
    readonly property bool canCancel:!cancelRequested && (queuedRequest!==null && isConnection(queuedRequest.action) || worker.running && isConnection(action))
    readonly property string progressText: {
        if(cancelling)return "Cancelling connection…"
        if(radioTarget!==null && active)return radioTarget ? "Waiting to turn on Wi-Fi…" : "Waiting to turn off Wi-Fi…"
        if(queuedRequest!==null)return "Waiting for the current update…"
        if(!active)return notice
        return ({snapshot:"Updating connections…",scan:"Looking for nearby networks…","wifi-connect":"Connecting to Wi-Fi…","device-connect":"Connecting device…","device-disconnect":"Disconnecting device…","profile-connect":"Connecting saved profile…","wifi-radio":"Changing Wi-Fi…"})[action] || "Updating network…"
    }
    signal completed(string action,bool success)
    function isConnection(value) {return ["wifi-connect","device-connect","profile-connect"].indexOf(value)>=0}
    function context(next,fields) {return {action:next,device:fields.device || "",id:fields.id || "",enabled:fields.enabled===true}}
    function begin(next,fields) {
        action=next;requestContext=context(next,fields)
        payload=Object.assign({action:next},fields)
        cancelRequested=false
        if(next!=="snapshot") {error="";errorCode="";notice="";lastFailure={}}
        worker.running=true
        return true
    }
    function request(next,values) {
        const fields=values || {}
        if(next==="wifi-radio")return setWifiEnabled(fields.enabled)
        if(active || queuedRequest!==null || radioTarget!==null) {
            if(next==="snapshot") {refreshPending=true;return false}
            // A background read must not eat a deliberate user click or secret.
            // The bounded pending request remains only in memory until handoff.
            if(worker.running && action==="snapshot" && !cancellation.running && queuedRequest===null && radioTarget===null) {
                queuedRequest={action:next,values:fields};return true
            }
            return false
        }
        return begin(next,fields)
    }
    function setWifiEnabled(enabled) {
        if(typeof enabled!=="boolean")return false
        radioTarget=enabled
        if(!enabled && queuedRequest!==null) {
            const pending=queuedRequest,fields=pending.values || {}
            const device=devices.find(function(item){return item.id===fields.device})
            const profile=profiles.find(function(item){return item.id===fields.id})
            if(pending.action==="wifi-connect" || device && device.kind==="wifi" || profile && profile.kind==="wifi") {
                queuedRequest=null;notice="Wi-Fi connection request cancelled."
            }
        }
        if(!enabled && worker.running && isConnection(action)) {
            const device=devices.find(function(item){return item.id===requestContext.device})
            const profile=profiles.find(function(item){return item.id===requestContext.id})
            if(action==="wifi-connect" || device && device.kind==="wifi" || profile && profile.kind==="wifi")cancel()
        }
        Qt.callLater(root.drain)
        return true
    }
    function refresh() {request("snapshot",{})}
    function perform(next,values) {return request(next,values)}
    function clearError(){error="";errorCode="";lastFailure={}}
    function cancel() {
        if(queuedRequest!==null && isConnection(queuedRequest.action)) {
            queuedRequest=null;notice="Connection request cancelled.";return true
        }
        if(!canCancel || !worker.running)return false
        cancelRequested=true
        cancelPayload={action:"cancel-connect",device:requestContext.device,id:requestContext.id}
        cancellation.running=true
        return true
    }
    function applySnapshot(result) {
        root.available=result.available===true;root.reason=result.reason || ""
        const devices=result.devices || [],networks=result.networks || [],profiles=result.profiles || []
        if(JSON.stringify(root.devices)!==JSON.stringify(devices))root.devices=devices
        if(JSON.stringify(root.networks)!==JSON.stringify(networks))root.networks=networks
        if(JSON.stringify(root.profiles)!==JSON.stringify(profiles))root.profiles=profiles
        root.wifiEnabled=result.wifiEnabled===true;root.wifiHardware=result.wifiHardware===true
        root.wifiScanMessage=result.wifiScanMessage || ""
        root.state=result.state || "";root.connectivity=result.connectivity || ""
    }
    function finishPending() {
        if(active)return
        if(cancelRequested)refreshPending=true
        root.cancelRequested=false;root.requestContext={}
        Qt.callLater(root.drain)
    }
    function drain() {
        if(active)return
        if(radioTarget!==null) {
            const enabled=radioTarget;radioTarget=null
            // Explicit intent is confirmed even when a previous failed readback
            // left the cached flag equal to it. Radio writes are idempotent.
            begin("wifi-radio",{enabled:enabled});return
        }
        if(queuedRequest!==null) {
            const next=queuedRequest;queuedRequest=null
            begin(next.action,next.values);return
        }
        if(refreshPending) {refreshPending=false;begin("snapshot",{})}
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
