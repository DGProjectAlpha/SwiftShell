import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../components"
import "../popovers"
import "../services"
import "../themes"
PanelWindow {
    id:window
    visible:ScreenshotService.open && ScreenshotService.screen!==null
    screen:ScreenshotService.screen
    color:"transparent"
    surfaceFormat.opaque:false
    exclusionMode:ExclusionMode.Ignore
    implicitWidth:screen ? screen.width : 1
    implicitHeight:screen ? screen.height : 1
    WlrLayershell.namespace:"swiftshell-screenshot"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:visible && !window.saving ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // Capture is a persistent utility, not a dismiss-on-focus-loss popover.
    // Only the card accepts input; the surrounding desktop stays interactive.
    mask:Region {item:surface}
    property bool saving:false
    readonly property bool surfaceBlurApplied:backdrop.applied
    function diagnostics(){return {visible:visible,blurApplied:backdrop.applied,hasImage:ScreenshotService.hasImage,busy:ScreenshotService.busy,saving:saving,frame:{x:surface.x,y:surface.y,width:surface.width,height:surface.height}}}
    onClosed:ScreenshotService.close()
    BackdropEffect {id:backdrop;targetWindow:window;surface:surface.blurSurface;cornerRadius:Theme.radius;enabled:window.visible && SettingsStore.panelBlur>0}
    PopoverSurface {
        id:surface
        x:Math.round((window.width-width)/2)
        y:Math.round((window.height-height)/2)
        focus:true
        maximumHeight:window.screen ? window.screen.height-Theme.panelMargin*2 : 700
        Keys.onEscapePressed:ScreenshotService.close()
        ScreenshotPanel {}
        Loader {
            id:dialogLoader
            objectName:"screenshotSaveDialogLoader"
            active:false
            source:"ScreenshotSaveDialog.qml"
            onLoaded: {
                window.saving=true
                item.open()
            }
            onStatusChanged:if(status===Loader.Error){window.saving=false;ScreenshotService.saveDialogUnavailable()}
        }
    }
    Connections {
        target:ScreenshotService
        function onSaveRequested(){if(dialogLoader.item){window.saving=true;dialogLoader.item.open()}else dialogLoader.active=true}
    }
    Connections {
        target:dialogLoader.item
        function onVisibleChanged(){if(dialogLoader.item && !dialogLoader.item.visible)window.saving=false}
    }
}
