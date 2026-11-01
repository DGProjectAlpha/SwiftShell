pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
Singleton {
    id: root
    property bool blurAvailable: false
    property string reason: "Checking backdrop blur…"
    function refresh() { if (!probe.running) probe.running=true }
    Component.onCompleted: refresh()
    Connections {
        target: Hyprland
        function onRawEvent(event) { if(event.name === "configreloaded") root.refresh() }
    }
    Process {
        id: probe
        command: ["python3",Quickshell.shellDir+"/helpers/windowctl.py","capabilities"]
        stdout: StdioCollector { id: reply; waitForEnd:true }
        onExited: function(code,status) {
            try {
                const result=JSON.parse(reply.text)
                root.blurAvailable=code===0 && result.ok && result.blurAvailable
                root.reason=result.blurReason || "Backdrop blur is unavailable."
            } catch(error) { root.blurAvailable=false;root.reason="Backdrop blur is unavailable." }
        }
    }
}
