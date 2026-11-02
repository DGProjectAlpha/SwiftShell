pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
Singleton {
    id:root
    property bool available:false
    property string error:""
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
    property string action:""
    readonly property bool busy:worker.running
    signal completed(string action,bool success)
    function request(next,values) {
        if(worker.running) {if(next==="snapshot")refreshPending=true;return false}
        action=next;payload=Object.assign({action:next},values || {});error=""
        worker.running=true
        return true
    }
    function refresh() {request("snapshot",{})}
    function perform(next,values) {return request(next,values)}
    function startViewing() {viewers++;refresh()}
    function stopViewing() {viewers=Math.max(0,viewers-1)}
    Timer {id:changes;interval:220;onTriggered:root.refresh()}
    Process {
        id:worker
        objectName:"networkWorker"
        command:["python3",Quickshell.shellDir+"/helpers/networkctl.py"]
        stdinEnabled:true
        onStarted: {worker.write(JSON.stringify(root.payload)+"\n");root.payload={}}
        stdout:StdioCollector {id:reply;waitForEnd:true}
        onExited:function(code,status) {
            let success=false
            root.payload={}
            try {
                const result=JSON.parse(reply.text)
                if(code!==0 || !result.ok)throw new Error(result.message || "The network service is unavailable.")
                root.available=result.available;root.reason=result.reason || ""
                root.devices=result.devices || [];root.networks=result.networks || [];root.profiles=result.profiles || []
                root.wifiEnabled=result.wifiEnabled===true;root.wifiHardware=result.wifiHardware===true
                root.state=result.state || "";root.connectivity=result.connectivity || "";root.error="";success=true
            }catch(error){root.error=error.message;root.reason=error.message;root.available=false}
            root.completed(root.action,success)
            if(root.refreshPending) {root.refreshPending=false;Qt.callLater(root.refresh)}
        }
    }
    // NetworkManager's event stream drives refreshes only while a manager is open.
    // Event text can contain SSIDs and is deliberately neither forwarded nor saved.
    Process {
        id:events
        command:["nmcli","--colors","no","monitor"]
        running:root.viewers>0 && root.available
        stdout:SplitParser {onRead:function(data){changes.restart()}}
    }
}
