import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../logic/launcher.js" as Launcher
import "../services"
import "../themes"
import "../components"

PanelWindow {
    id: window
    color: Theme.transparent
    surfaceFormat.opaque: false
    screen: LauncherModel.screen
    visible: LauncherModel.open && LauncherModel.screen !== null
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: screen ? screen.width : 1
    implicitHeight: screen ? screen.height : 1
    WlrLayershell.namespace: "swiftshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property bool searchHasFocus: card.searchHasFocus
    readonly property bool surfaceBlurApplied: backdrop.applied
    readonly property var frame: Launcher.gridFrame(screen ? screen.width : 0,screen ? screen.height : 0)
    property bool dismissing: false
    property real reveal: 0
    function diagnostics() {return {frame:frame,blurApplied:backdrop.applied,card:card.geometry()};}
    function releaseInput() {card.releaseInput();focusGrab.active=false;}
    function focusField() {
        if(!visible || !LauncherModel.open) return;
        focusGrab.active=true;
        Qt.callLater(function() {
            if(!window.visible || !LauncherModel.open) return;
            card.focusInput();
            if(!card.searchHasFocus) Qt.callLater(function(){if(window.visible && LauncherModel.open)card.focusInput();});
        });
    }
    function dismiss() {
        if(dismissing || !LauncherModel.open) return;
        dismissing=true;releaseInput();LauncherModel.closeLauncher();dismissing=false;
    }
    onVisibleChanged: {
        if(visible) {
            reveal=Theme.reducedMotion ? 1 : 0;
            Qt.callLater(function(){if(window.visible)window.reveal=1;});
            focusField();
        } else {
            reveal=0;releaseInput();
            if(LauncherModel.open && LauncherModel.screen===null && !dismissing)dismiss();
        }
    }
    Connections {
        target:LauncherModel
        function onInputRequested(){window.focusField();}
    }
    Component.onDestruction: releaseInput()
    HyprlandFocusGrab {id:focusGrab;windows:[window];onCleared:window.dismiss();}
    MouseArea {anchors.fill:parent;onClicked:window.dismiss();}
    Loader {
        id:shadowLoader
        x:card.x;y:card.y;width:card.width;height:card.height
        opacity:card.opacity
        // Compile optionally: Qt 6.4 hosts retain a clean no-shadow fallback.
        Component.onCompleted: {
            const component=Qt.createComponent("../components/SurfaceShadow.qml");
            if(component.status===Component.Ready)sourceComponent=component;
        }
    }
    LauncherCard {
        id:card
        x:window.frame.x;y:window.frame.y;width:window.frame.width;height:window.frame.height
        opacity:Theme.reducedMotion ? 1 : window.reveal
        onCloseRequested:window.dismiss()
        Behavior on opacity {NumberAnimation {duration:Theme.motionOpen;easing.type:Easing.OutCubic;}}
    }
    BackdropEffect {id:backdrop;targetWindow:window;surface:card;cornerRadius:Theme.radius;enabled:SettingsStore.panelBlur>0;}
}
