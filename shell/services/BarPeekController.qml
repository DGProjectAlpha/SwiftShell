import QtQuick
import Quickshell
import Quickshell.Io
import "../logic/bar.js" as Bar
Item {
    id:root
    required property var barWindow
    property bool requested:false
    property bool popupOpen:false
    property bool open:false
    property var cursor:null
    readonly property bool fullscreen:barWindow.outputFullscreen===true
    readonly property var pointer:Bar.peekPointer(cursor,barWindow.screen,barWindow.edge,barWindow.width,barWindow.height)
    readonly property bool watching:cursorWatch.running
    onRequestedChanged:if(!requested){open=false;cursor=null}
    onFullscreenChanged:if(!fullscreen){open=false;cursor=null}
    // No permanently mapped edge overlay. Sampling exists only for the opt-in
    // fullscreen output; crossing a monitor seam does not immediately reveal it.
    Timer {interval:180;running:root.requested && root.fullscreen && !root.open && root.pointer.atEdge;onTriggered:root.open=true}
    Timer {interval:400;running:root.open && !root.pointer.insideBar && !root.popupOpen;onTriggered:root.open=false}
    Process {
        id:cursorWatch
        objectName:"fullscreenCursorWatch"
        command:["python3",Quickshell.shellDir+"/helpers/cursorwatch.py"]
        running:root.requested && root.fullscreen
        stdout:SplitParser {onRead:function(data){try{root.cursor=JSON.parse(data)}catch(error){root.cursor=null}}}
        onExited:function(code,status){root.cursor=null;root.open=false}
    }
}
