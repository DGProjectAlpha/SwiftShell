pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
Singleton {
    id: root
    property bool available: false
    property string reasonUnavailable: ""
    property bool active: false
    property bool maximized: false
    property bool blurRegionApplied: false
    property bool blurAvailable: false
    property string blurReason: "Backdrop blur is unavailable."
    property string error: ""
    property var geometry: ({})
    property string action: ""
    property int lastBlurEnabled: -1
    property var queue: []
    readonly property bool busy: bridge.running
    signal completed(string action, bool success)
    function isBlur(action) { return action==="blur-on" || action==="blur-off" }
    function request(next) {
        const blur=isBlur(next),wanted=next==="blur-on" ? 1 : 0
        if (bridge.running) {
            if(blur) {
                // On/off requests are mutually exclusive: retain only the latest.
                queue=queue.filter(function(item){return !root.isBlur(item)})
                if(action!==next && (isBlur(action) || lastBlurEnabled!==wanted))queue=queue.concat([next])
            } else if(queue.indexOf(next)<0)queue=queue.concat([next])
            return
        }
        if(blur && lastBlurEnabled===wanted)return
        action=next
        bridge.command=["python3",Quickshell.shellDir+"/helpers/windowctl.py",next]
        bridge.running=true
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) { if(root.active && /^fullscreen/.test(event.name))root.request("status") }
    }
    Connections {
        target: SettingsStore
        function onPanelBlurChanged() {
            if(root.active)root.request(root.blurAvailable && SettingsStore.panelBlur>0 ? "blur-on" : "blur-off")
        }
    }
    Process {
        id: bridge
        objectName:"settingsWindowBridge"
        stdout: StdioCollector { id: reply;objectName:"settingsWindowReply";waitForEnd:true }
        onExited: function(code,status) {
            let success=false
            try {
                const result=JSON.parse(reply.text)
                if (code!==0 || !result.ok) throw new Error(result.message || "Window action failed.")
                if (root.action==="prepare") { root.available=true;root.reasonUnavailable="";root.blurAvailable=result.blurAvailable; root.blurReason=result.blurReason }
                const geometry=result.geometry || {}
                if(JSON.stringify(geometry)!==JSON.stringify(root.geometry))root.geometry=geometry
                if(result.window) root.maximized=result.window.fullscreen === 1
                root.error="";success=true
            } catch(failure) { root.error=failure.message;if(root.action==="prepare"){root.available=false;root.reasonUnavailable=failure.message} }
            if(root.isBlur(root.action))root.lastBlurEnabled=success ? (root.action==="blur-on" ? 1 : 0) : -1
            if (success && root.action === "mapped") {
                root.lastBlurEnabled=-1
                root.queue=root.queue.filter(function(item){return !root.isBlur(item)}).concat([root.blurAvailable && SettingsStore.panelBlur>0 ? "blur-on" : "blur-off"])
            }
            root.completed(root.action,success)
            if (root.queue.length) {
                const next=root.queue[0];root.queue=root.queue.slice(1)
                Qt.callLater(function(){root.request(next)})
            }
        }
    }
}
