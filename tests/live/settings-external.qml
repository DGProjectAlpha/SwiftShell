//@ pragma ShellId swiftshell-external-settings-audit
import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services
ShellRoot {
    id:audit
    property int stage:0
    property int ticks:0
    readonly property string scenario:Quickshell.env("SWIFTSHELL_EXTERNAL_CASE")
    function failed(message) {console.warn("External settings audit: FAILED",message);Qt.quit()}
    Process {
        id:editor
        command:["python3",Quickshell.shellDir+"/external-editor.py",audit.scenario]
        onExited:function(code,status) {
            if(code!==0) {audit.failed("owned editor failed");return}
            audit.stage=3;audit.ticks=0
        }
    }
    Timer {
        interval:40;running:true;repeat:true
        onTriggered: {
            const store=Services.SettingsStore
            audit.ticks++
            if(audit.stage===0 && store.persistenceState==="ready") {
                store.setUse24Hour(false)
                store.setPinnedIds(["owned-first.desktop","owned-second.desktop"])
                audit.stage=1
            } else if(audit.stage===1 && store.persistenceState==="ready") {
                audit.stage=2;editor.running=true
            } else if(audit.stage===3 && audit.scenario==="canonical" && store.use24Hour && store.persistenceState==="ready") {
                // FileView skips identical bytes without a saved signal. This
                // must remain ready after accepting a real external edit.
                store.writeLatest();audit.stage=4;audit.ticks=0
            } else if(audit.stage===4 && store.persistenceState==="ready") {
                store.setUse24Hour(false);audit.stage=5
            } else if(audit.stage===5 && store.persistenceState==="ready") {
                console.info("External settings audit: canonical readback and subsequent save passed");Qt.quit()
            } else if(audit.stage===3 && audit.scenario!=="canonical" && store.persistenceState==="protected") {
                if(store.use24Hour!==false || store.version!==3 || store.pinnedIds.join(",")!=="owned-first.desktop,owned-second.desktop") {
                    audit.failed("unvalidated external content changed live preferences");return
                }
                store.writeLatest();audit.stage=6;audit.ticks=0
            } else if(audit.stage===6 && audit.ticks>=5) {
                if(store.persistenceState!=="protected") {audit.failed("protected file became writable");return}
                console.info("External settings audit: protected content retained live preferences");Qt.quit()
            }
        }
    }
    Timer {interval:6000;running:true;onTriggered:audit.failed("timed out at stage "+audit.stage+" in "+Services.SettingsStore.persistenceState)}
}
