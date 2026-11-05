import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../popovers"
import "../services"
import "../themes"

PanelWindow {
    id:window
    required property var controller
    readonly property var hostWindow:controller.hostWindow
    readonly property Item anchorItem:controller.anchorItem
    property point placement:Qt.point(0,0)
    property bool ready:false
    property bool slowLoading:false
    readonly property Item captureItem:surface
    visible:controller.opened && ready
    screen:hostWindow ? hostWindow.screen : null
    color:"transparent"
    surfaceFormat.opaque:false
    exclusionMode:ExclusionMode.Ignore
    anchors {top:true;left:true}
    margins.left:Math.round(placement.x)
    margins.top:Math.round(placement.y)
    implicitWidth:Math.ceil(surface.implicitWidth)
    implicitHeight:Math.ceil(surface.implicitHeight)
    WlrLayershell.namespace:"swiftshell-tray-menu"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask:Region {item:surface.blurSurface;radius:Theme.radius}
    function reposition() {
        if(!screen || !hostWindow || !anchorItem)return;
        const point=anchorItem.mapToItem(hostWindow.contentItem,0,0);
        const edge=hostWindow.edge || "";
        let originX=hostWindow.margins ? hostWindow.margins.left : 0,originY=hostWindow.margins ? hostWindow.margins.top : 0;
        if(edge==="bottom")originY=screen.height-hostWindow.height-(hostWindow.margins ? hostWindow.margins.bottom : 0);
        else if(edge==="right")originX=screen.width-hostWindow.width-(hostWindow.margins ? hostWindow.margins.right : 0);
        else if(!edge) {
            // Qt does not promise global Wayland toplevel coordinates. Read only
            // this process/title from the already-published Hyprland model.
            const values=Hyprland.toplevels.values;
            for(let index=0;index<values.length;index++) {
                const record=values[index].lastIpcObject;
                if(record && record.pid===Quickshell.processId && record.title===hostWindow.title && record.at) {
                    originX=record.at[0]-screen.x;originY=record.at[1]-screen.y;break;
                }
            }
        }
        const inset=surface.shadowMargin,margin=Theme.panelMargin;
        let x=originX+point.x+anchorItem.width-implicitWidth+inset;
        let y=originY+point.y+anchorItem.height+Theme.panelGap-inset;
        if(edge==="bottom")y=originY-implicitHeight-Theme.panelGap+inset;
        else if(edge==="left") {x=hostWindow.width+Theme.panelGap-inset;y=point.y-inset;}
        else if(edge==="right") {x=screen.width-hostWindow.width-implicitWidth-Theme.panelGap+inset;y=point.y-inset;}
        x=Math.max(margin-inset,Math.min(screen.width-implicitWidth-margin+inset,x));
        y=Math.max(margin-inset,Math.min(screen.height-implicitHeight-margin+inset,y));
        placement=Qt.point(Math.round(x),Math.round(y));
    }
    function relayout() {
        if(!controller.opened || content.rowCount===0 && !slowLoading)return;
        surface.prepareLayout();reposition();ready=true;
        Qt.callLater(function(){if(window.visible)content.forceActiveFocus();});
    }
    function diagnostics() {
        return {visible:visible,depth:controller.depth,blurApplied:blur.applied,radius:Theme.radius,
            color:String(Theme.floaterSurface),x:screen ? screen.x+Math.round(placement.x) : 0,y:screen ? screen.y+Math.round(placement.y) : 0,
            width:width,height:height,items:content.geometry()};
    }
    onVisibleChanged:if(visible)Qt.callLater(function(){if(window.visible)content.forceActiveFocus();})
    onImplicitWidthChanged:if(ready)reposition()
    onImplicitHeightChanged:if(ready)reposition()
    onScreenChanged:if(ready && !screen)controller.close()
    onClosed:controller.close()
    Component.onCompleted:Qt.callLater(relayout)
    Component.onDestruction:grab.active=false
    Connections {target:controller;function onEntriesChanged(){Qt.callLater(window.relayout)}}
    Connections {
        target:content
        function onImplicitHeightChanged(){Qt.callLater(window.relayout)}
        function onRowCountChanged(){Qt.callLater(window.relayout)}
    }
    // A slow application gets a truthful loading surface, never an empty frame.
    Timer {interval:250;running:controller.opened && content.rowCount===0;onTriggered:{window.slowLoading=true;window.relayout()}}
    Connections {target:hostWindow;function onVisibleChanged(){if(!window.hostWindow.visible)window.controller.close()}}
    HyprlandFocusGrab {id:grab;windows:[window];active:window.visible;onCleared:controller.close()}
    BackdropEffect {id:blur;targetWindow:window;surface:surface.blurSurface;cornerRadius:Theme.radius;enabled:window.visible && SettingsStore.panelBlur>0}
    PopoverSurface {
        id:surface
        maximumHeight:window.screen ? window.screen.height-Theme.panelMargin*2 : 800
        TrayMenuContent {
            id:content
            width:Math.max(180,Math.min(300,window.screen ? window.screen.width-Theme.surfaceShadowInset*2-Theme.panelPadding*2-Theme.panelMargin*2 : 300))
            entries:controller.entries
            heading:controller.heading
            canGoBack:controller.depth>1
            onActivated:function(entry){controller.activate(entry)}
            onBackRequested:controller.back()
            onCloseRequested:controller.close()
            onRevealRequested:function(item){surface.reveal(item)}
        }
    }
}
