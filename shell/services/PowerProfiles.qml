pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
Singleton {
    id:root
    property bool available:false
    property string active:""
    property var profiles:[]
    property string inhibited:""
    property string degraded:""
    property int holds:0
    property string error:""
    property string previousProfile:""
    property string action:""
    property string beforeChange:""
    property bool refreshPending:false
    property int viewers:0
    property bool watching:true
    readonly property bool busy:bridge.running
    readonly property bool canUndo:previousProfile!=="" && previousProfile!==active && profiles.some(function(profile){return profile.id===root.previousProfile && profile.enabled})
    function refresh() {watching=true;request("snapshot","")}
    function choose(profile) {
        if(!profiles.some(function(candidate){return candidate.id===profile && candidate.enabled}))return false
        return request("set",profile)
    }
    function undo() {if(canUndo)choose(previousProfile)}
    function reason(code) {
        if(code==="lap-detected")return "Performance is limited while the computer rests on your lap."
        if(code==="high-operating-temperature")return "Performance is limited while the computer cools down."
        return code ? "Performance is temporarily limited by your hardware." : ""
    }
    function request(next,profile) {
        if(bridge.running) {if(next==="snapshot")refreshPending=true;return false}
        action=next;beforeChange=active;error=""
        bridge.command=["python3",Quickshell.shellDir+"/helpers/powerprofilesctl.py",next]
        if(profile)bridge.command=bridge.command.concat([profile])
        bridge.running=true
        return true
    }
    Component.onCompleted:refresh()
    Timer {id:refreshDelay;interval:100;repeat:false;onTriggered:root.refresh()}
    Process {
        id:bridge
        objectName:"powerProfileBridge"
        stdout:StdioCollector {id:reply;waitForEnd:true}
        onExited:function(code,status) {
            try {
                const result=JSON.parse(reply.text)
                root.available=result.available===true
                if(result.profiles && JSON.stringify(result.profiles)!==JSON.stringify(root.profiles))root.profiles=result.profiles
                if(result.active)root.active=result.active
                root.inhibited=result.inhibited || "";root.degraded=result.degraded || "";root.holds=result.holds || 0
                if(code!==0 || !result.ok)throw new Error(result.message || "System power profiles are unavailable.")
                if(root.action==="set" && root.beforeChange!==root.active)root.previousProfile=root.beforeChange
                root.error=""
            } catch(error) {root.error=error.message;root.available=false}
            if(root.refreshPending) {root.refreshPending=false;Qt.callLater(root.refresh)}
        }
    }
    Process {
        id:monitor
        // Profile-mode output contains signal headers only, never property bodies.
        command:["dbus-monitor","--system","--profile",
            "type='signal',sender='org.freedesktop.UPower.PowerProfiles',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='/org/freedesktop/UPower/PowerProfiles'",
            "type='signal',sender='net.hadess.PowerProfiles',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='/net/hadess/PowerProfiles'"]
        running:root.viewers>0 && root.available && root.watching
        stdout:SplitParser {
            onRead:function(data) {if(data.indexOf("PropertiesChanged")>=0)refreshDelay.restart()}
        }
        onExited:function(code,status) {if(root.viewers>0 && code!==0)root.watching=false}
    }
}
