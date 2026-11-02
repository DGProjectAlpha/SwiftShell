pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
Singleton {
    id: root
    property var roles: []
    property bool available: false
    property string error: ""
    readonly property bool busy: bridge.running
    property var queue: []
    signal completed(string action, bool success)
    property string action: ""
    function request(next, role, desktopId, target) {
        const args=["python3",Quickshell.shellDir+"/helpers/defaultappsctl.py",next]
        if(role)args.push("--role",role)
        if(desktopId)args.push("--desktop-id",desktopId)
        if(target)args.push("--target",target)
        if(bridge.running) {queue=queue.concat([{action:next,args:args}]);return}
        action=next;error="";bridge.command=args;bridge.running=true
    }
    function refresh() { if(!busy)request("snapshot") }
    function choose(role,id) {request("choose",role,id)}
    function reset(role) {request("reset",role)}
    function launch(role,target) {request("launch",role,"",target || "")}
    function roleInfo(id) {return roles.find(function(role){return role.id===id}) || null}
    Component.onCompleted: refresh()
    Process {
        id:bridge
        stdout:StdioCollector {id:reply;waitForEnd:true}
        onExited:function(code,status) {
            let success=false
            try {
                const result=JSON.parse(reply.text)
                if(code!==0 || !result.ok)throw new Error(result.message || "Application preferences are unavailable.")
                if(result.roles) {root.roles=result.roles;root.available=result.available===true}
                root.error="";success=true
            } catch(failure) {root.error=failure.message}
            root.completed(root.action,success)
            if(root.queue.length) {
                const item=root.queue[0];root.queue=root.queue.slice(1)
                Qt.callLater(function(){root.action=item.action;bridge.command=item.args;bridge.running=true})
            }
        }
    }
}
