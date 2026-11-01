//@ pragma ShellId swiftshell-bar-pattern
import QtQuick
import Quickshell
ShellRoot {
    FloatingWindow {
        title:"SwiftShell Bar Test Pattern"
        visible:true
        implicitWidth:400;implicitHeight:180
        minimumSize:Qt.size(400,180);maximumSize:Qt.size(400,180)
        color:"white"
        Grid {
            columns:50
            Repeater {model:50*23;Rectangle {required property int index;width:8;height:8;color:(Math.floor(index/50)+index%50)%2 ? "#eeeeee" : "#222222"}}
        }
    }
    Timer {interval:60000;running:true;onTriggered:Qt.quit()}
}
