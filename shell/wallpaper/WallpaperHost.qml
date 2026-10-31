import QtQuick
import Quickshell
import "../services"

Scope {
    Variants {
        model: Quickshell.screens
        WallpaperSurface {}
    }

    SlideshowClock {
        running: WallpaperModel.clockRunning
        intervalMs: WallpaperModel.intervalMs
        onFired: WallpaperModel.tick()
    }
}
