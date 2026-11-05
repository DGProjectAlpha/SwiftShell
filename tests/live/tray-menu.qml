//@ pragma ShellId swiftshell-themed-tray-audit
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "components"
import "services"
import "themes"
ShellRoot {
    id:audit
    property string selectedOutput:Quickshell.env("SWIFTSHELL_TRAY_OUTPUT")
    readonly property var output:Quickshell.screens.find(function(screen){return screen.name===audit.selectedOutput}) || Quickshell.screens[0]
    readonly property var entry:SystemTray.items.values.length ? SystemTray.items.values[0] : null
    PanelWindow {
        id:board
        screen:audit.output;visible:true;anchors {top:true;bottom:true;left:true;right:true}
        color:"#303030";exclusionMode:ExclusionMode.Ignore
        WlrLayershell.namespace:"swiftshell-tray-fixture-board";WlrLayershell.layer:WlrLayer.Overlay
        WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
        Canvas {anchors.fill:parent;onPaint:{const c=getContext("2d");for(let y=0;y<height;y+=16)for(let x=0;x<width;x+=16){c.fillStyle=(x+y)%32===0 ? "#777777" : "#303030";c.fillRect(x,y,16,16)}}}
    }
    PanelWindow {
        id:host
        screen:audit.output;visible:true;anchors {top:true;left:true}
        margins.left:120;margins.top:100
        property string edge:"top"
        signal dismissPopoutsRequested()
        implicitWidth:60;implicitHeight:36
        color:"#222222";exclusionMode:ExclusionMode.Ignore
        WlrLayershell.namespace:"swiftshell-tray-fixture-host";WlrLayershell.layer:WlrLayer.Overlay
        WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
        MouseArea {anchors.fill:parent;z:-1;onClicked:host.dismissPopoutsRequested()}
        TrayItemControl {id:control;entry:audit.entry;hostWindow:host;anchors.centerIn:parent}
    }
    IpcHandler {
        target:"audit"
        function state():string{return JSON.stringify({ready:SettingsStore.persistenceState==="ready",count:SystemTray.items.values.length,menuAvailable:control.menuAvailable,open:control.menuOpen,menu:control.menuDiagnostics(),light:Theme.lightSurface})}
        function theme(mode:string):void{SettingsStore.setAppearanceMode(mode)}
        function openMenu():bool{return control.showMenu()}
        function capture(path:string):bool {
            const popup=control.menuWindow;
            if(!popup || !popup.visible)return false;
            // An opaque fixture-only child prevents all unowned backdrop pixels
            // from entering this direct QML scene capture.
            const owned=Qt.createQmlObject('import QtQuick;Rectangle {anchors.fill:parent;z:-100;color:"#555555"}',popup.captureItem);
            Qt.callLater(function(){popup.captureItem.grabToImage(function(result){console.info("Owned menu capture",result.saveToFile(path));owned.destroy()})});
            return true;
        }
    }
}
