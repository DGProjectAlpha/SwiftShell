import QtQuick
import "../themes"
FocusScope {
    id:control
    property real value:0
    property real draft:0
    property bool dragging:false
    property string valueDescription:""
    signal seekStarted()
    signal seekCommitted(real fraction)
    signal seekCancelled()
    readonly property real shownValue:dragging ? draft : Math.max(0,Math.min(1,value))
    implicitWidth:240;implicitHeight:26
    activeFocusOnTab:true
    Accessible.role:Accessible.Slider
    Accessible.name:"Playback position "+valueDescription
    opacity:enabled ? 1 : .45
    function point(x){return Math.max(0,Math.min(1,x/Math.max(1,width)))}
    function nudge(delta) {
        if(!enabled)return
        seekStarted()
        seekCommitted(Math.max(0,Math.min(1,value+delta)))
    }
    Keys.onLeftPressed:nudge(-.025)
    Keys.onRightPressed:nudge(.025)
    Keys.onDownPressed:nudge(-.025)
    Keys.onUpPressed:nudge(.025)
    Keys.onPressed:function(event){if(enabled && (event.key===Qt.Key_Home || event.key===Qt.Key_End)){seekStarted();seekCommitted(event.key===Qt.Key_Home ? 0 : 1);event.accepted=true}}
    Keys.onEscapePressed:{if(dragging){dragging=false;seekCancelled()}}
    Rectangle {anchors.left:parent.left;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;height:3;radius:1.5;color:Theme.settingsSelected}
    Rectangle {anchors.left:parent.left;anchors.verticalCenter:parent.verticalCenter;width:control.shownValue*parent.width;height:3;radius:1.5;color:Theme.settingsText}
    Rectangle {x:Math.max(0,control.shownValue*(parent.width-width));anchors.verticalCenter:parent.verticalCenter;width:8;height:8;radius:4;color:Theme.settingsText;visible:control.enabled && (pointer.containsMouse || control.dragging || control.activeFocus)}
    MouseArea {
        id:pointer;anchors.fill:parent;hoverEnabled:true;cursorShape:enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed:function(mouse){control.forceActiveFocus();control.seekStarted();control.draft=control.point(mouse.x);control.dragging=true}
        onPositionChanged:function(mouse){if(pressed && control.dragging)control.draft=control.point(mouse.x)}
        onReleased:function(mouse){if(control.dragging){control.draft=control.point(mouse.x);control.seekCommitted(control.draft);control.dragging=false}}
        onCanceled:{if(control.dragging){control.dragging=false;control.seekCancelled()}}
    }
}
