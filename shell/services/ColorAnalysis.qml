pragma Singleton

import QtQuick
import Quickshell
import "../logic/contrast.js" as Contrast
import "../logic/inflate.js" as Inflate
import "../logic/png.js" as Png
import "../logic/wallpaper.js" as Wallpaper

Singleton {
    id: root

    property int requestId: 0
    property var sample: ({
        available: false,
        reason: "Automatic contrast is off.",
        scrim: false,
        foreground: "",
        accent: ({ r: 128, g: 128, b: 128 })
    })

    function blank(reason) {
        return {
            available: false,
            reason: reason,
            scrim: false,
            foreground: "",
            accent: { r: 128, g: 128, b: 128 }
        }
    }

    function refresh() {
        root.requestId += 1
        if (!SettingsStore.automaticText && !SettingsStore.automaticGradient) {
            root.sample = root.blank("Automatic contrast is off.")
            return
        }
        var path = Wallpaper.samplePath(SettingsStore.slideshow, WallpaperModel.shownPath, SettingsStore.wallpaperPath)
        var choice = Wallpaper.resolveSource(path)
        if (choice.source !== "file") {
            root.readUrl(Qt.resolvedUrl("../assets/wallpapers/swiftshell-default-crimson.png"))
            return
        }
        var lower = choice.path.toLowerCase()
        if (lower.length < 4 || lower.lastIndexOf(".png") !== lower.length - 4) {
            root.sample = root.blank("Jpeg and webp are displayed, but only png pixels can be sampled in this build.")
            return
        }
        root.readUrl(Wallpaper.fileUrl(choice.path))
    }

    function readUrl(url) {
        var token = root.requestId
        Png.bindInflate(Inflate.inflateZlib)
        var request = new XMLHttpRequest()
        request.open("GET", url)
        request.responseType = "arraybuffer"
        request.onreadystatechange = function () {
            if (token !== root.requestId)
                return
            if (request.readyState !== XMLHttpRequest.DONE)
                return
            if (!request.response) {
                root.sample = root.blank("The png could not be read.")
                return
            }
            var decoded = Png.decodePng(request.response)
            root.sample = Contrast.analyzeBands(Png.topBands(decoded, 8), root.sample)
        }
        request.send()
    }

    Component.onCompleted: refresh()

    Connections {
        target: SettingsStore
        function onWallpaperPathChanged() { root.refresh() }
        function onAutomaticTextChanged() { root.refresh() }
        function onAutomaticGradientChanged() { root.refresh() }
        function onSlideshowChanged() { root.refresh() }
    }

    Connections {
        target: WallpaperModel
        function onShownPathChanged() { root.refresh() }
    }
}
