//@ pragma ShellId swiftshell-tray-native-audit
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "bar" as Bar
ShellRoot {
    PanelWindow {
        id:window
        visible:false
        implicitWidth:600;implicitHeight:40
        Bar.TrayModule {id:tray;hostWindow:window}
    }
    Timer {
        interval:100;repeat:true;running:true
        onTriggered: {
            const expected=Number(Quickshell.env("SWIFTSHELL_TRAY_COUNT"))
            const actual=SystemTray.items.values
            if(actual.length!==expected || tray.itemCount!==expected)return
            const geometry=tray.geometry()
            if(geometry.length!==actual.length) {console.warn("Native tray audit: FAILED geometry count");Qt.quit();return}
            for(let index=0;index<actual.length;index++) {
                if(geometry[index].id!==actual[index].id) {console.warn("Native tray audit: FAILED native object order");Qt.quit();return}
            }
            console.info("Native tray audit: all registered native objects rendered",expected)
            Qt.quit()
        }
    }
    Timer {interval:5000;running:true;onTriggered:{console.warn("Native tray audit: FAILED timeout");Qt.quit()}}
}
