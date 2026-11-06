import QtQuick
import Quickshell
import "../services"

Scope {
    id: root

    function diagnostics() {
        return wallpapers.instances.map(function(surface) { return surface.diagnostics() })
    }

    function refreshOutputs() {
        var names = []
        var screens = Quickshell.screens || []
        for (var index = 0; index < screens.length; index++) {
            var name = screens[index] && screens[index].name ? screens[index].name : ""
            if (name !== "")
                names.push(name)
        }
        WallpaperModel.setOutputs(names)
    }

    Component.onCompleted: refreshOutputs()

    Connections {
        target: Quickshell
        function onScreensChanged() { root.refreshOutputs() }
    }

    Variants {
        id: wallpapers
        model: Quickshell.screens
        WallpaperSurface {}
    }

    SlideshowClock {
        running: WallpaperModel.clockRunning
        intervalMs: WallpaperModel.intervalMs
        onFired: WallpaperModel.tick()
    }
}
