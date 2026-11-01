import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
Item {
    id: effect
    required property var targetWindow
    required property Item surface
    property real cornerRadius: 0
    readonly property bool applied: enabled && SurfaceService.blurAvailable && regionApplied && surface !== null && surface.width>0 && surface.height>0
    property bool regionApplied: false
    property var region: Region { item: effect.surface; radius:effect.cornerRadius }
    function sync() {
        if (!targetWindow) return
        try {
            const wanted=enabled && SurfaceService.blurAvailable
            targetWindow.BackgroundEffect.blurRegion=wanted ? region : null
            regionApplied=wanted && targetWindow.BackgroundEffect.blurRegion === region
        } catch(error) {
            regionApplied=false
            SurfaceService.blurAvailable=false
            SurfaceService.reason="Backdrop blur is unavailable on this surface."
        }
    }
    onEnabledChanged: sync()
    onTargetWindowChanged: Qt.callLater(sync)
    Connections {
        target: SurfaceService
        function onBlurAvailableChanged() { effect.sync() }
    }
    Component.onCompleted: sync()
    Component.onDestruction: {
        try {
            if (targetWindow && targetWindow.BackgroundEffect.blurRegion === region)
                targetWindow.BackgroundEffect.blurRegion=null
        } catch(error) {}
    }
}
