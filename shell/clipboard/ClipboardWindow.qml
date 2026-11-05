import QtQuick
import Quickshell
import "../components"
import "../services"
import "../themes"
FloatingWindow {
    id:window
    title:"SwiftShell Clipboard"
    visible:ClipboardModel.windowOpen
    color:"transparent"
    implicitWidth:480;implicitHeight:600
    minimumSize:Qt.size(400,440)
    property int mapAttempts:0
    readonly property int inset:Theme.surfaceShadowInset
    readonly property bool blurApplied:blur.applied
    function beginResize(edges){if(maximized)maximized=false;return startSystemResize(edges)}
    onClosed:ClipboardModel.hideWindow()
    Component.onDestruction: {
        if(Quickshell.processId>0)Quickshell.execDetached(["python3",Quickshell.shellDir+"/helpers/clipboardwindow.py","cleanup","--owner-pid",String(Quickshell.processId)])
    }
    onVisibleChanged: {
        if(visible){mapAttempts=0;mapDelay.restart();Qt.callLater(panel.focusSearch)}
        else mapDelay.stop()
    }
    Timer {id:mapDelay;interval:120;onTriggered:{window.mapAttempts++;ClipboardModel.request("mapped")}}
    Connections {
        target:ClipboardModel
        function onWindowCompleted(action,success){if(action==="mapped" && !success && window.visible && window.mapAttempts<5)mapDelay.restart();if(action==="mapped" && success)panel.focusSearch()}
        function onWindowActivated(){panel.focusSearch()}
    }
    Loader {anchors.fill:surface;source:"../components/SurfaceShadow.qml";visible:Theme.shadowOpacity>0}
    BackdropEffect {id:blur;targetWindow:window;surface:surface;cornerRadius:Theme.radius;enabled:SettingsStore.panelBlur>0 && window.visible}
    Rectangle {
        id:surface;anchors.fill:parent;anchors.margins:window.inset
        radius:Theme.radius;color:Theme.floaterSurface
        Keys.onEscapePressed:ClipboardModel.hideWindow()
        Item {
            id:titlebar;width:parent.width;height:42
            MouseArea {anchors.fill:parent;anchors.rightMargin:42;onPressed:window.startSystemMove()}
            Text {anchors.left:parent.left;anchors.leftMargin:16;anchors.verticalCenter:parent.verticalCenter;text:"Clipboard";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize;font.weight:Font.Medium}
            FlatButton {objectName:"clipboardWindowClose";anchors.right:parent.right;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter;width:28;label:"×";Accessible.name:"Close clipboard window";onActivated:ClipboardModel.hideWindow()}
        }
        ClipboardPanel {
            id:panel;x:16;y:titlebar.height;width:Math.max(1,parent.width-32)
            detachedWindow:true
            maximumListHeight:Math.max(60,surface.height-titlebar.height-230)
            onDismissed:ClipboardModel.hideWindow()
        }
    }
    Repeater {
        model:[{edge:Qt.LeftEdge,x:window.inset-5,y:window.inset+8,w:8,h:window.height-window.inset*2-16,cursor:Qt.SizeHorCursor},{edge:Qt.RightEdge,x:window.width-window.inset-3,y:window.inset+8,w:8,h:window.height-window.inset*2-16,cursor:Qt.SizeHorCursor},{edge:Qt.TopEdge,x:window.inset+8,y:window.inset-5,w:window.width-window.inset*2-16,h:8,cursor:Qt.SizeVerCursor},{edge:Qt.BottomEdge,x:window.inset+8,y:window.height-window.inset-3,w:window.width-window.inset*2-16,h:8,cursor:Qt.SizeVerCursor},{edge:Qt.LeftEdge|Qt.TopEdge,x:window.inset-5,y:window.inset-5,w:13,h:13,cursor:Qt.SizeFDiagCursor},{edge:Qt.RightEdge|Qt.TopEdge,x:window.width-window.inset-8,y:window.inset-5,w:13,h:13,cursor:Qt.SizeBDiagCursor},{edge:Qt.LeftEdge|Qt.BottomEdge,x:window.inset-5,y:window.height-window.inset-8,w:13,h:13,cursor:Qt.SizeBDiagCursor},{edge:Qt.RightEdge|Qt.BottomEdge,x:window.width-window.inset-8,y:window.height-window.inset-8,w:13,h:13,cursor:Qt.SizeFDiagCursor}]
        delegate:MouseArea {required property var modelData;x:modelData.x;y:modelData.y;width:Math.max(1,modelData.w);height:Math.max(1,modelData.h);cursorShape:modelData.cursor;onPressed:window.beginResize(modelData.edge)}
    }
}
