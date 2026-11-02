//@ pragma ShellId swiftshell-network-devices-audit
import QtQuick
import Quickshell
import "services" as Services
ShellRoot {
    id:audit
    property bool finished:false
    Component.onCompleted:Services.NetworkService.startViewing()
    Connections {
        target:Services.NetworkService
        function onCompleted(action,success) {
            if(audit.finished || !success)return
            if(!Services.NetworkService.available || !Services.NetworkService.devices.length) {
                console.warn("Network native audit: service or hardware unavailable")
                Qt.quit();return
            }
            if(Services.NetworkService.viewers!==1) {
                console.warn("Network native audit: invalid manager ownership")
                Qt.quit();return
            }
            audit.finished=true
            Services.NetworkService.stopViewing()
            finish.start()
        }
    }
    Timer {
        id:finish;interval:250
        onTriggered: {
            if(Services.NetworkService.viewers===0)
                console.info("Network native audit: read-only snapshot and manager ownership passed")
            Qt.quit()
        }
    }
    Timer {interval:7000;running:true;onTriggered:{console.warn("Network native audit: timed out");Qt.quit()}}
}
