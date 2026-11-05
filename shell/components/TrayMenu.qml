import QtQuick
import Quickshell
import "../logic/menu.js" as Menu

// Every ancestor opener stays alive while visiting a submenu. Native menu
// entries can otherwise be destroyed as their parent's open reference closes.
Item {
    id:trayMenu
    property var hostWindow:null
    property Item anchorItem:null
    property bool nativeWindowEnabled:true
    property bool opened:false
    property var stack:[]
    readonly property int depth:stack.length
    readonly property var currentOpener:depth>0 && levels.count>=depth ? levels.itemAt(depth-1).opener : null
    readonly property var entries:currentOpener ? currentOpener.children : []
    readonly property string heading:depth ? stack[depth-1].title : "Application actions"
    readonly property var nativeWindow:windowLoader.item
    signal closed()
    function open(handle,title) {
        if(!handle || nativeWindowEnabled && (!hostWindow || !hostWindow.screen))return false;
        stack=[{handle:handle,title:title || "Application actions"}];opened=true;
        if(nativeWindowEnabled) {
            windowLoader.setSource(Qt.resolvedUrl("TrayMenuWindow.qml"),{controller:trayMenu});
            windowLoader.active=true;
        }
        return true;
    }
    function back() {if(depth>1)stack=stack.slice(0,-1);else close();}
    function close() {
        if(!opened)return;
        opened=false;windowLoader.active=false;stack=[];closed();
    }
    function activate(entry) {
        if(!entry || entry.enabled===false || entry.isSeparator===true)return false;
        if(entry.hasChildren===true) {
            if(depth>=16)return false;
            stack=stack.concat([{handle:entry,title:Menu.caption(entry.text || "Application actions")}]);
            // DBusMenuItem exposes this optional public refresh on 0.3.2.
            // Other native QsMenuEntry implementations need only the opener.
            if(typeof entry.updateLayout==="function")entry.updateLayout();
        } else {
            // Do not destroy an entry synchronously inside its own signal.
            entry.triggered();Qt.callLater(trayMenu.close);
        }
        return true;
    }
    function diagnostics() {return nativeWindow && nativeWindow.diagnostics ? nativeWindow.diagnostics() : {visible:false,depth:depth};}
    onHostWindowChanged:if(opened)close()
    onAnchorItemChanged:if(opened && !anchorItem)close()
    Connections {
        target:trayMenu.hostWindow
        ignoreUnknownSignals:true
        function onDismissPopoutsRequested(){trayMenu.close()}
    }
    Component.onDestruction:close()
    Repeater {
        id:levels
        model:16
        delegate:Item {
            required property int index
            visible:false
            property alias opener:nativeOpener
            QsMenuOpener {id:nativeOpener;menu:index<trayMenu.depth ? trayMenu.stack[index].handle : null}
        }
    }
    Loader {id:windowLoader;active:false}
}
