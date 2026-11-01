import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "../themes"
Item {
    id: adapter
    required property var targetWindow
    required property Item surface
    property bool blurEnabled: WindowService.blurAvailable
    property var region: Region { item:adapter.surface; radius:WindowService.maximized ? 0 : Theme.radius }
    function sync() {
        try {
            adapter.targetWindow.BackgroundEffect.blurRegion = blurEnabled ? region : null
            WindowService.blurRegionApplied = blurEnabled && adapter.targetWindow.BackgroundEffect.blurRegion === region
        }
        catch(error) {
            WindowService.blurAvailable=false
            WindowService.blurReason="Backdrop blur is unavailable on this surface."
        }
    }
    Component.onDestruction: {
        try { if(targetWindow) targetWindow.BackgroundEffect.blurRegion=null } catch(error) {}
        WindowService.blurRegionApplied=false
    }
    onBlurEnabledChanged: sync()
    onTargetWindowChanged: Qt.callLater(sync)
    Component.onCompleted: sync()
}
