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
    property var queue: []
    readonly property bool busy: bridge.running
    signal completed(string action, bool success)
    function request(next) {
        if (bridge.running) { queue = queue.concat([next]); return }
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
        function onPanelBlurChanged() { if(root.active)root.request(root.blurAvailable && SettingsStore.panelBlur>0 ? "blur-on" : "blur-off") }
    }
    Process {
        id: bridge
        stdout: StdioCollector { id: reply; waitForEnd:true }
        onExited: function(code,status) {
            let success=false
            try {
                const result=JSON.parse(reply.text)
                if (code!==0 || !result.ok) throw new Error(result.message || "Window action failed.")
                if (root.action==="prepare") { root.available=true;root.reasonUnavailable="";root.blurAvailable=result.blurAvailable; root.blurReason=result.blurReason }
                root.geometry=result.geometry || {}
                if(result.window) root.maximized=result.window.fullscreen === 1
                root.error="";success=true
            } catch(failure) { root.error=failure.message;if(root.action==="prepare"){root.available=false;root.reasonUnavailable=failure.message} }
            if (success && root.action === "mapped") root.queue=root.queue.concat([root.blurAvailable && SettingsStore.panelBlur>0 ? "blur-on" : "blur-off"])
            root.completed(root.action,success)
            if (root.queue.length) {
                const next=root.queue[0];root.queue=root.queue.slice(1)
                Qt.callLater(function(){root.request(next)})
            }
        }
    }
}
