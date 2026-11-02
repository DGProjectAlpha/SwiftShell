import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../services"
import "../themes"
import "../components"
import "../logic/overview.js" as Overview
PanelWindow {
    id:window
    screen:OverviewService.screen
    visible:OverviewService.open && OverviewService.screen!==null
    color:"transparent"
    surfaceFormat.opaque:false
    exclusionMode:ExclusionMode.Ignore
    anchors {top:true;bottom:true;left:true;right:true}
    WlrLayershell.namespace:"swiftshell-overview"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    readonly property var bounds:Overview.logicalMonitor(OverviewService.monitor || {width:1920,height:1080,scale:1})
    readonly property var layout:Overview.grid(width-96,height-156,OverviewService.workspaces.length,bounds.width/bounds.height)
    readonly property bool surfaceBlurApplied:backdrop.applied
    function diagnostics() {
        let ready=0,total=0;
        for(let i=0;i<cards.count;i++) {
            const card=cards.itemAt(i);
            for(const child of card.desktop.children)if(child.objectName==="overviewWindowTile"){total++;if(child.previewReady)ready++;}
        }
        return {open:visible,blurApplied:backdrop.applied,workspaces:cards.count,windows:total,previewsReady:ready,columns:layout.columns};
    }
    onVisibleChanged: {
        if(visible)Qt.callLater(function(){if(window.visible){grab.active=true;keyboard.forceActiveFocus();}});
        else grab.active=false;
    }
    Component.onDestruction:grab.active=false
    HyprlandFocusGrab {id:grab;windows:[window];onCleared:if(window.visible)OverviewService.closeOverview()}
    Rectangle {id:veil;anchors.fill:parent;color:Theme.floaterSurface}
    BackdropEffect {id:backdrop;targetWindow:window;surface:veil;cornerRadius:0;enabled:SettingsStore.panelBlur>0}
    MouseArea {anchors.fill:parent;onClicked:OverviewService.closeOverview()}
    Item {
        id:keyboard
        anchors.fill:parent;focus:true
        Keys.onEscapePressed:OverviewService.closeOverview()
        Keys.onReturnPressed:OverviewService.chooseWorkspace(OverviewService.selected)
        Keys.onLeftPressed:OverviewService.selected=Math.max(0,OverviewService.selected-1)
        Keys.onRightPressed:OverviewService.selected=Math.min(cards.count-1,OverviewService.selected+1)
        Keys.onUpPressed:OverviewService.selected=Math.max(0,OverviewService.selected-window.layout.columns)
        Keys.onDownPressed:OverviewService.selected=Math.min(cards.count-1,OverviewService.selected+window.layout.columns)
        Keys.onTabPressed:OverviewService.selected=(OverviewService.selected+1)%Math.max(1,cards.count)
        Text {
            x:48;y:32;text:"Workspaces";color:Theme.settingsText
            font.family:Theme.fontFamily;font.pixelSize:24;font.weight:Font.DemiBold
        }
        Text {
            x:48;y:68;text:OverviewService.monitor ? (OverviewService.monitor.model || OverviewService.monitor.name)+" · "+OverviewService.monitor.name : ""
            color:Theme.settingsMuted;font.family:Theme.fontFamily;font.pixelSize:Theme.fontSize
        }
        Grid {
            id:grid
            columns:window.layout.columns;spacing:18
            anchors.centerIn:parent
            Repeater {
                id:cards
                model:OverviewService.workspaces
                delegate:OverviewWorkspace {
                    required property var modelData
                    required property int index
                    workspace:modelData;monitor:OverviewService.monitor || {}
                    selected:index===OverviewService.selected
                    width:window.layout.width;height:window.layout.height
                    onActivated:OverviewService.chooseWorkspace(index)
                }
            }
        }
        Text {
            anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:24
            text:"Choose a window or workspace · Arrow keys to navigate · Esc to close"
            color:Theme.settingsMuted;font.family:Theme.fontFamily;font.pixelSize:Theme.fontSizeSmall
        }
    }
}
