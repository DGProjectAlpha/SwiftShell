//@ pragma ShellId swiftshell-blur-test
import QtQuick
import Quickshell
ShellRoot {
    id:fixture
    readonly property int testWidth:Number(Quickshell.env("SWIFTSHELL_BLUR_WIDTH") || "1100")
    readonly property int testHeight:Number(Quickshell.env("SWIFTSHELL_BLUR_HEIGHT") || "800")
    FloatingWindow {
        title:"SwiftShell Blur Test Pattern"
        visible:true
        implicitWidth:fixture.testWidth;implicitHeight:fixture.testHeight
        minimumSize:Qt.size(fixture.testWidth,fixture.testHeight);maximumSize:Qt.size(fixture.testWidth,fixture.testHeight)
        color:"white"
        Grid {
            columns:55
            Repeater {model:55*40;Rectangle {required property int index;width:20;height:20;color:(Math.floor(index/55)+index%55)%2 ? "#eeeeee" : "#222222"}}
        }
        Text {x:120;y:260;text:"Gaussian blur test 0123456789";color:"black";font.pixelSize:30;font.bold:true}
    }
    Timer {interval:60000;running:true;onTriggered:Qt.quit()}
}
